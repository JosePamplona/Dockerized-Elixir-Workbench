# Changelog — ecto

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for Ecto at the installer's
version plus the `.env` entry, as [mailer](../mailer/CHANGELOG.md) says.

## v0.3.1 - (2026-09-25)

### Fixed

- The line after the insert, the task's doc and the README say what
  happens: `wb.sh add` bakes the database server into the compose in
  the insert's own commit, and the app container's `mix setup` creates
  the database at the next `./wb.sh up`. They sent the reader to a
  `./wb.sh setup` that `wb.sh` never had, and the README to a separate
  `./wb.sh bake`.

## v0.3.0 - (2026-09-19)

### Updated

- Like every base cartridge: a file the project has not moved is
  written as `phx.new` writes it, byte for byte (engine, mailer
  v0.3.0).

## v0.2.0 - (2026-08-30)

### Added

- `--binary-id`: `phx.new`'s flag of the same name, which only Ecto
  reads — the `generators` entry of `config.exs` — so it is this
  cartridge's option, not a generation one.

## v0.1.0 - (2026-08-30)

### Added

- `mix workbench.install.ecto [--database postgres|mysql|mssql|sqlite3]`
  (`wb.sh add ecto`): Phoenix's Ecto for a project generated with
  `--no-ecto`, as the difference between the project generated with and
  without the flag, for the chosen database (`WorkbenchIgniter.PhxDelta`),
  plus `DATABASE_URL` — `DATABASE_PATH` for SQLite — in `.env` and
  `.env.sample`.
