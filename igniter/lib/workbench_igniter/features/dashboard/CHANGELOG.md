# Changelog — dashboard

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for it at the installer's
version, as [mailer](../mailer/CHANGELOG.md) says.

## v0.1.0 - (2026-08-30)

### Added

- `mix workbench.install.dashboard` (`wb.sh add dashboard`): liveDashboard — the dependency, the /dev/dashboard route and the live socket it rides on
  for a project generated with `--no-dashboard`, as the difference between
  the project generated with and without the flag
  (`WorkbenchIgniter.PhxDelta`).
