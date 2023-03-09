defmodule OpenTelemetryDecorator.AttributesTest do
  use ExUnit.Case, async: true

  alias OpenTelemetryDecorator.Attributes

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
      assert attrs == [obj_id: 1, obj: %{id: 1}]
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

    test "does not add attribute if object is nil" do
      assert Attributes.get([obj: nil], [[:obj, :id]]) == []
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
end
