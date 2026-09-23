# Changelog — guidelines

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.2.1 - (2026-09-22)

### Changed

- **Archived.** The box installs a page from a URL only the team has,
  and a shelf a project is picked from cannot hand it one — the reason
  it was always à la carte. It keeps its papers on the shelf, shows as
  retired, and `wb.sh add --archived guidelines --url URL` still puts
  it in for a team that has the URL.

- **`--url` is declared `:url`** (`formats/0`): the page is downloaded
  from it, and a value that is not an address the browser opens now
  ends the run with a sentence instead of a request that fails over the
  network. The console asks for it with a URL field.

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
