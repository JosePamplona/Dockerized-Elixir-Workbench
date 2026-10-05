# dashboard_extras — Design

*Revision: cartridge v0.1.0 (2026-09-18). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md).*

## Abstract

Phoenix LiveDashboard has two pages it cannot switch on by itself,
because each reads something the project has to bring: **OS Data**
reads Erlang's `:os_mon` application, which runs only when the project
starts it, and **Ecto Stats** reads a library of diagnostic queries
written for one database server, `ecto_psql_extras`,
`ecto_mysql_extras` or `ecto_sqlite3_extras`. The cartridge brings
both: `:os_mon` into `extra_applications`, always, and the extras of
the database the project is on, read off the project's own
dependencies. It is *shaped* by that state rather than refused for it:
no database, or SQL Server, and it installs the first half and says
why. A second run adds what is missing, so a project that gains a
database later gets its page then. It builds on the dashboard, and on
nothing else. It replaces two boxes, osmon and psql_extras, which were
one need split by mechanism, the second of them closed to every
database but Postgres.

## 1. Problem

A developer opening `/dev/dashboard` on a stock `phx.new` project
finds, measured on Phoenix 1.8.14 with LiveDashboard 0.8.7 (§4.2):

* **OS Data** greyed in the menu, with an *Enable* link to the
  dashboard's guide; its URL redirects home.
* **Ecto Stats** as a working link, to a card: "No Ecto repository was
  found running on this node. Currently, only PostgreSQL, MySQL, and
  SQLite databases are supported. Depending on the database,
  ecto_psql_extras, ecto_mysql_extras, or ecto_sqlite3_extras should be
  installed." [1] — on a project whose repository *is* running.

Both guides are short, and each ends in the project's `mix.exs`. What
a developer has to find out is which library is theirs, at which
version beside the dashboard's own, and that the machine's page is not
a dependency at all.

The shelf answered this with two boxes. **osmon** added `:os_mon`.
**psql_extras** added `ecto_psql_extras` and *required* ecto on
Postgres, so on MySQL or SQLite it refused — and a collection that
picked it stopped there — while LiveDashboard had a library for both.
The boundary between the boxes was the mechanism (an OTP application,
a Hex dependency), not the need, which is one: the dashboard's pages,
lit.

## 2. Background

### 2.1 OS Data and `os_mon`

LiveDashboard's guide [2]: "The OS Data comes from the `os_mon`
application, which ships as part of your Erlang distribution. You can
start it by adding it to the extra applications section in your
`mix.exs`", with `extra_applications: [:logger, :runtime_tools,
:os_mon]`; and "Some operating systems break Erlang into multiple
packages. In this case, you may need to install a package such as
`erlang-os-mon` or similar."

The page asks the node which applications run: `menu_link/2` answers
`{:ok, "OS Data"}` "if :os_mon in capabilities.applications" and
otherwise `{:disabled, @menu_text,
"https://hexdocs.pm/phoenix_live_dashboard/os_mon.html"}` [1].

OS_Mon itself [3]: "provides the following services: `cpu_sup` CPU
load and utilization supervision (Unix), `disksup` Disk supervision
(Unix, Windows), `memsup` Memory supervision (Unix, Windows)", and
"When OS_Mon is started, by default all services available for the OS,
except `os_sup`, are automatically started."

It does more than answer when asked. `disksup` [4]: "Periodically
checks the disks. For each disk or partition which uses more than a
certain amount of the available space, the alarm `{{disk_almost_full,
MountedOn}, []}` is set", threshold "The default is 0.80 (80%)", and
"Alarms are reported to the SASL alarm handler". `memsup` [5] does the
same for memory: `{system_memory_high_watermark, []}`, "The default is
0.80 (80%)". With no handler of the project's installed, those alarms
come out in the log (§4.2).

Where the figures come from: memory off `/proc/meminfo` [6], disks off
`df -lk` on Linux [4, source].

### 2.2 Ecto Stats and the extras

LiveDashboard's guide [7]: "These stats are shown for Ecto repositories
running on `Ecto.Adapters.Postgres`, `Ecto.Adapters.MyXQL`, or
`Ecto.Adapters.SQLite3`", and for each the first step is "Add the
[…] dependency": `{:ecto_psql_extras, "~> 0.6"}`,
`{:ecto_mysql_extras, "~> 0.3"}`, `{:ecto_sqlite3_extras, "~> 1.2.0"}`.
The router step is "**only needed if you want to restrict the
repositories** listed in your dashboard, because by default all
_repos_ are going to be listed." There is no fourth: `Ecto.Adapters.Tds`
is not named, and the page's `info_module_for/2` has no clause for it
[1].

The dashboard declares the three as optional dependencies [8]:
`{:ecto_psql_extras, "~> 0.7", optional: true}`, `{:ecto_mysql_extras,
"~> 0.5", optional: true}`, `{:ecto_sqlite3_extras, "~> 1.1.7 or ~>
1.2.0", optional: true}`. An optional dependency constrains the version
once the project declares it, so the cartridge's requirement has to
sit inside the dashboard's.

The page looks for the module at run time — "We check if the extra
module is available locally", `Code.ensure_loaded?(extra)` [1] — and
with the default `:auto_discover` the menu link is on whenever
`Ecto.Adapters.SQL` is loaded, which is why the link works and the
page is the card of §1.

What each library asks of its server:

* **Postgres** [9]: "Some of the queries (e.g., `calls` and `outliers`)
  require pg_stat_statements extension enabled."
* **MySQL** [10]: "The performance schema is enabled by default for
  MySQL databases but not for MariaDB."
* **SQLite** [11]: nothing; it "will automatically" integrate once
  beside `ecto_sqlite3`.

On Hex (read 2026-09-18): `ecto_psql_extras` 0.8.8 (May 2025),
`ecto_mysql_extras` 0.6.3 (December 2024), `ecto_sqlite3_extras` 1.2.2
(October 2023); `phoenix_live_dashboard` 0.9.1 (August 2026), with the
same three optional requirements as 0.8.7 [8]. `phx.new` 1.8 asks for
`~> 0.8.3`.

## 3. Design

### 3.1 One box, and what it builds on

The need is one — the dashboard's pages — so the box is one. What
decides a box's edge is that someone would want one half without the
other, and nobody wants Ecto Stats lit and OS Data dark on principle;
the old split only reflected that one half is an OTP application and
the other a dependency.

It **requires the dashboard** (`requires: ["dashboard"]`). Both halves
work without it — `:cpu_sup.avg1()` and
`EctoPSQLExtras.locks(MyApp.Repo)` from `iex` — but that is not what
the box claims, and a box that installed into a project where nothing
it says comes true would be lying on its label. osmon and psql_extras
did not require it, though osmon's own need named the dashboard's page.
Rejected: no requirement, with the pages as a bonus when the dashboard
is there — it makes the box's one sentence conditional.

### 3.2 Shaped by the state, not refused for it

psql_extras said `requires: [{"ecto", database: "postgres"}]`, and a
requirement has one answer to a project that does not meet it: refuse.
That is right when the box is *about* the state (pgAdmin administers
Postgres and nothing else). Here the state selects among equivalents:
the same page, another library. So the installer reads ecto's
`installed?/1` and `state/1` — the driver in the project's
dependencies, never what an insert was asked — and:

| The project | Installs |
| --- | --- |
| Postgres | `:os_mon`, `{:ecto_psql_extras, "~> 0.8"}` |
| MySQL | `:os_mon`, `{:ecto_mysql_extras, "~> 0.6"}` |
| SQLite | `:os_mon`, `{:ecto_sqlite3_extras, "~> 1.2"}` |
| SQL Server | `:os_mon`; a notice: LiveDashboard has no Ecto Stats for it |
| no database | `:os_mon`; a notice: run it again once ecto is in |

Each requirement is the current minor and sits inside the dashboard's
optional one (§2.2); the three resolve together beside LiveDashboard
0.8.7 and today's drivers (§4.3).

The two notices are not refusals because the box still does what it
can, and says what it did not. Rejected: ecto as a requirement with
the database free — it would refuse the machine's page to an API with
no database, which is the project osmon served without a question.

**No option.** A `--database` would let the answer disagree with the
project; `--no-os-mon` and the like have no case: the halves cost
nothing to the project that ignores them. With no option there is no
`state/1` to answer.

### 3.3 Every environment, like the dashboard

The extras carry no `only:`. psql_extras wrote `only: :dev`, on the
reasoning that `phx.new` serves the dashboard under `dev_routes`. But
`phx.new` declares `phoenix_live_dashboard` itself in every
environment, and its router comment tells the project how to take the
dashboard to production ("you should put it behind authentication").
A project that does would find Ecto Stats dark there, for a reason
buried in a dependency's options. The extras go where the thing they
extend goes; LiveDashboard's guide writes them without `only:` too
[7]. `:os_mon` has no per-environment form to begin with. The cost is
a small library and `table_rex` in the release; they start no process.
A dependency the project already declares is left as it is
(`on_exists: :skip`), `only: :dev` included.

### 3.4 The mark, and a second run

The mark is `:os_mon` in `extra_applications` — the half every project
gets. The extras cannot be part of it: a project without a database
carries the box whole. `rerun: :adds`: both writes are add-if-missing
(`append_new_to_list`, `on_exists: :skip`), so a second run on a
project that gained a database adds the extras and touches nothing
else. A project that *changed* database keeps the old extras beside
the new; removing a dependency is not an installer's to do.

A project that carried the old boxes reads correctly: osmon's mark is
this one's; one with psql_extras alone shows this box as not inserted,
and inserting it adds `:os_mon` and leaves the dependency.

### 3.5 Doors

`os data` at `/dev/dashboard/os_mon`, and `ecto stats` at
`/dev/dashboard/ecto_stats` when ecto is in the project. Both answer
directly, without the node in the path (§4.2). On SQL Server the second
door opens the card of §1, which is LiveDashboard's own explanation;
the door's condition can name a cartridge, not a state, and one more
kind of condition for this case was not worth adding.

### 3.6 What it does not write

* **`config :os_mon`**: the alarms of §2.1 are OTP's defaults and the
  thresholds a fact about the developer's machine. The README says
  where they come from and the two keys that move them.
* **`ecto_repos:` in the router**: the guide's step is for restricting
  repositories; auto-discovery is the default and found the probe's.
* **`pg_stat_statements`**: see §5.

## 4. Evaluation

### 4.1 Unit tests

`test/workbench_igniter/features/dashboard_extras_test.exs`, run
2026-09-18 with the collection's and the catalog's (77 tests, 0
failures): the patch on Postgres; the extras following MySQL and
SQLite; SQL Server and no database, each with its notice, no extras
and no issue; the second run adding the extras once ecto is in; the
refusal without the dashboard, with its remedy; a no-op when both
halves are in; a declared dependency left alone.

### 4.2 Real project

`phx.new` 1.8.9 (`--no-assets`), resolving Phoenix 1.8.14,
LiveDashboard 0.8.7, on Elixir 1.19.5 / OTP 27, the host's, against
`postgres:latest` in a container.

*Before*: the menu and the card of §1, read in a browser.

*After* `mix workbench.install.dashboard_extras --yes`: `mix.exs`
alone — `:os_mon` appended, the one dependency added —, no issue;
`ecto_psql_extras` 0.8.8 and `table_rex` 4.1.0 fetched. `/dev/dashboard/os_mon` and
`/dev/dashboard/ecto_stats`: 200 each, no redirect. OS Data showed
load averages, memory (used, buffered, cached, swap) and every mounted
disk. Ecto Stats showed `Probe.Repo` with 31 queries, *Diagnose*
first; *Calls* and *Outliers* were not among them (§2.2). The log
carried, at boot:

```
[notice]     :alarm_handler: {:set, {:system_memory_high_watermark, []}}
[notice]     :alarm_handler: {:set, {{:disk_almost_full, ~c"/"}, []}}
```

on a machine with a disk at 95%.

### 4.3 Resolution

A bare Mix project declaring `phoenix_live_dashboard ~> 0.8.3`, the
three drivers and the three extras at the cartridge's requirements
resolved: `ecto_psql_extras` 0.8.8, `ecto_mysql_extras` 0.6.3,
`ecto_sqlite3_extras` 1.2.2, beside `myxql` 0.9.0, `ecto_sqlite3`
0.24.1, `exqlite` 0.40.0.

### 4.4 Not measured

Ecto Stats on MySQL and on SQLite in a running project (the patch and
the resolution only); the box through `wb.sh add` in a workspace; OS
Data **inside the workspace's container**, where `/proc/meminfo` and
`df` are the container's view — argued from §2.1's sources, not read
off a screen: memory is likely the host's, the disks the container's
mounts; LiveDashboard 0.9.

## 5. Limitations and open questions

* **The slowest queries are not there on Postgres.** *Calls* and
  *Outliers* need `pg_stat_statements` [9], which is a server setting
  (`shared_preload_libraries`) plus `CREATE EXTENSION` — the first
  belongs to the Postgres service ecto's cartridge defines, the second
  to a migration of the project's. An option here could not do either
  alone. The NEED does not promise them.
* **The log lines of §4.2** on any machine past 80% of disk or memory.
  Documented, not configured (§3.6).
* **SQL Server has no page**, by LiveDashboard's choice. If it grows
  one, it is a row in `@extras`.
* **A project that changes database** keeps the old extras (§3.4).
* **The Ecto Stats door on SQL Server** leads to the card (§3.5).
* **Slim Erlang packages** may lack `os_mon` [2]; the workbench's
  images are the full OTP, and another image's is that image's matter.

## References

Read in full on 2026-09-18 unless marked otherwise.

1. `phoenix_live_dashboard` 0.8.7, `pages/os_mon_page.ex` and
   `pages/ecto_stats_page.ex` — the Hex tarball,
   <https://repo.hex.pm/tarballs/phoenix_live_dashboard-0.8.7.tar>.
   Read for `menu_link/2`, `extra_loaded?/1`, `info_module_for/2` and
   the error card; not the rendering.
2. Phoenix LiveDashboard, *Configuring OS Data* —
   `guides/os_mon.md` at `main`,
   <https://github.com/phoenixframework/phoenix_live_dashboard>.
3. Erlang/OTP 27.3, *OS Monitoring Application* —
   `lib/os_mon/doc/os_mon_app.md`, <https://github.com/erlang/otp>.
4. Erlang/OTP 27.3, `disksup` moduledoc and source —
   `lib/os_mon/src/disksup.erl`. The moduledoc in full; the source for
   the `df` commands only.
5. Erlang/OTP 27.3, `memsup` moduledoc — `lib/os_mon/src/memsup.erl`.
6. Erlang/OTP 27.3, `lib/os_mon/c_src/memsup.c`. **Searched, not
   read**: for `#define MEMINFO "/proc/meminfo"`.
7. Phoenix LiveDashboard, *Configuring Ecto repository stats* —
   `guides/ecto_stats.md` at `main`.
8. `phoenix_live_dashboard` 0.8.7 and 0.9.1, `mix.exs` — the Hex
   tarballs.
9. `ecto_psql_extras` 0.8.8, README — the Hex tarball. Read for
   installation and the extensions it needs; the per-query reference
   skimmed.
10. `ecto_mysql_extras` 0.6.3, README, *MySQL/MariaDB configuration* —
    the Hex tarball.
11. `ecto_sqlite3_extras` 1.2.2, README — the Hex tarball.
12. Hex package metadata for the four packages —
    <https://hex.pm/api/packages/>.
