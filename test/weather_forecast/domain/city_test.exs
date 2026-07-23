defmodule WeatherForecast.Domain.CityTest do
  use ExUnit.Case, async: true

  alias WeatherForecast.Domain.City

  describe "defaults/0" do
    test "returns the three covered cities in presentation order" do
      assert [
               %City{name: "São Paulo", latitude: -23.55, longitude: -46.63},
               %City{name: "Belo Horizonte", latitude: -19.92, longitude: -43.94},
               %City{name: "Curitiba", latitude: -25.43, longitude: -49.27}
             ] = City.defaults()
    end
  end
end
