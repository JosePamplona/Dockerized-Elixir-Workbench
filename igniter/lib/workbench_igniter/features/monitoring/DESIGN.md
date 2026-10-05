# monitoring — Design

Revision: cartridge v0.1.0 (2026-09-07)

## Abstract

The cartridge puts metrics in the app and dashboards in the workspace:
PromEx in the Phoenix project, Prometheus and Grafana in the compose.
Four decisions shaped it. PromEx over `telemetry_metrics_prometheus`,
for the dashboard each of its plugins ships. `PromEx.Plug` in the
endpoint over PromEx's own metrics server, so the metrics ride the
app's port and no second one is baked. The dashboards uploaded by the
app when it starts, as PromEx does it, over Grafana's file
provisioning, which would need them rendered at install time by a task
the installer cannot run; the app waits for Grafana to be healthy so
the one-shot uploader finds it. And the targets Prometheus scrapes
written by the compose into a file the project's `prometheus.yml`
reads, over a configuration per topology or DNS discovery, so the one
file the project owns serves the pod and the bridge, and every replica
keeps its name on the dashboards.

## 1. Problem

The workbench's compose plan (`scripts/PLAN.md`, step 5; closed on
2026-09-29 and kept in git history) asked for "Prometheus
and Grafana as services of one cartridge, whose Elixir side installs
PromEx or telemetry_metrics_prometheus; Grafana enters the console as
a door", and for k6's results to reach Prometheus "when the monitoring
stack is in". Three things the compose already settled constrain it:
a service is declared by a cartridge and opens with a file the project
owns (pgadmin, k6); whatever is the topology's is resolved in the
compose and handed to the service (k6's `BASE_URL`); and the release
image is built once and runs on both topologies, so nothing about
where a service is can be compiled into the app.

## 2. Background

### 2.1 PromEx

PromEx's README (read 2026-09-07, hexdocs, v1.12.0 — released
2026-06-19 per hex.pm) installs in four steps: `mix prom_ex.gen.config
--datasource YOUR_PROMETHEUS_DATASOURCE_ID`, the generated module
added to the supervision tree — "PromEx should be started before
anything else as PromEx will capture init events from libraries like
Ecto, Phoenix and Oban" — the plug in the endpoint, placed before
`Plug.Telemetry` in its example, and the plugins listed in
`plugins/0`. The generator's template lists `Plugins.Application` and
`Plugins.Beam` on, and `Phoenix`, `Ecto`, `Oban`, `PhoenixLiveView`,
`Absinthe`, `Broadway` commented, each with a dashboard of the same
name; `dashboard_assigns/0` carries `datasource_id` and
`default_selected_interval: "30s"`. The Phoenix plugin's `router` and
`endpoint` are "REQUIRED"; the Ecto plugin's `repos` is "OPTIONAL and
is a list with the full module name of your Ecto Repos".

`PromEx.Config` (source, `lib/prom_ex/config.ex`) defaults to
`disabled: false`, `manual_metrics_start_delay: :no_delay`,
`drop_metrics_groups: []`, `grafana: :disabled`, `metrics_server:
:disabled`; `disabled` "will disable the PromEx supervision tree
entirely and will not start any metrics collectors". The Grafana
client takes `host` (required), `username`, `password`, `auth_token`,
`upload_dashboards_on_start` (default `true`), `folder_name`,
`annotate_app_lifecycle`. `PromEx.DashboardUploader` is a transient
GenServer that uploads in `init/1`'s continue and stops; a failed
upload logs "PromEx.DashboardUploader failed to upload … to Grafana"
at warning level, and nothing retries it.

`PromEx.Plug` takes `:prom_ex_module` and `:path` ("default is
`/metrics`"); the doc says "how you chose to configure the visibility
of the metrics route is entirely up to the user" and points at
`Unplug` for gating it.

### 2.2 Prometheus

The configuration reference (read 2026-09-07): `scrape_interval`
defaults to `1m`; `file_sd_configs` "allows targets to be discovered
from files matching specified glob patterns"; `dns_sd_configs` takes
`names`, `type` (`A`, `AAAA` or `SRV`, default `A`) and `port`,
refreshed every 30 s. Environment variable references are expanded in
`external_labels` alone, not in the rest of the file. The storage
page: "The built-in remote write receiver can be enabled by setting
the `--web.enable-remote-write-receiver` command line flag. When
enabled, the remote write receiver endpoint is `/api/v1/write`."

### 2.3 Grafana

The provisioning page (read 2026-09-07): "You can use environment
variable lookups in all provisioning configuration. The syntax for an
environment variable is `$ENV_VAR_NAME` or `${ENV_VAR_NAME}`"; a
Prometheus datasource is `name`, `type: prometheus`, `uid`, `url`,
`access: proxy`, and the Docker image reads
`/etc/grafana/provisioning/datasources`. The configuration page:
options are overridden with `GF_<SectionName>_<KeyName>`; the admin
defaults are `admin`/`admin`; `[auth.anonymous]` has `enabled` and
`org_role`; the server listens on `3000`.

### 2.4 k6

The Prometheus remote write output (read 2026-09-07) is run with
`k6 run -o experimental-prometheus-rw`, `K6_PROMETHEUS_RW_SERVER_URL`
defaulting to `http://localhost:9090/api/v1/write`, and needs the
receiver flag above on Prometheus. The options reference names the
output's environment variable: `K6_OUT`, the equivalent of `--out`.

### 2.5 What phx.new already writes

A phx.new project carries `MyAppWeb.Telemetry`, whose `metrics/0`
lists the Phoenix, Ecto and VM metrics LiveDashboard draws, as
`Telemetry.Metrics` definitions. `telemetry_metrics_prometheus_core`
exports exactly that kind of list.

## 3. Design

### 3.1 PromEx, not `telemetry_metrics_prometheus`

The alternative was tempting for its economy: the project's
`Telemetry.metrics/0` list, exported once more as Prometheus text, one
list for LiveDashboard and Prometheus both. It was rejected for what it
leaves out: dashboards. A Grafana with a datasource and no dashboard is
a query prompt, and writing dashboards for Phoenix, Ecto, the VM and
LiveView is the work PromEx maintains — one per plugin, uploaded by the
app. The price is two metric lists in the project, LiveDashboard's and
PromEx's, on the same Telemetry events. The cartridge names the plugins
off the project's shape (a repo → Ecto, `phoenix_live_view` → LiveView)
and leaves the rest commented, as PromEx's generator does.

### 3.2 The plug, not the metrics server

PromEx can serve `/metrics` on a port of its own (`metrics_server`).
On the pod that would be one more port on the `network` container, on
the bridge one per replica, and either way a second thing to bake and
to keep out of the host. The plug rides the app's port, which every
deployment already publishes, and Prometheus scrapes one address per
app. Placed before `Plug.Telemetry`, as PromEx's example has it, a
scrape is not measured as a request. What this gives up: `/metrics` is
public on the app's port (§5).

### 3.3 Uploaded on start, and the app waits for Grafana

Grafana can provision dashboards from files, as it provisions the
datasource here. PromEx's dashboards are EEx templates rendered with
the app's `dashboard_assigns` (`mix prom_ex.dashboard.export`), which
needs `prom_ex` compiled — the installer adds that dependency in the
same run, so it cannot render them. PromEx's own way is the uploader
on start; the cartridge takes it, with `admin`/`admin`, which the
compose sets Grafana to. The uploader is transient and does not retry
(§2.1): if Grafana is not listening when the app starts, the dashboards
are missing until the next start. So the app's `depends_on` waits for
`grafana` to be `service_healthy` — a `wget --spider` on `/api/health`
— beside the database or the migrator it waited for already; the
templates' `depends_on` became a list for it. On the scaled network
every replica uploads the same dashboards; Grafana overwrites by uid.

### 3.4 The compose writes the targets

Prometheus does not expand environment variables in its scrape
configuration (§2.2), so one `prometheus.yml` cannot say "the app is
where the compose puts it". Three shapes were weighed. A configuration
per topology — the project would own a pod file and the compose carry
a scaled one inline, two sources for one job. DNS discovery on the
`app` alias — no file at all in scaled, but A records give IPs, and a
replica is then an address that changes on every up, not `app3`. And
`file_sd_configs`: the project's `prometheus.yml` names one job that
reads `/etc/prometheus/targets.yml`, and the compose writes that file
as a config with `content:` — `localhost:4000` in the pod, `app1:4000`
… `appN:4000` on the bridge, each replica an instance by its own name.
The project's file stays topology-neutral and is where a job or a rule
is added. The same rule gives Grafana its datasource: one provisioning
file with `url: ${PROMETHEUS_URL}`, which Grafana expands (§2.3), and
the compose sets per topology; and the app its `GRAFANA_HOST`, read in
`runtime.exs` because the release image is built once (§1).

### 3.5 Anonymous as admin

pgAdmin in the workspace opens without a master password; Grafana
opens without a sign-in the same way: `GF_AUTH_ANONYMOUS_ENABLED`,
`GF_AUTH_ANONYMOUS_ORG_ROLE=Admin`, `GF_AUTH_DISABLE_LOGIN_FORM`. The
uploader still authenticates with basic auth, which the login form
setting does not touch. A workbench deployment is on the host's
localhost; the console's door opens on the dashboards.

### 3.6 k6's results

With the k6 cartridge in as well, the compose sets `K6_OUT` and
`K6_PROMETHEUS_RW_SERVER_URL` on the k6 service and restates
Prometheus's command with the receiver flag (§2.2, §2.4), so
`./wb.sh k6` needs no new flag and Prometheus carries `k6_*` metrics
beside the app's. What `./wb.sh k6` prints does not change.

## 4. Evaluation

Verified: the cartridge's tests (the module per project shape, the
configuration in the three files, the tree and the endpoint, the two
files, the mark, the no-op); the compose fixtures for dev, prod and
scaled with and without a database, k6 and the balancer, each accepted
by `docker compose config`; the twenty-seven fixtures of the earlier
steps unchanged byte for byte after the `depends_on` list. A local
Phoenix project on SQLite took the insert, compiled without warnings,
passed its tests, and served the Application, Beam and Ecto metrics at
`/metrics`, the uploader warning "connection refused" with no Grafana
— as §2.1 says it does. Run live on 2026-09-08 through `new`, `add
monitoring`, `add k6`, `bake`, `up`, `k6` and `up --deploy prod` on a
fresh Postgres workspace: the datasource provisioned, the five
dashboards (Application, Beam, Ecto, Phoenix, LiveView) in Grafana
after the app's start, Prometheus's one target up, k6's 59 requests as
`k6_http_reqs_total` in Prometheus, the release serving `/metrics` too.
One thing the run corrected: Grafana's first start on a fresh volume
ran 813 migrations and took four and a half minutes beside the app
compiling, and a 30 s `start_period` with ten retries gave up on it —
the app's `depends_on` then failed the whole `up`. It has five minutes
now, as SQL Server has three, and thirty retries — five minutes more —
after them, since a second fresh start on the release came within
thirteen seconds of the period's end. Not run: the scaled deployment (its file
is validated by `docker compose config` alone). Not measured: the cost
of a scrape every 15 s on a dev app, and whether PromEx's dashboards
say anything useful about a project with no traffic — they are
PromEx's, taken as they come.

## 5. Limitations and open questions

- `/metrics` is served to anyone who reaches the app's port. PromEx
  suggests `Unplug` for gating it; a workbench deployment is local, and
  a project going somewhere else should gate it there.
- Grafana keeps its state (a dashboard edited by hand, a user) in the
  image's own volume, anonymous as pgAdmin's; `delete` drops it with
  the project.
- Prometheus is not published. Its own UI (targets, the expression
  browser) is reachable from a shell on the container, and Explore in
  Grafana covers queries; publishing it would be one more port to bake.
- k6's metrics land in Prometheus, but no k6 dashboard is provisioned:
  Grafana's community one (id 18030) would be a JSON to import by
  hand, or a file the cartridge could ship.
- No alerting: Prometheus's `evaluation_interval` is set and no rule
  file is named; a rule file in `monitoring/` is where it would go.

## References

1. PromEx README — https://prom-ex.hexdocs.pm/readme.html
2. `PromEx.Plug` — https://prom-ex.hexdocs.pm/PromEx.Plug.html
3. `PromEx.Plugins.Phoenix` — https://prom-ex.hexdocs.pm/PromEx.Plugins.Phoenix.html
4. PromEx source: `lib/prom_ex/config.ex`, `lib/prom_ex/dashboard_uploader.ex`, `lib/prom_ex/plugins/ecto.ex`, `lib/mix/tasks/prom_ex.gen.config.ex` — https://github.com/akoutmos/prom_ex
5. hex.pm, `prom_ex` releases — https://hex.pm/api/packages/prom_ex
6. Prometheus configuration — https://prometheus.io/docs/prometheus/latest/configuration/configuration/
7. Prometheus storage, remote write receiver — https://prometheus.io/docs/prometheus/latest/storage/
8. Grafana provisioning — https://grafana.com/docs/grafana/latest/administration/provisioning/
9. Grafana configuration — https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/
10. k6 Prometheus remote write — https://grafana.com/docs/k6/latest/results-output/real-time/prometheus-remote-write/
11. k6 options reference — https://grafana.com/docs/k6/latest/using-k6/k6-options/reference/

Not opened, named for the reader: `telemetry_metrics_prometheus_core`
on hex; Grafana's community k6 dashboard (id 18030).
