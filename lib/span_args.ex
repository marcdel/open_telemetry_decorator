defmodule SpanArgs do
  @moduledoc false

  require OpenTelemetry.Tracer

  def new(opts) when is_list(opts) do
    sampler = Keyword.get(opts, :sampler)

    case sampler do
      nil -> %{}
      sampler -> %{sampler: sampler}
    end
  end
end
