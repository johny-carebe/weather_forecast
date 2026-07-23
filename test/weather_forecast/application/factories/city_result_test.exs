defmodule WeatherForecast.Application.Factories.CityResultTest do
  use ExUnit.Case, async: true

  alias WeatherForecast.Application.Factories.CityResult
  alias WeatherForecast.Domain.City

  @city %City{name: "São Paulo", latitude: -23.55, longitude: -46.63}

  describe "build/2" do
    test "averages the configured forecast window on success" do
      assert CityResult.build(@city, {:ok, [28.0, 30.0, 26.0, 25.0, 28.0, 31.0]}) ==
               {@city, {:ok, 28.0}}
    end

    test "ignores values beyond the configured forecast window" do
      assert CityResult.build(@city, {:ok, [10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 100.0]}) ==
               {@city, {:ok, 10.0}}
    end

    test "passes a provider error through untouched" do
      assert CityResult.build(@city, {:error, :timeout}) == {@city, {:error, :timeout}}
    end
  end
end
