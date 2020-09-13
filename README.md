# OpenTelemetryDecorator

[![Build status badge](https://github.com/marcdel/open_telemetry_decorator/workflows/Elixir%20CI/badge.svg)](https://github.com/marcdel/open_telemetry_decorator/actions)
[![Hex version badge](https://img.shields.io/hexpm/v/open_telemetry_decorator.svg)](https://hex.pm/packages/open_telemetry_decorator)

<!-- MDOC -->
<!-- INCLUDE -->
A function decorator for OpenTelemetry traces.

## Usage

The event name can be any string.

    defmodule MyApp.Worker do
      use OpenTelemetryDecorator

      @decorate trace("my_app.worker.do_work")
      def do_work(arg1, arg2) do
        ...doing work
        do_more_work(arg1)
      end

      @decorate trace("MyApp::Worker::do_work")
      def do_more_work(arg1) do
        ...doing more work
      end
    end

We use `OpenTelemetry.Tracer.current_span_ctx()` to automatically link new spans to the current trace (if it exists and is in the same process). So the above example will link the `do_work` and `do_more_work` spans for you by default. 

You can provide span attributes by specifying a list of variable names as atoms.

This list can include...

Any variables (in the top level closure) available when the function exits:

    defmodule MyApp.Math do
      use OpenTelemetryDecorator

      @decorate trace("my_app.math.add", [:a, :b, :sum])
      def add(a, b) do
        sum = a + b
        {:ok, thing1}
      end
    end
    
    
The result of the function by including the atom `:result`:

    defmodule MyApp.Math do
      use OpenTelemetryDecorator

      @decorate trace("my_app.math.add", [:result])
      def add(a, b) do
        sum = a + b
        {:ok, thing1}
      end
    end
    
    
Map/struct properties using nested lists of atoms:

    defmodule MyApp.Worker do
      use OpenTelemetryDecorator

      @decorate trace("my_app.worker.do_work", [[:arg1, :count], [:arg2, :count], :total])
      def do_work(arg1, arg2) do
        total = arg1.count + arg2.count
        {:ok, total}
      end
    end

## Installation

Add `open_telemetry_decorator` to your list of dependencies in `mix.exs` and do a `mix deps.get`:

```elixir
def deps do
  [
    {:open_telemetry_decorator, "~> 0.1.0"}
  ]
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
