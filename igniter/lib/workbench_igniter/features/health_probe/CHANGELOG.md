# Changelog — health_probe

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a change in the generated files' shape or
routes is a minor, a change that breaks a project already carrying them
(a renamed module, a moved route) is a major.

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
