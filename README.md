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
  └─ Presentation.CLI                            formatting + IO
       └─ Application.UseCases.
          CalculateAverageMaxTemperatures        concurrent fan-out (Task.async_stream)
            ├─ Application.Ports.ForecastProvider    behaviour (the port)
            │    ◄─ Infrastructure.OpenMeteoClient   Req adapter
            ├─ Application.Factories.Cities          builds the covered cities
            ├─ Application.Factories.CityResult      builds each report entry
            └─ Domain.Forecast                       pure math (average)
                 Domain.City                         entity (struct + type)
```

- The three API calls run concurrently via `Task.async_stream` — bounded
  concurrency, a per-city deadline, ordered results. A city that fails
  (timeout, HTTP error, malformed body) is printed as `unavailable (<reason>)`
  without affecting the other cities.
- Hexagonal-lite layering: the use case depends on the `ForecastProvider`
  behaviour (port), never on HTTP details; the Open-Meteo adapter implements
  it and is swapped via config. Application factories (`Cities`, `CityResult`)
  mediate all domain access, keeping the use case thin.
- Environment constants (`FORECAST_DAYS`, `OPEN_METEO_BASE_URL`,
  `OPEN_METEO_TIMEZONE`) are declared in the committed `.env`/`.env.test`
  files (they are not secrets), loaded at boot by `config/runtime.exs` via
  [dotenvy](https://hexdocs.pm/dotenvy), and read only through
  `WeatherForecast.Config`. A gitignored `.env.local` can override them
  locally; in the test env the committed files always win, keeping the suite
  hermetic.
- [Req](https://hexdocs.pm/req) is the HTTP client; its built-in transient
  retries stay enabled for real runs and are disabled in tests.
- No custom supervision tree: this is a run-once CLI and the `:req`
  application supervises its own connection pool (`Task.Supervisor` was
  considered and rejected as ceremony for this shape).

## Tests

```
mix test
```

Each layer is tested at its own boundary: the use case, CLI, and facade mock
the `ForecastProvider` port with [Mox](https://hexdocs.pm/mox); the HTTP
adapter is tested against the API shape with
[`Req.Test`](https://hexdocs.pm/req/Req.Test.html) — so no test touches the
network. Quality gates, also enforced on CI: `mix format --check-formatted`,
`mix credo --strict`, `mix compile --warnings-as-errors`,
`mix test --warnings-as-errors` (against locked dependencies).

## How this was built

This project was co-authored with
[Claude Code](https://claude.com/claude-code), Anthropic's agentic CLI. It was
built spec-first: a design document and per-phase implementation plans were
written and reviewed before any code, and the work landed through reviewed
pull requests with the design docs guiding each step.

Those planning artifacts were removed from the tree once the code stood on its
own (so the repo ships only code, tests, and this README). If you want to see
what drove the build, they live in the diff of
[PR #3](https://github.com/johny-carebe/weather_forecast/pull/3) — the change
that removed them.
