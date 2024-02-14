defmodule OtelHelper do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      require OpenTelemetry.Tracer, as: Tracer
      require Record

      # https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry_api/include/opentelemetry.hrl
      @fields Record.extract(:span_ctx, from_lib: "opentelemetry_api/include/opentelemetry.hrl")
      # Allows pattern matching on span_ctx via span_ctx()
      Record.defrecordp(:span_ctx, @fields)

      # https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry/include/otel_span.hrl
      @fields Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
      # Allows pattern matching on spans via span()
      Record.defrecordp(:span, @fields)

      @fields Record.extract(:link, from_lib: "opentelemetry/include/otel_span.hrl")
      # Allows pattern matching on links via link()
      Record.defrecordp(:link, @fields)

      @fields Record.extract(:event, from_lib: "opentelemetry/include/otel_span.hrl")
      # Allows pattern matching on events via event()
      Record.defrecordp(:event, @fields)

      def otel_pid_reporter(_) do
        Application.load(:opentelemetry)

        Application.put_env(:opentelemetry, :processors, [
          {
            :otel_batch_processor,
            %{scheduled_delay_ms: 1, exporter: {:otel_exporter_pid, self()}}
          }
        ])

        {:ok, _} = Application.ensure_all_started(:opentelemetry)

        on_exit(fn ->
          Application.stop(:opentelemetry)
          Application.unload(:opentelemetry)
        end)
      end

      def get_span_attributes(attributes) do
        # https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry_api/src/otel_attributes.erl#L37
        # e.g. {:attributes, 128, :infinity, 0, %{count: 2}}
        {:attributes, _, :infinity, _, attr} = attributes
        attr
      end

      def get_span_events(events) do
        # https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry/src/otel_events.erl#L27
        # e.g. {:events, 128, 128, :infinity, 0, []}
        {:events, _, _, :infinity, _, event_list} = events
        event_list
      end

      def get_span_links(links) do
        # https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry/src/otel_links.erl#L27
        # e.g. {:links, 128, 128, :infinity, 0, []}
        {:links, _, _, :infinity, _, link_list} = links
        link_list
      end
    end
  end
end
