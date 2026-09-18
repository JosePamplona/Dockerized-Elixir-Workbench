# Cartridge: pgadmin

pgAdmin in the workspace, open on the project's Postgres.

* **Task**: `mix workbench.install.pgadmin`
* **Inserted by**: `wb.sh add pgadmin`; a chiefs_setup pick (beside psql_extras). Then `./wb.sh bake`.
* **Requires**: `{"ecto", database: "postgres"}` — ecto, in the state
  the requirement names; the refusal says what the project has instead
  ("this project's database is mysql").

## Description

pgAdmin used to come with the database, written into every compose that
had a Postgres. It is a cartridge now: a container the workspace runs
because the project asked for it, and a file the project owns — the
servers pgAdmin opens with. The compose is rendered from what the
project carries (`services/1`), so inserting this and running
`./wb.sh bake` puts the container in, and ejecting it and baking again
takes it out.

## What it installs

* `pgadmin/servers.json` — one server, the workspace's: `localhost:5432`,
  user `postgres`, named after the app, its password in the `pgpass`
  file the container writes at start. Mounted into the container as
  `/pgadmin4/servers.json` by the compose (`configs: pgadmin_servers`).
* The `pgadmin` service, declared for `mix workbench.compose`: the
  `dpage/pgadmin4` image (`PGADMIN_IMAGE_VERSION` in `config.conf`), on
  the pod's network, its port published beside the app's (the first free
  one from 5050), signed in with `pgadmin4@pgadmin.org` / `pass`.

**Idempotency**: the file is the mark; re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `pgadmin.ex` | Manifest + logic (`info/2`, `install/1`, `services/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Pgadmin` shell |
| `priv/features/pgadmin/templates/servers.json.eex` | The servers file |

Cartridge test: `test/workbench_igniter/features/pgadmin_test.exs`.
