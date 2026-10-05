# Changelog — monitoring

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-09-07)

### Added

- `prom_ex` with a `MyApp.PromEx` module — Application, Beam and Phoenix
  plugins, Ecto with a repo, LiveView with `phoenix_live_view`, the
  dashboard of each — first in the supervision tree, `PromEx.Plug`
  before `Plug.Telemetry` in the endpoint, its configuration in
  `config.exs`, off in `test.exs`, and the Grafana client in
  `runtime.exs` off `GRAFANA_HOST`.
- `monitoring/prometheus.yml` and `monitoring/grafana/datasource.yml`,
  the files the two containers open with, and the `prometheus` and
  `grafana` services declared for `mix workbench.compose`: Prometheus
  on the app's `/metrics` through a targets file the compose writes for
  the topology, Grafana on Prometheus through `PROMETHEUS_URL`, signed
  in already, its port published beside the app's; the app waits for
  it, so the dashboards land. With k6 in, its results go to Prometheus
  by remote write (scripts/PLAN.md, step 5). Run live on 2026-09-08 on
  a fresh Postgres workspace, dev and prod: Grafana's first start
  outlasted a 30 s start period — 813 migrations, four and a half
  minutes beside the app compiling — so its healthcheck allows five.
