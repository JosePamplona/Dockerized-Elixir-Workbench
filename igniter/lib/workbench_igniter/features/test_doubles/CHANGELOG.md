# Changelog — test_doubles

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-09-20)

### Added

- One box for the test doubles, the library as its option: `--double
  mimic,mox`, one or several, a second run adding the other. It takes
  over from `mock`, which is a dependency and nothing else; the
  migration of the eight generated test files that stand on `Mock` is
  per cartridge and `mock` stays on the shelf until it is done.
- The option is not a preference: Mimic replaces a module — any module,
  `File`, `System`, an HTTP client, a repo made to raise — and asks
  nothing of the code; Mox replaces nothing, builds a new module
  against a behaviour the project declares, and needs the code to ask
  its configuration whom to call. Without `--double`, **mimic**, which
  is what the shelf's own generated tests need without a redesign
  (DESIGN.md §3.2).
- `--type-check`, one switch with two implementations: **Hammox** in
  place of Mox, which wraps it and checks the callbacks' typespecs at
  run time, and `type_check: true` on every `Mimic.copy/2`. Off by
  default.
- **The way in**, which is what `mock` never had: `copy/4` and
  `defmock/4` register what a cartridge's tests replace into *its own
  block* of `test/test_helper.exs`, through
  `WorkbenchIgniter.BlockFile` — so healthcheck's copied modules and
  coveralls' stand in one file, before `ExUnit.start()`, and `forget/2`
  takes one away without touching the other. Lines already registered
  are not written twice.
- The mark is the dependency, and `state/1` says which doubles the
  project carries and whether they are type-checked — Hammox, or a copy
  asking for it in the test helper.
