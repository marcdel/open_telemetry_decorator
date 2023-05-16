defmodule OpenTelemetryDecorator.Attributes do
  @moduledoc false
  require OpenTelemetry.Tracer, as: Tracer

  def set(name, value) do
    Tracer.set_attribute(name, to_otlp_value(value))
  end

  def set(attributes) do
    attributes
    |> Enum.map(fn {key, value} -> {key, to_otlp_value(value)} end)
    |> Tracer.set_attributes()
  end

  def get(all_attributes, requested_attributes) do
    Enum.reduce(requested_attributes, [], fn requested_attribute, taken_attributes ->
      case get_attribute(all_attributes, requested_attribute) do
        {name, value} -> Keyword.put(taken_attributes, name, value)
        _ -> taken_attributes
      end
    end)
  end

  defp get_attribute(attributes, [attribute_name | nested_keys]) do
    requested_obj = attributes |> Keyword.get(attribute_name) |> as_map()

    if value = recursive_get_in(requested_obj, nested_keys) do
      {derived_name([attribute_name | nested_keys]), to_otlp_value(value)}
    end
  end

  defp recursive_get_in(obj, []), do: obj

  defp recursive_get_in(obj, [key | nested_keys]) do
    value =
      case get_in(obj, [key]) do
        value when is_struct(value) ->
          Map.from_struct(value)

        value ->
          value
      end

    recursive_get_in(value, nested_keys)
  end

  defp get_attribute(attributes, attribute_name) do
    if value = Keyword.get(attributes, attribute_name) do
      {derived_name(attribute_name), to_otlp_value(value)}
    end
  end

  defp derived_name([attribute_name | nested_keys]) do
    [remove_underscore(attribute_name) | nested_keys]
    |> composite_name()
    |> prefix_name()
  end

  defp derived_name(attribute_name) do
    attribute_name
    |> remove_underscore()
    |> prefix_name()
  end

  defp composite_name(keys) do
    joiner = Application.get_env(:open_telemetry_decorator, :attr_joiner) || "."
    Enum.join(keys, joiner)
  end

  defp prefix_name(name) when is_atom(name), do: prefix_name(Atom.to_string(name))

  defp prefix_name(name) when is_binary(name) do
    prefix = Application.get_env(:open_telemetry_decorator, :attr_prefix) || ""
    String.to_atom(prefix <> name)
  end

  defp remove_underscore(name) when is_atom(name) do
    name |> Atom.to_string() |> remove_underscore()
  end

  defp remove_underscore("_" <> name), do: name
  defp remove_underscore(name), do: name

  defp as_map(obj) when is_struct(obj), do: Map.from_struct(obj)
  defp as_map(obj) when is_map(obj), do: obj
  defp as_map(_), do: %{}

  defguard is_otlp_value(value)
           when is_binary(value) or is_integer(value) or is_boolean(value) or is_float(value)

  defp to_otlp_value(value) when is_otlp_value(value), do: value
  defp to_otlp_value(value), do: inspect(value)
end
