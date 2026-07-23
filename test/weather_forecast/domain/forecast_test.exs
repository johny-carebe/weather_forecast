defmodule WeatherForecast.Domain.ForecastTest do
  use ExUnit.Case, async: true

  alias WeatherForecast.Domain.Forecast

  doctest Forecast

  describe "average_max/2" do
    test "averages temperatures that need float precision" do
      assert_in_delta Forecast.average_max([28.5, 29.3, 27.1, 26.8, 28.0, 30.2], 6),
                      28.3166,
                      0.001
    end

    test "averages fewer values than the window when that is all the API returned" do
      assert Forecast.average_max([10.0, 20.0, 30.0], 6) == 20.0
    end

    test "rejects an empty list" do
      empty_temps = Enum.take([1.0], 0)

      assert_raise FunctionClauseError, fn -> Forecast.average_max(empty_temps, 6) end
    end
  end
end
