# Changelog — toolchain

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.2.0 - (2026-09-18)

### Removed

- `.tool-versions`, `--elixir` / `--erlang` and the versions in
  `state/1`: the pin of the host's stack is the new `version_manager`
  cartridge's (`.tool-versions` or `mise.toml`, by `--manager`). A
  version manager and a language server are two tools, and a project
  may have either without the other.

### Changed

- The mark is the `/.elixir_ls/` entry in `.gitignore`, where it was
  `.tool-versions`. A project that took v0.1.0 carries both files'
  marks: it reads as having toolchain and version_manager in, which is
  what it has.
- The name and the scope — ElixirLS is a language server, not only
  VS Code's; Lexical, Next LS and Expert keep directories of their own —
  are still to settle (`SCRIPT.md`, "The author's selection").

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
