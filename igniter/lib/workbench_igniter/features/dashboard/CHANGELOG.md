# Changelog — dashboard

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for it at the installer's
version, as [mailer](../mailer/CHANGELOG.md) says.

## v0.2.0 - (2026-09-19)

### Updated

- Like every base cartridge: a file the project has not moved is
  written as `phx.new` writes it, byte for byte (engine, mailer
  v0.3.0).
- The engine (`WorkbenchIgniter.PhxDelta`) applies the router's change
  as operations on its pipelines, scopes and routes
  (`WorkbenchIgniter.RouterFile`), not as a text merge: a project that
  had appended a scope of its own at the router's end conflicted with
  the dev block dashboard opens there; the block now goes after the
  project's scope. Each item is known by what it is, not by its line;
  what the project changed stays as the project has it, with a notice;
  and when the operations cannot turn `phx.new`'s base into its theirs,
  the router is merged as text as before. [mailer](../mailer/DESIGN.md)
  §3.4, §4.6.

## v0.1.0 - (2026-08-30)

### Added

- `mix workbench.install.dashboard` (`wb.sh add dashboard`): liveDashboard — the dependency, the /dev/dashboard route and the live socket it rides on
  for a project generated with `--no-dashboard`, as the difference between
  the project generated with and without the flag
  (`WorkbenchIgniter.PhxDelta`).
