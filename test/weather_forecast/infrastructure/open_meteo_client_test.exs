defmodule WeatherForecast.Infrastructure.OpenMeteoClientTest do
  use ExUnit.Case, async: true

  alias WeatherForecast.Domain.City
  alias WeatherForecast.Infrastructure.OpenMeteoClient

  @city %City{name: "São Paulo", latitude: -23.55, longitude: -46.63}

  describe "fetch_daily_max/1" do
    test "returns the daily maximum temperatures" do
      Req.Test.stub(OpenMeteoClient, fn conn ->
        Req.Test.json(conn, %{
          "daily" => %{
            "time" => ["2026-07-23"],
            "temperature_2m_max" => [28.5, 29.3, 27.1, 26.8, 28.0, 30.2]
          }
        })
      end)

      assert {:ok, [28.5, 29.3, 27.1, 26.8, 28.0, 30.2]} = OpenMeteoClient.fetch_daily_max(@city)
    end

    test "requests the city coordinates for six daily maximums" do
      Req.Test.stub(OpenMeteoClient, fn conn ->
        params = URI.decode_query(conn.query_string)

        assert params["latitude"] == "-23.55"
        assert params["longitude"] == "-46.63"
        assert params["daily"] == "temperature_2m_max"
        assert params["timezone"] == "America/Sao_Paulo"
        assert params["forecast_days"] == "6"

        Req.Test.json(conn, %{"daily" => %{"temperature_2m_max" => [1.0]}})
      end)

      assert {:ok, [1.0]} = OpenMeteoClient.fetch_daily_max(@city)
    end

    test "surfaces the reason returned by the API" do
      Req.Test.stub(OpenMeteoClient, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"error" => true, "reason" => "Latitude must be in range"})
      end)

      assert {:error, {:api_error, "Latitude must be in range"}} =
               OpenMeteoClient.fetch_daily_max(@city)
    end

    test "reports the status of a non-JSON HTTP failure" do
      Req.Test.stub(OpenMeteoClient, fn conn ->
        Plug.Conn.send_resp(conn, 500, "internal error")
      end)

      assert {:error, {:http_status, 500}} = OpenMeteoClient.fetch_daily_max(@city)
    end

    test "rejects a success body without temperatures" do
      Req.Test.stub(OpenMeteoClient, fn conn ->
        Req.Test.json(conn, %{"daily" => %{"time" => []}})
      end)

      assert {:error, :malformed_response} = OpenMeteoClient.fetch_daily_max(@city)
    end

    test "rejects a success body with an empty temperature list" do
      Req.Test.stub(OpenMeteoClient, fn conn ->
        Req.Test.json(conn, %{"daily" => %{"temperature_2m_max" => []}})
      end)

      assert {:error, :malformed_response} = OpenMeteoClient.fetch_daily_max(@city)
    end

    test "rejects a success body with non-numeric temperatures" do
      Req.Test.stub(OpenMeteoClient, fn conn ->
        Req.Test.json(conn, %{"daily" => %{"temperature_2m_max" => ["hot", "hotter"]}})
      end)

      assert {:error, :malformed_response} = OpenMeteoClient.fetch_daily_max(@city)
    end

    test "reports transport-level failures" do
      Req.Test.stub(OpenMeteoClient, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, message}} = OpenMeteoClient.fetch_daily_max(@city)
      assert message =~ "timeout"
    end
  end
end
