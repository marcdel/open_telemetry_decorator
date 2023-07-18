defmodule OpenTelemetryDecorator do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.filter(&(&1 =~ ~R{<!\-\-\ INCLUDE\ \-\->}))
             |> Enum.join("\n")
             # compensate for anchor id differences between ExDoc and GitHub
             |> (&Regex.replace(~R{\(\#\K(?=[a-z][a-z0-9-]+\))}, &1, "module-")).()

  use Decorator.Define, with_span: 1, with_span: 2, trace: 1, trace: 2

  alias OpenTelemetryDecorator.Attributes
  alias OpenTelemetryDecorator.Validator

  def trace(span_name, opts \\ [], body, context), do: with_span(span_name, opts, body, context)

  @doc """
  Decorate a function to add to or create an OpenTelemetry trace with a named span.

  You can provide span attributes by specifying a list of variable names as atoms.
  This list can include:

  - any variables (in the top level closure) available when the function exits,
  - the result of the function by including the atom `:result`,
  - map/struct properties using nested lists of atoms.

  ```elixir
  defmodule MyApp.Worker do
    use OpenTelemetryDecorator

    @decorate with_span("my_app.worker.do_work", include: [:arg1, [:arg2, :count], :total, :result])
    def do_work(arg1, arg2) do
      total = arg1.count + arg2.count
      {:ok, total}
    end
  end
  ```
  """
  def with_span(span_name, opts \\ [], body, context) do
    include = Keyword.get(opts, :include, [])
    Validator.validate_args(span_name, include)

    quote location: :keep do
      require OpenTelemetry.Tracer, as: Tracer
      require OpenTelemetry.Span, as: Span

      Tracer.with_span unquote(span_name) do
        span_context = Tracer.current_span_ctx()

        input_params =
          Kernel.binding()
          |> Attributes.get(unquote(include))
          |> Keyword.delete(:result)

        Attributes.set(input_params)

        try do
          result = unquote(body)

          attrs =
            Kernel.binding()
            |> Keyword.put(:result, result)
            |> Attributes.get(unquote(include))
            |> Keyword.merge(input_params)
            |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)

          # Called functions can mess up Tracer's current span context, so ensure we at least write to ours
          Attributes.set(span_context, attrs)

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
