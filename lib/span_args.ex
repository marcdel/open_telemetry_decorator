defmodule SpanArgs do
  @moduledoc false

  require OpenTelemetry.Tracer

  def new(opts) when is_list(opts) do
    sampler = Keyword.get(opts, :sampler)
    parent_ctx = OpenTelemetry.Tracer.current_span_ctx()

    case sampler do
      nil -> %{parent: parent_ctx}
      sampler -> %{parent: parent_ctx, sampler: sampler}
    end
  end
end
