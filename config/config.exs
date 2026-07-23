import Config

config :weather_forecast,
  forecast_provider: WeatherForecast.Infrastructure.OpenMeteoClient

if config_env() == :test do
  import_config "test.exs"
end
