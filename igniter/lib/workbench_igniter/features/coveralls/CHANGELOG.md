# Changelog — coveralls

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a change in the report or the task is a
minor, a change that breaks a project already carrying them is a major.

Backfilled at the version below, its first: the cartridge shipped
before a changelog was part of the anatomy, and gets one on its next
change, as the features index says.

## v0.1.0 - (2026-08-30)

### Added

- ExCoveralls with the workbench's HTML report: the dependency, the
  `test_coverage` and `preferred_envs` entries in `mix.exs`, the
  `coveralls.json` (`--minimum-coverage`, and the paths left out of the
  report — `open_api` on `--interface graphql`, the components folder
  when the project has no html, read off the project), the report
  template of `--theme` (`exdoc-ish` | `custom`, one directory each
  under the cartridge's assets) and the `mix cover` task, which writes
  `TESTING.md` for the docs when exdoc is in.
- `--build`: runs the suite once the insert is applied, so the report
  has numbers before anyone opens it. Off by default and queued, not
  inline: `mix cover` needs the dependencies compiled and — on a
  project with Ecto, read off the project — a test database, which the
  queued `ecto.create`/`ecto.migrate` prepare and the workspace's
  compose must actually carry (`./wb.sh bake`). `afterwards/0` names
  the command for whoever leaves it off.
