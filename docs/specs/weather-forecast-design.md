# weather_forecast — Design Spec

## Goal

A small Elixir application that fetches the weather forecast for three Brazilian
cities from the public [Open-Meteo API](https://open-meteo.com/), computes each
city's average daily maximum temperature (`temperature_2m_max`) over the next
six days (today + 5), and prints one line per city:

```
São Paulo: 28.5°C
Belo Horizonte: 27.8°C
Curitiba: 22.1°C
```

## Requirements

1. The project is generated with `mix new`.
2. Forecast data comes from Open-Meteo's `GET /v1/forecast` endpoint (no API key).
3. The three API calls run concurrently.
4. Each city's result is the arithmetic mean of the first six
   `temperature_2m_max` values.
5. Output lists each city with its average, one decimal place, `°C` suffix.
6. Tests mock the API; no test touches the network.

### Fixed input

| City           | Latitude | Longitude |
| -------------- | -------- | --------- |
| São Paulo      | -23.55   | -46.63    |
| Belo Horizonte | -19.92   | -43.94    |
| Curitiba       | -25.43   | -49.27    |

All three cities are in the `America/Sao_Paulo` timezone, which is sent as a
constant query parameter.

## Architecture

Hexagonal-lite (ports & adapters) with DDD-style layering. The dependency rule:
**presentation → application → domain**; infrastructure plugs into the
application's port from the side and depends only on the domain. The domain
depends on nothing.

```
mix weather
  └─ Presentation.CLI                        formatting + IO
       └─ Application.UseCases.
          CalculateAverageMaxTemperatures    concurrent fan-out
            ├─ Application.Ports.
            │  ForecastProvider              behaviour (the port)
            │    ◄─ Infrastructure.
            │       OpenMeteoClient          Req adapter (the implementation)
            └─ Domain.Forecast               pure math (average)
                 Domain.City                 entity + static city data
```

The app defines no supervision tree of its own: it is a run-once CLI, and the
`:req` application supervises its own HTTP connection pool.

### Module contracts

All modules live under the `WeatherForecast` namespace.

- **`Domain.City`** — `defstruct [:name, :latitude, :longitude]` with
  `@type t`. `defaults/0` returns the three fixed cities in presentation order.
- **`Domain.Forecast`** — pure. `average_max(temps)` takes the first six values
  of a non-empty number list and returns their mean as a float. Fewer than six
  values (the API misbehaving despite `forecast_days=6`) means averaging what
  is available. Documented with doctests.
- **`Application.Ports.ForecastProvider`** — the port: a behaviour with
  `@callback fetch_daily_max(City.t()) :: {:ok, [number(), ...]} | {:error, term()}`.
  Use cases depend on this contract, never on a concrete client.
- **`Application.UseCases.CalculateAverageMaxTemperatures`** —
  `call(cities \\ City.defaults(), timeout \\ 30_000)` fans out one task per
  city through the configured provider and returns
  `[{City.t(), {:ok, float()} | {:error, term()}}]` in input order. The
  provider module is resolved at runtime from the `:forecast_provider` app env
  (prod: `Infrastructure.OpenMeteoClient`; test: a Mox mock).
- **`Infrastructure.OpenMeteoClient`** — the adapter
  (`@behaviour ForecastProvider`) and the only module that knows the API
  shape: builds the GET, validates the body, returns `{:ok, temps}` or a
  normalized `{:error, reason}` (taxonomy below). Req options are merged from
  the `:open_meteo_req_options` app env so the test environment can inject
  `plug: {Req.Test, Infrastructure.OpenMeteoClient}` and `retry: false`.
- **`Presentation.CLI`** — `run/0` invokes the use case, formats each entry,
  prints to stdout, returns `:ok`. Owns number formatting
  (`:erlang.float_to_binary(avg, decimals: 1)` — always exactly one decimal).
- **`WeatherForecast`** — thin public facade: `run/0` delegates to the use
  case with defaults, so library consumers (`iex -S mix`) have one obvious
  entry point.
- **`Mix.Tasks.Weather`** — `mix weather` entry point: starts the app
  (`@requirements ["app.start"]`) and delegates to `Presentation.CLI.run/0`.

## Concurrency model

The use case runs `Task.async_stream/3` with:

- `max_concurrency: max(length(cities), 1)` — all cities in flight at once,
- `timeout: 30_000` — sized above Req's worst-case retry envelope,
- `on_timeout: :kill_task` — a hung city yields `{:exit, :timeout}` instead of
  crashing the caller,
- `ordered: true` — results zip back to cities in input order.

Each stream element maps to the per-city result: `{:ok, result}` unwraps and
`{:exit, :timeout}` becomes `{:error, :timeout}`. (The tasks are linked, so a
non-timeout crash is a bug and fails the run loudly rather than being masked.)
One city failing — timeout, HTTP error, malformed body — never affects the
other cities' results.

## Error handling

`Infrastructure.OpenMeteoClient` normalizes every failure into one of:

| Reason                      | Trigger                                              |
| --------------------------- | ---------------------------------------------------- |
| `{:api_error, message}`     | Open-Meteo's `{"error": true, "reason": ...}` body   |
| `{:http_status, status}`    | Non-200 response without an Open-Meteo reason        |
| `:malformed_response`       | 200 whose body lacks a non-empty numeric `daily.temperature_2m_max` list |
| `{:request_failed, message}`| Transport-level failure (DNS, refused, TLS, timeout) |

The use case adds `:timeout` for a city exceeding the task deadline. The
CLI renders any failed city as:

```
Curitiba: unavailable (timeout)
```

on the same output stream, using a human-readable rendering of the reason
(e.g. `HTTP 500`, the Open-Meteo reason string, `malformed response`). The
task completes normally either way — partial results are still useful results.

Req's built-in transient retries (safe idempotent retry on 5xx/transport
errors) stay enabled for real runs and are disabled in tests.

## Open-Meteo API contract

Request:

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude=-23.55&longitude=-46.63
  &daily=temperature_2m_max
  &timezone=America/Sao_Paulo
  &forecast_days=6
```

Successful response (fields the app reads):

```json
{
  "daily": {
    "time": ["2026-07-23", "..."],
    "temperature_2m_max": [28.5, 29.3, 27.1, 26.8, 28.0, 30.2]
  }
}
```

`forecast_days=6` asks the API for exactly the six days needed (today + 5);
`Domain.Forecast.average_max/1` still defensively takes at most the first six
values. Values may arrive as integers or floats; the mean is computed in float
arithmetic and rounded only at the presentation layer.

## Testing strategy

All tests are `async: true`, and each layer is tested at its own boundary:

- **Port consumers (use case, CLI, facade)** mock the `ForecastProvider`
  behaviour with [Mox](https://hexdocs.pm/mox) — expectations against an
  explicit contract, resolved via the `:forecast_provider` app env in
  `config/test.exs`.
- **The HTTP adapter** is tested against the API shape with `Req.Test`
  (plug-based, ships with Req), injected via the `:open_meteo_req_options`
  app env. No test touches the network.

| Test file                              | Coverage                                                        |
| -------------------------------------- | --------------------------------------------------------------- |
| `test/weather_forecast/domain/forecast_test.exs` | doctests + averaging edges (six values, more than six, fewer) |
| `test/weather_forecast/domain/city_test.exs`     | the three fixed cities, order, coordinates |
| `test/weather_forecast/infrastructure/open_meteo_client_test.exs` | happy path; API-error body; plain 500; malformed 200; transport error (Req.Test) |
| `test/weather_forecast/application/use_cases/calculate_average_max_temperatures_test.exs` | concurrent fan-out through the mocked port: per-city values, input-order results, failure isolation, timeout normalization, empty list |
| `test/weather_forecast/presentation/cli_test.exs` | `capture_io` asserting the exact output lines, incl. the unavailable rendering |
| `test/weather_forecast_test.exs`       | the facade delegates to the use case |

## Toolchain, layout & CI

- **Versions:** Erlang/OTP `29.0.3`, Elixir `1.20.2-otp-29`, pinned in
  `.tool-versions` (asdf).
- **Dependencies:** `req ~> 0.5`; `plug` (test only — required by `Req.Test`);
  `mox` (test only); `credo` (dev/test only). JSON decoding is handled by Req.
- **Quality gates:** `mix format --check-formatted`, `mix credo --strict`,
  `mix compile --warnings-as-errors`, `mix test`. Public functions carry
  `@spec`; modules carry `@moduledoc`.
- **CI:** GitHub Actions on push/PR — `erlef/setup-beam` reading
  `.tool-versions`, dependency/build caching, then the four quality gates.

```
weather_forecast/
├── .github/workflows/ci.yml
├── .tool-versions
├── config/config.exs                # prod wiring; imports test overrides in :test
├── docs/
│   ├── plans/                       # implementation plans (executed)
│   └── specs/                       # this document
├── lib/
│   ├── mix/tasks/weather.ex
│   ├── weather_forecast.ex          # public facade
│   └── weather_forecast/
│       ├── application/
│       │   ├── ports/forecast_provider.ex
│       │   └── use_cases/calculate_average_max_temperatures.ex
│       ├── domain/{city,forecast}.ex
│       ├── infrastructure/open_meteo_client.ex
│       └── presentation/cli.ex
└── test/                            # mirrors lib/
```

## Design decisions

- **Hexagonal-lite layering with an explicit port:** the use case depends on
  the `ForecastProvider` behaviour, not on Req or any HTTP detail, keeping the
  dependency rule (presentation → application → domain) enforceable and the
  application testable against an explicit contract. Full DDD ceremony
  (aggregates, repositories, domain events) was considered and rejected — one
  endpoint and three fixed cities don't earn it.
- **`Task.async_stream` over `Task.async`/`await_many`:** linked plain tasks
  share one fate — a single crash or missed deadline takes down the whole run.
  `async_stream` gives bounded concurrency, per-task timeouts, and per-city
  failure isolation with less code.
- **No `--sup`/`Task.Supervisor`:** a supervision tree earns its keep in
  long-running systems; this is a run-once CLI. Considered and rejected as
  ceremony.
- **Req over Tesla/HTTPoison + Bypass:** Req is the current community
  standard, retries transient failures out of the box, and `Req.Test` covers
  the adapter's HTTP tests without an additional dependency.
- **Mox at the port, Req.Test at the adapter:** each layer mocks the boundary
  it actually owns — use case and CLI tests assert application behavior
  against the behaviour contract; adapter tests assert the HTTP/JSON shape.
- **Rounding at the edge:** the core returns full-precision floats; only the
  CLI formats to one decimal. Keeps the math testable independently of
  presentation.
