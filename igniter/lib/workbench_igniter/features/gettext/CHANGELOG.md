# Changelog — gettext

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for gettext at the installer's
version, as [mailer](../mailer/CHANGELOG.md) says.

## v0.1.0 - (2026-08-30)

### Added

- `mix workbench.install.gettext` (`wb.sh add gettext`): Phoenix's
  gettext for a project generated with `--no-gettext`, as the
  difference between the project generated with and without the flag
  (`WorkbenchIgniter.PhxDelta`).
