import Config

config :weather_forecast,
  forecast_provider: WeatherForecast.ForecastProviderMock,
  open_meteo_req_options: [
    plug: {Req.Test, WeatherForecast.Infrastructure.OpenMeteoClient},
    retry: false
  ]
