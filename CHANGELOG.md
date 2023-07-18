# OpenTelemetryDecorator

## v1.4.5
- Fixes an issue with included input parameters not being recorded in the span attributes when an exception is raised. Included body parameters will still not be included since they are not available from the rescue block.

## v1.4.4
- Fixes an issue with error not being recorded in the span attributes when using `Attributes.set` since it was being passed as an atom.

## v1.4.3
- Do not prefix "error" attributes with the configured prefix since these have special meaning in open telemetry

## v1.4.2

- Bump opentelemetry_exporter from 1.4.1 to 1.5.0 by @dependabot in https://github.com/marcdel/open_telemetry_decorator/pull/111
- Ensure that keys are strings before we call Span.set_attributes (https://github.com/marcdel/open_telemetry_decorator/issues/114)
- Adds with_span decorator (delegates to trace, so you can use either)
- Ensure attributes set with the helper get prefixed

## v1.4.1

### Features

- Adds span set attribute helper that treats attributes the same way `:include` does (currently `inspects` anything it doesn't know how to handle) (thanks @ulissesalmeida)
- Updates :include attribute validator to allow nested string keys (thanks @leggebroten)

### Bug fixes

- Fixes an issue where indexing into a nested struct via `:include` would crash due to a `*Struct* does not implement the Access behaviour` error
- Protect against context corruption (thanks @leggebroten)

## v1.4.0

### API

- You're now able to `:include` nested result elements e.g. `include: [[:result, :name]]`
- You're now able to index into string keyed maps e.g. `include: [[:user, "id"]]`
- Complex object attributes (lists, maps, tuples, etc.) are now `inspect`ed rather than omitted from the trace
- 🚨The default joiner for nested attributes is now `.` rather than `_` e.g. `user.id=1` rather than `user_id=1`🚨
  - You can change this behavior via configuration e.g. `config :open_telemetry_decorator, attr_joiner: "_"`

## v1.3.0

Introduces a breaking (kind of) change. The API hasn't changed at all, but it will no longer overwrite function input parameters in the span attributes if they are rebound in the body of the function.

e.g. this `param_override(3, 2)` will add `x=3` to the span, where previously it would have been `x=4`

```
@decorate trace("param_override", include: [:x, :y])
def param_override(x, y) do
  x = x + 1

  {:ok, x + y}
end
```