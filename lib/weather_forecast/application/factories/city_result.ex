defmodule WeatherForecast.Application.Factories.CityResult do
  @moduledoc """
  Builds a per-city report entry from the provider's response,
  delegating the averaging to the domain. Use cases go through this
  factory instead of calling the domain directly; the forecast window
  arrives as an argument, so the factory reads no config.
  """

  alias WeatherForecast.Domain.City
  alias WeatherForecast.Domain.Forecast

  @type t :: {City.t(), {:ok, float()} | {:error, term()}}

  @spec build(City.t(), {:ok, [number(), ...]} | {:error, term()}, pos_integer()) :: t()
  def build(%City{} = city, {:ok, temps}, forecast_days),
    do: {city, {:ok, Forecast.average_max(temps, forecast_days)}}

  def build(%City{} = city, {:error, reason}, _forecast_days), do: {city, {:error, reason}}
end
