# Cartridge: psql_extras

Postgres observability queries (`ecto_psql_extras`).

* **Task**: `mix workbench.install.psql_extras`
* **Inserted by**: `wb.sh add psql_extras`; a chiefs_setup pick (the trivial dep-only group).
* **Requires**: `{"ecto", database: "postgres"}` — ecto, on Postgres,
  read off the project; the refusal says what the project has instead.

## Description

Ready-made queries to diagnose database health (unused indexes, slow
queries, locks). Part of the trivial dep-only group (a chiefs_setup pick).

## What it installs

* `{:ecto_psql_extras, "~> 0.8", only: :dev}` in the project deps.

**Idempotency**: `on_exists: :skip` — re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `psql_extras.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.PsqlExtras` shell |

Cartridge test: `test/workbench_igniter/features/psql_extras_test.exs`.
