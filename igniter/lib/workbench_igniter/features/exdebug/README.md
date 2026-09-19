# Cartridge: exdebug

ExDebug inspection helpers.

* **Task**: `mix workbench.install.exdebug`
* **Inserted by**: `wb.sh add exdebug`

## Description

Utilities to inspect values comfortably while developing. A dep-only
cartridge.

## What it installs

* `{:ex_debug, "~> 1.0"}` in the project deps.

**Idempotency**: `on_exists: :skip` — re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `exdebug.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Exdebug` shell |

Cartridge test: `test/workbench_igniter/features/exdebug_test.exs`.
