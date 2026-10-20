# Changelog — health_probe

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a change in the generated files' shape or
routes is a minor, a change that breaks a project already carrying them
(a renamed module, a moved route) is a major.

## v0.3.0 - (2026-10-20)

### Fixed

- **A probe in plain HTTP got a 301 instead of an answer.** Mounted
  first in the endpoint was meant to put the plug ahead of `force_ssl`,
  and it does not: Phoenix plugs `Plug.SSL` inside
  `use Phoenix.Endpoint`, before any plug of the project's, and phx.new
  turns `force_ssl` on in `prod.exs` since Phoenix 1.8.2. Measured on
  workspace `_001` (Phoenix 1.8.15, Plug 1.20.3), its prod deployment
  up: from `localhost` both routes answered 200, since `Plug.SSL`
  spares that host by default; with the pod's address as `Host`, as a
  kubelet or a balancer sends it, both answered `301` to
  `https://localhost/…`, and with the database stopped `/ready` still
  answered `301` — a pass for Kubernetes, which counts 200–399, so a
  pod without its database stayed in rotation. Fly.io and an ALB,
  which want a 200, would have failed it always.

### Changed

- **Both routes go into `force_ssl`'s `exclude: [paths: …]`** in
  `config/prod.exs` when it sets `force_ssl`: Plug's own way out since
  Plug 1.19, and the one Phoenix's template hints at with a commented
  `# paths: ["/health"]`, which is left where it is. Paths are matched
  whole, so the hint's `/health` alone would not cover the probes:
  both are listed. The edit goes into the `config` call that holds
  `force_ssl`: a project with assets has two for the endpoint, and the
  first draft, through Igniter's configuration API, wrote into the
  `cache_static_manifest` one — right once `Config` merged them, out of
  sight of `force_ssl`, and found only on a live copy, since the test
  project had no assets. The test now runs on both shapes. An `exclude` the project already has keeps its
  entries; a new one carries Plug.SSL's default hosts beside the
  probes; a `prod.exs` without `force_ssl` is not touched. The plug's
  moduledoc says that a new prefix has to be changed in both places.
- **Readiness answers within 500 ms, not one second, and the bound
  is the whole check.** Kubernetes gives up on a probe after one
  second by default (`timeoutSeconds`), so a one-second query ended in
  the kubelet's timeout instead of the plug's 503. A healthy
  `SELECT 1` takes a few milliseconds. The query's own `:timeout`
  holds only once DBConnection hands over a connection: with the
  database down there is none, the call waits in the pool's queue
  until its CoDel check drops it — two `queue_interval`s, about 4 s,
  measured — so `ready?/1` now runs the query in a `Task` and gives it
  500 ms with `Task.yield/2`. Measured on a copy of `_001`: 503 after
  0.50 s with the database stopped, against 3.99 s without the task.
  The test it writes into the project gains a repo that never answers.
- **The Kubernetes example points the startup probe at `/live`**, as
  Kubernetes documents it — "the same command, HTTP or TCP check" as
  liveness. A failing startup probe kills the container, so on
  `/ready` a database down during a deploy restarted the pods: the
  restart on a dependency the whole design keeps out of liveness.

## v0.2.1 - (2026-09-22)

### Changed

- **`--path` is declared `:route`** (`formats/0`): path segments,
  whatever slashes are put around them — `/health`, `status`, `//up//`
  and `/` all still read as they did — and a value carrying a space, a
  query or a fragment is refused instead of being written into a route
  nobody can call.

## v0.2.0 - (2026-09-20)

### Changed

- The cartridge is `health_probe`, not `healthcheck2`: `wb.sh add
  health_probe`, `mix workbench.install.health_probe`. The `2` said
  only that another box got the word first; the name says now what the
  box writes — the probe a platform polls — and stands on its own
  beside `health_endpoint`, the reading endpoint that was
  `healthcheck`. What it installs is unchanged: the same
  `MyAppWeb.Plugs.Health`, the same two routes, the same `--path`.
- The comment the installer leaves above the plug in the endpoint reads
  `Workbench health probe`, the one line of generated text that carried
  the old name.

## v0.1.0 - (2026-08-28)

### Added

- `MyAppWeb.Plugs.Health`: `GET /health/live` (200 while the VM answers,
  checks nothing else) and `GET /health/ready` (200/503 from a
  `SELECT 1` on `MyApp.Repo` with a one-second timeout; `ready?/1`
  rescues and catches, so it never raises). Plain-text body,
  `Cache-Control: no-store`, anything else passes through.
- Its test, through the endpoint and with the plug alone against a repo
  that answers an error and one that raises.
- `plug MyAppWeb.Plugs.Health` mounted first in `MyAppWeb.Endpoint`,
  before `Plug.Static`.
- `--path` option (default `/health`).
- A project without `MyApp.Repo` gets a `/ready` that answers like
  `/live`.
