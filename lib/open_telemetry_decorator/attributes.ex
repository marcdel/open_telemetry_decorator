defmodule OpenTelemetryDecorator.Attributes do
  @moduledoc """
  Wrapper to switch between v1 and v2
  """

  def set(attributes) do
    attrs_module().set(attributes)
  end

  def set(name, value) do
    attrs_module().set(name, value)
  end

  def set(span_ctx, name, value) do
    attrs_module().set(span_ctx, name, value)
  end

  def get(all_attributes, requested_attributes) do
    attrs_module().get(all_attributes, requested_attributes)
  end

  defp attrs_module do
    case Application.get_env(:open_telemetry_decorator, :attrs_version, "v1") do
      "v1" -> OpenTelemetryDecorator.AttributesV1
      "v2" -> OpenTelemetryDecorator.AttributesV2
    end
  end
end
