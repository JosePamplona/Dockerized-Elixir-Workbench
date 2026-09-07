# Changelog — pgadmin

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-09-06)

### Added

- `pgadmin/servers.json`, the servers pgAdmin opens with — the JSON the
  compose used to carry inline, now the project's own file — and the
  `pgadmin` service declared for `mix workbench.compose`. pgAdmin came
  with every Postgres before; it is a cartridge of its own from here
  (scripts/PLAN.md, step 3), inserted by chiefs_setup and by hand.
