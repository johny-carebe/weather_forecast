defmodule Mix.Tasks.Weather do
  @shortdoc "Prints each city's 6-day average maximum temperature"
  @moduledoc """
  Fetches the Open-Meteo forecast for the configured cities and prints
  one line per city:

      $ mix weather
      São Paulo: 28.5°C
      Belo Horizonte: 27.8°C
      Curitiba: 22.1°C
  """

  use Mix.Task

  alias WeatherForecast.Presentation.CLI

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    CLI.run()
  end
end
