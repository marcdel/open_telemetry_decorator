defmodule OpenTelemetryDecorator do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.filter(&(&1 =~ ~R{<!\-\-\ INCLUDE\ \-\->}))
             |> Enum.join("\n")
             # compensate for anchor id differences between ExDoc and GitHub
             |> (&Regex.replace(~R{\(\#\K(?=[a-z][a-z0-9-]+\))}, &1, "module-")).()

  use Decorator.Define, trace: 1, trace: 2, simple_trace: 0, simple_trace: 1

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
      require OpenTelemetry.Span
      require OpenTelemetry.Tracer
      require OpenTelemetryDecorator

      OpenTelemetry.Tracer.with_span unquote(span_name) do
        span_ctx = OpenTelemetry.Tracer.current_span_ctx()
        result = unquote(body)

        included_attrs = Attributes.get(Kernel.binding(), unquote(include), result)

        OpenTelemetry.Span.set_attributes(span_ctx, included_attrs)

        result |> OpenTelemetryDecorator.treat_result()
      end
    end
  rescue
    e in ArgumentError ->
      target = "#{inspect(context.module)}.#{context.name}/#{context.arity} @decorate telemetry"
      reraise %ArgumentError{message: "#{target} #{e.message}"}, __STACKTRACE__
  end

  @doc """
  Decorate a function to add an OpenTelemetry trace with a named span. The input parameters and result are automatically added to the span attributes.
  You can specify a span name or one will be generated based on the module name, function name, and arity.
  ```elixir
  defmodule MyApp.Worker do
    use OpenTelemetryDecorator
    @decorate simple_trace()
    def do_work(arg1, arg2) do
      total = arg1.count + arg2.count
      {:ok, total}
    end
    @decorate simple_trace("worker.do_more_work")
    def handle_call({:do_more_work, args}, _from, state) do
      {:reply, {:ok, args}, state}
    end
  end
  ```
  """
  def simple_trace(body, context) do
    context
    |> SpanName.from_context()
    |> simple_trace(body, context)
  end

  def simple_trace(span_name, body, context) do
    quote location: :keep do
      require OpenTelemetry.Span
      require OpenTelemetry.Tracer
      require OpenTelemetryDecorator

      parent_ctx = OpenTelemetry.Tracer.current_span_ctx()

      attributes =
        case Logger.metadata() do
          [request_id: value] -> [request_id: value]
          _ -> []
        end

      OpenTelemetry.Tracer.with_span unquote(span_name), %{
        parent: parent_ctx,
        attributes: attributes
      } do
        unquote(body) |> OpenTelemetryDecorator.treat_result()
      end
    end
  rescue
    e in ArgumentError ->
      target = "#{inspect(context.module)}.#{context.name}/#{context.arity} @decorate telemetry"
      reraise %ArgumentError{message: "#{target} #{e.message}"}, __STACKTRACE__
  end

  def treat_result(result) do
    case result do
      :error ->
        OpenTelemetryDecorator.add_error()
        :error

      tuple when is_tuple(tuple) ->
        case Tuple.to_list(tuple) do
          [:error | _tail] ->
            OpenTelemetryDecorator.add_error()
            tuple

          _any ->
            tuple
        end

      any ->
        any
    end
  end

  def add_error() do
    status = OpenTelemetry.status(:Error, "Error")
    span_ctx = OpenTelemetry.Tracer.current_span_ctx()
    OpenTelemetry.Span.set_status(span_ctx, status)
  end
end
