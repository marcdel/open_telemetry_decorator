defmodule OpenTelemetryDecorator.AttributesV2Test do
  use ExUnit.Case, async: false
  use OtelHelper

  alias OpenTelemetryDecorator.AttributesV2, as: Attributes

  setup [:otel_pid_reporter]

  defmodule SomeStruct do
    defstruct [:beep, :count, :maths, :failed]
  end

  describe "set" do
    test "sets unchanged otlp attributes on the current span" do
      Tracer.with_span "important_stuff" do
        Attributes.set(:beep, "boop")
        Attributes.set(:count, 12)
        Attributes.set(:maths, 1.2)
        Attributes.set(:failed, true)
      end

      assert_receive {:span, span(name: "important_stuff", attributes: attrs)}

      assert get_span_attributes(attrs) == %{
               "beep" => "boop",
               "count" => 12,
               "failed" => true,
               "maths" => 1.2
             }
    end

    test "can take a keyword list" do
      Tracer.with_span "important_stuff" do
        Attributes.set(beep: "boop", count: 12, maths: 1.2, failed: true)
      end

      assert_receive {:span, span(name: "important_stuff", attributes: attrs)}

      assert get_span_attributes(attrs) == %{
               "beep" => "boop",
               "count" => 12,
               "failed" => true,
               "maths" => 1.2
             }
    end

    test "cannot handle single attributes without a name" do
      Tracer.with_span "important_stuff" do
        Attributes.set([1, 2, 3])
        Attributes.set({:error, "too sick bro"})
        Attributes.set(:pink)
        Attributes.set("boop")
        Attributes.set(12)
        Attributes.set(1.2)
        Attributes.set(true)
      end

      assert_receive {:span, span(name: "important_stuff", attributes: attrs)}

      assert get_span_attributes(attrs) == %{}
    end

    test "can take a map" do
      Tracer.with_span "important_stuff" do
        Attributes.set(%{beep: "boop", count: 12, maths: 1.2, failed: true})
      end

      assert_receive {:span, span(name: "important_stuff", attributes: attrs)}

      assert get_span_attributes(attrs) == %{
               "beep" => "boop",
               "count" => 12,
               "failed" => true,
               "maths" => 1.2
             }
    end

    test "can take a struct" do
      Tracer.with_span "important_stuff" do
        Attributes.set(%SomeStruct{beep: "boop", count: 12, maths: 1.2, failed: true})
      end

      assert_receive {:span, span(name: "important_stuff", attributes: attrs)}

      assert get_span_attributes(attrs) == %{
               "beep" => "boop",
               "count" => 12,
               "failed" => true,
               "maths" => 1.2
             }
    end

    defmodule User do
      defstruct [:id, :name]
    end

    test "inspect()s non-otlp attributes before setting them on the current span" do
      Tracer.with_span "whaaaat" do
        Attributes.set(:result, {:error, "too sick bro"})
        Attributes.set(:color, :pink)
        Attributes.set(:numbers, [1, 2, 3, 4])
        Attributes.set(:object, %{id: 1})
        Attributes.set(:params, %{"id" => 1})
        Attributes.set(:user, %User{id: 1, name: "jane"})
      end

      expected = %{
        "result" => "{:error, \"too sick bro\"}",
        "color" => :pink,
        "numbers" => "[1, 2, 3, 4]",
        "object.id" => 1,
        "params.id" => 1,
        "user.id" => 1,
        "user.name" => "jane"
      }

      assert_receive {:span, span(name: "whaaaat", attributes: attrs)}

      assert get_span_attributes(attrs) == expected
    end
  end

  describe "set prefixes attributes with the configured prefix" do
    setup do
      prev = Application.get_env(:open_telemetry_decorator, :attr_prefix)
      Application.put_env(:open_telemetry_decorator, :attr_prefix, "app.")
      on_exit(fn -> Application.put_env(:open_telemetry_decorator, :attr_prefix, prev) end)
    end

    test "when prefix is configured, prefixes attribute names" do
      Tracer.with_span "important_stuff" do
        Attributes.set(beep: "boop", count: 12)
        Attributes.set(%{maths: 1.2, failed: true})
        Attributes.set(:result, {:error, "too sick bro"})
        Attributes.set(:color, "pink")
      end

      expected = %{
        "app.beep" => "boop",
        "app.color" => "pink",
        "app.count" => 12,
        "app.failed" => true,
        "app.maths" => 1.2,
        "app.result" => "{:error, \"too sick bro\"}"
      }

      assert_receive {:span, span(name: "important_stuff", attributes: attrs)}

      assert get_span_attributes(attrs) == expected
    end

    test "we no longer treat the error attribute differently" do
      Tracer.with_span "important_stuff" do
        Attributes.set(:error, "too sick bro")
      end

      assert_receive {:span, span(name: "important_stuff", attributes: attrs)}

      assert get_span_attributes(attrs) == %{"app.error" => "too sick bro"}
    end
  end

  describe "get" do
    test "handles flat attributes" do
      assert Attributes.get([id: 1, name: "jane"], [:id, :name]) == [id: 1, name: "jane"]
      assert Attributes.get([id: 1, name: "jane"], [:id]) == [id: 1]
    end

    test "does not handle nested attributes" do
      attrs = Attributes.get([obj: %{id: 1}], [[:obj, :id]])
      assert attrs == []
    end

    test "when target value is valid OTLP type, use it" do
      assert [{:val, 42.42}] == Attributes.get([val: 42.42], [:val])
      assert [{:val, true}] == Attributes.get([val: true], [:val])
      assert [{:val, 42}] == Attributes.get([val: 42], [:val])
      assert [{:val, "a string"}] == Attributes.get([val: "a string"], [:val])
      assert [{:val, :atom}] == Attributes.get([val: :atom], [:val])
    end

    test "when target value is falsy, don't return (OTLP doesn't save these attributes)" do
      assert [] == Attributes.get([val: false], [:val])
      assert [] == Attributes.get([val: nil], [:val])
    end

    test "when target value is NOT a valid OTLP type, fall back to `inspect`" do
      assert [{:val, "{:ok, 1}"}] == Attributes.get([val: {:ok, 1}], [:val])
      assert [{:val, "[1, 2, 3, 4]"}] == Attributes.get([val: [1, 2, 3, 4]], [:val])
      assert [{:obj, "%{id: 1}"}] == Attributes.get([obj: %{id: 1}], [:obj])
    end

    test "does not add attribute if missing" do
      attrs = Attributes.get([obj: %{}], [[:obj, :id]])
      assert attrs == []

      attrs = Attributes.get([], [[:obj, :id]])
      assert attrs == []
    end

    test "does not add attribute if object is nil" do
      assert Attributes.get([obj: nil], [[:obj, :id]]) == []
    end

    test "when :result is given, adds result to the list" do
      attrs = Attributes.get([result: {:ok, "include me"}], [:result])
      assert attrs == [result: "{:ok, \"include me\"}"]

      attrs = Attributes.get([result: {:ok, "include me"}, id: 10], [:result, :id])

      assert attrs == [{:id, 10}, {:result, "{:ok, \"include me\"}"}]
    end

    test "when :result is missing, does not add result to the list" do
      attrs = Attributes.get([result: {:ok, "include me"}], [])
      assert attrs == []

      attrs = Attributes.get([result: {:ok, "include me"}, name: "blah"], [:name])

      assert attrs == [name: "blah"]
    end

    test "removes leading underscores from keys" do
      assert Attributes.get([_id: 1], [:_id]) == [id: 1]

      attrs = Attributes.get([_id: 1, _name: "asd"], [:_id, :_name])
      assert attrs == [id: 1, name: "asd"]
    end

    test "doesn't modify keys without underscores" do
      attrs = Attributes.get([_id: 1, name: "asd"], [:_id, :name])
      assert Keyword.get(attrs, :id) == 1
      assert Keyword.get(attrs, :name) == "asd"
    end
  end

  describe "maybe_prefix with prefix that can be converted to an atom" do
    setup do
      prev = Application.get_env(:open_telemetry_decorator, :attr_prefix)
      Application.put_env(:open_telemetry_decorator, :attr_prefix, "my_")
      on_exit(fn -> Application.put_env(:open_telemetry_decorator, :attr_prefix, prev) end)
    end

    test "when prefix is configured, prefixes attribute names" do
      assert Attributes.get([id: 1], [:id]) == [my_id: 1]
    end
  end

  describe "maybe_prefix with prefix that cannot be converted to an atom" do
    setup do
      prev = Application.get_env(:open_telemetry_decorator, :attr_prefix)
      Application.put_env(:open_telemetry_decorator, :attr_prefix, "my.")
      on_exit(fn -> Application.put_env(:open_telemetry_decorator, :attr_prefix, prev) end)
    end

    test "when prefix is configured, prefixes attribute names" do
      assert Attributes.get([id: 1], [:id]) == ["my.id": 1]
    end
  end
end
