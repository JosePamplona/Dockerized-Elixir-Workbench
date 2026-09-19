# Cartridge: dashboard_extras

The two pages Phoenix LiveDashboard ships dark — the machine's and the
database's — lit.

* **Task**: `mix workbench.install.dashboard_extras`
* **Inserted by**: `wb.sh add dashboard_extras`
* **Requires**: `dashboard`.

## Description

[LiveDashboard](https://hexdocs.pm/phoenix_live_dashboard) comes with
every `phx.new` project, and two of its pages come switched off,
because each reads something only the project can bring:

* **OS Data** — CPU load averages, memory (used, buffered, cached,
  swap) and every mounted disk. It reads `os_mon`, an application that
  ships with Erlang and runs only when the project starts it. Until
  then the menu entry is greyed, with an *Enable* link to a guide.
* **Ecto Stats** — what the database server knows about itself: index
  usage and unused indexes, locks and who is blocking whom, cache hit
  ratios, table and index sizes, bloat, long-running queries, and a
  *Diagnose* tab that reads them for you. The queries are a library's,
  one per server: [`ecto_psql_extras`](https://hexdocs.pm/ecto_psql_extras)
  (a port of Heroku's `pg-extras`),
  [`ecto_mysql_extras`](https://hexdocs.pm/ecto_mysql_extras),
  [`ecto_sqlite3_extras`](https://hexdocs.pm/ecto_sqlite3_extras).
  LiveDashboard picks one by the repository's adapter; until it is in
  the deps, the page is a card telling you to install it.

Which library is yours, at which version beside the dashboard's, and
that the machine's page is no dependency at all: that is what this
cartridge knows.

The libraries work without the dashboard too —
`EctoPSQLExtras.locks(MyApp.Repo)` from `iex` prints the same table.

## What it installs

| The project is on | It installs |
| --- | --- |
| Postgres | `:os_mon` + `{:ecto_psql_extras, "~> 0.8"}` |
| MySQL | `:os_mon` + `{:ecto_mysql_extras, "~> 0.6"}` |
| SQLite | `:os_mon` + `{:ecto_sqlite3_extras, "~> 1.2"}` |
| SQL Server | `:os_mon`; a notice — LiveDashboard has no Ecto Stats for it |
| no database | `:os_mon`; a notice — run it again once there is one |

`:os_mon` is appended to `extra_applications` in `mix.exs`. The
database is **read off the project's dependencies**, never asked: the
box is shaped by the project instead of refusing it. The extras go in
every environment, as `phx.new` declares the dashboard itself, so a
project that takes the dashboard to production finds the page lit
there too.

## Options

None. There is nothing to choose that the project has not already said.

## Idempotency

A second run adds what is missing and nothing else: insert a database
later, run it again, and Ecto Stats lights up. A dependency the project
already declares is left as it is, its options included.

## In the log

`os_mon` does not only answer the dashboard: it watches, and raises an
alarm when a disk or the memory passes 80%. On such a machine the app
boots with

```
[notice]     :alarm_handler: {:set, {{:disk_almost_full, ~c"/"}, []}}
```

That is OTP telling the truth, not an error. The thresholds are the
project's to move, in its config:

```elixir
config :os_mon,
  disk_almost_full_threshold: 0.95,
  system_memory_high_watermark: 0.95
```

## What the pages need of the server

* **Postgres**: the *Calls* and *Outliers* tabs — the slowest
  statements — appear only with the `pg_stat_statements` extension,
  which is a server setting (`shared_preload_libraries`) plus `CREATE
  EXTENSION`. Everything else works on a stock server.
* **MySQL**: the performance schema, on by default in MySQL and off in
  MariaDB.
* **SQLite**: nothing.

## In the console

Two doors: **os data** (`/dev/dashboard/os_mon`) and, with a database
in the project, **ecto stats** (`/dev/dashboard/ecto_stats`).

## Contents

| File | Role |
| --- | --- |
| `dashboard_extras.ex` | Manifest + logic: the extras by database, the mark, the doors |
| `task.ex` | `Mix.Tasks.Workbench.Install.DashboardExtras` shell |
| `NEED.md` | The need it answers |
| `CHANGELOG.md` | The cartridge's own version history |
| `DESIGN.md` | Why one box and not two, why shaped and not refused, why every environment; with sources and what was measured |

Cartridge test: `test/workbench_igniter/features/dashboard_extras_test.exs`.
