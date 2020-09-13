defmodule OpenTelemetryDecorator do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.filter(&(&1 =~ ~R{<!\-\-\ INCLUDE\ \-\->}))
             |> Enum.join("\n")
             # compensate for anchor id differences between ExDoc and GitHub
             |> (&Regex.replace(~R{\(\#\K(?=[a-z][a-z0-9-]+\))}, &1, "module-")).()

  use Decorator.Define, trace: 1, trace: 2

  @doc """
  Decorate a function to add an OpenTelemetry trace with a named span.

  You can provide span attributes by specifying a list of variable names as atoms. This list can include:

  - any variables (in the top level closure) available when the function exits,
  - the result of the function by including the atom `:result`,
  - map/struct properties using nested lists of atoms.

  ```
  defmodule MyApp.Worker do
    use OpenTelemetryDecorator

    @decorate trace("my_app.worker.do_work", [:arg1, [:arg2, :count], :total, :result])
    def do_work(arg1, arg2) do
      total = arg1.count + arg2.count
      {:ok, total}
    end
  end
  ```
  """
  def trace(span_name, attr_keys \\ [], body, context) do
    validate_args(span_name, attr_keys)

    quote location: :keep do
      require OpenTelemetry.Span
      require OpenTelemetry.Tracer

      parent_ctx = OpenTelemetry.Tracer.current_span_ctx()

      OpenTelemetry.Tracer.with_span unquote(span_name), %{parent: parent_ctx} do
        result = unquote(body)

        reportable_attrs =
          OpenTelemetryDecorator.get_reportable_attrs(
            Kernel.binding(),
            unquote(attr_keys),
            result
          )

        OpenTelemetry.Span.set_attributes(reportable_attrs)

        result
      end
    end
  rescue
    e in ArgumentError ->
      target = "#{inspect(context.module)}.#{context.name}/#{context.arity} @decorate telemetry"
      reraise %ArgumentError{message: "#{target} #{e.message}"}, __STACKTRACE__
  end

  @doc """
  This method has to be public because it's used within the macro, but it shouldn't be called directly.
  """
  def validate_args(span_name, attr_keys) do
    if not (is_binary(span_name) and span_name != ""),
      do: raise(ArgumentError, "span_name must be a non-empty string")

    if not (is_list(attr_keys) and atoms_or_lists_of_atoms_only?(attr_keys)),
      do:
        raise(ArgumentError, "attr_keys must be a list of atoms, including nested lists of atoms")
  end

  @doc """
  This method has to be public because it's used within the macro, but it shouldn't be called directly.
  """
  def get_reportable_attrs(bound_variables, reportable_attr_keys, result \\ nil) do
    bound_variables
    |> take_attrs(reportable_attr_keys)
    |> maybe_add_result(reportable_attr_keys, result)
    |> remove_underscores()
    |> stringify_list()
    |> Enum.into([])
  end

  defp take_attrs(bound_variables, attr_keys) do
    {keys, nested_keys} = Enum.split_with(attr_keys, &is_atom/1)

    attrs = Keyword.take(bound_variables, keys)

    nested_attrs =
      nested_keys
      |> Enum.map(fn key_list ->
        key = key_list |> Enum.join("_") |> String.to_atom()
        {obj_key, other_keys} = List.pop_at(key_list, 0)

        with {:ok, obj} <- Keyword.fetch(bound_variables, obj_key),
             {:ok, value} <- take_nested_attr(obj, other_keys) do
          {key, value}
        else
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    Keyword.merge(nested_attrs, attrs)
  end

  defp take_nested_attr(obj, keys) do
    case get_in(obj, Enum.map(keys, &Access.key(&1, nil))) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  defp maybe_add_result(attrs, attr_keys, result) do
    if Enum.member?(attr_keys, :result) do
      Keyword.put_new(attrs, :result, result)
    else
      attrs
    end
  end

  defp remove_underscores(attrs) do
    Enum.map(attrs, fn {key, value} ->
      key =
        key
        |> Atom.to_string()
        |> String.trim_leading("_")
        |> String.to_existing_atom()

      {key, value}
    end)
  end

  defp stringify_list(attrs) do
    Enum.map(attrs, fn {key, value} -> {key, stringify(value)} end)
  end

  defp stringify(thing) when is_map(thing) or is_struct(thing) or is_list(thing) do
    inspect(thing)
  end

  defp stringify(thing), do: thing

  defp atoms_or_lists_of_atoms_only?(list) when is_list(list) do
    Enum.all?(list, fn item ->
      (is_list(item) && atoms_or_lists_of_atoms_only?(item)) or is_atom(item)
    end)
  end

  defp atoms_or_lists_of_atoms_only?(item) when is_atom(item) do
    true
  end
end
