# OpenTelemetryDecorator

## v1.4.10
Addresses an issue setting error status on parent spans after exception

When two functions that are decorated with the with_span function are nested and the child throws, the current span was not being set back to the parent as expected.
Calling Tracer.set_status would attempt to set the status on the child span which has been closed at that point and fail meaning the parent's status would be undefined.

## v1.4.9
Adds the ability to pass links to a function decorated with `with_span` or `trace`. This is done by passing a `links` option to the decorator.
The `links` option should be the atom names of variables containing linked spans. You can create a link to a span with `OpenTelemetry.link/1`

e.g.
```elixir
require OpenTelemetry.Tracer, as: Tracer

def parent do
  parent_span = Tracer.start_span("parent")
  link = OpenTelemetry.link(parent_span)

  child(link)
end

@decorate with_span("child", links: [:parent_link])
def child(parent_link) do
  # ...
  :ok
end
```

## v1.4.8
- Adds a v2 of the attributes module and the ability to toggle between. The v2 version is more limited, but simpler and (hopefully) easier to understand.
- Changes with_span to use start/end span


Previously dyalizer would not error on invalid contracts for functions
annotated with the decorator. presumably this was because the return
actually happens in a closure.


So, for example, the following code would pass dialyzer successfully

```elixir
@spec hello :: {:ok, :asdf}
@decorate with_span("hello")
def hello do
  :world
end
````

After this change it fails as expected

```shell
lib/spec_demo.ex:17:invalid_contract
The @spec for the function does not match the success typing of the function.

Function:
SpecDemo.hello/0

Success typing:
@spec hello() :: :world
```

## v1.4.7
- Fixes a bug causing the attribute prefix to be appended twice when using the include option
- Update and remove unused dependencies

## v1.4.6
- Updates dependencies, notably minor versions of the opentelemetry api and sdk
```shell
mix hex.outdated
Dependency              Current  Latest  Status
credo                   1.7.0    1.7.1   Update possible
decorator               1.4.0    1.4.0   Up-to-date
dialyxir                1.3.0    1.4.1   Update possible
ex_doc                  0.30.3   0.30.6  Update possible
excoveralls             0.16.1   0.17.1  Update not possible
opentelemetry           1.3.0    1.3.1   Update possible
opentelemetry_api       1.2.1    1.2.2   Update possible
opentelemetry_exporter  1.6.0    1.6.0   Up-to-date
```

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