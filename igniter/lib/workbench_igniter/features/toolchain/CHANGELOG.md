# Changelog — toolchain

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-08-30)

### Added

- `.tool-versions` with the Elixir and Erlang running the installer,
  and `/.elixir_ls/` in `.gitignore` — the two halves of working on the
  project outside the container, rescued from the retired
  `workbench.setup` (which rendered the file from `config.conf`'s stack
  variables and prepended the gitignore entry).
- `--elixir` / `--erlang` to pin something else, and `state/1` reading
  the versions back off the file.

### Changed

- The versions come from the running toolchain (`System.version/0` and
  the OTP release file), not from arguments the workbench passes in:
  the file then agrees with the image that built the workspace by
  construction, instead of by whoever kept `config.conf` up to date.
