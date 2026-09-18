# Changelog — psql_extras

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

Backfilled at the version below, its first: the cartridge shipped
before a changelog was part of the anatomy, and gets one on its next
change, as the features index says.

## v0.1.1 - (2026-09-18)

### Changed

- The Postgres check is the requirement, not a check of its own:
  `requires/0` says `{"ecto", database: "postgres"}`, the resolver every
  cartridge shares reads it off ecto's `state/1`, and the refusal reads
  as every other's. What it installs is what it did.

## v0.1.0 - (2026-08-30)

### Added

- `{:ecto_psql_extras, "~> 0.8", only: :dev}` in the project's deps, on
  a project whose database is Postgres; refused, naming the adapter,
  on any other.
