# Cartridge: adminer

Adminer in the workspace, open on the project's database, whatever the adapter.

* **Task**: `mix workbench.install.adminer`
* **Inserted by**: `wb.sh add adminer` — à la carte, not a chiefs_setup pick (that is pgadmin). Then `./wb.sh bake`.
* **Requires**: ecto, on any of its adapters.

## Description

pgAdmin administers Postgres alone. Adminer is one PHP page that reads
Postgres, MySQL, MSSQL and SQLite, and this cartridge puts it beside
the workspace's database on its own port: a container the workspace
runs because the project asked for it, and a file the project owns —
the login Adminer opens with. The compose is rendered from what the
project carries (`services/1`), so inserting this and running
`./wb.sh bake` puts the container in, and ejecting it and baking again
takes it out. The box stands beside pgadmin as healthcheck2 stands
beside healthcheck — two boxes for one need — and does not refuse on
Postgres.

## What it installs

* `adminer/login.php` — one Adminer plugin, the project's own: the
  workspace's database as the one server in the login form, named
  after the app, with the driver and the user off the project's
  adapter (`pgsql` / `postgres`; `server` / `root` — `server` being
  Adminer's key for MySQL; `mssql` / `sa`; `sqlite`, with neither); the
  user and the database filled into the form; and the password Adminer
  verifies itself, `pass`, as `password_hash()` of it. On MSSQL, whose
  server checks its own, type sa's (`some!Password`) instead. Where the
  server is and which database to open come from the compose
  (`WORKBENCH_SERVER`, `WORKBENCH_DATABASE`); the file's own values are
  the dev pod's, for an Adminer run by hand.
* The `adminer` service, declared for `mix workbench.compose`: the
  `adminer` image (`ADMINER_IMAGE_VERSION` in `config.conf`, the major
  `6`), on the pod's network, its port published beside the app's (the
  first free one from 8080), the project's `adminer/` mounted read-only
  as the image's `plugins-enabled/`. On SQLite it also mounts the file
  — the source in dev, the `data` volume in prod — and runs as the
  file's owner, so SQLite can write its journal beside it.

Why a password of Adminer's own: Adminer 6 refuses an empty password,
a database without passwords and a server that accepts any — and
inside the pod Postgres trusts 127.0.0.1, MySQL's root has no password
and SQLite has none. [DESIGN.md](DESIGN.md) §2.4 and §3.3.

**Idempotency**: the file is the mark; re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `adminer.ex` | Manifest + logic (`info/2`, `install/1`, `services/1`, `login/2`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Adminer` shell |
| `priv/features/adminer/templates/login.php.eex` | The login plugin |
| `CHANGELOG.md` | The cartridge's own version history |
| `DESIGN.md` | Why Adminer, why one file fusing two of its plugins, what was measured |

Cartridge test: `test/workbench_igniter/features/adminer_test.exs`.
