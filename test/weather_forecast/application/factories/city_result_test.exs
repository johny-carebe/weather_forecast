defmodule WeatherForecast.Application.Factories.CityResultTest do
  use ExUnit.Case, async: true

  alias WeatherForecast.Application.Factories.CityResult
  alias WeatherForecast.Domain.City

  @city %City{name: "São Paulo", latitude: -23.55, longitude: -46.63}

  describe "build/3" do
    test "averages the first forecast_days temperatures on success" do
      assert CityResult.build(@city, {:ok, [28.0, 30.0, 26.0, 25.0, 28.0, 31.0]}, 6) ==
               {@city, {:ok, 28.0}}
    end

    test "ignores values beyond the given forecast window" do
      assert CityResult.build(@city, {:ok, [10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 100.0]}, 6) ==
               {@city, {:ok, 10.0}}
    end

    test "applies whatever window it is given" do
      assert CityResult.build(@city, {:ok, [10.0, 20.0, 99.0]}, 2) == {@city, {:ok, 15.0}}
    end

    test "passes a provider error through untouched" do
      assert CityResult.build(@city, {:error, :timeout}, 6) == {@city, {:error, :timeout}}
    end
  end
end
