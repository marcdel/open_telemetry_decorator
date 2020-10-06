defmodule SpanArgs do
  @moduledoc false

  require OpenTelemetry.Tracer

  def new(opts) when is_list(opts) do
    sampler = get_sampler(opts)
    parent_ctx = OpenTelemetry.Tracer.current_span_ctx()

    case sampler do
      nil -> %{parent: parent_ctx}
      sampler -> %{parent: parent_ctx, sampler: sampler}
    end
  end

  defp get_sampler(opts) do
    opts_sampler_provider = Keyword.get(opts, :sampler_provider)
    config_sampler_provider = Application.get_env(:open_telemetry_decorator, :sampler_provider)

    cond do
      is_function(opts_sampler_provider) -> opts_sampler_provider.()
      is_function(config_sampler_provider) -> config_sampler_provider.()
      true -> nil
    end
  end
end
