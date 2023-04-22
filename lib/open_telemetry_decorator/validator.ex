defmodule OpenTelemetryDecorator.Validator do
  @moduledoc false

  def validate_args(span_name, attr_keys) do
    if not (is_binary(span_name) and span_name != ""),
      do: raise(ArgumentError, "span_name must be a non-empty string")

    if not (is_list(attr_keys) and atoms_or_lists_of_atoms_only?(attr_keys)),
      do:
        raise(ArgumentError, "attr_keys must be a list of atoms, including nested lists of atoms")
  end

  defp atoms_or_lists_of_atoms_only?(list) when is_list(list) do
    Enum.all?(list, fn item ->
      (is_list(item) && atoms_or_lists_of_atoms_only?(item)) or is_atom(item)
    end)
  end

  defp atoms_or_lists_of_atoms_only?(item) when is_atom(item) do
    true
  end
end
