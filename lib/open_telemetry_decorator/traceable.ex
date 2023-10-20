defprotocol OpenTelemetryDecorator.Traceable do
  @type t :: OpenTelemetryDecorator.Traceable.t()

  @type otlp_value :: number() | String.t() | boolean() | OpenTelemetry.attributes_map()

  @spec otlp_value(t()) :: otlp_value()
  def otlp_value(value)
end
