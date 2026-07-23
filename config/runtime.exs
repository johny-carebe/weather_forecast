import Config
import Dotenvy

# Right-most source wins. Tests pin the committed env files above the
# shell so the suite stays hermetic; other envs let real environment
# variables (and a gitignored .env.local) override the committed files.
env_sources =
  case config_env() do
    :test -> [System.get_env(), ".env", ".env.test"]
    env -> [".env", ".env.#{env}", ".env.local", System.get_env()]
  end

source!(env_sources)

config :weather_forecast,
  forecast_days: env!("FORECAST_DAYS", :integer!),
  open_meteo_base_url: env!("OPEN_METEO_BASE_URL", :string!),
  open_meteo_timezone: env!("OPEN_METEO_TIMEZONE", :string!)
