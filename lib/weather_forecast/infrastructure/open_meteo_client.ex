defmodule WeatherForecast.Infrastructure.OpenMeteoClient do
  @moduledoc """
  Client for the Open-Meteo forecast API (https://open-meteo.com/).

  The only module that knows the API shape. Every failure mode is
  normalized into a tagged error tuple. Endpoint constants come from
  `WeatherForecast.Config`; the test env additionally injects a
  `Req.Test` plug (and disables retries) through the same config.
  """

  alias WeatherForecast.Application.Ports.ForecastProvider
  alias WeatherForecast.Config
  alias WeatherForecast.Domain.City

  @behaviour ForecastProvider

  @impl ForecastProvider
  @spec fetch_daily_max(City.t()) :: {:ok, [number(), ...]} | {:error, term()}
  def fetch_daily_max(%City{} = city) do
    [
      base_url: Config.open_meteo_base_url(),
      url: "/v1/forecast",
      params: [
        latitude: city.latitude,
        longitude: city.longitude,
        daily: "temperature_2m_max",
        timezone: Config.open_meteo_timezone(),
        forecast_days: Config.forecast_days()
      ]
    ]
    |> Keyword.merge(Config.open_meteo_req_options())
    |> Req.request()
    |> handle_response()
  end

  defp handle_response({:ok, %Req.Response{status: 200, body: body}}), do: parse_body(body)

  defp handle_response({:ok, %Req.Response{body: %{"error" => true, "reason" => reason}}}),
    do: {:error, {:api_error, reason}}

  defp handle_response({:ok, %Req.Response{status: status}}),
    do: {:error, {:http_status, status}}

  defp handle_response({:error, exception}) when is_exception(exception),
    do: {:error, {:request_failed, Exception.message(exception)}}

  defp parse_body(%{"daily" => %{"temperature_2m_max" => [_ | _] = temps}}) do
    if Enum.all?(temps, &is_number/1) do
      {:ok, temps}
    else
      {:error, :malformed_response}
    end
  end

  defp parse_body(_body), do: {:error, :malformed_response}
end
