defmodule OpenTelemetryDecorator.Attributes do
  @moduledoc false
  require OpenTelemetry.Tracer, as: Tracer
  require OpenTelemetry.Span, as: Span

  # This is getting way too fucking complicated

  def set(span_ctx, name, value) do
    Span.set_attribute(span_ctx, Atom.to_string(prefix_name(name)), to_otlp_value(value))
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

  def get(all_attributes, requested_attributes) do
    Enum.reduce(requested_attributes, [], fn requested_attribute, taken_attributes ->
      otlp_attributes = get_attributes(all_attributes, requested_attribute)

      otlp_attributes ++ taken_attributes
    end)
  end

  defp get_attributes(attributes, [attribute_name | nested_keys]) do
    requested_obj = attributes |> Keyword.get(attribute_name) |> as_map()

    if value = recursive_get_in(requested_obj, nested_keys) do
      otlp_value = to_otlp_value(value)

      map_otlp_attributes([attribute_name | nested_keys], otlp_value)
    else
      []
    end
  end

  defp get_attributes(attributes, attribute_name) do
    if value = Keyword.get(attributes, attribute_name) do
      otlp_value = to_otlp_value(value)

      map_otlp_attributes([attribute_name], otlp_value)
    else
      []
    end
  end

  defp map_otlp_attributes(name_nesting, otlp_value) do
    case otlp_value do
      attrs when is_list(attrs) ->
        Enum.map(attrs, fn {key, value} ->
          name = derived_name(name_nesting ++ [key])
          {name, value}
        end)

      otlp_value ->
        [{derived_name(name_nesting), otlp_value}]
    end
  end

  defp recursive_get_in(obj, []), do: obj

  defp recursive_get_in(obj, [key]), do: get_in(obj, [key])

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
    joiner = Application.get_env(:open_telemetry_decorator, :attr_joiner) || "."
    Enum.join(keys, joiner)
  end

  defp prefix_name(:error), do: :error
  defp prefix_name("error"), do: :error

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

  defp to_otlp_value(value) do
    case OpenTelemetryDecorator.Traceable.impl_for(value) do
      nil -> inspect(value)
      impl -> impl.otlp_value(value)
    end
  end
end
