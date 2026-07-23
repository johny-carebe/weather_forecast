defmodule WeatherForecast.Domain.City do
  @moduledoc """
  A city whose forecast is fetched, identified by name and coordinates.
  """

  @enforce_keys [:name, :latitude, :longitude]
  defstruct [:name, :latitude, :longitude]

  @type t :: %__MODULE__{name: String.t(), latitude: float(), longitude: float()}

  @doc "The three cities covered by the report, in presentation order."
  @spec defaults() :: [t(), ...]
  def defaults do
    [
      %__MODULE__{name: "São Paulo", latitude: -23.55, longitude: -46.63},
      %__MODULE__{name: "Belo Horizonte", latitude: -19.92, longitude: -43.94},
      %__MODULE__{name: "Curitiba", latitude: -25.43, longitude: -49.27}
    ]
  end
end
