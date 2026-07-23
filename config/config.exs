import Config

config :weather_forecast,
  forecast_provider: WeatherForecast.Infrastructure.OpenMeteoClient,
  forecast_days: 6,
  open_meteo_base_url: "https://api.open-meteo.com",
  open_meteo_timezone: "America/Sao_Paulo"

if config_env() == :test do
  import_config "test.exs"
end
