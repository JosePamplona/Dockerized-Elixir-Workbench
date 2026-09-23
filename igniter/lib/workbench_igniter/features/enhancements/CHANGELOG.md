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

## v1.2.0 - (2026-09-22)

### Removed

- **The database half of the Ecto group.** The `mix db` task, its test,
  the `html_entities` dependency, the DbSchema export under
  `assets/db_schema/` and the page and diagrams under `guides/` are
  [dbschema](../dbschema/)'s box now. `ecto_enum` stays.

### Changed

- **The Ecto group composes `workbench.install.dbschema`** with the
  combo `--auth0`, `--openai` and `--stripe` choose, so a project with a
  database gets everything it got before, from the box that owns it.
- **`state/1` reads the Postman collection alone.** `--auth0` and
  `--openai` were read off the DbSchema model *or* the collection; the
  model is not this cartridge's to read any more, so they are read off
  the collection, and `--project-name` with them. On an install without
  the REST group there is no collection and the four say `nil` — which
  is the truth: nothing of enhancements marks them.

## v1.1.0 - (2026-09-21)

### Updated

- `mix db` writes the database page and the model diagrams under
  `guides/`, where exdoc v0.2.0 keeps the site's sources, instead of
  `assets/exdoc/`, the release build's input.

## v1.0.0 - (2026-09-17)

### Removed

- The `mix version` task and its test: they are versioning's now
  (`--task`), rewritten there for a stock project. The version is that
  cartridge's decision and the task is its tool; here it was a lodger.
  A project that carries the task from this cartridge keeps it — the
  file is the project's — and versioning's `--task` notices it and
  skips. Major because the mark moved with it.

### Changed

- The mark is `test/support/fixtures.ex`, the one file every shape of
  the install writes; it was the task file.

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
