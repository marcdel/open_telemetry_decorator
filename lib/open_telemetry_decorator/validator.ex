defmodule OpenTelemetryDecorator.Validator do
  @moduledoc false

  def validate_args(span_name, attr_keys) do
    if not (is_binary(span_name) and span_name != "") do
      raise(ArgumentError, "span_name: #{inspect(span_name)} must be a non-empty string")
    end

    if not (is_list(attr_keys) and singular_atom_or_list_starts_with_atom?(attr_keys)) do
      raise(ArgumentError, "attr_keys must be a list of (atom | [atom | list])")
    end
  end

  defp singular_atom_or_list_starts_with_atom?(list) do
    Enum.all?(list, fn
      item when is_atom(item) -> true
      [item | _rest] when is_atom(item) -> true
      _ -> false
    end)
  end
end
