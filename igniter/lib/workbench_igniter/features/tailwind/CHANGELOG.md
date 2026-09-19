# Changelog — tailwind

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for it at the installer's
version, as [mailer](../mailer/CHANGELOG.md) says.

## v0.2.0 - (2026-09-19)

### Updated

- Like every base cartridge: a file the project has not moved is
  written as `phx.new` writes it, byte for byte (engine, mailer
  v0.3.0).

## v0.1.1 - (2026-08-30)

### Added

- A notice when the project has no html: `phx.new`'s `app.css` imports
  `phoenix-colocated/<app>/colocated.css`, which LiveView's compiler
  writes and html brings, so `mix assets.build` fails until html is in.
- The static placeholders `--no-tailwind` left in
  `priv/static/assets/` (`css/app.css`, `default.css`) are taken away
  by the insert when untouched (engine, mailer v0.2.0).

## v0.1.0 - (2026-08-30)

### Added

- `mix workbench.install.tailwind` (`wb.sh add tailwind`): tailwind — the dependency, heroicons, its configuration, the watcher and the assets aliases
  for a project generated with `--no-tailwind`, as the difference between
  the project generated with and without the flag
  (`WorkbenchIgniter.PhxDelta`).
