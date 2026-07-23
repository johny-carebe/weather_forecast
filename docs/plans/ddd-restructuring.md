# DDD Restructuring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the flat `weather_forecast/` namespace into hexagonal-lite DDD layers — domain / application (ports + use cases) / infrastructure / presentation — inverting the HTTP dependency behind a `ForecastProvider` behaviour mocked with Mox.

**Architecture:** Dependency rule: presentation → application → domain; infrastructure implements the application's port and depends only on the domain. `WeatherForecast` stays as a thin public facade (`run/0`). Behavior, output, error taxonomy, and concurrency model are unchanged.

**Tech Stack:** adds `mox` (test only). Everything else unchanged.

Authoritative design: `docs/specs/weather-forecast-design.md` (already updated).

## Global Constraints

- All commands run from the repo root: `~/workspace/weather_forecast`.
- The suite is green at the end of every task; every test module stays `async: true`.
- Use `git mv` for moves so history follows the files.
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

### Task 1: Move the domain modules under `Domain`

**Files:**
- Move: `lib/weather_forecast/city.ex` → `lib/weather_forecast/domain/city.ex` (module `WeatherForecast.Domain.City`)
- Move: `lib/weather_forecast/forecast.ex` → `lib/weather_forecast/domain/forecast.ex` (module `WeatherForecast.Domain.Forecast`)
- Move: `test/weather_forecast/city_test.exs` → `test/weather_forecast/domain/city_test.exs`
- Move: `test/weather_forecast/forecast_test.exs` → `test/weather_forecast/domain/forecast_test.exs`
- Modify (alias updates): `lib/weather_forecast.ex`, `lib/weather_forecast/open_meteo.ex`, `lib/weather_forecast/cli.ex`, `test/weather_forecast/open_meteo_test.exs`, `test/weather_forecast_test.exs`, `test/weather_forecast/cli_test.exs`

**Interfaces:**
- Produces: `WeatherForecast.Domain.City` (same struct + `defaults/0`) and `WeatherForecast.Domain.Forecast.average_max/1`. Every consumer now aliases `WeatherForecast.Domain.City` / `WeatherForecast.Domain.Forecast`.

- [x] **Step 1: Move the files**

```bash
mkdir -p lib/weather_forecast/domain test/weather_forecast/domain
git mv lib/weather_forecast/city.ex lib/weather_forecast/domain/city.ex
git mv lib/weather_forecast/forecast.ex lib/weather_forecast/domain/forecast.ex
git mv test/weather_forecast/city_test.exs test/weather_forecast/domain/city_test.exs
git mv test/weather_forecast/forecast_test.exs test/weather_forecast/domain/forecast_test.exs
```

- [x] **Step 2: Rename the modules**

In the moved files: `defmodule WeatherForecast.City` → `defmodule WeatherForecast.Domain.City`; `defmodule WeatherForecast.Forecast` → `defmodule WeatherForecast.Domain.Forecast`; test modules `WeatherForecast.Domain.CityTest` / `WeatherForecast.Domain.ForecastTest`. In the forecast doctests, the invocation lines become `iex> WeatherForecast.Domain.Forecast.average_max(...)`.

- [x] **Step 3: Update every alias**

In `lib/weather_forecast.ex`, `lib/weather_forecast/open_meteo.ex`, `lib/weather_forecast/cli.ex`, `test/weather_forecast/open_meteo_test.exs`, `test/weather_forecast_test.exs`, `test/weather_forecast/cli_test.exs`:
`alias WeatherForecast.City` → `alias WeatherForecast.Domain.City`, and in `lib/weather_forecast.ex` also `alias WeatherForecast.Forecast` → `alias WeatherForecast.Domain.Forecast`. Test module aliases `alias WeatherForecast.Forecast` (forecast test) likewise.

- [x] **Step 4: Verify green**

Run: `mix test`
Expected: `23 passed`

- [x] **Step 5: Commit**

```bash
mix format
git add -A
```

Commit with subject: `Move the domain modules under Domain`

---

### Task 2: Move the client under `Infrastructure`

**Files:**
- Move: `lib/weather_forecast/open_meteo.ex` → `lib/weather_forecast/infrastructure/open_meteo_client.ex` (module `WeatherForecast.Infrastructure.OpenMeteoClient`)
- Move: `test/weather_forecast/open_meteo_test.exs` → `test/weather_forecast/infrastructure/open_meteo_client_test.exs`
- Modify: `config/test.exs` (Req.Test stub key), `lib/weather_forecast.ex` (alias)

**Interfaces:**
- Produces: `WeatherForecast.Infrastructure.OpenMeteoClient.fetch_daily_max/1` (same contract); Req.Test stub name is now `WeatherForecast.Infrastructure.OpenMeteoClient`.

- [x] **Step 1: Move and rename**

```bash
mkdir -p lib/weather_forecast/infrastructure test/weather_forecast/infrastructure
git mv lib/weather_forecast/open_meteo.ex lib/weather_forecast/infrastructure/open_meteo_client.ex
git mv test/weather_forecast/open_meteo_test.exs test/weather_forecast/infrastructure/open_meteo_client_test.exs
```

Module renames: `WeatherForecast.OpenMeteo` → `WeatherForecast.Infrastructure.OpenMeteoClient`; test module `WeatherForecast.Infrastructure.OpenMeteoClientTest` with `alias WeatherForecast.Infrastructure.OpenMeteoClient` (stub calls become `Req.Test.stub(OpenMeteoClient, ...)`).

- [x] **Step 2: Update the config stub key**

`config/test.exs`:

```elixir
import Config

config :weather_forecast,
  open_meteo_req_options: [
    plug: {Req.Test, WeatherForecast.Infrastructure.OpenMeteoClient},
    retry: false
  ]
```

- [x] **Step 3: Update consumers**

`lib/weather_forecast.ex`: `alias WeatherForecast.OpenMeteo` → `alias WeatherForecast.Infrastructure.OpenMeteoClient`, call site `OpenMeteoClient.fetch_daily_max(city)`. `test/weather_forecast_test.exs`: same alias swap for its `Req.Test.stub(OpenMeteoClient, ...)` calls.

- [x] **Step 4: Verify green**

Run: `mix test`
Expected: `23 passed`

- [x] **Step 5: Commit**

```bash
mix format
git add -A
```

Commit with subject: `Move the Open-Meteo client under Infrastructure`

---

### Task 3: Move the CLI under `Presentation`

**Files:**
- Move: `lib/weather_forecast/cli.ex` → `lib/weather_forecast/presentation/cli.ex` (module `WeatherForecast.Presentation.CLI`)
- Move: `test/weather_forecast/cli_test.exs` → `test/weather_forecast/presentation/cli_test.exs`
- Modify: `lib/mix/tasks/weather.ex`

**Interfaces:**
- Produces: `WeatherForecast.Presentation.CLI.run/0` and `format_line/1` (same contracts).

- [x] **Step 1: Move and rename**

```bash
mkdir -p lib/weather_forecast/presentation test/weather_forecast/presentation
git mv lib/weather_forecast/cli.ex lib/weather_forecast/presentation/cli.ex
git mv test/weather_forecast/cli_test.exs test/weather_forecast/presentation/cli_test.exs
```

Module renames: `WeatherForecast.CLI` → `WeatherForecast.Presentation.CLI`; test module `WeatherForecast.Presentation.CLITest` with `alias WeatherForecast.Presentation.CLI`.

- [x] **Step 2: Update the mix task**

`lib/mix/tasks/weather.ex` body becomes `WeatherForecast.Presentation.CLI.run()`.

- [x] **Step 3: Verify green**

Run: `mix test`
Expected: `23 passed`

- [x] **Step 4: Commit**

```bash
mix format
git add -A
```

Commit with subject: `Move the CLI under Presentation`

---

### Task 4: Invert the dependency behind the `ForecastProvider` port

**Files:**
- Create: `lib/weather_forecast/application/ports/forecast_provider.ex`
- Create: `lib/weather_forecast/application/use_cases/calculate_average_max_temperatures.ex`
- Create: `test/weather_forecast/application/use_cases/calculate_average_max_temperatures_test.exs`
- Modify: `mix.exs` (add mox), `test/test_helper.exs` (defmock), `config/config.exs` (prod wiring), `config/test.exs` (mock wiring), `lib/weather_forecast/infrastructure/open_meteo_client.ex` (`@behaviour`), `lib/weather_forecast.ex` (facade), `lib/weather_forecast/presentation/cli.ex` (call the use case), `test/weather_forecast_test.exs` (facade test via Mox), `test/weather_forecast/presentation/cli_test.exs` (Mox instead of Req.Test)

**Interfaces:**
- Consumes: `Domain.City`, `Domain.Forecast`, `Infrastructure.OpenMeteoClient`.
- Produces: `Application.Ports.ForecastProvider` behaviour (`@callback fetch_daily_max(City.t()) :: {:ok, [number(), ...]} | {:error, term()}`); `Application.UseCases.CalculateAverageMaxTemperatures.call/0..2` (same semantics as the old `WeatherForecast.run/0..2`); app env `:forecast_provider` (prod: the client; test: `WeatherForecast.ForecastProviderMock`); facade `WeatherForecast.run/0`.

- [x] **Step 1: Add Mox and the wiring**

`mix.exs` deps:

```elixir
  defp deps do
    [
      {:req, "~> 0.5"},
      {:plug, "~> 1.0", only: :test},
      {:mox, "~> 1.2", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
```

`test/test_helper.exs`:

```elixir
Mox.defmock(WeatherForecast.ForecastProviderMock,
  for: WeatherForecast.Application.Ports.ForecastProvider
)

ExUnit.start()
```

`config/config.exs`:

```elixir
import Config

config :weather_forecast,
  forecast_provider: WeatherForecast.Infrastructure.OpenMeteoClient

if config_env() == :test do
  import_config "test.exs"
end
```

`config/test.exs`:

```elixir
import Config

config :weather_forecast,
  forecast_provider: WeatherForecast.ForecastProviderMock,
  open_meteo_req_options: [
    plug: {Req.Test, WeatherForecast.Infrastructure.OpenMeteoClient},
    retry: false
  ]
```

Run: `mix deps.get`
Expected: resolves `mox` (+ `nimble_ownership`).

- [x] **Step 2: Define the port**

`lib/weather_forecast/application/ports/forecast_provider.ex`:

```elixir
defmodule WeatherForecast.Application.Ports.ForecastProvider do
  @moduledoc """
  Application-side port for fetching a city's daily maximum temperatures.

  Use cases depend on this contract; infrastructure adapters implement
  it. The active adapter is resolved from the `:forecast_provider` app
  env.
  """

  alias WeatherForecast.Domain.City

  @callback fetch_daily_max(City.t()) :: {:ok, [number(), ...]} | {:error, term()}
end
```

- [x] **Step 3: Write the failing use-case tests**

`test/weather_forecast/application/use_cases/calculate_average_max_temperatures_test.exs`:

```elixir
defmodule WeatherForecast.Application.UseCases.CalculateAverageMaxTemperaturesTest do
  use ExUnit.Case, async: true

  import Mox

  alias WeatherForecast.Application.UseCases.CalculateAverageMaxTemperatures
  alias WeatherForecast.Domain.City
  alias WeatherForecast.ForecastProviderMock

  setup :verify_on_exit!

  describe "call/2" do
    test "averages every city's forecast, preserving input order" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn %City{} = city ->
        case city.name do
          "São Paulo" -> {:ok, [28.0, 30.0, 26.0, 25.0, 28.0, 31.0]}
          "Belo Horizonte" -> {:ok, [20.0, 21.0, 22.0, 23.0, 24.0, 25.0]}
          "Curitiba" -> {:ok, [10.0, 10.0, 10.0, 10.0, 10.0, 10.0]}
        end
      end)

      assert [
               {%City{name: "São Paulo"}, {:ok, 28.0}},
               {%City{name: "Belo Horizonte"}, {:ok, 22.5}},
               {%City{name: "Curitiba"}, {:ok, 10.0}}
             ] = CalculateAverageMaxTemperatures.call()
    end

    test "isolates one city's failure from the others" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn city ->
        case city.name do
          "Curitiba" -> {:error, {:http_status, 500}}
          _other -> {:ok, [12.0, 14.0]}
        end
      end)

      assert [
               {%City{name: "São Paulo"}, {:ok, 13.0}},
               {%City{name: "Belo Horizonte"}, {:ok, 13.0}},
               {%City{name: "Curitiba"}, {:error, {:http_status, 500}}}
             ] = CalculateAverageMaxTemperatures.call()
    end

    test "converts an exceeded deadline into a per-city timeout error" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn city ->
        case city.name do
          "Curitiba" -> Process.sleep(500)
          _other -> :ok
        end

        {:ok, [10.0]}
      end)

      assert [
               {%City{name: "São Paulo"}, {:ok, 10.0}},
               {%City{name: "Belo Horizonte"}, {:ok, 10.0}},
               {%City{name: "Curitiba"}, {:error, :timeout}}
             ] = CalculateAverageMaxTemperatures.call(City.defaults(), 100)
    end

    test "returns an empty report for an empty city list" do
      assert CalculateAverageMaxTemperatures.call([]) == []
    end
  end
end
```

Run: `mix test test/weather_forecast/application`
Expected: FAIL — `CalculateAverageMaxTemperatures.call/0 is undefined`

- [x] **Step 4: Write the use case**

`lib/weather_forecast/application/use_cases/calculate_average_max_temperatures.ex`:

```elixir
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
```

Run: `mix test test/weather_forecast/application`
Expected: `4 passed`

- [x] **Step 5: Implement the behaviour in the adapter**

In `lib/weather_forecast/infrastructure/open_meteo_client.ex`, add below the aliases:

```elixir
  alias WeatherForecast.Application.Ports.ForecastProvider

  @behaviour ForecastProvider
```

and tag the function:

```elixir
  @impl ForecastProvider
  @spec fetch_daily_max(City.t()) :: {:ok, [number(), ...]} | {:error, term()}
  def fetch_daily_max(%City{} = city) do
```

- [x] **Step 6: Shrink the facade and rewire the CLI**

`lib/weather_forecast.ex` becomes:

```elixir
defmodule WeatherForecast do
  @moduledoc """
  Public API: concurrent 6-day maximum-temperature averages for
  Brazilian cities, backed by the Open-Meteo API.
  """

  alias WeatherForecast.Application.UseCases.CalculateAverageMaxTemperatures

  @doc "Runs the report for the default cities."
  @spec run() :: [CalculateAverageMaxTemperatures.city_result()]
  def run, do: CalculateAverageMaxTemperatures.call()
end
```

In `lib/weather_forecast/presentation/cli.ex`, alias the use case and call it:

```elixir
  alias WeatherForecast.Application.UseCases.CalculateAverageMaxTemperatures
  alias WeatherForecast.Domain.City

  @spec run() :: :ok
  def run do
    CalculateAverageMaxTemperatures.call()
    |> Enum.each(&IO.puts(format_line(&1)))
  end
```

- [x] **Step 7: Re-point the facade and CLI tests at the port**

Replace `test/weather_forecast_test.exs` with:

```elixir
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
```

Replace `test/weather_forecast/presentation/cli_test.exs` with:

```elixir
defmodule WeatherForecast.Presentation.CLITest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mox

  alias WeatherForecast.Domain.City
  alias WeatherForecast.ForecastProviderMock
  alias WeatherForecast.Presentation.CLI

  @sao_paulo %City{name: "São Paulo", latitude: -23.55, longitude: -46.63}

  setup :verify_on_exit!

  describe "run/0" do
    test "prints one line per city with the 6-day average" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn city ->
        case city.name do
          "São Paulo" -> {:ok, [27.0, 28.0, 29.0, 30.0, 28.5, 28.5]}
          "Belo Horizonte" -> {:ok, [26.8, 27.8, 28.8, 27.0, 28.0, 28.4]}
          "Curitiba" -> {:ok, [21.1, 22.1, 23.1, 22.0, 22.2, 22.1]}
        end
      end)

      output = capture_io(fn -> assert CLI.run() == :ok end)

      assert output == """
             São Paulo: 28.5°C
             Belo Horizonte: 27.8°C
             Curitiba: 22.1°C
             """
    end

    test "reports a failed city as unavailable without dropping the others" do
      expect(ForecastProviderMock, :fetch_daily_max, 3, fn city ->
        case city.name do
          "Curitiba" -> {:error, {:http_status, 500}}
          _other -> {:ok, [12.0, 14.0]}
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
end
```

- [x] **Step 8: Verify green**

Run: `mix test`
Expected: `24 passed` (1 facade + 6 forecast + 1 city + 8 client + 4 use case + 4 CLI)

- [x] **Step 9: Commit**

```bash
mix format
git add -A
```

Commit with subject: `Invert the forecast dependency behind a ForecastProvider port`

---

### Task 5: Update the README + final gates

**Files:**
- Modify: `README.md` (Design + Tests sections)

**Interfaces:** none (documentation).

- [x] **Step 1: Update the README design tree and test notes**

Replace the `## Design` tree with:

```
mix weather
  └─ Presentation.CLI                            formatting + IO
       └─ Application.UseCases.
          CalculateAverageMaxTemperatures        concurrent fan-out (Task.async_stream)
            ├─ Application.Ports.ForecastProvider    behaviour (the port)
            │    ◄─ Infrastructure.OpenMeteoClient   Req adapter
            └─ Domain.Forecast                       pure math (average)
                 Domain.City                         static city data
```

Add one bullet after the concurrency bullet:

```markdown
- Hexagonal-lite layering: the use case depends on the `ForecastProvider`
  behaviour (port), never on HTTP details; the Open-Meteo adapter implements
  it and is swapped via config.
```

Replace the Tests paragraph with:

```markdown
Each layer is tested at its own boundary: the use case, CLI, and facade mock
the `ForecastProvider` port with [Mox](https://hexdocs.pm/mox); the HTTP
adapter is tested against the API shape with
[`Req.Test`](https://hexdocs.pm/req/Req.Test.html) — so no test touches the
network. Quality gates, also enforced on CI: `mix format --check-formatted`,
`mix credo --strict`, `mix compile --warnings-as-errors`, `mix test`.
```

- [x] **Step 2: Run all gates**

```bash
mix format --check-formatted
mix credo --strict
mix compile --warnings-as-errors --force
mix test
mix weather
```

Expected: all clean; live run prints three real lines.

- [x] **Step 3: Commit**

```bash
git add README.md
```

Commit with subject: `Document the layered architecture in the README`

---

## Verification checklist (after all tasks)

- [x] `mix test` — `24 passed`, all async
- [x] `mix format --check-formatted`, `mix credo --strict`, `mix compile --warnings-as-errors` — clean
- [x] `mix weather` — three real forecast lines
- [x] `git log --oneline` — one focused commit per task, none pushed
