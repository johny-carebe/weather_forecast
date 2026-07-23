defmodule WeatherForecast do
  @moduledoc """
  Public API: concurrent 6-day maximum-temperature averages for
  Brazilian cities, backed by the Open-Meteo API.
  """

  alias WeatherForecast.Application.UseCases.CalculateAverageMaxTemperatures

  @doc "Runs the report for the default cities."
  @spec run() :: [CalculateAverageMaxTemperatures.city_result()]
  def run, do: CalculateAverageMaxTemperatures.call()
end
