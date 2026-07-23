defmodule WeatherForecast.Application.UseCases.CalculateAverageMaxTemperatures do
  @moduledoc """
  Fetches every city's forecast concurrently — one task per city through
  the configured `ForecastProvider` adapter — and averages the daily
  maximum temperatures.
  """

  alias WeatherForecast.Domain.City
  alias WeatherForecast.Domain.Forecast

  @default_timeout 30_000

  @type city_result :: {City.t(), {:ok, float()} | {:error, term()}}

  @doc """
  One task per city; a city that fails (provider error or exceeded
  deadline) yields an `{:error, reason}` without affecting the others.
  Results come back in input order.
  """
  @spec call([City.t()], timeout()) :: [city_result()]
  def call(cities \\ City.defaults(), timeout \\ @default_timeout) do
    stream_results =
      Task.async_stream(
        cities,
        &fetch_average_max/1,
        max_concurrency: max(length(cities), 1),
        timeout: timeout,
        on_timeout: :kill_task,
        ordered: true
      )

    cities
    |> Enum.zip(stream_results)
    |> Enum.map(fn {city, stream_result} -> {city, unwrap(stream_result)} end)
  end

  defp fetch_average_max(%City{} = city) do
    with {:ok, temps} <- forecast_provider().fetch_daily_max(city) do
      {:ok, Forecast.average_max(temps)}
    end
  end

  defp forecast_provider do
    Application.fetch_env!(:weather_forecast, :forecast_provider)
  end

  defp unwrap({:ok, city_result}), do: city_result
  defp unwrap({:exit, :timeout}), do: {:error, :timeout}
end
