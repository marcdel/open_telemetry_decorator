defmodule OpenTelemetryDecoratorTest do
  use ExUnit.Case, async: true
  doctest OpenTelemetryDecorator

  require OpenTelemetry.Tracer
  require OpenTelemetry.Span

  require Record

  # Make span methods available
  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/otel_span.hrl") do
    Record.defrecord(name, spec)
  end

  setup [:telemetry_pid_reporter]

  def get_span_attributes(attributes) do
    # https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry/src/otel_attributes.erl#L26-L31
    # e.g. {:attributes, 128, :infinity, 0, %{count: 2}}
    {:attributes, _, :infinity, _, attr} = attributes
    attr
  end

  def get_span_events(events) do
    # https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry/src/otel_attributes.erl#L26-L31
    # e.g. {:events, 128, 128, :infinity, 0, []}
    {:events, _, _, :infinity, _, event_list} = events
    event_list
  end

  describe "trace" do
    defmodule Example do
      use OpenTelemetryDecorator

      @decorate trace("Example.step", include: [:id, :result])
      def step(id), do: {:ok, id}

      @decorate trace("Example.workflow", include: [:count, :result])
      def workflow(count), do: Enum.map(1..count, fn id -> step(id) end)

      @decorate trace("Example.numbers", include: [:up_to])
      def numbers(up_to), do: [1..up_to]

      @decorate trace("Example.find", include: [:id, [:user, :name], :error, :_even, :result])
      def find(id) do
        _even = rem(id, 2) == 0
        user = %{id: id, name: "my user"}

        case id do
          1 ->
            {:ok, user}

          error ->
            {:error, error}
        end
      end

      @decorate trace("Example.no_include")
      def no_include(opts), do: {:ok, opts}

      @decorate trace("Example.with_exception")
      def with_exception, do: File.read!("fake file")
    end

    test "does not modify inputs or function result" do
      assert Example.step(1) == {:ok, 1}
    end

    test "automatically links spans" do
      Example.workflow(2)

      assert_receive {:span,
                      span(
                        name: "Example.workflow",
                        trace_id: parent_trace_id,
                        attributes: attrs
                      )}

      assert %{count: 2} = get_span_attributes(attrs)

      assert_receive {:span,
                      span(
                        name: "Example.step",
                        trace_id: ^parent_trace_id,
                        attributes: attrs
                      )}

      assert %{id: 1} = get_span_attributes(attrs)

      assert_receive {:span,
                      span(
                        name: "Example.step",
                        trace_id: ^parent_trace_id,
                        attributes: attrs
                      )}

      assert %{id: 2} = get_span_attributes(attrs)
    end

    test "handles simple attributes" do
      Example.find(1)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert %{id: 1} = get_span_attributes(attrs)
    end

    test "handles nested attributes" do
      Example.find(1)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert %{user_name: "my user"} = get_span_attributes(attrs)
    end

    test "handles handles underscored attributes" do
      Example.find(2)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert %{even: true} = get_span_attributes(attrs)
    end

    test "converts atoms to strings" do
      Example.step(:two)
      assert_receive {:span, span(name: "Example.step", attributes: attrs)}
      assert %{id: ":two"} = get_span_attributes(attrs)
    end

    test "does not include result unless asked for" do
      Example.numbers(1000)
      assert_receive {:span, span(name: "Example.numbers", attributes: attrs)}
      assert Map.has_key?(get_span_attributes(attrs), :result) == false
    end

    test "does not include variables not in scope when the function exists" do
      Example.find(098)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert Map.has_key?(get_span_attributes(attrs), :error) == false
    end

    test "does not include anything unless specified" do
      Example.no_include(include_me: "nope")
      assert_receive {:span, span(name: "Example.no_include", attributes: attrs)}
      assert %{} == get_span_attributes(attrs)
    end

    test "records an exception event" do
      try do
        Example.with_exception()
        flunk("Should have re-raised the exception")
      rescue
        e ->
          assert Exception.format(:error, e, __STACKTRACE__) =~ "File.read!/1"
          assert_receive {:span, span(name: "Example.with_exception", events: events)}
          assert [{:event, _, "exception", _}] = get_span_events(events)
      end
    end

    # The assumption here is that if an exception bubbles up
    # outside of the current span, we can consider it "unhandled"
    # and set the status to error.
    test "sets the status of the span to error" do
      try do
        Example.with_exception()
      rescue
        _ ->
          assert_receive {:span, span(name: "Example.with_exception", status: status)}
          assert {:status, :error, ""} = status
      end
    end
  end

  def telemetry_pid_reporter(_) do
    ExUnit.CaptureLog.capture_log(fn -> :application.stop(:opentelemetry) end)

    :application.set_env(:opentelemetry, :tracer, :otel_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:otel_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    :ok
  end
end
