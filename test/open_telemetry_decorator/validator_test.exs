defmodule OpenTelemetryDecorator.ValidatorTest do
  use ExUnit.Case, async: false

  alias OpenTelemetryDecorator.Validator

  describe "validate_args" do
    test "event name must be a non-empty string" do
      Validator.validate_args("name_space.event", [])

      Validator.validate_args("A Fancier Name", [])

      assert_raise ArgumentError, ~r/^span_name/, fn ->
        Validator.validate_args("", [])
      end

      assert_raise ArgumentError, ~r/^span_name/, fn ->
        Validator.validate_args(nil, [])
      end
    end

    test "attr_keys can be empty" do
      Validator.validate_args("event", [])
    end

    test "first reference in attrs_keys must be atom" do
      Validator.validate_args("event", [:variable])
      Validator.validate_args("event", [:variable, [:key1, :key2]])
      Validator.validate_args("event", [:variable, [:key1, "key2"]])

      assert_raise ArgumentError, ~r/^attr_keys/, fn ->
        Validator.validate_args("event", ["variable"])
      end

      assert_raise ArgumentError, ~r/^attr_keys/, fn ->
        Validator.validate_args("event", [["variable", :key]])
      end
    end

    test "attrs_keys can contain nested lists of atoms" do
      Validator.validate_args("event", [:variable, [:obj, :key]])
    end
  end
end
