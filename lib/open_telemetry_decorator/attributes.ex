defmodule OpenTelemetryDecorator.Attributes do
  @moduledoc false

  def get(bound_variables, reportable_attr_keys) do
    bound_variables
    |> take_attrs(reportable_attr_keys)
    |> remove_underscores()
    |> convert_atoms_to_strings()
    |> prefix_attr_names()
    |> Enum.into([])
  end

  defp take_attrs(bound_variables, attr_keys) do
    {keys, nested_keys} = Enum.split_with(attr_keys, &is_atom/1)

    attrs = Keyword.take(bound_variables, keys)
    nested_attrs = take_nested_attrs(bound_variables, nested_keys)

    Keyword.merge(nested_attrs, attrs)
  end

  defp take_nested_attrs(bound_variables, nested_keys) do
    joiner = Application.get_env(:open_telemetry_decorator, :attr_joiner) || "_"

    nested_keys
    |> Enum.map(fn key_list ->
      key = key_list |> Enum.join(joiner) |> String.to_atom()
      {obj_key, other_keys} = List.pop_at(key_list, 0)

      with {:ok, obj} <- Keyword.fetch(bound_variables, obj_key),
           {:ok, value} <- take_nested_attr(obj, other_keys) do
        {key, value}
      else
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp take_nested_attr(nil, _keys), do: {:error, nil}

  defp take_nested_attr(obj, keys) do
    case get_in(obj, Enum.map(keys, &Access.key(&1, nil))) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  defp remove_underscores(attrs) do
    Enum.map(attrs, fn {key, value} ->
      key =
        key
        |> Atom.to_string()
        |> String.trim_leading("_")
        |> String.to_atom()

      {key, value}
    end)
  end

  defp convert_atoms_to_strings(attrs) do
    Enum.map(attrs, fn {key, value} ->
      if is_atom(value) do
        {key, Atom.to_string(value)}
      else
        {key, value}
      end
    end)
  end

  defp prefix_attr_names(attrs) do
    prefix = Application.get_env(:open_telemetry_decorator, :attr_prefix)
    do_prefix_attr_names(attrs, prefix)
  end

  defp do_prefix_attr_names(attrs, nil), do: attrs
  defp do_prefix_attr_names(attrs, ""), do: attrs

  defp do_prefix_attr_names(attrs, prefix) do
    Enum.map(attrs, fn {key, value} ->
      {String.to_atom(prefix <> Atom.to_string(key)), value}
    end)
  end
end
