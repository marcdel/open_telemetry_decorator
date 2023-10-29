defimpl OpenTelemetryDecorator.Traceable, for: Date do
  def otlp_value(date), do: Date.to_iso8601(date)
end

defimpl OpenTelemetryDecorator.Traceable, for: URI do
  def otlp_value(uri) do
    [
      {"authority", uri.authority},
      {"fragment", uri.fragment},
      {"host", uri.host},
      {"path", uri.path},
      {"port", uri.port},
      {"query", uri.query},
      {"scheme", uri.scheme},
      {"userinfo", uri.userinfo}
    ]
  end
end
