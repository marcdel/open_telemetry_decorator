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

  alias OpenTelemetryDecorator.Attributes
  alias OpenTelemetryDecorator.Validator

  @doc """
  Decorate a function to add an OpenTelemetry trace with a named span.

  You can provide span attributes by specifying a list of variable names as atoms.
  This list can include:

  - any variables (in the top level closure) available when the function exits,
  - the result of the function by including the atom `:result`,
  - map/struct properties using nested lists of atoms.

  ```elixir
  defmodule MyApp.Worker do
    use OpenTelemetryDecorator

    @decorate trace("my_app.worker.do_work", include: [:arg1, [:arg2, :count], :total, :result])
    def do_work(arg1, arg2) do
      total = arg1.count + arg2.count
      {:ok, total}
    end
  end
  ```
  """
  def trace(span_name, opts \\ [], body, context) do
    include = Keyword.get(opts, :include, [])
    Validator.validate_args(span_name, include)

    quote location: :keep do
      require OpenTelemetry.Tracer, as: Tracer

      OpenTelemetry.Tracer.with_span unquote(span_name) do
        input_params = Attributes.get(Kernel.binding(), unquote(include))

        try do
          result = unquote(body)

          Kernel.binding()
          |> Attributes.get(unquote(include), result)
          |> Keyword.merge(input_params)
          |> Tracer.set_attributes()

          result
        rescue
          e ->
            Tracer.record_exception(e)
            Tracer.set_status(OpenTelemetry.status(:error))
            reraise e, __STACKTRACE__
        end
      end
    end
  rescue
    e in ArgumentError ->
      target = "#{inspect(context.module)}.#{context.name}/#{context.arity} @decorate telemetry"
      reraise %ArgumentError{message: "#{target} #{e.message}"}, __STACKTRACE__
  end
end
