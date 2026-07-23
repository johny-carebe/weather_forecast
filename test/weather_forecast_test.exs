defmodule WeatherForecastTest do
  use ExUnit.Case, async: true

  import Mox

  alias WeatherForecast.Domain.City
  alias WeatherForecast.ForecastProviderMock

  setup :verify_on_exit!

  test "run/0 reports the default cities through the configured provider" do
    expect(ForecastProviderMock, :fetch_daily_max, 3, fn %City{} -> {:ok, [10.0]} end)

    assert [
             {%City{name: "São Paulo"}, {:ok, 10.0}},
             {%City{name: "Belo Horizonte"}, {:ok, 10.0}},
             {%City{name: "Curitiba"}, {:ok, 10.0}}
           ] = WeatherForecast.run()
  end
end
