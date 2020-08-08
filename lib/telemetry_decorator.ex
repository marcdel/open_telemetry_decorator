defmodule TelemetryDecorator do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.filter(&(&1 =~ ~R{<!\-\-\ INCLUDE\ \-\->}))
             |> Enum.join("\n")
             # compensate for anchor id differences between ExDoc and GitHub
             |> (&Regex.replace(~R{\(\#\K(?=[a-z][a-z0-9-]+\))}, &1, "module-")).()

  use Decorator.Define, telemetry: 1, telemetry: 2

  @doc """
  Attach a quick-and-dirty telemetry handler for watching events in action.

          handler_id = TelemetryDecorator.watch([:my_app, :succeed])
  """
  def watch([_ | _] = event_prefix, handler_id \\ nil) do
    handler_id = handler_id || make_ref()
    event_names = for tail <- [:start, :stop, :exception], do: event_prefix ++ [tail]
    :telemetry.attach_many(handler_id, event_names, &watch_handler/4, Process.group_leader())
    handler_id
  end

  defp watch_handler(event_name, measurements, metadata, device) do
    Pretty.inspect(
      device,
      %{
        event_name: event_name,
        measurements: measurements,
        metadata: metadata
      },
      []
    )
  end

  @doc """
  Detach the handler attached by `watch/1` or `watch/2`.

  Delegated to `:telemetry.detach/1`. These calls are equivalent:

      TelemetryDecorator.unwatch(handler_id)
      :telemetry.detach(handler_id)
  """
  defdelegate unwatch(handler_id), to: :telemetry, as: :detach

  @doc """
  Decorate a method for telemetry.

      @decorate telemetry([:my_app, :succeed])
      def succeed(arg1, arg2) do
        :...
      end

  Options include:

  * `include`: a list of atoms naming variables in scope at the end of your function, each of
    which will be included in the metadata of the `:stop` event.
  """
  def telemetry(event_name, opts \\ [], body, context) do
    {include, opts} = Keyword.pop(opts, :include, [])
    for {k, _} <- opts, do: raise(ArgumentError, "no such option: #{k}")

    if not (is_list(event_name) and atoms_only?(event_name) and not Enum.empty?(event_name)),
      do: raise(ArgumentError, "event_name must be a non-empty list of atoms")

    if Enum.empty?(event_name), do: raise(ArgumentError, "event_name is empty")

    if not (is_list(include) and atoms_only?(include)),
      do: raise(ArgumentError, "include option must be a list of atoms")

    quote location: :keep do
      metadata = Enum.into(Kernel.binding(), %{})

      :telemetry.span(unquote(event_name), metadata, fn ->
        result = unquote(body)

        metadata =
          Kernel.binding()
          |> Keyword.take(unquote(include))
          |> Keyword.put_new(:result, result)
          |> Enum.into(metadata)

        {result, metadata}
      end)
    end
  rescue
    e in ArgumentError ->
      target = "#{inspect(context.module)}.#{context.name}/#{context.arity} @decorate telemetry"
      reraise %ArgumentError{message: "#{target} #{e.message}"}, __STACKTRACE__
  end

  defp atoms_only?(list), do: Enum.all?(list, &is_atom/1)
end
