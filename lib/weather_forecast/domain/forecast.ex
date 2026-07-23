defmodule WeatherForecast.Domain.Forecast do
  @moduledoc """
  Pure calculations over forecast data. Free of configuration and I/O:
  the forecast window is an argument, supplied by the caller.
  """

  @doc """
  Averages the first `forecast_days` daily maximum temperatures.

  Values beyond the first `forecast_days` are ignored; when the API
  returns fewer, the available values are averaged.

  ## Examples

      iex> WeatherForecast.Domain.Forecast.average_max([28.0, 30.0, 26.0, 25.0, 28.0, 31.0], 6)
      28.0

      iex> WeatherForecast.Domain.Forecast.average_max([10, 10, 10, 10, 10, 10, 100], 6)
      10.0

      iex> WeatherForecast.Domain.Forecast.average_max([10, 20], 6)
      15.0
  """
  @spec average_max([number(), ...], pos_integer()) :: float()
  def average_max([_ | _] = temps, forecast_days)
      when is_integer(forecast_days) and forecast_days > 0 do
    considered_temps = Enum.take(temps, forecast_days)

    Enum.sum(considered_temps) / length(considered_temps)
  end
end
