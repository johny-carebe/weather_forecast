defmodule WeatherForecast.Application.Factories.Cities do
  @moduledoc """
  Builds the `Domain.City` entities covered by the report.
  """

  alias WeatherForecast.Domain.City

  @doc "The three covered cities, in presentation order."
  @spec defaults() :: [City.t(), ...]
  def defaults do
    [
      %City{name: "São Paulo", latitude: -23.55, longitude: -46.63},
      %City{name: "Belo Horizonte", latitude: -19.92, longitude: -43.94},
      %City{name: "Curitiba", latitude: -25.43, longitude: -49.27}
    ]
  end
end
