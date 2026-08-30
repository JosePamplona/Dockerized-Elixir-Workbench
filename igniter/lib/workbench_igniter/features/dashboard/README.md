# dashboard

Phoenix's dashboard for a project generated with `--no-dashboard`.

[LiveDashboard](https://hexdocs.pm/phoenix_live_dashboard/Phoenix.LiveDashboard.html)
"provides real-time performance monitoring and debugging tools for
Phoenix developers": the home and OS pages, metrics from the
project's `Telemetry` module, a request logger, processes, ETS and —
with a repo — Ecto stats, served as a LiveView at `/dev/dashboard` in
development. Its own guide for an existing app asks for the
dependency, the `/live` socket in the endpoint and a `live_dashboard`
route in a dev-only scope; that is what `phx.new` writes unless told
`--no-dashboard`.

Standalone, base cartridge. Install it on demand with

```sh
./wb.sh add dashboard
mix workbench.install.dashboard
```

## What it installs

Whatever `phx.new` generates for it at the installer's version in the
toolchain — asked of `phx.new` itself (`WorkbenchIgniter.PhxDelta`, see
[mailer](../mailer/) for the mechanism). With Phoenix 1.8.12: `{:phoenix_live_dashboard, "~> 0.8.3"}`, the
`live_dashboard "/dashboard"` route in the router's dev-only scope
(with `import Phoenix.LiveDashboard.Router`), and the endpoint's
`/live` socket uncommented when live had not already turned it on.

Files the project already changed are merged three ways; a conflict is
reported with `phx.new`'s version of the file beside it.

## Options

None. `phx.new` has none for it.

## Idempotency

Re-running is a no-op: when the `phoenix_live_dashboard` dependency is there — a default project carries
it — nothing is touched and a notice says so.

## Contents

| File | Role |
| --- | --- |
| `dashboard.ex` | Manifest + logic: the flag, the mark |
| `task.ex` | `Mix.Tasks.Workbench.Install.Dashboard` shell |
| `CHANGELOG.md` | The cartridge's own version history |
| `DESIGN.md` | Why it requires neither html nor live, with sources; the engine is in [mailer's](../mailer/DESIGN.md) |

Cartridge test: `test/workbench_igniter/features/base_cartridges_test.exs`.
