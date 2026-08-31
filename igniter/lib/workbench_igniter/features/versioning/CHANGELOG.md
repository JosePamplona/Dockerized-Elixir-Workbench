# Changelog — versioning

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-08-30)

### Added

- The `version:` of `mix.exs` (`--version`, default `0.0.0`) and the
  `CHANGELOG.md` opened at it, both rescued from the retired
  `workbench.setup`: they were its `INIT_VERSION` and its
  `changelog.eex` template, which travelled with it.
- `state/1` reading back the version `mix.exs` declares.
