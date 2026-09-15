# The compose, generated from a plan

How the workspace's orchestration files should be produced once the
services in them are optional, and why the generator moves from `sed`
in `wb.sh` to a mix task in the igniter package. Written on 2026-09-06,
before any of it is built; the order at the end is the order to build.

## What the bake is today, and where it stops scaling

`bake_compose` copies `docker-compose.seed.yml`, substitutes the
`%{…}` values, and then *carves*: the dev file loses the one-shot
`migrate` service, the prod file loses the source volume and the build
arguments, and a project without a database server loses `database`,
`pgadmin`, `migrate`, the app's `depends_on` and the pgAdmin port — each
cut a `sed` over a range anchored on a comment line. The scaled
deployment has a seed of its own, with its own copy of the database,
because it swaps the pod pattern for a bridge network.

Three things this cannot do without multiplying the cuts. Postgres is
the only database the compose knows, while the ecto cartridge already
offers `mysql`, `mssql` and `sqlite3` and says of the first two "no
service in the workspace's compose". pgAdmin comes and goes with the
database, never on its own. And every auxiliary service to come — k6
for load, Prometheus and Grafana for monitoring — would be one more
block in two seeds and two more range deletions. The range deletion is
also the script's most fragile move: `bake_prod_compose` records the
time a cut left `build:/app/src/_build` standing under `env_file`.

The question "does this project run on a database server" is a grep
over `config/config.exs` and `mix.exs`, which an umbrella project — its
deps in `apps/*/mix.exs` — would answer wrong.

## The shape

A **plan**, rendered by **templates**, produced by **one task**.

The plan is data: the deployment (`dev`, `prod`, `scaled`) and its
topology (`pod`, `bridge`); the app — image, dockerfile, whether the
source is mounted, its endpoints with their host and container ports
(a list from the start, since an umbrella may publish more than one),
replicas and balancer for `scaled`; and the **services**, each a struct
with image, environment, healthcheck, the ports it publishes, volumes,
what it depends on, and its compose profiles. Whatever is topology's is
resolved in one place and handed to every service: how it attaches
(`network_mode: "service:network"` in the pod, `networks: [cluster]` on
the bridge) and what the host is called (`localhost`, or the service's
name). Dev and prod are the same plan on the pod topology, with another
image and two switches; they are not two seeds.

The renderer is EEx, not a YAML encoder. The seeds carry the reasoning
for every decision in comments — why the pod, why no `restart:`, why
`pg_isready -h` — and the README promises a file a reader can open and
understand. An encoder drops the prose. Templates are what the
cartridges already render with (`embed_templates`), and the output is
tested by parsing it back and by `docker compose config`, never by
comparing text — except in the first step, where byte-equality with
today's files is the point.

The task is `mix workbench.compose`, in the igniter package: `--deploy
dev|prod|scaled`, `--replicas N`, `--no-balancer`, the YAML on standard
output. `wb.sh` stops knowing YAML: `bake` becomes a redirect of that
task, through `workspace_igniter` with a project and `package_igniter`
without one. Both run the package in the workbench's image, which `new`
builds before it bakes, so the generator is at hand at every moment the
script bakes today. The console loads the package as a dependency and
can show the compose a bake would write, before writing it.

## Who says which services

The cartridges, in their manifests, as they already contribute doors,
tabs and probes to the console: a `services/1` off the cartridge's
state. Ecto contributes `postgres` or `mysql` as `--database` says, and
nothing for `sqlite3`; `pgadmin` is a cartridge of its own that
requires ecto with postgres; `k6` and the monitoring stack are
cartridges too. The plan's services are the base — `network`, `app`,
`migrate` when there is a database — plus the union of what the
inserted cartridges declare. `status --json` reports the list, and the
console draws it instead of its two fixed cases.

Two consequences. "Needs a database" stops being a grep and becomes a
fact the cartridge states, off the same mark its installer and its
`installed?` read — the rule everything else here follows. And a
cartridge that writes no Elixir (pgadmin, k6) still leaves a real diff
to commit and to eject: the compose is tracked in the workspace, so
insert bakes the service in, `installed?` finds it there, and eject
reverts the commit.

Ports already published are read back from the existing compose before
a bake, by service name, so a re-bake moves nothing; a new service
takes the first free port after the ones in the file. Hand edits go to
`docker-compose.override.yml`, which Compose reads on its own and the
bake never touches — the README should say so.

## What it opens

- **k6** — a service under `profiles: [tools]`, so `up` never starts
  it, and a verb that runs `compose run --rm k6` with the script named;
  its results to a volume, or to Prometheus when the monitoring stack
  is in.
- **Monitoring** — Prometheus and Grafana as services of one cartridge,
  whose Elixir side installs PromEx or telemetry_metrics_prometheus;
  Grafana enters the console as a door.
- **SQLite in a release** — today a project without a database server
  loses the migrator too, and a release on SQLite still needs
  `bin/migrate`. The plan makes `migrate` depend on "has a repo", not on
  "has a database service".
- **Umbrella** — the compose barely changes (an umbrella is still one
  image); what changes is the Elixir side, `Phx.New.Single` only in the
  delta engine, `lib/app_web` assumed by the cartridges. Its own
  exploration; the endpoints-as-a-list is the one thing done for it now.

## Risks

The YAML is still text: parsing it back in the tests and running
`docker compose config` in CI (whose runners carry Docker) covers it.
`bake` on an existing workspace costs a one-off container of the
package, seconds once compiled. The first step has to be dull on
purpose — the task reproduces the three files the script writes today,
byte for byte, under golden tests — so that the script changes its
mechanism without changing a single file it writes.

## The order

1. `WorkbenchIgniter.Compose` and `mix workbench.compose` render the
   dev, prod and scaled files exactly as `wb.sh` writes them now, golden
   tests against the current output; `wb.sh` redirects the task.
   *Landed on 2026-09-06*: thirteen fixtures generated from the bash
   bake (`igniter/test/support/compose_golden.sh`), two of them
   corrected where the bash was wrong — `up --deploy prod` without a
   database wrote a truncated file, and the no-balancer scaled file
   ended in a stray blank line; both are recorded in the harness. Two
   templates, `priv/compose/pod.yml.eex` and `scaled.yml.eex`; the flag
   interface is the test's fixture table. Verified against test_85's
   three files: identical below the header. What the bash left and the
   templates reproduce on purpose, for step 2 to clean: a
   `configs: pgadmin_servers` block in the no-database pod files.
2. Services come from the cartridges; `status --json` lists them; ports
   are read back; the grep goes.
   *Landed on 2026-09-06*: `services/1` on the manifest, `[]` by
   default; ecto's `state/1` reports the adapter off `PhxDelta.facts/1`
   and asks for `postgres` and `pgadmin` on postgres, nothing otherwise
   (mysql and mssql used to get a Postgres they never used).
   `Features.services/1` is the union over the installed cartridges;
   `Status.read/0` carries it; `workbench.compose` reads it off the
   project when `--services` is not given, and writes with `--out`
   because a mix run's stdout is not clean. `wb.sh` runs the task on
   the project (`workspace_igniter`), reads the prod file's pgAdmin
   port back, and tells `add` the compose is behind by rendering and
   comparing. The console still draws pgAdmin off the published ports;
   drawing the service list is step 3's, with the first cartridge that
   brings a service of its own.
3. `pgadmin` and `k6` as cartridges, with the `k6` verb.
   *Landed on 2026-09-06*: each installs one file the project owns —
   `pgadmin/servers.json`, `k6/smoke.js` — which is its mark, and
   declares its service; the compose references the servers file
   instead of carrying the JSON inline. k6 sits under `profiles:
   [tools]` and gets `BASE_URL` per topology; `./wb.sh k6` runs it with
   `compose --profile tools run`. Ecto declares `postgres` alone: a
   vanilla `new` no longer brings pgAdmin, `chiefs_setup` does. The
   console still draws pgAdmin off the published ports; the service
   list is in the status for when a screen wants it.
4. `mysql` and `mssql` services, with their healthchecks; the ecto
   cartridge's table stops saying "no service".
   *Landed on 2026-09-07*, SQLite in a release with it: ecto declares
   the engine (`postgres`, `mysql`, `mssql`, `sqlite`), the `database`
   service keeps its name and takes its engine, `database_init` creates
   SQL Server's database in the release deployments, `data_init` chowns
   SQLite's volume for `nobody`, and scaled refuses SQLite. One table in
   the ecto module writes the release's connection for both its
   installer and `new`. *Run live the same day*: MySQL, SQLite and SQL
   Server each through `new`, `up` and `up --deploy prod` on fresh
   workspaces, k6 against the MySQL one (66 requests, every check
   green), pgadmin inserted, baked and up on a fresh Postgres one. SQL
   Server's first start outlasted its healthcheck's retries: it has a
   `start_period` now. One limit seen on the way, not of these steps:
   the host ports are chosen when a file is baked, and `up` does not
   notice when another workspace took them since — it fails on
   Docker's "port is already allocated". A bake that re-reads its
   ports, or an `up` that checks them, is the fix. *Done the same day*:
   a free port is one nothing listens on and no other workspace has
   baked, and `up` checks the file's ports before compose does, naming
   the holder.
5. Monitoring.
   *Landed on 2026-09-07*: the `monitoring` cartridge — PromEx in the
   app (the plugins the project's shape calls for, `/metrics` on the
   endpoint, the Grafana client at runtime off `GRAFANA_HOST`) and
   `prometheus` with `grafana` in the compose, Grafana published beside
   the app's port and healthy before the app starts, so the dashboards
   PromEx uploads land. The rule the step settled: a service opens with
   a file the project owns, and what is the topology's the compose
   writes — Prometheus's targets (`localhost` in the pod, one line per
   replica by name on the scaled network), `PROMETHEUS_URL`,
   `GRAFANA_HOST` — so one insert serves the three deployments. k6's
   results go to Prometheus by remote write when both are in. The app's
   `depends_on` became a list in the templates for it. Grafana enters
   the console as the workbench's own door, off its port, as pgAdmin
   does; the service list is still not drawn as such. *Run live the
   next day*, dev and prod with k6 on a fresh Postgres workspace: the
   five dashboards up, k6's requests in Prometheus; Grafana's first
   start took four and a half minutes and its healthcheck allows five
   now. The scaled file is validated by `docker compose config` alone.
6. Umbrella, on its own plan.
