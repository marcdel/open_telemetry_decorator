defmodule OtelHelper do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      require OpenTelemetry.Tracer, as: Tracer

      require Record
      @fields Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
      # Allows pattern matching on spans via
      Record.defrecordp(:span, @fields)

      def otel_pid_reporter(_) do
        Application.load(:opentelemetry)

        Application.put_env(:opentelemetry, :processors, [
          {:otel_batch_processor, %{scheduled_delay_ms: 1, exporter: {:otel_exporter_pid, self()}}},
          {:otel_simple_processor, %{exporter: {:otel_exporter_pid, self()}}}
        ])

        {:ok, _} = Application.ensure_all_started(:opentelemetry)

        on_exit(fn ->
          Application.stop(:opentelemetry)
          Application.unload(:opentelemetry)
        end)
      end

      def get_span_attributes(attributes) do
        # https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry/src/otel_attributes.erl#L26-L31
        # e.g. {:attributes, 128, :infinity, 0, %{count: 2}}
        {:attributes, _, :infinity, _, attr} = attributes
        attr
      end

      def get_span_events(events) do
        # https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry/src/otel_attributes.erl#L26-L31
        # e.g. {:events, 128, 128, :infinity, 0, []}
        {:events, _, _, :infinity, _, event_list} = events
        event_list
      end
    end
  end
end
