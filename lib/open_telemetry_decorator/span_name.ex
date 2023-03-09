defmodule OpenTelemetryDecorator.SpanName do
  @moduledoc false

  def from_context(%{module: m, name: f, arity: a}), do: "#{trim(m)}.#{f}/#{a}"

  # "Elixir module names are just atoms prefixed with 'Elixir.'"
  defp trim(m), do: m |> Atom.to_string() |> String.trim_leading("Elixir.")
end
