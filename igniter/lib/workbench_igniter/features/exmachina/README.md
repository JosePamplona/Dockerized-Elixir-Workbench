# Cartridge: exmachina

ExMachina test factories.

* **Task**: `mix workbench.install.exmachina`
* **Enabled by**: manual (`wb.sh add exmachina`)

## Description

Test data factories: realistic sample records in one line. Installed on
demand with `wb.sh add exmachina`; no collection picks it.

## What it installs

* `{:ex_machina, "~> 2.8", only: :test}` in the project deps.

**Idempotency**: `on_exists: :skip` — re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `exmachina.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Exmachina` shell |

Cartridge test: `test/workbench_igniter/features/exmachina_test.exs`.
