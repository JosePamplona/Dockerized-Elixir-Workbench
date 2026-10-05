# Changelog — esbuild

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for it at the installer's
version, as [mailer](../mailer/CHANGELOG.md) says.

## v0.2.0 - (2026-09-19)

### Updated

- Like every base cartridge: a file the project has not moved is
  written as `phx.new` writes it, byte for byte (engine, mailer
  v0.3.0).

## v0.1.1 - (2026-08-30)

### Updated

- The static placeholder `--no-esbuild` left at
  `priv/static/assets/js/app.js` is taken away by the insert when
  untouched (engine, mailer v0.2.0).

## v0.1.0 - (2026-08-30)

### Added

- `mix workbench.install.esbuild` (`wb.sh add esbuild`): esbuild — the dependency, its configuration, the watcher and the assets aliases
  for a project generated with `--no-esbuild`, as the difference between
  the project generated with and without the flag
  (`WorkbenchIgniter.PhxDelta`).
