import Config

# Runtime overrides for deployment. The compile-time defaults in
# config/config.exs stand when the variable is unset; only the upstream
# endpoint is realistically worth overriding (e.g. pointing at a mock).
# Skipped in :test so the suite stays hermetic against the shell.
if config_env() != :test do
  if base_url = System.get_env("OPEN_METEO_BASE_URL") do
    config :weather_forecast, open_meteo_base_url: base_url
  end
end
