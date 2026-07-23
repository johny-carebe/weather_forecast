defmodule WeatherForecast.Application.UseCases.CalculateAverageMaxTemperaturesTest do
  use ExUnit.Case, async: true

  import Mox

  alias WeatherForecast.Application.Factories.Cities
  alias WeatherForecast.Application.UseCases.CalculateAverageMaxTemperatures
  alias WeatherForecast.Domain.City
  alias WeatherForecast.ForecastProviderMock

  setup :verify_on_exit!

  describe "call/2" do
    test "averages every city's forecast, preserving input order" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn %City{} = city ->
        case city.name do
          "São Paulo" -> {:ok, [28.0, 30.0, 26.0, 25.0, 28.0, 31.0]}
          "Belo Horizonte" -> {:ok, [20.0, 21.0, 22.0, 23.0, 24.0, 25.0]}
          "Curitiba" -> {:ok, [10.0, 10.0, 10.0, 10.0, 10.0, 10.0]}
        end
      end)

      assert [
               {%City{name: "São Paulo"}, {:ok, 28.0}},
               {%City{name: "Belo Horizonte"}, {:ok, 22.5}},
               {%City{name: "Curitiba"}, {:ok, 10.0}}
             ] = CalculateAverageMaxTemperatures.call()
    end

    test "isolates one city's failure from the others" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn city ->
        case city.name do
          "Curitiba" -> {:error, {:http_status, 500}}
          _other -> {:ok, [12.0, 14.0]}
        end
      end)

      assert [
               {%City{name: "São Paulo"}, {:ok, 13.0}},
               {%City{name: "Belo Horizonte"}, {:ok, 13.0}},
               {%City{name: "Curitiba"}, {:error, {:http_status, 500}}}
             ] = CalculateAverageMaxTemperatures.call()
    end

    test "converts an exceeded deadline into a per-city timeout error" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn city ->
        case city.name do
          "Curitiba" -> Process.sleep(500)
          _other -> :ok
        end

        {:ok, [10.0]}
      end)

      assert [
               {%City{name: "São Paulo"}, {:ok, 10.0}},
               {%City{name: "Belo Horizonte"}, {:ok, 10.0}},
               {%City{name: "Curitiba"}, {:error, :timeout}}
             ] = CalculateAverageMaxTemperatures.call(Cities.defaults(), 100)
    end

    test "returns an empty report for an empty city list" do
      assert CalculateAverageMaxTemperatures.call([]) == []
    end
  end
end
