# ecto

Phoenix's Ecto, with its database adapter, for a project generated with
`--no-ecto`.

[Ecto](https://hexdocs.pm/phoenix/ecto.html) is how a Phoenix project
validates and persists data: a `MyApp.Repo` on one of four adapters
(Postgres, MySQL, MSSQL, SQLite3), configured per environment,
migrations under `priv/repo`, a `DataCase` for tests and the sandbox
that isolates them. "Newly generated Phoenix projects include Ecto
with the PostgreSQL adapter by default"; `--database` changes the
adapter and `--no-ecto` leaves all of it out — after which
`phx.gen.html`, `phx.gen.live` and `phx.gen.context` "may no longer
work as expected", as `mix help phx.new` warns.

Base cartridge. Install it on demand with

```sh
./wb.sh add ecto [--database postgres|mysql|mssql|sqlite3] [--binary-id]
mix workbench.install.ecto --database postgres
```

## What it installs

Whatever `phx.new --database <db>` generates for Ecto at the
installer's version in the toolchain — asked of `phx.new` itself
(`WorkbenchIgniter.PhxDelta`, see [mailer](../mailer/) for the
mechanism). With Phoenix 1.8.12 and Postgres: `ecto_sql`, `postgrex`
and `phoenix_ecto` in `mix.exs` with the `ecto.setup`/`ecto.reset`
aliases, `MyApp.Repo`, the repo in the supervision tree, its
configuration in every environment (`DATABASE_URL` read in
`runtime.exs`), `priv/repo/migrations` and `seeds.exs`,
`test/support/data_case.ex`, `ecto_repos` in `config.exs`. Files the
project already changed are merged three ways; a conflict is reported
with `phx.new`'s version of the file beside it. And what
`phx.gen.release` writes at birth only when Ecto is in: `MyApp.Release`
(`lib/my_app/release.ex`) and `rel/overlays/bin/migrate`, the script
the release's compose runs before the app.

On top of the delta, the one thing `phx.new` leaves to the environment:
`DATABASE_URL` (or `DATABASE_PATH` for SQLite) in `.env` and
`.env.sample`, pointing at the workspace's own server — on `localhost`
inside the pod, with the dev credentials `phx.new` configures the
project with (`postgres:postgres`, `root` with no password, `sa` with
`some!Password`) — or at `/app/data/<app>_prod.db`, the volume the
release's compose mounts for the SQLite file. The same line
`workbench.setup` writes for a project born with Ecto.

## Options

| Option | Default | Values |
| --- | --- | --- |
| `--database` | `postgres` | `postgres`, `mysql`, `mssql` — the workspace's compose provides the server, configured with `phx.new`'s dev credentials — or `sqlite3`, a file, with a volume for it in a release |
| `--binary-id` | off | `binary_id` as the primary key type of generated schemas — `phx.new --binary-id`, the `generators` entry of `config.exs` |

Both are `phx.new` flags it accepts without Ecto and only Ecto reads:
that is why they are this cartridge's, and why the workbench's *New
project* offers them with the ecto box rather than beside `--adapter`.

Inserted once: changing the database of a project that has data is a
migration, not a flag — eject and insert again, then migrate by hand.

## After inserting

The workspace's `docker-compose.yml` was baked for the project as it
was, without a database service. `wb.sh add ecto` bakes it again in
the insert's own commit, with the server the adapter needs. The
database itself is created by the app container: it runs `mix setup`
at every boot, and phx.new's `setup` alias runs `ecto.setup` (create,
migrate, seeds). So the next `./wb.sh up` finishes the job. With `--database sqlite3`
there is no server: the dev compose stays as it was (the file lives
beside the source), and the prod compose gets a `data` volume for it
and the migrator; the scaled deployment refuses SQLite, since replicas
cannot share a file.

## Idempotency

Re-running is a no-op: when `ecto_sql` is a dependency — a default
project carries it — nothing is touched and a notice says so.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/ecto/` | The cartridge: its code and its papers |
| `├── 📄 ecto.ex` | The delta, `--database`, the `.env` entry |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why the options, `.env` and the `bake` |
|  |  |
| `📁 priv/features/ecto/compose/` | The database's containers |
| `├── 📁 pod/` | One host: dev and prod |
| `│   ├── 📄 postgres.yml.eex` | The Postgres server |
| `│   ├── 📄 mysql.yml.eex` | The MySQL server |
| `│   ├── 📄 mssql.yml.eex` | The SQL Server server |
| `│   ├── 📄 create.yml.eex` | Creates the database on SQL Server |
| `│   ├── 📄 volume_init.yml.eex` | SQLite's volume, handed to the release |
| `│   └── 📄 migrate.yml.eex` | The one-shot migration, before the app |
| `└── 📁 scaled/` | Replicas: no SQLite |
| `    ├── 📄 postgres.yml.eex` | The Postgres server |
| `    ├── 📄 mysql.yml.eex` | The MySQL server |
| `    ├── 📄 mssql.yml.eex` | The SQL Server server |
| `    ├── 📄 create.yml.eex` | Creates the database on SQL Server |
| `    └── 📄 migrate.yml.eex` | One migration, not one per replica |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 ecto_test.exs` | Its flags, and every `--database` |
