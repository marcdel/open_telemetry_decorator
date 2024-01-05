defmodule OpenTelemetryDecorator.AttributesV2 do
  @moduledoc false
  require OpenTelemetry.Tracer, as: Tracer
  require OpenTelemetry.Span, as: Span

  def set(span_ctx, name, value) do
    Span.set_attribute(span_ctx, Atom.to_string(derived_name(name)), to_otlp_value(value))
  end

  def set(name, value) when is_binary(name) or is_atom(name) do
    set(Tracer.current_span_ctx(), name, value)
  end

  def set(span_ctx, attributes) do
    Enum.map(attributes, fn {key, value} ->
      set(span_ctx, key, value)
    end)
  end

  def set(attributes) when is_struct(attributes) do
    set(Map.from_struct(attributes))
  end

  def set(attributes) do
    set(Tracer.current_span_ctx(), attributes)
  end

  def get(all_attributes, requested_attributes) when is_list(all_attributes) do
    all_attributes
    |> Enum.into(%{})
    |> get(requested_attributes)
  end

  def get(all_attributes, requested_attributes) when is_map(all_attributes) do
    all_attributes
    |> Map.take(requested_attributes)
    |> Enum.filter(fn {_, value} -> value end)
    |> Enum.map(fn {key, value} -> {derived_name(key), to_otlp_value(value)} end)
  end

  defp derived_name(attribute_name) do
    attribute_name
    |> remove_underscore()
    |> prefix_name()
  end

  # The error attribute is meaningful in the context of the span, so we don't want to prefix it
  defp prefix_name(:error), do: :error
  defp prefix_name("error"), do: :error

  defp prefix_name(name) when is_atom(name), do: prefix_name(Atom.to_string(name))

  defp prefix_name(name) when is_binary(name) do
    prefix = Application.get_env(:open_telemetry_decorator, :attr_prefix) || ""

    if String.starts_with?(name, prefix) do
      String.to_atom(name)
    else
      String.to_atom(prefix <> name)
    end
  end

  defp remove_underscore(name) when is_atom(name) do
    name |> Atom.to_string() |> remove_underscore()
  end

  defp remove_underscore("_" <> name), do: name
  defp remove_underscore(name), do: name

  defguard is_otlp_value(value)
           when is_binary(value) or is_integer(value) or is_boolean(value) or is_float(value)

  defp to_otlp_value(value) when is_otlp_value(value), do: value
  defp to_otlp_value(value), do: inspect(value)
end
