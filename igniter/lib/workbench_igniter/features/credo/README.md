# Cartridge: credo

Credo static code analysis.

* **Task**: `mix workbench.install.credo`
* **Enabled by**: `--enhance` on `workbench.setup` (config.conf: `ENHANCE`)

## Description

An automated reviewer that flags style and code-quality issues before
they reach production. Part of the trivial dep-only group toggled by
`--enhance`.

## What it installs

* `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` in the project deps.

**Idempotency**: `on_exists: :skip` — re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `credo.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Credo` shell |

Cartridge test: `test/workbench_igniter/features/credo_test.exs`.
