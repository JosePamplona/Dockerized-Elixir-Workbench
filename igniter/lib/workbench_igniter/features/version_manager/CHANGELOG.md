# Changelog — version_manager

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-09-18)

### Added

- The pin of the host's Erlang and Elixir, taken out of toolchain
  (v0.1.0 there), where it shared a box with the language server's
  ignore: a version manager and a language server are two tools. The
  versions read off the running toolchain came along as they were.
- `--manager asdf|mise`: `.tool-versions` (the default — asdf's file,
  and mise reads it too) or `mise.toml`, the file mise recommends over
  it. `state/1` says the manager back off the file that is there; a
  version file of either manager, `.mise.toml` included, is the mark,
  and none is ever overwritten.

### Removed

- `--elixir` / `--erlang`, which toolchain had: an option to type the
  versions contradicts the file's one claim, that it agrees with what
  runs the project. Another pin is an edit of the file, which is the
  project's. `state/1` answers for the manager alone.

### Changed

- Elixir is pinned with the OTP it runs on (`1.19.6-otp-28`, where
  toolchain wrote `1.19.6`). Both managers install Elixir precompiled,
  and the bare version is the build against the oldest OTP that Elixir
  supports — not the Erlang pinned on the line above it (DESIGN.md,
  3.2).
