# Cartridge: osmon

OS process monitoring (`:os_mon`).

* **Task**: `mix workbench.install.osmon`
* **Enabled by**: `--enhance` on `workbench.setup` (config.conf: `ENHANCE`)

## Description

Machine resource monitoring (CPU, memory, disk) visible from the
dashboard. Part of the trivial group toggled by `--enhance`; dep-less —
it enables an OTP application instead of adding a dependency.

## What it installs

* `:os_mon` appended to `extra_applications` in `mix.exs`.

**Idempotency**: `append_new_to_list` — re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `osmon.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Osmon` shell |

Cartridge test: `test/workbench_igniter/features/osmon_test.exs`.
