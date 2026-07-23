defmodule WeatherForecast.Application.Ports.ForecastProvider do
  @moduledoc """
  Application-side port for fetching a city's daily maximum temperatures.

  Use cases depend on this contract; infrastructure adapters implement
  it. The active adapter is resolved from the `:forecast_provider` app
  env.
  """

  alias WeatherForecast.Domain.City

  @callback fetch_daily_max(City.t()) :: {:ok, [number(), ...]} | {:error, term()}
end
