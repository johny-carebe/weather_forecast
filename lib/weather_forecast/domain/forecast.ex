defmodule WeatherForecast.Domain.Forecast do
  @moduledoc """
  Pure calculations over forecast data.
  """

  @forecast_days 6

  @doc """
  Averages the first #{@forecast_days} daily maximum temperatures.

  Values beyond the first #{@forecast_days} are ignored; when the API
  returns fewer, the available values are averaged.

  ## Examples

      iex> WeatherForecast.Domain.Forecast.average_max([28.0, 30.0, 26.0, 25.0, 28.0, 31.0])
      28.0

      iex> WeatherForecast.Domain.Forecast.average_max([10, 10, 10, 10, 10, 10, 100])
      10.0

      iex> WeatherForecast.Domain.Forecast.average_max([10, 20])
      15.0
  """
  @spec average_max([number(), ...]) :: float()
  def average_max([_ | _] = temps) do
    considered_temps = Enum.take(temps, @forecast_days)

    Enum.sum(considered_temps) / length(considered_temps)
  end
end
