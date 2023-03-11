defmodule OpenTelemetryDecorator.MixProject do
  use Mix.Project

  @version "1.2.3"
  @github_page "https://github.com/marcdel/open_telemetry_decorator"

  def project do
    [
      app: :open_telemetry_decorator,
      version: @version,
      name: "OpenTelemetryDecorator",
      description: "A function decorator for OpenTelemetry traces",
      homepage_url: @github_page,
      elixir: "~> 1.10",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test, "coveralls.json": :test],
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:decorator, "~> 1.4"},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:ex_doc, "~> 0.29.2", only: :dev, runtime: false},
      {:excoveralls, "~> 0.16.0", only: :test, runtime: false},
      {:opentelemetry, "~> 1.2"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.4", only: :test}
    ]
  end

  defp docs do
    [
      api_reference: false,
      authors: ["Marc Delagrammatikas"],
      canonical: "http://hexdocs.pm/open_telemetry_decorator",
      main: "OpenTelemetryDecorator",
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      files: ~w(mix.exs README.md lib),
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_page,
        "marcdel.com" => "https://www.marcdel.com",
        "OpenTelemetry Erlang SDK" => "https://github.com/open-telemetry/opentelemetry-erlang"
      },
      maintainers: ["Marc Delagrammatikas"]
    ]
  end
end
