# ecto — Design

*Revision: cartridge v0.3.2 (2026-10-06): §3.5, a project on SQLite
has no scaled deployment, with references 11–14 read on that date.
Cartridge v0.3.1 (2026-09-25): the step after the insert
is the compose baked in the insert's commit and `mix setup` at the app
container's boot; `./wb.sh setup` never existed. The rest: cartridge
v0.2.0 (2026-08-30). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md); the engine is
argued in the [mailer paper](../mailer/DESIGN.md) §2.3–§2.7 and
§3.1–§3.5. This paper holds what ecto decides beyond it: two options,
one environment variable, and a step after the insert.*

## Abstract

`phx.new --no-ecto` leaves out the repo, its adapter, three
environments of configuration, the supervision-tree entry, the
`ecto.*` aliases, `priv/repo`, the data case and the Ecto lines of the
test helpers — and the two flags only Ecto reads, `--database` and
`--binary-id`, become inert. The cartridge brings the delta back, for
the database chosen, and takes those two flags as its own options.
On top of the delta it writes the one thing `phx.new` leaves to the
environment: `DATABASE_URL` — `DATABASE_PATH` for SQLite — in `.env`
and `.env.sample`, with the values the workspace's own compose
provides, as `workbench.setup2` writes them for a project born with
Ecto. The workspace's compose was baked without a database service, so
the cartridge names what follows: `./wb.sh bake`, then `setup`. The
mark is `ecto_sql`. The alternatives — asking the database of the
project instead of `phx.new`'s option, writing the compose from the
cartridge, or letting Igniter's port of `phx.new` supply the delta —
were rejected on the sources; the last one is the reason the engine
runs `phx.new`'s own generator.

## 1. Problem

Phoenix's Ecto guide: "Newly generated Phoenix projects include Ecto
with the PostgreSQL adapter by default" and "You can pass the
`--database` option to change or `--no-ecto` flag to exclude this"
[4]. A project excluded at birth and wanting a database later has the
most files of any base capability to gain (§2.1), a choice to make
that `phx.new` made at generation for everyone else, and a workspace
whose compose has no database service because the project did not
need one. Three questions: which database and how to ask; what the
release needs that no generated file supplies; and who puts the
database into the compose.

## 2. Background

### 2.1 What `phx.new` does with `--no-ecto` and `--database`

`mix help phx.new` [1]:

> `--database` - specify the database adapter for Ecto. One of:
> `postgres` - via https://github.com/elixir-ecto/postgrex, `mysql` -
> via https://github.com/elixir-ecto/myxql, `mssql` - via
> https://github.com/livehelpnow/tds, `sqlite3` - via
> https://github.com/elixir-sqlite/ecto_sqlite3 […] Defaults to
> "postgres".

> `--no-ecto` - do not generate Ecto files

> `--binary-id` - use `binary_id` as primary key type in Ecto schemas

and the warning after the options: "When passing the `--no-ecto` flag,
Phoenix generators such as `phx.gen.html`, `phx.gen.json`,
`phx.gen.live`, and `phx.gen.context` may no longer work as expected as
they generate context files that rely on Ecto for the database access"
[1].

`put_binding/1` [2]: `ecto = Keyword.get(opts, :ecto, true)`; `db =
Keyword.get(opts, :database, "postgres")` is resolved through
`get_ecto_adapter/3` to `{adapter_app, adapter_module, adapter_config}`
*whether or not* Ecto is on — `postgrex`/`Ecto.Adapters.Postgres`,
`myxql`/`MyXQL`, `tds`/`Tds`, `ecto_sqlite3`/`SQLite3`, and
`Mix.raise("Unknown database …")` otherwise; `--binary-id` is put into
`adapter_config`, from which `generators:` in `config.exs` is
rendered. `Single.generate/1`: `if Project.ecto?(project), do:
gen_ecto(project)`, which copies `phx_ecto/repo.ex.eex`,
`priv/repo/migrations/.formatter.exs`, `seeds.exs`,
`test/support/data_case.ex`, creates `priv/repo/migrations`, and calls
`gen_ecto_config/1` [2, 3] — three injections: `config/dev.exs`,
`config/test.exs`, and into `config/runtime.exs`'s `:prod` block the
adapter's `prod_variables` and `prod_config`. For the socket databases
`prod_variables` is [2]:

```elixir
database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """
```

with `ECTO_IPV6` and `POOL_SIZE` (default `"10"`) beside it; for
SQLite, `DATABASE_PATH` — "For example: /etc/#{app}/#{app}.db" — and
`POOL_SIZE` default `"5"`. The dev and test credentials are the
adapter's: `postgres`/`postgres` on `localhost`, `root`/`""` for MySQL,
`sa`/`some!Password` for MSSQL, `Path.expand("../#{app}_dev.db")` for
SQLite [2].

The conditionals in the templates [3]: `mix.exs` (`phoenix_ecto`,
`ecto_sql`, the adapter app; the `ecto.setup`/`ecto.reset` aliases and
`test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]`;
`setup` gaining `ecto.setup`), `config.exs` (`ecto_repos`,
`generators`), `application.ex` (`App.Repo` among the children; for
SQLite an extra clause), `endpoint.ex` (`plug
Phoenix.Ecto.CheckRepoStatus` under code reloading), `telemetry.ex`
(the repo metrics), `conn_case.ex` and `test_helper.exs` (the sandbox),
`.formatter.exs` (`:ecto, :ecto_sql` imports, `subdirectories:
["priv/*/migrations"]`), `.gitignore` for SQLite, `errors.pot` and
`errors.po` (the changeset messages), `AGENTS.md` (the Ecto usage
rules).

Measured [8]: on a default project without Ecto, created 4 files,
changed 14; on an API-only project, 4 and 12 (no `.pot`/`.po`); with
`--database sqlite3`, 13 changed, `.gitignore` among them.

### 2.2 What Igniter's port would give instead

Igniter 0.8.3's `Igniter.Phoenix.Generator.gen_ecto_config/2` injects
`config/dev.exs` only [5] — the mailer paper §2.4 quotes both
functions. An ecto delta taken from the port would arrive without the
test sandbox configuration and without the `DATABASE_URL` block the
release reads. That is the fact that made the engine run `phx.new`'s
generator (mailer §3.1, option 2), and it was found here.

### 2.3 What the workbench does for a project born with Ecto

`mix workbench.setup2` renders `.env` from
`priv/setup/templates/env.eex`, whose Ecto line is
`DATABASE_URL="<%= @database_url %>"` under `<%= if @ecto do %>`, with
`database_url/2` building `ecto://<user>:<pass>@<host>:<port>/<app>_prod`
from the setup's options [6]. The workspace's compose is baked from
`docker-compose.seed.yml` by `wb.sh`'s `bake_compose`, which drops the
`database` and `pgadmin` services when `workspace_needs_database`
fails — "an Ecto repo in `config.exs`, and not the SQLite adapter (a
file, no service)": `grep -q "ecto_repos" config/config.exs && ! grep
-q "ecto_sqlite3" mix.exs` [7]. The `add` command, after committing
the insert, tests the same predicate against the compose and prints
"The project now runs on a database and the compose has none: ./wb.sh
bake bakes it in, then ./wb.sh setup creates it"; `bake` re-bakes the
compose keeping the workspace's ports, as one commit [7]. Inside the
pod every service is on `localhost` (the clustering paper §2.5), so the
Postgres the compose provides is `localhost:5432` from the app's point
of view, with the seed's `postgres`/`postgres`.

Phoenix's deployment guide, for what the release needs [9, summary
only]: "`$ export DATABASE_URL=ecto://USER:PASS@HOST/database`" among
the secrets loaded in `config/runtime.exs`, and "if you are using a
database, you will also want to run `mix ecto.migrate` before starting
the server".

## 3. Design

### 3.1 `--database` and `--binary-id` are this cartridge's options

`phx.new` accepts both without Ecto and only Ecto reads them (§2.1):
`get_ecto_adapter/3` runs on every generation, and `generators:` in
`config.exs` is rendered from `adapter_config` — but with `--no-ecto`
nothing consumes either. So they are not generation options of `new2`;
they are what an ecto insert has to be told. Three ways to take them:

1. **Detect the database from the project.** There is nothing to
   detect: a `--no-ecto` project carries no driver, and `facts/1`'s
   `database` reads `postgres` for it (mailer §3.2) — correct for the
   base generation, meaningless as a choice.
2. **A closed list of the cartridge's own.** Chosen, as `phx.new`'s
   list and `phx.new`'s words: `@databases` carries the four names with
   the `mix help` phrasing ("via postgrex", …) and one workbench fact
   each (which the compose provides), validated before anything is
   generated — `phx.new` itself would `Mix.raise` on an unknown name
   (§2.1), and an issue is the cartridge's form of that. The list is
   the catalog's `choices` and the console's dropdown.
3. **Pass whatever the user gives through to `phx.new`.** Rejected:
   `Mix.raise` inside `generate/1` is a crash in the middle of two
   generations, not an issue.

`--binary-id` is one boolean handed to the generation as an override
(`PhxDelta.apply(igniter, :ecto, %{database:, binary_id:})`) — the
delta's *theirs* is generated with it and its *base* without, so the
`generators: [binary_id: true]` entry is part of the difference; the
unit test pins it. A default project's `facts.binary_id` is read off
`config.exs` (`binary_id:\s*true`) so that a project born with it
generates its base with it, which is the mailer paper's §3.2 applied
to the one option that is not a dependency.

### 3.2 The environment variable is written; the compose is not

`phx.new` reads `DATABASE_URL` in `runtime.exs` and writes it nowhere
(§2.1); `workbench.setup2` writes it in `.env` for a project born with
Ecto (§2.3). The cartridge does the same, through
`WorkbenchIgniter.EnvFile.entry/3` — a comment and the line, appended to
`.env` and `.env.sample` when the key is absent — with three bodies:

* `postgres`: `ecto://postgres:postgres@localhost:5432/<app>_prod`,
  the workspace's Postgres as the pod sees it (§2.3) — the value
  `setup2` would have written.
* `sqlite3`: `DATABASE_PATH="<app>_prod.db"`, since that adapter's
  `runtime.exs` reads a path, not a URL (§2.1).
* `mysql`, `mssql`: `ecto://user:pass@localhost/<app>_prod` with a
  comment saying the compose provides no such service — a placeholder
  that reads as one, because a value that looked right for a server
  the workspace does not run would be worse.

Not a secret, so `.env.sample` gets the same text (`EnvFile.entry/3`,
mailer paper reference 13). What the cartridge does *not* write is the
compose: `bake_compose` derives the database service from the project
(§2.3), the seed is `wb.sh`'s, and a cartridge editing
`docker-compose.yml` would be a second author of a file with one
source. Instead the manifest's `afterwards/0` names the step —
"./wb.sh bake puts the database into the workspace's compose, then
./wb.sh setup creates it" — and `wb.sh add` says it again when the
predicate is true after the insert (§2.3). With `sqlite3` the predicate
is false and `bake` leaves the compose alone: the same rule that keeps
a `new2 --database sqlite3` workspace without a Postgres.

### 3.3 The mark: `ecto_sql`; inserted once

`installed?/1` is `dep_installed?(igniter, :ecto_sql)` — what `facts/1`
reads for `ecto` and the first thing `--no-ecto` leaves out. `ecto`
alone would match a project using Ecto without a database (`etso`,
embedded schemas), `phoenix_ecto` a project with the integration but
no repo, the driver a specific choice; `ecto_sql` is the capability.

The cartridge is `:noop` on re-run: changing `--database` on a
project that has a repo, migrations and data is not a flag flip but a
migration — a different driver, different credentials in three
environments, a different `DATABASE_URL`. The README says eject and
insert again, then migrate by hand; the alternative, an installer that
swaps the driver in place, would have to know what to do with
`priv/repo/migrations` and was not designed.

### 3.4 What is deliberately absent

No `mix ecto.create` queued: the database does not exist until `bake`
and `setup` (§3.2), and in the workspace the container that runs the
installer has no database beside it. No `POOL_SIZE`, `ECTO_IPV6`: read
with defaults in `runtime.exs` (§2.1). No pgAdmin variables: the
compose's. No migration: there is nothing to migrate.

### 3.5 A project on SQLite has no scaled deployment

The scaled deployment is N replicas of the release that any request
may reach: behind the balancer, or one by one on their own ports. That
holds only while the replicas read the same data. A server gives them
that; a SQLite file does not, because each replica is a container with
a file of its own. What the reader would see depends on how requests
are spread, and none of the ways is a working application:

| Topology | What a request reads |
|---|---|
| balancer, round robin | another replica's data on each request: rows come and go |
| balancer with affinity | each client's own data, for as long as the affinity holds |
| no balancer | one application per port, each with its own data |
| any of them, clustered | PubSub and Presence cross the nodes and the Repo does not: a node is told of a row it does not have |

So the cartridge does not refuse the set of services, which is what
`{:error, reason}` is for (two databases). It says the project has no
such deployment: `compose/1` answers `{:unavailable, reason}`,
`mix workbench.compose` prints it as `unavailable> REASON` and exits
with 4, and `wb.sh` tells that apart from a render that failed. A
project is born with its dev and prod files and one note; a scaled
file baked before `add ecto --database sqlite3` is removed in the
insert's commit; `bake --deploy scaled` ends with the reason; the
status carries it (`deployments.scaled.unavailable`) and the console
shows the row switched off, saying why.

Considered and left out:

* **One file on a volume all the replicas mount.** It would run on the
  one Docker host a workspace is, and nowhere the deployment stands
  for. SQLite's own word on WAL: "All processes using a database must
  be on the same host computer; WAL does not work over a network
  filesystem", and "there can only be one writer at a time" [11]. On a
  file shared over a network its locks "have been known to operate
  incorrectly for some network filesystems. This has led to database
  corruption", and its advice is the one given here: "if your data is
  separated from the application by a network, you want to use a
  client/server database" [12]. A deployment that works only because
  its replicas are on one machine teaches the opposite of what it is
  for.
* **Leaving the balancer out.** The third row of the table: it names
  the divergence instead of hiding it, and it is still N applications.
  Not an option of this cartridge, since a use for it was not found.
* **Replicating the file.** LiteFS puts "a passthrough file system"
  under the application, has one node take the writes — "All writes
  should be directed to that node and it will propagate changes to the
  rest of the cluster" — and chooses that node with "a lease from
  Consul" [13]; rqlite puts a Raft log in front of SQLite and is
  another server with its own client [14]. Both are real, and both are
  an architecture of their own — a file system or a server, a lease, a
  way to send writes to one node — not a flag on this one. If one is
  ever wanted it is a cartridge.
* **A read-only file in the image.** Identical in every replica, so it
  scales; it is a dataset the application ships, not the Repo with
  migrations that `phx.new --database sqlite3` generates.

## 4. Evaluation

**Unit tests** (`features/ecto_test.exs`, 6 cases; run 2026-08-30 in
the suite of the mailer paper §4.1, 0 failures): the mark out
and in; with Postgres the repo, `data_case.ex`, `seeds.exs`,
`ecto_sql` and `postgrex` in `mix.exs`, `Test.Repo` in the supervision
tree, `ecto_repos` in `config.exs`, `DATABASE_URL` read in
`runtime.exs` and written in `.env` and `.env.sample`; `--database
sqlite3` with `Ecto.Adapters.SQLite3`, `ecto_sqlite3` and no
`postgrex`, `DATABASE_PATH` in both files; `--binary-id` present and
absent in `config.exs`; `--database oracle` refused with an issue; a
second run unchanged.

**Real project**, three runs on 2026-08-30 (mailer §4.2):

* *API-only probe, first run* (generator mismatch): `mix.exs` and
  `priv/gettext/errors.pot` conflicts, nothing written.
* *API-only probe, second run* (versions matched, gettext inserted
  first): "priv/gettext/errors.pot: the ecto lines conflict" — the
  trailing-newline case the gettext paper §4 diagnoses — and nothing
  written. Fixed in the engine (mailer §3.4); probe D (mailer §4.4)
  ran the same order clean, with the Ecto entries appended to the
  `.pot`.
* *Probe B* — `phx.new --no-live --no-ecto --no-dashboard --no-mailer
  --no-gettext`, live inserted first, then `mix workbench.install.ecto
  --yes`: 12 files changed (`.formatter.exs`, `AGENTS.md`,
  `config/config.exs`, `dev.exs`, `runtime.exs`, `test.exs`,
  `lib/probe/application.ex`, `lib/probe_web/endpoint.ex`,
  `telemetry.ex`, `mix.exs`, `test/support/conn_case.ex`,
  `test/test_helper.exs`), 5 created (`.env`, `.env.sample`,
  `lib/probe/repo.ex`, `priv/repo/`, `test/support/data_case.ex`), no
  issue; a second run printed "ecto_sql is already a dependency: Ecto
  is in, skipping." `.env` read `DATABASE_URL="ecto://postgres:postgres@localhost:5432/probe_prod"`
  under its comment, `.env.sample` the same. With gettext, mailer and
  dashboard inserted after it, `mix compile --warnings-as-errors`
  passed and the project's `mix test` — `ecto.create` and
  `ecto.migrate` on a Postgres at `127.0.0.1:5432` with
  `postgres`/`postgres`, then the suite — reported 5 tests, 0
  failures.
* *Probe C* — API-only, ecto last, after html, esbuild, tailwind and
  the dashboard: 18 files, no issue (the `AGENTS.md` block goes before
  html's, in the middle of the file), `mix test` 5/5.

**Not measured**: `--database mysql` and `mssql` beyond the unit test's
list (no server); `./wb.sh add ecto` followed by `bake` and `setup` in
a workspace; a project with data changing its database; `ecto.migrate`
in the release.

## 5. Limitations and open questions

* **The `.env` values assume the pod.** `localhost:5432` and
  `postgres:postgres` are the workspace compose's; the scaled
  deployment overrides `DATABASE_URL` in its own `environment` block
  (clustering paper §2.5), and a deployment elsewhere edits `.env`.
  Same as for a project born with Ecto.
* **`mysql` and `mssql` get a placeholder URL.** The workspace has no
  service for them; the seed could grow one, and then the cartridge's
  value should follow. Open.
* **No pgAdmin for a database inserted later** beyond what `bake`
  brings back — which is all of it, since the seed carries the service.
  Not a limitation once `bake` runs; listed because `add ecto` without
  `bake` leaves a project that cannot `mix ecto.create`.
* **Changing the database is not supported** (§3.3). The catalog says
  `:noop`; the console shows the option only while the cartridge is
  out.
* **`--binary-id` on a project born with Ecto** is the generators
  entry, and a project that later inserts a cartridge reads it off
  `config.exs` (mailer §3.2); a project that sets `binary_id` in a
  different form (`generators: [binary_id: true, …]` on one line is
  matched; a multi-line keyword with the key elsewhere is too, since
  the regex is `binary_id:\s*true`) — no case found that is not
  matched, and none tried beyond the template's.

## References

Read in full on 2026-08-30 unless marked otherwise.

1. `phx_new` 1.8.9, `Mix.Tasks.Phx.New` moduledoc —
   `igniter/deps/phx_new/lib/mix/tasks/phx.new.ex`.
2. `phx_new` 1.8.9, `Phx.New.Generator` — `put_binding/1`,
   `gen_ecto_config/1`, `get_ecto_adapter/3`, `socket_db_config/4`,
   `fs_db_config/2`, `adapter_generators/1` —
   `igniter/deps/phx_new/lib/phx_new/generator.ex`.
3. `phx_new` 1.8.9, `Phx.New.Single` (`template(:ecto, …)`,
   `gen_ecto/1`) and the templates `phx_ecto/*`, `phx_single/mix.exs.eex`,
   `phx_single/config/config.exs.eex`,
   `phx_single/lib/app_name/application.ex.eex`,
   `phx_web/endpoint.ex.eex`, `phx_web/telemetry.ex.eex`,
   `phx_test/support/conn_case.ex.eex`,
   `phx_single/test/test_helper.exs.eex`, `phx_single/formatter.exs.eex`,
   `phx_single/gitignore.eex`, `phx_gettext/errors.pot.eex` —
   `igniter/deps/phx_new/`.
4. Phoenix 1.8, *Ecto* — <https://hexdocs.pm/phoenix/ecto.html> (served
   from <https://phoenix.hexdocs.pm/ecto.html>). **Summary only**:
   fetched through a summarizer; quoted for the default adapter and the
   `--database` / `--no-ecto` sentence.
5. Igniter 0.8.3, `Igniter.Phoenix.Generator.gen_ecto_config/2` —
   `igniter/deps/igniter/lib/igniter/phoenix/generator.ex`.
6. `igniter/lib/mix/tasks/workbench.setup2.ex` (`database_url/2`),
   `igniter/priv/setup/templates/env.eex`, this repository.
7. `wb.sh`, this repository — `bake_compose`, `workspace_needs_database`,
   the `add` and `bake` commands; `scripts/docker-compose.seed.yml`.
8. `PhxDelta.delta/3` run on 2026-08-30 (mailer paper, reference 15).
9. Phoenix 1.8, *Deploying* — <https://hexdocs.pm/phoenix/deployment.html>
   (served from <https://phoenix.hexdocs.pm/deployment.html>).
   **Summary only**; quoted for `DATABASE_URL` and `ecto.migrate`.
10. `igniter/lib/workbench_igniter/features/ecto/ecto.ex`, `task.ex`;
    `WorkbenchIgniter.EnvFile.entry/4` (`igniter/lib/workbench_igniter/env_file.ex`);
    `igniter/test/workbench_igniter/features/ecto_test.exs`; the
    [mailer paper](../mailer/DESIGN.md) for the engine.
11. SQLite, *Write-Ahead Logging* — <https://www.sqlite.org/wal.html>.
    Read on 2026-10-06, **summary only** (fetched through a
    summarizer, asked for the sentences verbatim); quoted for the same
    host and the single writer.
12. SQLite, *SQLite Over a Network, Caveats and Considerations* —
    <https://www.sqlite.org/useovernet.html>. Read on 2026-10-06,
    **summary only**, as [11]; quoted for the locks and the advice.
13. Fly.io, *How LiteFS Works* —
    <https://docs.fly.io/litefs/how-it-works>. Read on 2026-10-06,
    **summary only**, as [11]; quoted for the file system, the writes
    and the lease.
14. rqlite — <https://rqlite.io>. **Not read for this paper**: named
    as what it is known to be, a distributed database built on SQLite
    and Raft, and quoted for nothing.
