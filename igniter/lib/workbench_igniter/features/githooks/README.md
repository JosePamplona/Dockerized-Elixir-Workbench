# Cartridge: githooks

git_hooks management.

* **Task**: `mix workbench.install.githooks`
* **Enabled by**: manual (`wb.sh add githooks`)

## Description

Automates checks before each commit, so problematic code doesn't even
reach the repository. Standalone: not in the `WorkbenchIgniter.Features`
registry — `workbench.setup` never composes it.

## What it installs

* `{:git_hooks, "~> 0.7", only: :dev, runtime: false}` in the project deps.

**Idempotency**: `on_exists: :skip` — re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `githooks.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Githooks` shell |

Cartridge test: `test/workbench_igniter/features/githooks_test.exs`.
