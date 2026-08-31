# Changelog — guidelines

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-08-30)

### Added

- `assets/exdoc/coding.md`, downloaded from `--url`, and its entries in
  the `extras` and `groups_for_extras[:Support]` lists of exdoc's
  `docs:` block — appended, so exdoc's own pages stay where its
  installer put them.
- `requires: ["exdoc"]`: the installer refuses, naming it, while the
  site is not in.
- The placeholder page and warning when the download fails, carried
  over from exdoc's implementation.

### Changed

- Split out of exdoc, where this was `--guidelines-url`: exdoc no
  longer reaches the network to install, and the page has its own
  version and its own box.
