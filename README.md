# OpenTelemetryDecorator

[![Build status badge](https://github.com/marcdel/open_telemetry_decorator/workflows/Elixir%20CI/badge.svg)](https://github.com/marcdel/open_telemetry_decorator/actions)
[![Hex version badge](https://img.shields.io/hexpm/v/open_telemetry_decorator.svg)](https://hex.pm/packages/open_telemetry_decorator)

⚠️ Caution: the public API for this project is still evolving and is not yet stable

<!-- MDOC -->
<!-- INCLUDE -->
A function decorator for OpenTelemetry traces.

## Installation

Add `open_telemetry_decorator` to your list of dependencies in `mix.exs`. We include the `opentelemetry_api` package, but you'll need to add `opentelemetry` yourself in order to report spans and traces.

```elixir
def deps do
  [
    {:open_telemetry_decorator, "~> 1.0.0-rc.3"},
    {:opentelemetry, "~> 1.0.0-rc.3"}
  ]
end
```

Then follow the directions for the exporter of your choice to send traces to to zipkin, honeycomb, etc.

https://github.com/garthk/opentelemetry_honeycomb

https://github.com/opentelemetry-beam/opentelemetry_zipkin

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
    ...doing work
  end
end
```

The decorator uses a macro to insert code into your function at compile time to wrap the body in a new span and link it to the currently active span. In the example above, the `do_work` method would become something like this:

```elixir
def do_work(arg1, arg2) do
  require OpenTelemetry.Span
  require OpenTelemetry.Tracer

  parent_ctx = OpenTelemetry.Tracer.current_span_ctx()

  OpenTelemetry.Tracer.with_span "my_app.worker.do_work", %{parent: parent_ctx} do
    ...doing work
    OpenTelemetry.Span.set_attributes(arg1: arg1, arg2: arg2)
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
    {:ok, thing1}
  end
end
```

The result of the function by including the atom `:result`:

```elixir
defmodule MyApp.Math do
  use OpenTelemetryDecorator

  @decorate trace("my_app.math.add", include: [:result])
  def add(a, b) do
    sum = a + b
    {:ok, thing1}
  end
end
```

Map/struct properties using nested lists of atoms:

```elixir
defmodule MyApp.Worker do
  use OpenTelemetryDecorator

  @decorate trace("my_app.worker.do_work", include: [[:arg1, :count], [:arg2, :count], :total])
  def do_work(arg1, arg2) do
    total = arg1.count + arg2.count
    {:ok, total}
  end
end
```

<!-- MDOC -->

## Development

`make check` before you commit! If you'd prefer to do it manually:

* `mix do deps.get, deps.unlock --unused, deps.clean --unused` if you change dependencies
* `mix compile --warnings-as-errors` for a stricter compile
* `mix coveralls.html` to check for test coverage
* `mix credo` to suggest more idiomatic style for your code
* `mix dialyzer` to find problems typing might reveal… albeit *slowly*
* `mix docs` to generate documentation
