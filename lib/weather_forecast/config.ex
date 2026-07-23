defmodule WeatherForecast.Config do
  @moduledoc """
  Single read point for application configuration.

  Environment constants are declared in `.env`/`.env.test` and loaded
  into the app env by `config/runtime.exs`; compile-time wiring (the
  active `ForecastProvider` adapter, test-only Req options) lives in
  `config/*.exs`. No other module touches the app env directly.
  """

  @app :weather_forecast

  @spec forecast_provider() :: module()
  def forecast_provider, do: Application.fetch_env!(@app, :forecast_provider)

  @spec forecast_days() :: pos_integer()
  def forecast_days, do: Application.fetch_env!(@app, :forecast_days)

  @spec open_meteo_base_url() :: String.t()
  def open_meteo_base_url, do: Application.fetch_env!(@app, :open_meteo_base_url)

  @spec open_meteo_timezone() :: String.t()
  def open_meteo_timezone, do: Application.fetch_env!(@app, :open_meteo_timezone)

  @spec open_meteo_req_options() :: keyword()
  def open_meteo_req_options, do: Application.get_env(@app, :open_meteo_req_options, [])
end
