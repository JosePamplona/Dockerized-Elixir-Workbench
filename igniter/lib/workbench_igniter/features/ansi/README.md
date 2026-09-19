# Cartridge: ansi

Coloured logs from inside the container.

* **Task**: `mix workbench.install.ansi`
* **Inserted by**: `wb.sh add ansi`

## Description

Elixir decides at boot whether to emit ANSI escapes, and it decides
against it when the process has no terminal attached — which is every
container `docker compose` starts. The logs then arrive as plain text
however capable the terminal reading them is. This cartridge sets the
decision by hand.

It is one line of configuration. It is a cartridge and not a line in
the setup task because it is an opinion, not a requirement: the project
boots and runs identically without it.

## What it installs

* `config :elixir, ansi_enabled: true` in `config/config.exs`.

**Idempotency**: the mark is the configuration key itself
(`configures_key?`), so a second run finds it and changes nothing.

## Contents

| File | Role |
| --- | --- |
| `ansi.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Ansi` shell |

Cartridge test: `test/workbench_igniter/features/ansi_test.exs`.
