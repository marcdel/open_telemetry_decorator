defmodule TelemetryDecoratorTest do
  use ExUnit.Case
  doctest TelemetryDecorator

  test "greets the world" do
    assert TelemetryDecorator.hello() == :world
  end
end
