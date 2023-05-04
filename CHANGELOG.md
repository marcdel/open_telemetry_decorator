# OpenTelemetryDecorator

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