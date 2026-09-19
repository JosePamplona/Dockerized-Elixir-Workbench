# Changelog — gettext

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for gettext at the installer's
version, as [mailer](../mailer/CHANGELOG.md) says.

## v0.2.0 - (2026-09-19)

### Updated

- Like every base cartridge: a file the project has not moved is
  written as `phx.new` writes it, byte for byte (engine, mailer
  v0.3.0).

## v0.1.0 - (2026-08-30)

### Added

- `mix workbench.install.gettext` (`wb.sh add gettext`): Phoenix's
  gettext for a project generated with `--no-gettext`, as the
  difference between the project generated with and without the flag
  (`WorkbenchIgniter.PhxDelta`).
