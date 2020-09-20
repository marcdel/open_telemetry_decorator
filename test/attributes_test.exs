defmodule AttributesTest do
  use ExUnit.Case, async: true

  describe "take_attrs" do
    test "handles flat attributes" do
      assert Attributes.get([id: 1], [:id]) == [id: 1]
    end

    test "handles nested attributes" do
      assert Attributes.get([obj: %{id: 1}], [[:obj, :id]]) == [
               obj_id: 1
             ]
    end

    test "handles flat and nested attributes" do
      attrs =
        Attributes.get([error: "whoops", obj: %{id: 1}], [
          :error,
          [:obj, :id]
        ])

      assert attrs == [obj_id: 1, error: "whoops"]
    end

    test "can take the top level element and a nested attribute" do
      attrs = Attributes.get([obj: %{id: 1}], [:obj, [:obj, :id]])
      assert attrs == [obj_id: 1, obj: "%{id: 1}"]
    end

    test "handles multiply nested attributes" do
      attrs = Attributes.get([obj: %{user: %{id: 2}}], [[:obj, :user, :id]])

      assert attrs == [obj_user_id: 2]

      attrs =
        Attributes.get(
          [obj: %{user: %{track: %{id: 3}}}],
          [[:obj, :user, :track, :id]]
        )

      assert attrs == [obj_user_track_id: 3]
    end

    test "does not add attribute if missing" do
      attrs = Attributes.get([obj: %{}], [[:obj, :id]])
      assert attrs == []

      attrs = Attributes.get([], [[:obj, :id]])
      assert attrs == []
    end
  end

  describe "maybe_add_result" do
    test "when :result is given, adds result to the list" do
      attrs = Attributes.get([], [:result], {:ok, "include me"})
      assert attrs == [result: {:ok, "include me"}]

      attrs = Attributes.get([id: 10], [:result, :id], {:ok, "include me"})

      assert attrs == [result: {:ok, "include me"}, id: 10]
    end

    test "when :result is missing, does not add result to the list" do
      attrs = Attributes.get([], [], {:ok, "include me"})
      assert attrs == []

      attrs = Attributes.get([name: "blah"], [:name], {:ok, "include me"})

      assert attrs == [name: "blah"]
    end
  end

  describe "remove_underscores" do
    test "removes underscores from keys" do
      assert Attributes.get([_id: 1], [:_id]) == [id: 1]

      assert Attributes.get([_id: 1, _name: "asd"], [:_id, :_name]) ==
               [
                 id: 1,
                 name: "asd"
               ]
    end

    test "doesn't modify keys without underscores" do
      assert Attributes.get([_id: 1, name: "asd"], [:_id, :name]) ==
               [
                 id: 1,
                 name: "asd"
               ]
    end
  end

  describe "stringify_list" do
    test "doesn't modify strings" do
      attrs = Attributes.get([string_attr: "hello"], [:string_attr])
      assert attrs == [string_attr: "hello"]
    end

    test "doesn't modify integers" do
      attrs = Attributes.get([int_attr: 12], [:int_attr])
      assert attrs == [int_attr: 12]
    end

    test "stringifies maps" do
      attrs = Attributes.get([obj: %{id: 10}], [:obj])
      assert attrs == [obj: "%{id: 10}"]
    end

    defmodule TestStruct do
      defstruct [:id, :name]
    end

    test "stringifies structs" do
      attrs =
        Attributes.get([obj: %TestStruct{id: 10, name: "User1"}], [
          :obj
        ])

      assert attrs == [obj: "%AttributesTest.TestStruct{id: 10, name: \"User1\"}"]
    end

    test "stringifies lists" do
      attrs = Attributes.get([matches: [1, 2, 3, 4]], [:matches])
      assert attrs == [matches: "[1, 2, 3, 4]"]

      attrs =
        Attributes.get(
          [matches: [{"user 1", "user 2"}, {"user 3", "user 4"}]],
          [:matches]
        )

      assert attrs == [matches: "[{\"user 1\", \"user 2\"}, {\"user 3\", \"user 4\"}]"]
    end
  end
end
