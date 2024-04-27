defmodule OpenTelemetryDecorator.Attributes do
  @moduledoc """
  Wrapper to switch between v1 and v2
  """

  @deprecated "Use O11y.set_attributes/1 instead"
  def set(attributes) do
    attrs_module().set(attributes)
  end

  @deprecated "Use O11y.set_attribute/2 instead"
  def set(name, value) do
    attrs_module().set(name, value)
  end

  @deprecated "Use Tracer.set_current_span/1 and O11y.set_attribute/2 instead"
  def set(span_ctx, name, value) do
    attrs_module().set(span_ctx, name, value)
  end

  @deprecated "Use O11y.SpanAttributes.get/1 instead"
  def get(all_attributes, requested_attributes) do
    attrs_module().get(all_attributes, requested_attributes)
  end

  def attribute_prefix do
    prefix =
      :open_telemetry_decorator
      |> Application.get_env(:attr_prefix, "")
      |> String.trim()
      |> String.trim_trailing(".")

    if prefix == "" do
      nil
    else
      prefix
    end
  end

  defp attrs_module do
    case Application.get_env(:open_telemetry_decorator, :attrs_version, "v1") do
      "v1" -> OpenTelemetryDecorator.AttributesV1
      "v2" -> OpenTelemetryDecorator.AttributesV2
    end
  end
end
