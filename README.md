# OpenTelemetryDecorator

[![Build status badge](https://github.com/marcdel/open_telemetry_decorator/workflows/Elixir%20CI/badge.svg)](https://github.com/marcdel/open_telemetry_decorator/actions)
[![Hex version badge](https://img.shields.io/hexpm/v/open_telemetry_decorator.svg)](https://hex.pm/packages/open_telemetry_decorator)
[![Hex downloads badge](https://img.shields.io/hexpm/dt/open_telemetry_decorator.svg)](https://hex.pm/packages/open_telemetry_decorator)

<!-- MDOC -->
<!-- INCLUDE -->
A function decorator for OpenTelemetry traces.

## Installation

Add `open_telemetry_decorator` to your list of dependencies in `mix.exs`. We include the `opentelemetry_api` package, but you'll need to add `opentelemetry` yourself in order to report spans and traces.

```elixir
def deps do
  [
    {:opentelemetry, "~> 1.4"},
    {:opentelemetry_exporter, "~> 1.7"},
    {:open_telemetry_decorator, "~> 1.5"}
  ]
end
```

Then follow the directions for the exporter of your choice to send traces to to zipkin, honeycomb, etc.
https://github.com/open-telemetry/opentelemetry-erlang/tree/main/apps/opentelemetry_zipkin

### Honeycomb Example

`config/runtime.exs`
```elixir
api_key = System.fetch_env!("HONEYCOMB_KEY")

config :opentelemetry_exporter,
  otlp_endpoint: "https://api.honeycomb.io:443",
  otlp_headers: [{"x-honeycomb-team", api_key}]
```

## Usage

Add `use OpenTelemetryDecorator` to the module, and decorate any methods you want to trace with `@decorate with_span("span name")`.

The `with_span` decorator will automatically wrap the decorated function in an opentelemetry span with the provided name.

```elixir
defmodule MyApp.Worker do
  use OpenTelemetryDecorator

  @decorate with_span("worker.do_work")
  def do_work(arg1, arg2) do
    ...doing work
  end
end
```

### Span Attributes

The `with_span` decorator allows you to specify an `include` option which gives you more flexibility with what you can include in the span attributes. Omitting the `include` option with `with_span` means no attributes will be added to the span by the decorator.

```elixir
defmodule MyApp.Worker do
  use OpenTelemetryDecorator

  @decorate with_span("worker.do_work", include: [:arg1, :arg2])
  def do_work(arg1, arg2) do
    # ...doing work
  end
end
```

The O11y module includes a helper for setting additional attributes outside of the `include` option. Attributes added in either a `set` call or in the `include` that are not [primitive OTLP values](https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry_api/src/opentelemetry.erl#L111) will be converted to strings with `Kernel.inspect/1`.

```elixir
defmodule MyApp.Worker do
  use OpenTelemetryDecorator

  @decorate with_span("worker.do_work")
  def do_work(arg1, arg2) do
    O11y.set_attributes(arg1: arg1, arg2: arg2)
    # ...doing work
    Attributes.set_attribute(:output, "something")
  end
end
```

The decorator uses a macro to insert code into your function at compile time to wrap the body in a new span and link it to the currently active span. In the example above, the `do_work` method would become something like this:

```elixir
defmodule MyApp.Worker do
  require OpenTelemetry.Tracer, as: Tracer

  def do_work(arg1, arg2) do
    Tracer.with_span "my_app.worker.do_work" do
      # ...doing work
      Tracer.set_attributes(arg1: arg1, arg2: arg2)
    end
  end
end
```

## Configuration

### Prefixing Span Attributes
Honeycomb suggests that you [namespace custom fields](https://docs.honeycomb.io/getting-data-in/data-best-practices/#namespace-custom-fields), specifically prefixing manual instrumentation with `app`

✳️ You can now set this in the underlying `o11y` library with the `attribute_namespace` option ✳️

```elixir
config :o11y, :attribute_namespace, "app"
```

⚠️ You can still configure it with the `attr_prefix` option in `config/config.exs`, but that will be deprecated in a future release. ⚠️

```elixir
config :open_telemetry_decorator, attr_prefix: "app."
```

### Changing the join character for nested attributes

⚠️ This configuration option is no longer available ⚠️

## Additional Examples

You can provide span attributes by specifying a list of variable names as atoms.

This list can include...

Any variables (in the top level closure) available when the function exits.
Note that variables declared as part of an `if`, `case`, `cond`, or `with` block are in a separate scope so NOT available for `include` attributes.

```elixir
defmodule MyApp.Math do
  use OpenTelemetryDecorator

  @decorate with_span("my_app.math.add", include: [:a, :b, :sum])
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

  @decorate with_span("my_app.math.add", include: [:result])
  def add(a, b) do
    {:ok, a + b}
  end
end
```

Structs will be converted to maps and included in the span attributes. You can specify which fields to include with the `@derive` attribute provided by `O11y`.

```elixir
defmodule User do
  use OpenTelemetryDecorator

  @derive {O11y.SpanAttributes, only: [:id, :name]}
  defstruct [:id, :name, :email, :password]

  @decorate with_span("user.create", include: [:user])
  def create(user) do
    {:ok, user}
  end
end
```

## Development

`make check` before you commit! If you'd prefer to do it manually:

* `mix do deps.get, deps.unlock --unused, deps.clean --unused` if you change dependencies
* `mix compile --warnings-as-errors` for a stricter compile
* `mix coveralls.html` to check for test coverage
* `mix credo` to suggest more idiomatic style for your code
* `mix dialyzer` to find problems typing might reveal… albeit *slowly*
* `mix docs` to generate documentation

<!-- MDOC -->
