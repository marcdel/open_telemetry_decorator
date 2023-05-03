defmodule OpenTelemetryDecorator.Attributes do
  @moduledoc false

  def get(bound_variables, requested_attributes) do
    prefix = Application.get_env(:open_telemetry_decorator, :attr_prefix) || ""

    requested_attributes
    |> Enum.reduce(%{}, fn path, attributes ->
      case get_bound_var(bound_variables, path) do
        {path, value} ->
          Map.put(attributes, String.to_atom(prefix <> as_string(path)), as_string(value))

        _ ->
          attributes
      end
    end)
    |> Enum.into([])
  end

  defp get_bound_var(bound_vars, [head | rest]) when is_atom(head) do
    var =
      case Keyword.get(bound_vars, head) do
        var when is_struct(var) -> Map.from_struct(var)
        var -> var
      end

    if value = get_in(var, rest) do
      joiner = Application.get_env(:open_telemetry_decorator, :attr_joiner) || "_"

      path = [remove_underscore(head) | rest]
      {Enum.join(path, joiner), value}
    end
  end

  defp get_bound_var(bound_vars, target) when is_atom(target) do
    if var = Keyword.get(bound_vars, target), do: {remove_underscore(target), var}
  end

  defp as_string(term) when is_binary(term) or is_integer(term) or is_boolean(term) or is_float(term), do: term
  defp as_string(term), do: inspect(term)

  defp remove_underscore(head) when is_atom(head),
    do: head |> Atom.to_string() |> remove_underscore()

  defp remove_underscore("_" <> head), do: head
  defp remove_underscore(head), do: head
end
