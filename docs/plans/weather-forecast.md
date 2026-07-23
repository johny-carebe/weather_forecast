# weather_forecast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An Elixir CLI that concurrently fetches Open-Meteo forecasts for three Brazilian cities and prints each city's 6-day average maximum temperature.

**Architecture:** Functional core (`City`, `Forecast`), one API-aware client (`OpenMeteo`), a `Task.async_stream` orchestrator (`WeatherForecast`), and a thin IO shell (`CLI` + `mix weather`). No custom supervision tree — the `:req` application supervises its own pool.

**Tech Stack:** Elixir 1.20.2 / OTP 29.0.3 (pinned in `.tool-versions`), Req ~> 0.5 (HTTP + JSON), Req.Test + Plug (test-only API stubbing), Credo (lint), ExUnit.

Authoritative design: `docs/specs/weather-forecast-design.md`.

## Global Constraints

- All commands run from the repo root.
- Tests never touch the network: `config/test.exs` injects `plug: {Req.Test, WeatherForecast.OpenMeteo}` and `retry: false` into the client's Req options.
- Every test module is `async: true`.
- Every public function has `@spec`; every module has `@moduledoc`.
- Run `mix format` before every commit; code must compile with `--warnings-as-errors`.
- Commits are local only — never push. Every commit uses this exact template:

```bash
git commit -m "$(cat <<'EOF'
<subject in imperative mood>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 1: Scaffold the mix project

**Files:**
- Create (generated): `mix.exs`, `.formatter.exs`, `.gitignore`, `README.md`, `lib/weather_forecast.ex`, `test/test_helper.exs`
- Create: `config/config.exs`, `config/test.exs`
- Delete: `test/weather_forecast_test.exs` (generated hello-world test; the real one returns in Task 5)
- Already present, commit here: `.tool-versions`

**Interfaces:**
- Produces: app `:weather_forecast` with deps `req`, `plug` (test), `credo` (dev/test); app env key `:open_meteo_req_options` consumed by Task 4.

- [x] **Step 1: Generate the project in place**

Run: `mix new . --app weather_forecast`
Expected: `* creating mix.exs`, `* creating lib/weather_forecast.ex`, etc. (generates into the existing clone; `docs/` and dotfiles don't conflict).

- [x] **Step 2: Declare dependencies in `mix.exs`**

Replace the generated `deps/0` so the full file reads:

```elixir
defmodule WeatherForecast.MixProject do
  use Mix.Project

  def project do
    [
      app: :weather_forecast,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:plug, "~> 1.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
```

`plug` is required by `Req.Test` (it is an optional dependency of `req`).

- [x] **Step 3: Add config files**

`config/config.exs`:

```elixir
import Config

if config_env() == :test do
  import_config "test.exs"
end
```

`config/test.exs`:

```elixir
import Config

config :weather_forecast,
  open_meteo_req_options: [
    plug: {Req.Test, WeatherForecast.OpenMeteo},
    retry: false
  ]
```

- [x] **Step 4: Strip the generated hello-world**

Replace `lib/weather_forecast.ex` with:

```elixir
defmodule WeatherForecast do
  @moduledoc """
  Concurrent 6-day maximum-temperature averages for Brazilian cities,
  backed by the Open-Meteo API.
  """
end
```

Delete `test/weather_forecast_test.exs`.

- [x] **Step 5: Verify the scaffold**

Run: `mix deps.get && mix test`
Expected: deps resolve (req, finch, mint, plug, credo, …); `0 failures`.

- [x] **Step 6: Commit**

```bash
mix format
git add -A
```

Commit (template above) with subject: `Scaffold the mix project`

---

### Task 2: City struct and defaults

**Files:**
- Create: `lib/weather_forecast/city.ex`
- Test: `test/weather_forecast/city_test.exs`

**Interfaces:**
- Produces: `%WeatherForecast.City{name: String.t(), latitude: float(), longitude: float()}` (`@enforce_keys` on all three) and `City.defaults/0 :: [City.t(), ...]` returning São Paulo, Belo Horizonte, Curitiba in that order.

- [x] **Step 1: Write the failing test**

`test/weather_forecast/city_test.exs`:

```elixir
defmodule WeatherForecast.CityTest do
  use ExUnit.Case, async: true

  alias WeatherForecast.City

  describe "defaults/0" do
    test "returns the three covered cities in presentation order" do
      assert [
               %City{name: "São Paulo", latitude: -23.55, longitude: -46.63},
               %City{name: "Belo Horizonte", latitude: -19.92, longitude: -43.94},
               %City{name: "Curitiba", latitude: -25.43, longitude: -49.27}
             ] = City.defaults()
    end
  end
end
```

- [x] **Step 2: Run test to verify it fails**

Run: `mix test test/weather_forecast/city_test.exs`
Expected: FAIL — `WeatherForecast.City.defaults/0 is undefined (module WeatherForecast.City is not available)`

- [x] **Step 3: Write the implementation**

`lib/weather_forecast/city.ex`:

```elixir
defmodule WeatherForecast.City do
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
```

- [x] **Step 4: Run test to verify it passes**

Run: `mix test test/weather_forecast/city_test.exs`
Expected: `1 test, 0 failures`

- [x] **Step 5: Commit**

```bash
mix format
git add lib/weather_forecast/city.ex test/weather_forecast/city_test.exs
```

Commit with subject: `Add the City struct with the three covered cities`

---

### Task 3: Forecast averaging (pure core)

**Files:**
- Create: `lib/weather_forecast/forecast.ex`
- Test: `test/weather_forecast/forecast_test.exs`

**Interfaces:**
- Produces: `Forecast.average_max/1 :: [number(), ...] -> float()` — mean of the first six values; fewer than six averages what is available; raises `FunctionClauseError` on `[]`.

- [x] **Step 1: Write the failing test**

`test/weather_forecast/forecast_test.exs`:

```elixir
defmodule WeatherForecast.ForecastTest do
  use ExUnit.Case, async: true

  alias WeatherForecast.Forecast

  doctest Forecast

  describe "average_max/1" do
    test "averages temperatures that need float precision" do
      assert_in_delta Forecast.average_max([28.5, 29.3, 27.1, 26.8, 28.0, 30.2]),
                      28.3166,
                      0.001
    end

    test "averages fewer than six values when that is all the API returned" do
      assert Forecast.average_max([10.0, 20.0, 30.0]) == 20.0
    end

    test "rejects an empty list" do
      assert_raise FunctionClauseError, fn -> Forecast.average_max([]) end
    end
  end
end
```

- [x] **Step 2: Run test to verify it fails**

Run: `mix test test/weather_forecast/forecast_test.exs`
Expected: FAIL — `WeatherForecast.Forecast.average_max/1 is undefined`

- [x] **Step 3: Write the implementation (doctests included)**

`lib/weather_forecast/forecast.ex`:

```elixir
defmodule WeatherForecast.Forecast do
  @moduledoc """
  Pure calculations over forecast data.
  """

  @forecast_days 6

  @doc """
  Averages the first #{@forecast_days} daily maximum temperatures.

  Values beyond the first #{@forecast_days} are ignored; when the API
  returns fewer, the available values are averaged.

  ## Examples

      iex> WeatherForecast.Forecast.average_max([28.0, 30.0, 26.0, 25.0, 28.0, 31.0])
      28.0

      iex> WeatherForecast.Forecast.average_max([10, 10, 10, 10, 10, 10, 100])
      10.0

      iex> WeatherForecast.Forecast.average_max([10, 20])
      15.0
  """
  @spec average_max([number(), ...]) :: float()
  def average_max([_ | _] = temps) do
    considered_temps = Enum.take(temps, @forecast_days)

    Enum.sum(considered_temps) / length(considered_temps)
  end
end
```

- [x] **Step 4: Run test to verify it passes**

Run: `mix test test/weather_forecast/forecast_test.exs`
Expected: `6 tests, 0 failures` (3 doctests + 3 tests)

- [x] **Step 5: Commit**

```bash
mix format
git add lib/weather_forecast/forecast.ex test/weather_forecast/forecast_test.exs
```

Commit with subject: `Add the pure 6-day average calculation`

---

### Task 4: Open-Meteo client

**Files:**
- Create: `lib/weather_forecast/open_meteo.ex`
- Test: `test/weather_forecast/open_meteo_test.exs`

**Interfaces:**
- Consumes: `City.t` (Task 2); app env `:open_meteo_req_options` (Task 1).
- Produces: `OpenMeteo.fetch_daily_max/1 :: City.t() -> {:ok, [number(), ...]} | {:error, reason}` with reasons `{:api_error, String.t()}`, `{:http_status, integer()}`, `:malformed_response`, `{:request_failed, String.t()}`. The `Req.Test` stub name is the module itself: `WeatherForecast.OpenMeteo`.

- [x] **Step 1: Write the failing tests**

`test/weather_forecast/open_meteo_test.exs`:

```elixir
defmodule WeatherForecast.OpenMeteoTest do
  use ExUnit.Case, async: true

  alias WeatherForecast.City
  alias WeatherForecast.OpenMeteo

  @city %City{name: "São Paulo", latitude: -23.55, longitude: -46.63}

  describe "fetch_daily_max/1" do
    test "returns the daily maximum temperatures" do
      Req.Test.stub(OpenMeteo, fn conn ->
        Req.Test.json(conn, %{
          "daily" => %{
            "time" => ["2026-07-23"],
            "temperature_2m_max" => [28.5, 29.3, 27.1, 26.8, 28.0, 30.2]
          }
        })
      end)

      assert {:ok, [28.5, 29.3, 27.1, 26.8, 28.0, 30.2]} = OpenMeteo.fetch_daily_max(@city)
    end

    test "requests the city coordinates for six daily maximums" do
      Req.Test.stub(OpenMeteo, fn conn ->
        params = URI.decode_query(conn.query_string)

        assert params["latitude"] == "-23.55"
        assert params["longitude"] == "-46.63"
        assert params["daily"] == "temperature_2m_max"
        assert params["timezone"] == "America/Sao_Paulo"
        assert params["forecast_days"] == "6"

        Req.Test.json(conn, %{"daily" => %{"temperature_2m_max" => [1.0]}})
      end)

      assert {:ok, [1.0]} = OpenMeteo.fetch_daily_max(@city)
    end

    test "surfaces the reason returned by the API" do
      Req.Test.stub(OpenMeteo, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"error" => true, "reason" => "Latitude must be in range"})
      end)

      assert {:error, {:api_error, "Latitude must be in range"}} =
               OpenMeteo.fetch_daily_max(@city)
    end

    test "reports the status of a non-JSON HTTP failure" do
      Req.Test.stub(OpenMeteo, fn conn ->
        Plug.Conn.send_resp(conn, 500, "internal error")
      end)

      assert {:error, {:http_status, 500}} = OpenMeteo.fetch_daily_max(@city)
    end

    test "rejects a success body without temperatures" do
      Req.Test.stub(OpenMeteo, fn conn ->
        Req.Test.json(conn, %{"daily" => %{"time" => []}})
      end)

      assert {:error, :malformed_response} = OpenMeteo.fetch_daily_max(@city)
    end

    test "rejects a success body with an empty temperature list" do
      Req.Test.stub(OpenMeteo, fn conn ->
        Req.Test.json(conn, %{"daily" => %{"temperature_2m_max" => []}})
      end)

      assert {:error, :malformed_response} = OpenMeteo.fetch_daily_max(@city)
    end

    test "rejects a success body with non-numeric temperatures" do
      Req.Test.stub(OpenMeteo, fn conn ->
        Req.Test.json(conn, %{"daily" => %{"temperature_2m_max" => ["hot", "hotter"]}})
      end)

      assert {:error, :malformed_response} = OpenMeteo.fetch_daily_max(@city)
    end

    test "reports transport-level failures" do
      Req.Test.stub(OpenMeteo, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, message}} = OpenMeteo.fetch_daily_max(@city)
      assert message =~ "timeout"
    end
  end
end
```

- [x] **Step 2: Run test to verify it fails**

Run: `mix test test/weather_forecast/open_meteo_test.exs`
Expected: FAIL — `WeatherForecast.OpenMeteo.fetch_daily_max/1 is undefined`

- [x] **Step 3: Write the implementation**

`lib/weather_forecast/open_meteo.ex`:

```elixir
defmodule WeatherForecast.OpenMeteo do
  @moduledoc """
  Client for the Open-Meteo forecast API (https://open-meteo.com/).

  The only module that knows the API shape. Every failure mode is
  normalized into a tagged error tuple; test config injects a
  `Req.Test` plug (and disables retries) through the
  `:open_meteo_req_options` app env.
  """

  alias WeatherForecast.City

  @base_url "https://api.open-meteo.com"
  @timezone "America/Sao_Paulo"
  @forecast_days 6

  @spec fetch_daily_max(City.t()) :: {:ok, [number(), ...]} | {:error, term()}
  def fetch_daily_max(%City{} = city) do
    [
      base_url: @base_url,
      url: "/v1/forecast",
      params: [
        latitude: city.latitude,
        longitude: city.longitude,
        daily: "temperature_2m_max",
        timezone: @timezone,
        forecast_days: @forecast_days
      ]
    ]
    |> Keyword.merge(configured_req_options())
    |> Req.request()
    |> handle_response()
  end

  defp configured_req_options do
    Application.get_env(:weather_forecast, :open_meteo_req_options, [])
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
```

- [x] **Step 4: Run test to verify it passes**

Run: `mix test test/weather_forecast/open_meteo_test.exs`
Expected: `8 tests, 0 failures`

- [x] **Step 5: Commit**

```bash
mix format
git add lib/weather_forecast/open_meteo.ex test/weather_forecast/open_meteo_test.exs
```

Commit with subject: `Add the Open-Meteo client with normalized errors`

---

### Task 5: Concurrent orchestrator

**Files:**
- Modify: `lib/weather_forecast.ex`
- Test: `test/weather_forecast_test.exs`

**Interfaces:**
- Consumes: `City.defaults/0`, `OpenMeteo.fetch_daily_max/1`, `Forecast.average_max/1`.
- Produces: `WeatherForecast.run/0..2` — `run(cities \\ City.defaults(), timeout \\ 30_000) :: [{City.t(), {:ok, float()} | {:error, term()}}]`, results in input order; timeout normalized to `{:error, :timeout}`.

- [x] **Step 1: Write the failing tests**

`test/weather_forecast_test.exs`:

```elixir
defmodule WeatherForecastTest do
  use ExUnit.Case, async: true

  alias WeatherForecast.City
  alias WeatherForecast.OpenMeteo

  describe "run/2" do
    test "fetches every city's average, preserving input order" do
      stub_forecasts_by_latitude(%{
        "-23.55" => [28.0, 30.0, 26.0, 25.0, 28.0, 31.0],
        "-19.92" => [20.0, 21.0, 22.0, 23.0, 24.0, 25.0],
        "-25.43" => [10.0, 10.0, 10.0, 10.0, 10.0, 10.0]
      })

      assert [
               {%City{name: "São Paulo"}, {:ok, 28.0}},
               {%City{name: "Belo Horizonte"}, {:ok, 22.5}},
               {%City{name: "Curitiba"}, {:ok, 10.0}}
             ] = WeatherForecast.run()
    end

    test "isolates one city's failure from the others" do
      Req.Test.stub(OpenMeteo, fn conn ->
        case URI.decode_query(conn.query_string) do
          %{"latitude" => "-25.43"} ->
            Plug.Conn.send_resp(conn, 500, "internal error")

          _params ->
            Req.Test.json(conn, %{"daily" => %{"temperature_2m_max" => [12.0, 14.0]}})
        end
      end)

      assert [
               {%City{name: "São Paulo"}, {:ok, 13.0}},
               {%City{name: "Belo Horizonte"}, {:ok, 13.0}},
               {%City{name: "Curitiba"}, {:error, {:http_status, 500}}}
             ] = WeatherForecast.run()
    end

    test "converts an exceeded deadline into a per-city timeout error" do
      Req.Test.stub(OpenMeteo, fn conn ->
        case URI.decode_query(conn.query_string) do
          %{"latitude" => "-25.43"} -> Process.sleep(500)
          _params -> :ok
        end

        Req.Test.json(conn, %{"daily" => %{"temperature_2m_max" => [10.0]}})
      end)

      assert [
               {%City{name: "São Paulo"}, {:ok, 10.0}},
               {%City{name: "Belo Horizonte"}, {:ok, 10.0}},
               {%City{name: "Curitiba"}, {:error, :timeout}}
             ] = WeatherForecast.run(City.defaults(), 100)
    end

    test "returns an empty report for an empty city list" do
      assert WeatherForecast.run([]) == []
    end
  end

  defp stub_forecasts_by_latitude(temps_by_latitude) do
    Req.Test.stub(OpenMeteo, fn conn ->
      %{"latitude" => latitude} = URI.decode_query(conn.query_string)

      Req.Test.json(conn, %{
        "daily" => %{"temperature_2m_max" => Map.fetch!(temps_by_latitude, latitude)}
      })
    end)
  end
end
```

- [x] **Step 2: Run test to verify it fails**

Run: `mix test test/weather_forecast_test.exs`
Expected: FAIL — `WeatherForecast.run/0 is undefined or private`

- [x] **Step 3: Write the implementation**

Replace `lib/weather_forecast.ex` with:

```elixir
defmodule WeatherForecast do
  @moduledoc """
  Concurrent 6-day maximum-temperature averages for Brazilian cities,
  backed by the Open-Meteo API.
  """

  alias WeatherForecast.City
  alias WeatherForecast.Forecast
  alias WeatherForecast.OpenMeteo

  @default_timeout 30_000

  @doc """
  Fetches every city's forecast concurrently and averages the daily
  maximums.

  One task per city; a city that fails (HTTP error, malformed body,
  exceeded deadline) yields an `{:error, reason}` without affecting the
  others. Results come back in input order.
  """
  @spec run([City.t()], timeout()) :: [{City.t(), {:ok, float()} | {:error, term()}}]
  def run(cities \\ City.defaults(), timeout \\ @default_timeout) do
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
    with {:ok, temps} <- OpenMeteo.fetch_daily_max(city) do
      {:ok, Forecast.average_max(temps)}
    end
  end

  defp unwrap({:ok, city_result}), do: city_result
  defp unwrap({:exit, :timeout}), do: {:error, :timeout}
end
```

- [x] **Step 4: Run test to verify it passes**

Run: `mix test test/weather_forecast_test.exs`
Expected: `4 tests, 0 failures`

- [x] **Step 5: Run the whole suite**

Run: `mix test`
Expected: all green — `19 tests, 0 failures` (1 + 6 + 8 + 4)

- [x] **Step 6: Commit**

```bash
mix format
git add lib/weather_forecast.ex test/weather_forecast_test.exs
```

Commit with subject: `Fan out the city forecasts with Task.async_stream`

---

### Task 6: CLI formatting and output

**Files:**
- Create: `lib/weather_forecast/cli.ex`
- Test: `test/weather_forecast/cli_test.exs`

**Interfaces:**
- Consumes: `WeatherForecast.run/0` (Task 5).
- Produces: `CLI.run/0 :: :ok` (prints the report) and `CLI.format_line/1 :: {City.t(), {:ok, float()} | {:error, term()}} -> String.t()` (consumed by Task 7 only through `run/0`).

- [x] **Step 1: Write the failing tests**

`test/weather_forecast/cli_test.exs`:

```elixir
defmodule WeatherForecast.CLITest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias WeatherForecast.City
  alias WeatherForecast.CLI
  alias WeatherForecast.OpenMeteo

  @sao_paulo %City{name: "São Paulo", latitude: -23.55, longitude: -46.63}

  describe "run/0" do
    test "prints one line per city with the 6-day average" do
      stub_forecasts_by_latitude(%{
        "-23.55" => [27.0, 28.0, 29.0, 30.0, 28.5, 28.5],
        "-19.92" => [26.8, 27.8, 28.8, 27.0, 28.0, 28.4],
        "-25.43" => [21.1, 22.1, 23.1, 22.0, 22.2, 22.1]
      })

      output = capture_io(fn -> assert CLI.run() == :ok end)

      assert output == """
             São Paulo: 28.5°C
             Belo Horizonte: 27.8°C
             Curitiba: 22.1°C
             """
    end

    test "reports a failed city as unavailable without dropping the others" do
      Req.Test.stub(OpenMeteo, fn conn ->
        case URI.decode_query(conn.query_string) do
          %{"latitude" => "-25.43"} ->
            Plug.Conn.send_resp(conn, 500, "internal error")

          _params ->
            Req.Test.json(conn, %{"daily" => %{"temperature_2m_max" => [12.0, 14.0]}})
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

  defp stub_forecasts_by_latitude(temps_by_latitude) do
    Req.Test.stub(OpenMeteo, fn conn ->
      %{"latitude" => latitude} = URI.decode_query(conn.query_string)

      Req.Test.json(conn, %{
        "daily" => %{"temperature_2m_max" => Map.fetch!(temps_by_latitude, latitude)}
      })
    end)
  end
end
```

- [x] **Step 2: Run test to verify it fails**

Run: `mix test test/weather_forecast/cli_test.exs`
Expected: FAIL — `WeatherForecast.CLI.run/0 is undefined`

- [x] **Step 3: Write the implementation**

`lib/weather_forecast/cli.ex`:

```elixir
defmodule WeatherForecast.CLI do
  @moduledoc """
  Formats the forecast report and prints it to stdout.

  Owns all presentation concerns: the core returns full-precision
  floats and tagged errors; this module renders one decimal and
  human-readable failure reasons.
  """

  alias WeatherForecast.City

  @spec run() :: :ok
  def run do
    WeatherForecast.run()
    |> Enum.each(&IO.puts(format_line(&1)))
  end

  @spec format_line({City.t(), {:ok, float()} | {:error, term()}}) :: String.t()
  def format_line({%City{name: name}, {:ok, average}}) do
    "#{name}: #{:erlang.float_to_binary(average, decimals: 1)}°C"
  end

  def format_line({%City{name: name}, {:error, reason}}) do
    "#{name}: unavailable (#{format_reason(reason)})"
  end

  defp format_reason({:api_error, message}), do: message
  defp format_reason({:http_status, status}), do: "HTTP #{status}"
  defp format_reason({:request_failed, message}), do: message
  defp format_reason(:malformed_response), do: "malformed response"
  defp format_reason(:timeout), do: "timeout"
  defp format_reason(other), do: inspect(other)
end
```

- [x] **Step 4: Run test to verify it passes**

Run: `mix test test/weather_forecast/cli_test.exs`
Expected: `4 tests, 0 failures`

- [x] **Step 5: Commit**

```bash
mix format
git add lib/weather_forecast/cli.ex test/weather_forecast/cli_test.exs
```

Commit with subject: `Add the CLI report rendering`

---

### Task 7: `mix weather` task + live smoke run

**Files:**
- Create: `lib/mix/tasks/weather.ex`

**Interfaces:**
- Consumes: `CLI.run/0`.
- Produces: the `mix weather` entry point.

- [x] **Step 1: Write the task**

`lib/mix/tasks/weather.ex`:

```elixir
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

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    WeatherForecast.CLI.run()
  end
end
```

(No unit test: the task is a two-line shell over `CLI.run/0`, which Task 6 covers; this task's verification is the live run below.)

- [x] **Step 2: Verify against the real API (the one intentional network call)**

Run: `mix weather`
Expected: three lines, today's real values, e.g.:

```
São Paulo: 24.3°C
Belo Horizonte: 26.1°C
Curitiba: 20.8°C
```

Also confirm `mix help weather` shows the shortdoc.

- [x] **Step 3: Run the whole suite**

Run: `mix test`
Expected: `23 tests, 0 failures`

- [x] **Step 4: Commit**

```bash
mix format
git add lib/mix/tasks/weather.ex
```

Commit with subject: `Add the mix weather entry point`

---

### Task 8: README

**Files:**
- Modify: `README.md` (replace the `mix new` boilerplate entirely)

**Interfaces:** none (documentation).

- [x] **Step 1: Write the README**

Replace `README.md` with:

````markdown
# weather_forecast

Fetches the [Open-Meteo](https://open-meteo.com/) weather forecast for three
Brazilian cities concurrently, averages each city's daily maximum temperature
(`temperature_2m_max`) over the next six days (today + 5), and prints:

```
São Paulo: 28.5°C
Belo Horizonte: 27.8°C
Curitiba: 22.1°C
```

## Requirements

Erlang/OTP 29.0.3 and Elixir 1.20.2, pinned in `.tool-versions` — with
[asdf](https://asdf-vm.com/) installed, run `asdf install` inside the repo.

## Usage

```
mix deps.get
mix weather
```

`WeatherForecast.run/0` returns the raw `{city, result}` pairs and can be used
directly from `iex -S mix`.

## Design

```
mix weather
  └─ WeatherForecast.CLI            formatting + IO
       └─ WeatherForecast           concurrent fan-out (Task.async_stream)
            ├─ WeatherForecast.OpenMeteo   HTTP client + response validation
            ├─ WeatherForecast.Forecast    pure math (average)
            └─ WeatherForecast.City        static city data
```

- The three API calls run concurrently via `Task.async_stream` — bounded
  concurrency, a per-city deadline, ordered results. A city that fails
  (timeout, HTTP error, malformed body) is printed as `unavailable (<reason>)`
  without affecting the other cities.
- [Req](https://hexdocs.pm/req) is the HTTP client; its built-in transient
  retries stay enabled for real runs and are disabled in tests.
- No custom supervision tree: this is a run-once CLI and the `:req`
  application supervises its own connection pool (`Task.Supervisor` was
  considered and rejected as ceremony for this shape).
- Full rationale: [`docs/specs/weather-forecast-design.md`](docs/specs/weather-forecast-design.md).

## Tests

```
mix test
```

The Open-Meteo API is mocked with
[`Req.Test`](https://hexdocs.pm/req/Req.Test.html) — plug stubs injected via
`config/test.exs` — so no test touches the network. Quality gates, also
enforced on CI: `mix format --check-formatted`, `mix credo --strict`,
`mix compile --warnings-as-errors`, `mix test`.
````

- [x] **Step 2: Commit**

```bash
git add README.md
```

Commit with subject: `Document the project in the README`

---

### Task 9: Quality gates + CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:** none (tooling).

- [x] **Step 1: Run the gates locally and fix every offense**

Run, in order, fixing anything they flag (including in `docs/`-adjacent files they cover):

```bash
mix format --check-formatted
mix credo --strict
mix compile --warnings-as-errors --force
mix test
```

Expected: all four exit 0. Credo `--strict` readability nits (alias ordering, module layout) get fixed, not ignored.

- [x] **Step 2: Add the workflow**

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4

      - uses: erlef/setup-beam@v1
        with:
          version-file: .tool-versions
          version-type: strict

      - uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: mix-${{ runner.os }}-${{ hashFiles('.tool-versions') }}-${{ hashFiles('mix.lock') }}
          restore-keys: |
            mix-${{ runner.os }}-${{ hashFiles('.tool-versions') }}-

      - run: mix deps.get
      - run: mix format --check-formatted
      - run: mix credo --strict
      - run: mix compile --warnings-as-errors
      - run: mix test
```

(If `erlef/setup-beam` lacks a prebuilt OTP `29.0.3` for the runner, the run fails at setup — fix by bumping the runner image or relaxing `version-type`; verify on the first pushed run.)

- [x] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
```

Commit with subject: `Add the CI workflow`

---

## Verification checklist (after all tasks)

- [x] `mix test` — `23 tests, 0 failures`, all async
- [x] `mix format --check-formatted`, `mix credo --strict`, `mix compile --warnings-as-errors` — clean
- [x] `mix weather` — three real forecast lines
- [x] `git log --oneline` — one focused commit per task, none pushed
