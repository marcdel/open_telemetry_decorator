defmodule OpenTelemetryDecoratorTest do
  use ExUnit.Case, async: false
  use O11y.TestHelper

  require OpenTelemetry.Tracer, as: Tracer

  doctest OpenTelemetryDecorator

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

    defmodule User do
      @derive {O11y.SpanAttributes, only: [:id, :name]}
      defstruct [:id, :name]
    end

    defmodule Example do
      use OpenTelemetryDecorator
      alias OpenTelemetryDecorator.AttributesV1, as: Attributes

      @decorate with_span("Example.step", include: [:id, :result])
      def step(id), do: {:ok, id}

      @decorate with_span("Example.workflow", include: [:count, :result])
      def workflow(count), do: Enum.map(1..count, fn id -> step(id) end)

      @decorate with_span("Example.numbers", include: [:up_to])
      def numbers(up_to), do: [1..up_to]

      @decorate with_span("Example.find", include: [:id, :user, :error, :_even, :result])
      def find(id) do
        _even = rem(id, 2) == 0
        user = %User{id: id, name: "my user"}

        case id do
          1 -> {:ok, user}
          error -> {:error, error}
        end
      end

      @decorate with_span("Example.parse_params", include: [:params])
      def parse_params(params) do
        %{"id" => id} = params

        id
      end

      @decorate with_span("Example.no_include")
      def no_include(opts), do: {:ok, opts}

      @decorate with_span("Example.exception_parent")
      def exception_parent(child_fn) do
        child_fn.()
      end

      @decorate with_span("Example.with_exception", include: [:file_name, :body_var])
      def with_exception(file_name) do
        body_var = "hello!"
        File.read!("#{file_name}.#{body_var}")
      end

      @decorate with_span("Example.with_exit")
      def with_exit(exit_args) do
        exit(exit_args)
      end

      @decorate with_span("Example.with_process_exit")
      def with_process_exit(exit_args) do
        exit(exit_args)
      end

      @decorate with_span("Example.with_throw")
      def with_throw(throw_args) do
        throw(throw_args)
      end

      @decorate with_span("Example.with_error")
      def with_error, do: Attributes.set(:error, "ruh roh!")

      @decorate with_span("Example.with_link", links: [:_span_link])
      def with_link(_span_link), do: :ok
    end

    test "does not modify inputs or function result" do
      assert Example.step(1) == {:ok, 1}
    end

    test "automatically links spans" do
      Example.workflow(2)

      workflow_span = assert_span("Example.workflow")
      assert %{"app.count" => 2} = workflow_span.attributes

      step_span = assert_span("Example.step")
      assert workflow_span.span_id == step_span.parent_span_id
      assert %{"app.id" => 1} = step_span.attributes

      step_span = assert_span("Example.step")
      assert workflow_span.span_id == step_span.parent_span_id
      assert %{"app.id" => 2} = step_span.attributes
    end

    test "can manually link spans" do
      related_span = Tracer.start_span("related-stuff")
      Tracer.end_span(related_span)

      span_ctx(trace_id: linked_trace_id, span_id: linked_span_id) = related_span

      related_span
      |> OpenTelemetry.link()
      |> Example.with_link()

      span = assert_span("Example.with_link")
      assert [%{trace_id: ^linked_trace_id, span_id: ^linked_span_id}] = span.links
    end

    test "handles simple attributes" do
      Example.find(1)

      span = assert_span("Example.find")
      assert %{"app.id" => 1} = span.attributes
    end

    test "handles structs" do
      Example.find(1)

      span = assert_span("Example.find")

      assert %{
               "app.user.id" => 1,
               "app.user.name" => "my user"
             } = span.attributes
    end

    test "handles maps with string keys" do
      Example.parse_params(%{"id" => 12})

      span = assert_span("Example.parse_params")
      assert %{"app.params.id" => 12} = span.attributes
    end

    test "handles handles underscored attributes" do
      Example.find(2)

      span = assert_span("Example.find")
      assert %{"app.even" => true} = span.attributes
    end

    test "does not include result unless asked for" do
      Example.numbers(1000)

      span = assert_span("Example.numbers")
      refute Map.has_key?(span.attributes, :result)
    end

    test "does not include variables not in scope when the function exits" do
      Example.find(098)

      span = assert_span("Example.find")
      refute Map.has_key?(span.attributes, "error")
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

      span = assert_span("param_override")
      assert %{"app.x" => 1, "app.y" => 1} = span.attributes
    end

    test "does not write input parameters not in the include" do
      defmodule InputExample do
        use OpenTelemetryDecorator

        @decorate with_span("inputs", include: [:x])
        def inputs(x, y) do
          z = x + y
          {:ok, z}
        end
      end

      assert {:ok, 3} = InputExample.inputs(1, 2)

      span = assert_span("inputs")
      assert span.attributes == %{"app.x" => 1}
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

      span = assert_span("ExampleResult.add")
      %{"app.result" => 10} = span.attributes
    end

    test "does not include anything unless specified" do
      Example.no_include(include_me: "nope")

      span = assert_span("Example.no_include")
      assert %{} == span.attributes
    end

    test "records an exception event" do
      try do
        Example.with_exception("fake file")
        flunk("Should have re-raised the exception")
      rescue
        e ->
          assert Exception.format(:error, e, __STACKTRACE__) =~ "File.read!/1"
          span = assert_span("Example.with_exception")
          assert [%{name: "exception"}] = span.events
      end
    end

    test "catches exits, sets errors, and re-throws" do
      try do
        Example.with_exit(%{bad: :times})
        flunk("Should have re-raised the exception")
      catch
        :exit, %{bad: :times} ->
          span = assert_span("Example.with_exit")
          assert span.status.code == :error
          assert span.status.message == "exited: %{bad: :times}"
      end
    end

    test "normal exits don't throw or set errors" do
      try do
        Example.with_exit(:normal)
        flunk("Should have continued normal exit")
      catch
        :exit, :normal ->
          span = assert_span("Example.with_exit")
          assert span.status.code == :unset
          assert span.status.message == ""
      end
    end

    test "normal exits add an exit attribute" do
      try do
        Example.with_exit(:normal)
        flunk("Should have continued normal exit")
      catch
        :exit, :normal ->
          span = assert_span("Example.with_exit")
          assert span.attributes == %{"app.exit" => :normal}
      end
    end

    test "shutdowns don't throw or set errors" do
      try do
        Example.with_exit(:shutdown)
        flunk("Should have continued normal shutdown")
      catch
        :exit, :shutdown ->
          span = assert_span("Example.with_exit")
          assert span.status.code == :unset
          assert span.status.message == ""
      end
    end

    test "shutdowns add an exit attribute" do
      try do
        Example.with_exit(:shutdown)
        flunk("Should have continued normal shutdown")
      catch
        :exit, :shutdown ->
          span = assert_span("Example.with_exit")
          assert span.attributes == %{"app.exit" => :shutdown}
      end
    end

    test "shutdowns with a reason don't throw or set errors" do
      try do
        Example.with_exit({:shutdown, :chillin})
        flunk("Should have continued normal shutdown")
      catch
        :exit, {:shutdown, _reason} ->
          span = assert_span("Example.with_exit")
          assert span.status.code == :unset
          assert span.status.message == ""
      end
    end

    test "shutdowns with a reason add exit and shutdown_reason attributes" do
      try do
        Example.with_exit({:shutdown, %{just: :chillin}})
        flunk("Should have continued normal shutdown")
      catch
        :exit, {:shutdown, _reason} ->
          span = assert_span("Example.with_exit")

          assert span.attributes == %{
                   "app.exit" => :shutdown,
                   "app.shutdown_reason.just" => :chillin
                 }
      end
    end

    test "catches throws, sets errors, and re-throws" do
      try do
        Example.with_throw(%{catch: :this})
        flunk("Should have re-raised the exception")
      catch
        :throw, %{catch: :this} ->
          span = assert_span("Example.with_throw")
          assert span.status.code == :error
          assert span.status.message == "uncaught: %{catch: :this}"
      end
    end

    test "adds included input params on exception" do
      try do
        Example.with_exception("fake file")
        flunk("Should have re-raised a File.read!/1 exception")
      rescue
        _ ->
          span = assert_span("Example.with_exception")
          %{"app.file_name" => "fake file"} = span.attributes
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
          span = assert_span("Example.with_exception")
          assert span.status.code == :error
          assert span.status.message =~ ""
      end
    end

    test "reraise causes the parent's status to be set to error" do
      try do
        Example.exception_parent(fn ->
          Example.with_exception("fake file")
        end)
      rescue
        _ ->
          span = assert_span("Example.with_exception")
          assert span.status.code == :error
          assert span.status.message =~ ""

          span = assert_span("Example.exception_parent")
          assert span.status.code == :error
          assert span.status.message =~ ""
      end
    end

    test "can set the error attribute on the span" do
      Example.with_error()

      span = assert_span("Example.with_error")
      %{"error" => "ruh roh!"} = span.attributes
    end

    test "handles current and parent span correctly" do
      defmodule CurrentSpanExample do
        use OpenTelemetryDecorator

        @decorate with_span("CurrentSpanExample.outer")
        def outer do
          before_ctx = Tracer.current_span_ctx()
          inner(before_ctx)
          after_ctx = Tracer.current_span_ctx()

          assert before_ctx == after_ctx
        end

        @decorate with_span("CurrentSpanExample.inner")
        def inner(parent_ctx) do
          assert parent_ctx != Tracer.current_span_ctx()
        end
      end

      CurrentSpanExample.outer()

      parent_span = assert_span("CurrentSpanExample.outer")
      child_span = assert_span("CurrentSpanExample.inner")

      assert parent_span.span_id == child_span.parent_span_id
    end
  end
end
