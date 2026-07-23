defmodule WeatherForecast.Application.UseCases.CalculateAverageMaxTemperatures do
  @moduledoc """
  Fetches every city's forecast concurrently — one task per city through
  the configured `ForecastProvider` adapter — and builds each city's
  report entry through the `CityResult` factory.
  """

  alias WeatherForecast.Application.Factories.Cities
  alias WeatherForecast.Application.Factories.CityResult
  alias WeatherForecast.Config
  alias WeatherForecast.Domain.City

  @default_timeout 30_000

  @doc """
  One task per city; a city that fails (provider error or exceeded
  deadline) yields an `{:error, reason}` without affecting the others.
  Results come back in input order.
  """
  @spec call([City.t()], timeout()) :: [CityResult.t()]
  def call(cities \\ Cities.defaults(), timeout \\ @default_timeout) do
    stream_results =
      Task.async_stream(
        cities,
        &fetch_daily_max/1,
        max_concurrency: max(length(cities), 1),
        timeout: timeout,
        on_timeout: :kill_task,
        ordered: true
      )

    forecast_days = Config.forecast_days()

    cities
    |> Enum.zip(stream_results)
    |> Enum.map(&build_city_result(&1, forecast_days))
  end

  defp fetch_daily_max(%City{} = city), do: Config.forecast_provider().fetch_daily_max(city)

  defp build_city_result({city, stream_result}, forecast_days) do
    CityResult.build(city, unwrap(stream_result), forecast_days)
  end

  defp unwrap({:ok, provider_result}), do: provider_result
  defp unwrap({:exit, :timeout}), do: {:error, :timeout}
end
