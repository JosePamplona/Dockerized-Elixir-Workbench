# Changelog — exdoc

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a new page or route is a minor, a change
that breaks a project already carrying the generated code (a renamed
module, a moved route) is a major.

Backfilled at the version below, its first: the cartridge shipped
before a changelog was part of the anatomy, and gets one on its next
change, as the features index says.

## v0.2.0 - (2026-09-21)

### Updated

- **`--coveralls` is `--coverage`**, after the box it names, which
  took the need's name. The page and the report it joins are the same.

## v0.1.0 - (2026-08-30)

### Added

- The ExDoc site served by the application at `/dev/docs`: the
  `ex_doc` dependency, the `MyAppWeb.ExDocController` and its test, the
  `docs:` block of `mix.exs` (extras, groups, the workbench theme's
  `before_closing_*_tag` hooks), the theme assets and logo, and the
  per-feature extra pages — the coverage report with coveralls, the
  access-token page with auth0, the database page when the project has
  Ecto (read off the project, not asked).
- `--build`: runs `mix docs` once the insert is applied, so the door
  has pages the first time it is opened. Off by default, and queued
  rather than run inline — the site needs the dependencies fetched and
  compiled, which only happens after the files land. `afterwards/0`
  names the command for whoever leaves it off.

### Removed

- `--guidelines-url`, and with it the only network call this installer
  made. The coding-guidelines page is the [guidelines](../guidelines/)
  cartridge now: it downloads the markdown and appends its entries to
  the two lists this cartridge's `docs:` block keeps.
