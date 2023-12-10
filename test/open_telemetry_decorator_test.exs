defmodule OpenTelemetryDecoratorTest do
  use ExUnit.Case, async: false
  use OtelHelper

  doctest OpenTelemetryDecorator

  setup [:otel_pid_reporter]

  describe "with_span" do
    setup do
      prev = Application.get_env(:open_telemetry_decorator, :attr_joiner)
      Application.put_env(:open_telemetry_decorator, :attr_joiner, "_")
      on_exit(fn -> Application.put_env(:open_telemetry_decorator, :attr_joiner, prev) end)
    end

    setup do
      prev = Application.get_env(:open_telemetry_decorator, :attr_prefix)
      Application.put_env(:open_telemetry_decorator, :attr_prefix, "app.")
      on_exit(fn -> Application.put_env(:open_telemetry_decorator, :attr_prefix, prev) end)
    end

    defmodule Example do
      use OpenTelemetryDecorator

      @decorate with_span("Example.step", include: [:id, :result])
      def step(id), do: {:ok, id}

      @decorate with_span("Example.workflow", include: [:count, :result])
      def workflow(count), do: Enum.map(1..count, fn id -> step(id) end)

      @decorate with_span("Example.numbers", include: [:up_to])
      def numbers(up_to), do: [1..up_to]

      @decorate with_span("Example.find", include: [:id, [:user, :name], :error, :_even, :result])
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

      @decorate with_span("Example.parse_params", include: [[:params, "id"]])
      def parse_params(params) do
        %{"id" => id} = params

        id
      end

      @decorate with_span("Example.no_include")
      def no_include(opts), do: {:ok, opts}

      @decorate with_span("Example.with_exception", include: [:file_name, :body_var])
      def with_exception(file_name) do
        body_var = "hello!"
        File.read!("#{file_name}.#{body_var}")
      end

      @decorate with_span("Example.with_error")
      def with_error, do: OpenTelemetryDecorator.Attributes.set(:error, "ruh roh!")

      @decorate with_span("Example.with_attributes", attributes: [foo: "bar", baz: "qux"])
      def with_attributes, do: :ok

      @decorate with_span("Example.with_attrs_and_include",
                  attributes: [foo: "bar", baz: "qux"],
                  include: [:opts]
                )
      def with_attrs_and_include(opts), do: {:ok, opts}

      @decorate with_span("Example.with_attrs_and_conflicts",
                  attributes: [foo: "bar"],
                  include: [:foo]
                )
      def with_attrs_and_conflicts(foo), do: {:ok, foo}
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

      assert %{"app.count" => 2} = get_span_attributes(attrs)

      assert_receive {:span,
                      span(
                        name: "Example.step",
                        trace_id: ^parent_trace_id,
                        attributes: attrs
                      )}

      assert %{"app.id" => 1} = get_span_attributes(attrs)

      assert_receive {:span,
                      span(
                        name: "Example.step",
                        trace_id: ^parent_trace_id,
                        attributes: attrs
                      )}

      assert %{"app.id" => 2} = get_span_attributes(attrs)
    end

    test "handles simple attributes" do
      Example.find(1)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert %{"app.id" => 1} = get_span_attributes(attrs)
    end

    test "handles nested attributes" do
      Example.find(1)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert %{"app.user_name" => "my user"} = get_span_attributes(attrs)
    end

    test "handles maps with string keys" do
      Example.parse_params(%{"id" => 12})
      assert_receive {:span, span(name: "Example.parse_params", attributes: attrs)}
      assert %{"app.params_id" => 12} = get_span_attributes(attrs)
    end

    test "handles handles underscored attributes" do
      Example.find(2)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert %{"app.even" => true} = get_span_attributes(attrs)
    end

    test "converts atoms to strings" do
      Example.step(:two)
      assert_receive {:span, span(name: "Example.step", attributes: attrs)}
      assert %{"app.id" => ":two"} = get_span_attributes(attrs)
    end

    test "does not include result unless asked for" do
      Example.numbers(1000)
      assert_receive {:span, span(name: "Example.numbers", attributes: attrs)}
      assert Map.has_key?(get_span_attributes(attrs), :result) == false
    end

    test "does not include variables not in scope when the function exists" do
      Example.find(098)
      assert_receive {:span, span(name: "Example.find", attributes: attrs)}
      assert Map.has_key?(get_span_attributes(attrs), "error") == false
    end

    test "does not overwrite input parameters" do
      defmodule OverwriteExample do
        use OpenTelemetryDecorator

        @decorate with_span("param_override", include: [:x, :y])
        def param_override(x, y) do
          x = x + 1

          {:ok, x + y}
        end
      end

      assert {:ok, 3} = OverwriteExample.param_override(1, 1)

      assert_receive {:span, span(name: "param_override", attributes: attrs)}
      assert Map.get(get_span_attributes(attrs), "app.x") == 1
    end

    test "overwrites the default result value" do
      defmodule ExampleResult do
        use OpenTelemetryDecorator

        @decorate with_span("ExampleResult.add", include: [:a, :b, :result])
        def add(a, b) do
          a + b
        end
      end

      ExampleResult.add(5, 5)
      assert_receive {:span, span(name: "ExampleResult.add", attributes: attrs)}
      assert Map.get(get_span_attributes(attrs), "app.result") == 10
    end

    test "supports nested results" do
      defmodule NestedResult do
        use OpenTelemetryDecorator

        @decorate with_span("ExampleResult.make_struct", include: [:a, :b, [:result, :sum]])
        def make_struct(a, b) do
          %{sum: a + b}
        end
      end

      NestedResult.make_struct(5, 5)
      assert_receive {:span, span(name: "ExampleResult.make_struct", attributes: attrs)}
      assert Map.get(get_span_attributes(attrs), "app.result_sum") == 10
    end

    test "does not include anything unless specified" do
      Example.no_include(include_me: "nope")
      assert_receive {:span, span(name: "Example.no_include", attributes: attrs)}
      assert %{} == get_span_attributes(attrs)
    end

    test "records an exception event" do
      try do
        Example.with_exception("fake file")
        flunk("Should have re-raised the exception")
      rescue
        e ->
          assert Exception.format(:error, e, __STACKTRACE__) =~ "File.read!/1"
          assert_receive {:span, span(name: "Example.with_exception", events: events)}
          assert [{:event, _, "exception", _}] = get_span_events(events)
      end
    end

    test "adds included input params on exception" do
      try do
        Example.with_exception("fake file")
        flunk("Should have re-raised a File.read!/1 exception")
      rescue
        _ ->
          expected = %{"app.file_name" => "fake file"}
          assert_receive {:span, span(name: "Example.with_exception", attributes: attrs)}
          assert get_span_attributes(attrs) == expected
      end
    end

    # The assumption here is that if an exception bubbles up
    # outside of the current span, we can consider it "unhandled"
    # and set the status to error.
    test "sets the status of the span to error" do
      try do
        Example.with_exception("fake file")
      rescue
        _ ->
          assert_receive {:span, span(name: "Example.with_exception", status: status)}
          assert {:status, :error, ""} = status
      end
    end

    test "can set the error attribute on the span" do
      Example.with_error()
      assert_receive {:span, span(name: "Example.with_error", attributes: attrs)}
      expected = %{"error" => "ruh roh!"}
      assert get_span_attributes(attrs) == expected
    end

    test "can set the span.kind on the span" do
      defmodule SpanKinds do
        use OpenTelemetryDecorator

        @decorate with_span("SpanKinds.producer", kind: :producer)
        def producer do
          :ok
        end

        @decorate with_span("SpanKinds.consumer", kind: :consumer)
        def consumer do
          :ok
        end

        @decorate with_span("SpanKinds.internal", kind: :internal)
        def internal do
          :ok
        end

        @decorate with_span("SpanKinds.client", kind: :client)
        def client do
          :ok
        end

        @decorate with_span("SpanKinds.server", kind: :server)
        def server do
          :ok
        end

        @decorate with_span("SpanKinds.invalid", kind: :invalid)
        def invalid do
          :ok
        end
      end

      SpanKinds.producer()
      assert_receive {:span, span(name: "SpanKinds.producer", kind: :producer)}

      SpanKinds.consumer()
      assert_receive {:span, span(name: "SpanKinds.consumer", kind: :consumer)}

      SpanKinds.client()
      assert_receive {:span, span(name: "SpanKinds.client", kind: :client)}

      SpanKinds.server()
      assert_receive {:span, span(name: "SpanKinds.server", kind: :server)}

      SpanKinds.internal()
      assert_receive {:span, span(name: "SpanKinds.internal", kind: :internal)}

      # using an invalid span.kind will default to :internal
      SpanKinds.invalid()
      assert_receive {:span, span(name: "SpanKinds.invalid", kind: :internal)}
    end

    test "can set attributes on the span" do
      Example.with_attributes()
      assert_receive {:span, span(name: "Example.with_attributes", attributes: attrs)}
      assert %{"app.baz" => "qux", "app.foo" => "bar"} == get_span_attributes(attrs)
    end

    test "can set attributes and input params on the span" do
      Example.with_attrs_and_include(:include_me)
      assert_receive {:span, span(name: "Example.with_attrs_and_include", attributes: attrs)}

      assert %{"app.baz" => "qux", "app.foo" => "bar", "app.opts" => ":include_me"} ==
               get_span_attributes(attrs)
    end

    test "can set attributes and input params on the span, where attributes win with conflicting names" do
      Example.with_attrs_and_conflicts("not_bar")
      assert_receive {:span, span(name: "Example.with_attrs_and_conflicts", attributes: attrs)}
      assert %{"app.foo" => "bar"} == get_span_attributes(attrs)
    end
  end
end
