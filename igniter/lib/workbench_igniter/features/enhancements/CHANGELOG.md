# Changelog — enhancements

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a new module or task is a minor, a
change that breaks a project already carrying them (a renamed module, a
changed schema default) is a major.

Backfilled at the version below, its first: the cartridge shipped
before a changelog was part of the anatomy, and gets one on its next
change, as the features index says.

## v0.1.0 - (2026-08-30)

### Added

- The workbench's base layer on a generated project: `MyApp.Schema` and
  `MyApp.Helper` with their tests, the `mix db` and `mix version`
  tasks, the enhanced error views, the extended test suite and support
  files, and the DbSchema diagrams and Postman collections that match
  what the project carries. What it has of Ecto, html, the mailer and
  the dashboard is read off the project (`PhxDelta.facts`), not asked.
- The configuration half of `--id-type` and `--timestamps`, rescued
  from the retired `workbench.setup`: `migration_primary_key` and
  `migration_timestamps` on the repo, and `generators: [timestamp_type:
  :utc_datetime_usec]`. It is one decision and this cartridge already
  owned the options; without the config half, `mix phx.gen.*` kept
  emitting `phx.new`'s defaults and the tables drifted from the schemas
  `MyApp.Schema` defines. Written only when the project has Ecto, with
  everything else in the Ecto group.
