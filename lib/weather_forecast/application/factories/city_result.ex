defmodule WeatherForecast.Application.Factories.CityResult do
  @moduledoc """
  Builds a per-city report entry from the provider's response,
  delegating the averaging to the domain. Use cases go through this
  factory instead of calling the domain directly.
  """

  alias WeatherForecast.Config
  alias WeatherForecast.Domain.City
  alias WeatherForecast.Domain.Forecast

  @type t :: {City.t(), {:ok, float()} | {:error, term()}}

  @spec build(City.t(), {:ok, [number(), ...]} | {:error, term()}) :: t()
  def build(%City{} = city, {:ok, temps}),
    do: {city, {:ok, Forecast.average_max(temps, Config.forecast_days())}}

  def build(%City{} = city, {:error, reason}), do: {city, {:error, reason}}
end
