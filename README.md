# TelemetryDecorator

[![Build status badge](https://github.com/amplifiedai/telemetry_decorator/workflows/Elixir%20CI/badge.svg)](https://github.com/amplifiedai/telemetry_decorator/actions)
[![Hex version badge](https://img.shields.io/hexpm/v/telemetry_decorator.svg)](https://hex.pm/packages/telemetry_decorator)

<!-- MDOC -->
<!-- INCLUDE -->
A function decorator for telemetry.

## Usage

    defmodule MyApp.MyModule do
      use TelemetryDecorator

      @decorate telemetry([:my_app, :succeed])
      def succeed(arg1, arg2) do
        :...
      end
    end

Because we're using `:telemetry.span/3` under the hood, you'll get these events:

* `[:my_app, :succeed, :start]`
* `[:my_app, :succeed, :stop]`
* `[:my_app, :succeed, :exception]`

Because we're wrapping it with `Decorator`, we can provide more metadata than
`:telemetry.span/3` usually does:

* Any variables matched by your arguments for `:start`, `:stop`, and `:exception` events

* Your function's `result` for `:stop` events (overriding any variable named `result`)

To include more internal variables in your `:stop` events, add the `include` option:

    defmodule MyApp.MyModule do
      use TelemetryDecorator

      def succeed(why), do: succeed(why, [])

      @decorate telemetry([:my_app, :succeed], include: [:type])
      def succeed(why, opts) do
        type = Keyword.get(opts, :type, :ok)
        {type, why}
      end
    end

To watch `:telemetry.span/3` style events at the `iex>` prompt:

    handler_id = TelemetryDecorator.watch([:my_app, :succeed])
    MyApp.MyModule.succeed(42)
    # hang up, or explicitly unwatch:
    TelemetryDecorator.unwatch(handler_id)

`TelemetryDecorator.watch/1` sends to remote consoles, too, and with syntax colours. See the
documentation for `Pretty` to find out how.

<!-- MDOC -->
## Installation

Add `telemetry_decorator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:telemetry_decorator, "~> 1.0.0"}
  ]
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
