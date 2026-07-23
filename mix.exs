defmodule WeatherForecast.MixProject do
  use Mix.Project

  def project do
    [
      app: :weather_forecast,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:dotenvy, "~> 1.1"},
      {:plug, "~> 1.0", only: :test},
      {:mox, "~> 1.2", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
