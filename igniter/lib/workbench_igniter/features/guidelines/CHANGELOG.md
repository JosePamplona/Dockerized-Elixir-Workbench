# Changelog — guidelines

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.2.0 - (2026-09-21)

### Updated

- The page is `guides/coding.md`, beside the rest of the site's sources
  since exdoc v0.2.0 moved them out of `assets/`, the release build's
  input. Its entries in the `docs:` block are written through exdoc's
  `list_page/4`, the code that owns the block's shape.

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
