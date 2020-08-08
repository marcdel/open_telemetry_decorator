defmodule OpenTelemetryDecoratorTest do
  use ExUnit.Case
  doctest OpenTelemetryDecorator

  test "greets the world" do
    assert OpenTelemetryDecorator.hello() == :world
  end
end
