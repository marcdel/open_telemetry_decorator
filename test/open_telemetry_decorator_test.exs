defmodule OpenTelemetryDecoratorTest do
  use ExUnit.Case, async: true
  doctest OpenTelemetryDecorator

  require OpenTelemetry.Tracer
  require OpenTelemetry.Span

  # Make span methods available
  require Record

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/ot_span.hrl") do
    Record.defrecord(name, spec)
  end

  setup [:telemetry_pid_reporter]

  defmodule Example do
    use OpenTelemetryDecorator

    @decorate trace(name: "Example.step", include: [:id, :result])
    def step(id), do: {:ok, id}

    @decorate trace(name: "Example.workflow", include: [:count, :result])
    def workflow(count), do: Enum.map(1..count, fn id -> step(id) end)

    @decorate trace(name: "Example.numbers", include: [:up_to])
    def numbers(up_to), do: [1..up_to]

    @decorate trace(name: "Example.find", include: [:id, [:user, :name], :error, :_even, :result])
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

    @decorate trace(name: "Example.no_include")
    def no_include(opts), do: {:ok, opts}

    @decorate trace(include: [:opts])
    def default_name(opts), do: {:ok, opts}

    @decorate trace()
    def default_name_no_include(opts), do: {:ok, opts}
  end

  describe "trace" do
    test "does not modify inputs or function result" do
      assert Example.step(1) == {:ok, 1}
    end

    test "automatically links spans" do
      Example.workflow(2)

      assert_receive {:span,
                      span(
                        name: "Example.workflow",
                        trace_id: parent_trace_id,
                        attributes: [result: "[ok: 1, ok: 2]", count: 2]
                      )}

      assert_receive {:span,
                      span(
                        name: "Example.step",
                        trace_id: ^parent_trace_id,
                        attributes: [result: {:ok, 1}, id: 1]
                      )}

      assert_receive {:span,
                      span(
                        name: "Example.step",
                        trace_id: ^parent_trace_id,
                        attributes: [result: {:ok, 2}, id: 2]
                      )}
    end

    test "handles simple attributes" do
      Example.find(1)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert Keyword.fetch!(attrs, :id) == 1
    end

    test "handles nested attributes" do
      Example.find(1)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert Keyword.fetch!(attrs, :user_name) == "my user"
    end

    test "handles handles underscored attributes" do
      Example.find(2)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert Keyword.fetch!(attrs, :even) == true
    end

    test "does not include result unless asked for" do
      Example.numbers(1000)
      assert_receive {:span, span(name: "Example.numbers", attributes: attrs)}
      assert Keyword.has_key?(attrs, :result) == false
    end

    test "does not include variables not in scope when the function exists" do
      Example.find(098)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert Keyword.has_key?(attrs, :error) == false
    end

    test "does not include anything unless specified" do
      Example.no_include(include_me: "nope")
      assert_receive {:span, span(name: "Example.no_include", attributes: [])}
    end

    test "span name is generated if not given" do
      Example.default_name(a: 12)

      assert_receive {:span,
                      span(
                        name: "OpenTelemetryDecoratorTest.Example.default_name/1",
                        attributes: [opts: "[a: 12]"]
                      )}
    end

    test "can be called with no args" do
      Example.default_name_no_include(a: 42)

      assert_receive {:span,
                      span(
                        name: "OpenTelemetryDecoratorTest.Example.default_name_no_include/1",
                        attributes: []
                      )}
    end
  end

  def telemetry_pid_reporter(_) do
    ExUnit.CaptureLog.capture_log(fn -> :application.stop(:opentelemetry) end)

    :application.set_env(:opentelemetry, :tracer, :ot_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:ot_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :ot_batch_processor.set_exporter(:ot_exporter_pid, self())

    :ok
  end
end
