defmodule WeatherForecast.Presentation.CLITest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mox

  alias WeatherForecast.Domain.City
  alias WeatherForecast.ForecastProviderMock
  alias WeatherForecast.Presentation.CLI

  @sao_paulo %City{name: "São Paulo", latitude: -23.55, longitude: -46.63}

  setup :verify_on_exit!

  describe "run/0" do
    test "prints one line per city with the 6-day average" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn city ->
        case city.name do
          "São Paulo" -> {:ok, [27.0, 28.0, 29.0, 30.0, 28.5, 28.5]}
          "Belo Horizonte" -> {:ok, [26.8, 27.8, 28.8, 27.0, 28.0, 28.4]}
          "Curitiba" -> {:ok, [21.1, 22.1, 23.1, 22.0, 22.2, 22.1]}
        end
      end)

      output = capture_io(fn -> assert CLI.run() == :ok end)

      assert output == """
             São Paulo: 28.5°C
             Belo Horizonte: 27.8°C
             Curitiba: 22.1°C
             """
    end

    test "reports a failed city as unavailable without dropping the others" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn city ->
        case city.name do
          "Curitiba" -> {:error, {:http_status, 500}}
          _other -> {:ok, [12.0, 14.0]}
        end
      end)

      output = capture_io(fn -> CLI.run() end)

      assert output == """
             São Paulo: 13.0°C
             Belo Horizonte: 13.0°C
             Curitiba: unavailable (HTTP 500)
             """
    end
  end

  describe "format_line/1" do
    test "always renders exactly one decimal" do
      assert CLI.format_line({@sao_paulo, {:ok, 28.0}}) == "São Paulo: 28.0°C"
      assert CLI.format_line({@sao_paulo, {:ok, 27.799999999999997}}) == "São Paulo: 27.8°C"
    end

    test "renders each error reason as a readable message" do
      assert CLI.format_line({@sao_paulo, {:error, :timeout}}) ==
               "São Paulo: unavailable (timeout)"

      assert CLI.format_line({@sao_paulo, {:error, {:api_error, "Latitude must be in range"}}}) ==
               "São Paulo: unavailable (Latitude must be in range)"

      assert CLI.format_line({@sao_paulo, {:error, :malformed_response}}) ==
               "São Paulo: unavailable (malformed response)"

      assert CLI.format_line({@sao_paulo, {:error, {:request_failed, "connection refused"}}}) ==
               "São Paulo: unavailable (connection refused)"
    end
  end
end
