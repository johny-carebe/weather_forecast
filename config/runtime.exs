import Config
import Dotenvy

source!([".env", ".env.#{config_env()}", System.get_env()])

config :weather_forecast,
  forecast_days: env!("FORECAST_DAYS", :integer),
  open_meteo_base_url: env!("OPEN_METEO_BASE_URL", :string),
  open_meteo_timezone: env!("OPEN_METEO_TIMEZONE", :string)
