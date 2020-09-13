defmodule OpenTelemetryDecoratorTest do
  use ExUnit.Case, async: true
  doctest OpenTelemetryDecorator

  describe "validate_args" do
    test "event name must be a non-empty list of atoms" do
      OpenTelemetryDecorator.validate_args([:name, :space, :event], [])

      assert_raise ArgumentError, ~r/^event_name/, fn ->
        OpenTelemetryDecorator.validate_args("name.space.event", [])
      end
    end

    test "attr_keys can be empty" do
      OpenTelemetryDecorator.validate_args([:name, :space, :event], [])
    end

    test "attrs_keys must be atoms" do
      OpenTelemetryDecorator.validate_args([:name, :space, :event], [:variable])

      assert_raise ArgumentError, ~r/^attr_keys/, fn ->
        OpenTelemetryDecorator.validate_args([:name, :space, :event], ["variable"])
      end
    end

    test "attrs_keys can contain nested lists of atoms" do
      OpenTelemetryDecorator.validate_args([:name, :space, :event], [:variable, [:obj, :key]])
    end
  end

  describe "get_reportable_attrs" do
    test "all together" do
      attrs =
        OpenTelemetryDecorator.get_reportable_attrs(
          [count: 10, _name: "user name", obj: %{id: 1}],
          [:count, :_name, [:obj, :id], :result],
          {:ok, :success}
        )

      assert attrs == [result: {:ok, :success}, obj_id: 1, count: 10, name: "user name"]
    end
  end

  describe "take_attrs" do
    test "handles flat attributes" do
      assert OpenTelemetryDecorator.get_reportable_attrs([id: 1], [:id]) == [id: 1]
    end

    test "handles nested attributes" do
      assert OpenTelemetryDecorator.get_reportable_attrs([obj: %{id: 1}], [[:obj, :id]]) == [
               obj_id: 1
             ]
    end

    test "handles flat and nested attributes" do
      attrs =
        OpenTelemetryDecorator.get_reportable_attrs([error: "whoops", obj: %{id: 1}], [
          :error,
          [:obj, :id]
        ])

      assert attrs == [obj_id: 1, error: "whoops"]
    end

    test "can take the top level element and a nested attribute" do
      attrs = OpenTelemetryDecorator.get_reportable_attrs([obj: %{id: 1}], [:obj, [:obj, :id]])
      assert attrs == [obj_id: 1, obj: "%{id: 1}"]
    end

    test "handles multiply nested attributes" do
      attrs =
        OpenTelemetryDecorator.get_reportable_attrs([obj: %{user: %{id: 2}}], [[:obj, :user, :id]])

      assert attrs == [obj_user_id: 2]

      attrs =
        OpenTelemetryDecorator.get_reportable_attrs(
          [obj: %{user: %{track: %{id: 3}}}],
          [[:obj, :user, :track, :id]]
        )

      assert attrs == [obj_user_track_id: 3]
    end

    test "does not add attribute if missing" do
      attrs = OpenTelemetryDecorator.get_reportable_attrs([obj: %{}], [[:obj, :id]])
      assert attrs == []

      attrs = OpenTelemetryDecorator.get_reportable_attrs([], [[:obj, :id]])
      assert attrs == []
    end
  end

  describe "maybe_add_result" do
    test "when :result is given, adds result to the list" do
      attrs = OpenTelemetryDecorator.get_reportable_attrs([], [:result], {:ok, "include me"})
      assert attrs == [result: {:ok, "include me"}]

      attrs =
        OpenTelemetryDecorator.get_reportable_attrs([id: 10], [:result, :id], {:ok, "include me"})

      assert attrs == [result: {:ok, "include me"}, id: 10]
    end

    test "when :result is missing, does not add result to the list" do
      attrs = OpenTelemetryDecorator.get_reportable_attrs([], [], {:ok, "include me"})
      assert attrs == []

      attrs =
        OpenTelemetryDecorator.get_reportable_attrs([name: "blah"], [:name], {:ok, "include me"})

      assert attrs == [name: "blah"]
    end
  end

  describe "remove_underscores" do
    test "removes underscores from keys" do
      assert OpenTelemetryDecorator.get_reportable_attrs([_id: 1], [:_id]) == [id: 1]

      assert OpenTelemetryDecorator.get_reportable_attrs([_id: 1, _name: "asd"], [:_id, :_name]) ==
               [
                 id: 1,
                 name: "asd"
               ]
    end

    test "doesn't modify keys without underscores" do
      assert OpenTelemetryDecorator.get_reportable_attrs([_id: 1, name: "asd"], [:_id, :name]) ==
               [
                 id: 1,
                 name: "asd"
               ]
    end
  end

  describe "stringify_list" do
    test "doesn't modify strings" do
      attrs = OpenTelemetryDecorator.get_reportable_attrs([string_attr: "hello"], [:string_attr])
      assert attrs == [string_attr: "hello"]
    end

    test "doesn't modify integers" do
      attrs = OpenTelemetryDecorator.get_reportable_attrs([int_attr: 12], [:int_attr])
      assert attrs == [int_attr: 12]
    end

    test "stringifies maps" do
      attrs = OpenTelemetryDecorator.get_reportable_attrs([obj: %{id: 10}], [:obj])
      assert attrs == [obj: "%{id: 10}"]
    end

    defmodule TestStruct do
      defstruct [:id, :name]
    end

    test "stringifies structs" do
      attrs =
        OpenTelemetryDecorator.get_reportable_attrs([obj: %TestStruct{id: 10, name: "User1"}], [
          :obj
        ])

      assert attrs == [obj: "%OpenTelemetryDecoratorTest.TestStruct{id: 10, name: \"User1\"}"]
    end

    test "stringifies lists" do
      attrs = OpenTelemetryDecorator.get_reportable_attrs([matches: [1, 2, 3, 4]], [:matches])
      assert attrs == [matches: "[1, 2, 3, 4]"]

      attrs =
        OpenTelemetryDecorator.get_reportable_attrs(
          [matches: [{"user 1", "user 2"}, {"user 3", "user 4"}]],
          [:matches]
        )

      assert attrs == [matches: "[{\"user 1\", \"user 2\"}, {\"user 3\", \"user 4\"}]"]
    end
  end
end
