# OpenTelemetryDecorator

[![Build status badge](https://github.com/marcdel/open_telemetry_decorator/workflows/Elixir%20CI/badge.svg)](https://github.com/marcdel/open_telemetry_decorator/actions)
[![Hex version badge](https://img.shields.io/hexpm/v/open_telemetry_decorator.svg)](https://hex.pm/packages/open_telemetry_decorator)

<!-- MDOC -->
<!-- INCLUDE -->
A function decorator for OpenTelemetry traces.

## Installation

Add `open_telemetry_decorator` to your list of dependencies in `mix.exs`. We include the `opentelemetry_api` package, but you'll need to add `opentelemetry` yourself in order to report spans and traces.

```elixir
def deps do
  [
    {:opentelemetry, "~> 1.2"},
    {:opentelemetry_exporter, "~> 1.4"},
    {:open_telemetry_decorator, "~> 1.3"}
  ]
end
```

Then follow the directions for the exporter of your choice to send traces to to zipkin, honeycomb, etc.
https://github.com/open-telemetry/opentelemetry-erlang/tree/main/apps/opentelemetry_zipkin

### Honeycomb Example

`config/runtime.exs`
```elixir
api_key = Map.fetch!(System.get_env(), "HONEYCOMB_KEY")

config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter:
      {:opentelemetry_exporter,
       %{
         protocol: :grpc,
         headers: [
           {'x-honeycomb-team', api_key},
           {'x-honeycomb-dataset', 'YOUR_APP_NAME'}
         ],
         endpoints: [{:https, 'api.honeycomb.io', 443, []}]
       }}
  }

```

## Usage

Add `use OpenTelemetryDecorator` to the module, and decorate any methods you want to trace with `@decorate trace("span name")`.

The `trace` decorator will automatically wrap the decorated function in an opentelemetry span with the provided name.

```elixir
defmodule MyApp.Worker do
  use OpenTelemetryDecorator

  @decorate trace("worker.do_work")
  def do_work(arg1, arg2) do
    ...doing work
  end
end
```

### Span Attributes

The `trace` decorator allows you to specify an `includes` option which gives you more flexibility with what you can include in the span attributes. Omitting the `includes` option with `trace` means no attributes will be added to the span.

```elixir
defmodule MyApp.Worker do
  use OpenTelemetryDecorator

  @decorate trace("worker.do_work", include: [:arg1, :arg2])
  def do_work(arg1, arg2) do
    # ...doing work
  end
end
```

The decorator uses a macro to insert code into your function at compile time to wrap the body in a new span and link it to the currently active span. In the example above, the `do_work` method would become something like this:

```elixir
defmodule MyApp.Worker do
  require OpenTelemetry.Tracer, as: Tracer

  def do_work(arg1, arg2) do
    OpenTelemetry.Tracer.with_span "my_app.worker.do_work" do
      # ...doing work
      Tracer.set_attributes(arg1: arg1, arg2: arg2)
    end
  end
end

```

You can provide span attributes by specifying a list of variable names as atoms.

This list can include...

Any variables (in the top level closure) available when the function exits:

```elixir
defmodule MyApp.Math do
  use OpenTelemetryDecorator

  @decorate trace("my_app.math.add", include: [:a, :b, :sum])
  def add(a, b) do
    sum = a + b
    {:ok, sum}
  end
end
```

The result of the function by including the atom `:result`:

```elixir
defmodule MyApp.Math do
  use OpenTelemetryDecorator

  @decorate trace("my_app.math.add", include: [:result])
  def add(a, b) do
    {:ok, a + b}
  end
end
```

Map/struct properties using nested lists of atoms:

```elixir
defmodule MyApp.Worker do
  use OpenTelemetryDecorator

  @decorate trace("my_app.worker.do_work", include: [[:arg1, :count], [:arg2, :count], :total])
  def do_work(arg1, arg2) do
    total = some_calculation(arg1.count, arg2.count)
    {:ok, total}
  end
end
```

### Prefixing Span Attributes
Honeycomb suggests that you [namespace custom fields](https://docs.honeycomb.io/getting-data-in/data-best-practices/#namespace-custom-fields), specifically putting manual instrumentation under `app.`

In order to do this, you'll configure the `attr_prefix` option in `config/config.exs`
```elixir
config :open_telemetry_decorator, attr_prefix: "app."
```

### Changing the join character for nested attributes
By default, nested attributes are joined with an underscore. However, when you have an object with underscores and a property with underscores, this can be hard to visually parse. For example, `my_struct.other_struct.field`, would be exported as `my_struct_other_struct_field`.

To override this, you'll configure the `attr_joiner` option in `config/config.exs`. The default value will likely change from `_` to `.` in a future version.
```elixir
config :open_telemetry_decorator, attr_joiner: "."
```

Thanks to @benregn for the examples and inspiration for these two options!
<!-- MDOC -->

## Development

`make check` before you commit! If you'd prefer to do it manually:

* `mix do deps.get, deps.unlock --unused, deps.clean --unused` if you change dependencies
* `mix compile --warnings-as-errors` for a stricter compile
* `mix coveralls.html` to check for test coverage
* `mix credo` to suggest more idiomatic style for your code
* `mix dialyzer` to find problems typing might reveal… albeit *slowly*
* `mix docs` to generate documentation
