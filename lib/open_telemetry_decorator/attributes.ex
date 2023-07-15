defmodule OpenTelemetryDecorator.Attributes do
  @moduledoc false
  require OpenTelemetry.Tracer, as: Tracer

  def set(name, value) when is_struct(value) do
    set(name, Map.from_struct(value))
  end

  def set(name, value) when is_map(value) do
    value
    |> Enum.map(fn {key, value} -> {"#{name}#{joiner()}#{key}", value} end)
    |> set()
  end

  def set(name, value) do
    Tracer.set_attribute(name, to_otlp_value(value))
  end

  def set(attributes) when is_struct(attributes) do
    name = short_struct_name(attributes)
    set(prefix_name(name), Map.from_struct(attributes))
  end

  def set(attributes) do
    attributes
    |> Enum.map(fn {key, value} -> {prefix_name(key), to_otlp_value(value)} end)
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

  defp get_attribute(attributes, attribute_name) do
    if value = Keyword.get(attributes, attribute_name) do
      {derived_name(attribute_name), to_otlp_value(value)}
    end
  end

  defp recursive_get_in(obj, []), do: obj

  defp recursive_get_in(obj, [key | nested_keys]) do
    nested_obj =
      case get_in(obj, [key]) do
        nested_obj when is_struct(nested_obj) -> Map.from_struct(nested_obj)
        nested_obj -> nested_obj
      end

    recursive_get_in(nested_obj, nested_keys)
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
    Enum.join(keys, joiner())
  end

  defp prefix_name(name) when is_atom(name), do: prefix_name(Atom.to_string(name))

  defp prefix_name(name) when is_binary(name) do
    String.to_atom(prefix() <> name)
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

#  defp to_otlp_value(value) when is_struct(value) do
#    name = short_struct_name(value)
#
#    value
#    |> as_map()
#    |> Enum.map(fn {key, value} -> {"#{name}#{joiner()}#{key}", to_otlp_value(value)} end)
#    |> dbg()
#  end

  defp to_otlp_value(value), do: inspect(value)

  defp joiner do
    Application.get_env(:open_telemetry_decorator, :attr_joiner) || "."
  end

  defp prefix do
    Application.get_env(:open_telemetry_decorator, :attr_prefix) || ""
  end

  defp short_struct_name(variable) do
    variable
    |> Map.fetch!(:__struct__)
    |> Module.split()
    |> List.last()
    |> Macro.camelize()
    |> Macro.underscore()
  end
end
