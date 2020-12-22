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

  You can also provide a sampler that will override the globally configured one:

  ```elixir
  defmodule MyApp.Worker do
    use OpenTelemetryDecorator

    @sampler :ot_sampler.setup(:probability, %{probability: 0.5})

    @decorate trace("my_app.worker.do_work", sampler: @sampler, include: [:arg1, :arg2, :result])
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

      span_args = SpanArgs.new(unquote(opts))

      OpenTelemetry.Tracer.with_span unquote(span_name), span_args do
        span_ctx = OpenTelemetry.Tracer.current_span_ctx
        result = unquote(body)

        included_attrs = Attributes.get(Kernel.binding(), unquote(include), result)

        OpenTelemetry.Span.set_attributes(span_ctx, included_attrs)

        result
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

      parent_ctx = OpenTelemetry.Tracer.current_span_ctx()

      OpenTelemetry.Tracer.with_span unquote(span_name), %{parent: parent_ctx} do

        require IEx; IEx.pry()
        
        span_ctx = OpenTelemetry.Tracer.current_span_ctx
        OpenTelemetry.Span.set_attributes(span_ctx, Kernel.binding())

        result = unquote(body)

        OpenTelemetry.Span.set_attribute(span_ctx, :result, result)

        result
      end
    end
  rescue
    e in ArgumentError ->
      target = "#{inspect(context.module)}.#{context.name}/#{context.arity} @decorate telemetry"
      reraise %ArgumentError{message: "#{target} #{e.message}"}, __STACKTRACE__
  end
end
