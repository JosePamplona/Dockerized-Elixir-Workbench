# Cartridge: monitoring

Metrics and dashboards: [PromEx](https://hexdocs.pm/prom_ex) in the
application, [Prometheus](https://prometheus.io) and
[Grafana](https://grafana.com) in the workspace.

* **Task**: `mix workbench.install.monitoring`
* **Inserted by**: `wb.sh add monitoring`. Then `./wb.sh bake`, and the next `up`.

## Description

PromEx turns the Telemetry events Phoenix, Ecto, LiveView and the VM
already emit into Prometheus metrics, served at `/metrics` on the app's
port, and ships a Grafana dashboard per plugin that it uploads to
Grafana when the application starts. The cartridge installs that side
in the project, and declares the two containers (`services/1`) the
compose renders at the next `./wb.sh bake`: Prometheus scraping the
app, Grafana reading Prometheus, its port published beside the app's
(the first free one from `3000`), signed in already so the door opens
without a form. `./wb.sh status` and the console show the address.

Each container opens with a file the project owns, so what a reader
would tune is in the project and not in a generated file. What is the
topology's — the app on `localhost` inside the pod or one line per
replica on the scaled network, Prometheus and Grafana on `localhost` or
by name — the compose hands over: the targets file Prometheus reads,
`PROMETHEUS_URL` for the datasource, `GRAFANA_HOST` for the app. The
three files say nothing about it, and the same insert serves dev, prod
and scaled. The app waits for Grafana to be healthy before it starts,
so the upload finds it there.

With the k6 cartridge in, `./wb.sh k6` writes its results to Prometheus
as well (`k6_*` metrics, by remote write, which Prometheus accepts for
it), for Grafana to draw beside the app's.

## What it installs

* `{:prom_ex, "~> 1.12"}`, and `lib/my_app/prom_ex.ex` — `MyApp.PromEx`
  with the plugins the project's shape calls for: Application, Beam and
  Phoenix always; Ecto when the project has a repo; LiveView when
  `phoenix_live_view` is a dependency. The dashboards to match, on the
  `prometheus` datasource. Oban, Absinthe and Broadway are left
  commented for when the project takes them on.
* `config/config.exs`: PromEx's own settings; `config/test.exs`:
  `disabled: true`, nothing scrapes a test; `config/runtime.exs`: the
  Grafana client, host off `GRAFANA_HOST` (`http://localhost:3000` by
  default), `admin`/`admin`, dashboards uploaded on start.
* `MyApp.PromEx` first in the supervision tree, and `plug PromEx.Plug`
  before `Plug.Telemetry` in the endpoint.
* `monitoring/prometheus.yml` — one job, `app`, whose targets come from
  `/etc/prometheus/targets.yml`, which the compose writes.
* `monitoring/grafana/datasource.yml` — the `prometheus` datasource,
  `url: ${PROMETHEUS_URL}`, provisioned when Grafana starts.
* The `prometheus` and `grafana` services, declared for
  `mix workbench.compose`: `prom/prometheus` and `grafana/grafana`
  (`PROMETHEUS_IMAGE_VERSION`, `GRAFANA_IMAGE_VERSION` in `config.conf`).
  Prometheus is not published: Grafana reads it from inside the
  workspace, and a query is Grafana's Explore.

**Idempotency**: the PromEx module is the mark; re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `monitoring.ex` | Manifest + logic (`info/2`, `install/1`, `services/1`, `console/0`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Monitoring` shell |
| `DESIGN.md` | Why PromEx, why the plug, why the compose writes the targets |
| `priv/features/monitoring/templates/prom_ex.ex.eex` | The PromEx module |
| `priv/features/monitoring/assets/prometheus.yml` | Prometheus's configuration, copied verbatim |
| `priv/features/monitoring/assets/grafana/datasource.yml` | The datasource, copied verbatim |

Cartridge test: `test/workbench_igniter/features/monitoring_test.exs`.
