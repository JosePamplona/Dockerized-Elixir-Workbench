# Changelog — ansi

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-08-30)

### Added

- `config :elixir, ansi_enabled: true` in `config/config.exs`, rescued
  from the retired `workbench.setup`, where it was one of the lines the
  opinionated creation wrote into every project.
