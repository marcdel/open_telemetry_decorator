# OpenTelemetryDecorator

## v1.5.6

- 🐞BUG FIX: v1.5.4 introduced a bug where exits were being caught and the span annotated, but then control flow continued as if the exit had not occurred. We now exit with the same reason that was caught, so control flow is unchanged.

## v1.5.5

- Decorator will catch throws as well as exits and add an error status to the span.

## v1.5.4

- Catch unhandled Erlang exits and add an error status to the span.

## v1.5.3

- Bumps o11y version to v0.2.4 which includes an `add_event` method that processes the attributes given to it the same way `with_span` does.

## v1.5.2

- Fixes a bug which included input parameters you didn't ask for in the span attributes.

## v1.5.1

- Fixes a bug with missing `attrs_version`

## v1.5.0

- 🚨 The decorator now uses the `O11y.set_attribute(s)` functions to set attributes on spans. This means that the attribute processing logic that was here previously has been migrated there. However, there are some backwards incompatible changes listed below.
- 🚨 The decorator no longer supports nested attributes in the `include` option. The `O11y` `set_attribute` and `set_attributes` functions should now be used to handle more complex attribute specifications. The `SpanAttributes` protocol in particular is what I recommend if you need to extract a subset of fields from an object. The example below will add only `user.id` and `user.name` to the span attributes.

```elixir
defmodule User do
  @derive {O11y.SpanAttributes, only: [:id, :name]}
  defstruct [:id, :name, :email, :password]
end

defmodule UserFactory do
  use OpenTelemetryDecorator

  @decorate with_span("UserFactory.create", include: [:user])
  def create() do
    user = %User{id: 1, name: "Bob", email: "bob@work.com", password: "secret"}
    {:ok, user}
  end
end
```
- 🚨 Changes the default attrs_version to "v2". You can override this with `config :open_telemetry_decorator, attrs_version: "v1"`, but that only affects usages of `Attribtues` directly.
- ⚠️ Changes AttributesV2 to use the `O11y.set_attribute(s)` functions. The attribute processing logic that was here previously has been migrated there. However, there are some backwards incompatible changes listed below.
- ⚠️ Changed functionality: the `error` attribute is no longer treated differently from other attributes. It will be namespaced or prefixed as expected. If you're using Honeycomb this field will be automatically derived from the span's status_code, so you don't need to (and probably shouldn't) set it manually. Instead, use `O11y.set_error/1` to set the status code to "error" and message to the provided (string or exception) value.
- ⚠️ Changed functionality: maps and structs given to `Attributes.set/2` will be flattened and prefixed with the given name. e.g.
```elixir
params = %{key: "value"}
Attributes.set(:params, params)
# Becomes
%{"params.key" => "value"}
```

## v1.4.13
- Updates O11y dependency to v0.1.4 to fix an issue with setting error messages on spans.

## v1.4.12
- Updates decorator to use the o11y version of start and end span
- Refactor tests to use `O11y.TestHelper` and the available structs for asserting on span conents.

## v1.4.11
Clean up after ourselves instead of right before setting the status

I didn't realize `Span.end_span` does _not_ change the current span, which is why when the parent catches the reraise it had the wrong span as the current span.
We're starting the span in a place where we can hold on to it so we can manually update the current span to the parent so that callers that _aren't_ using the decorator have the correct current span.

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
