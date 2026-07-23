defmodule WeatherForecast.Domain.City do
  @moduledoc """
  A city whose forecast is fetched, identified by name and coordinates.
  """

  @enforce_keys [:name, :latitude, :longitude]
  defstruct [:name, :latitude, :longitude]

  @type t :: %__MODULE__{name: String.t(), latitude: float(), longitude: float()}
end
