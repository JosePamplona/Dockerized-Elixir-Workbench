# Cartridge: mock

Mock library for tests.

* **Task**: `mix workbench.install.mock`
* **Enabled by**: `--enhance` on `workbench.setup` — also composed directly by
  `healthcheck`, `coveralls` and `enhancements`, whose generated tests use it (config.conf: `ENHANCE`)

## Description

Lets tests simulate external pieces (APIs, services) without depending
on the real thing. Part of the trivial dep-only group toggled by
`--enhance`.

## Pending: migration to Mox

The `mock` library sits on `meck`, whose latest release (0.9.2) does not
compile on OTP 29 (old-style `(catch ...)` is deprecated there and meck
builds with warnings-as-errors), so any project generated with this dep
on an OTP ≥ 29 stack fails its test compile. Mox is the maintained,
ecosystem-blessed replacement; migrating means reworking this feature and
the healthcheck controller tests that `import Mock`. Until then, stacks up
to OTP 28 work fine.

## What it installs

* `{:mock, "~> 0.3", only: :test}` in the project deps.

**Idempotency**: `on_exists: :skip` — re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `mock.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Mock` shell |

Cartridge test: `test/workbench_igniter/features/mock_test.exs`.
