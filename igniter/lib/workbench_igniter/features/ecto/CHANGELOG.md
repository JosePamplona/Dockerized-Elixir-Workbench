# Changelog — ecto

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for Ecto at the installer's
version plus the `.env` entry, as [mailer](../mailer/CHANGELOG.md) says.

## v0.3.2 - (2026-10-06)

### Fixed

- A project on SQLite has no scaled deployment, and that is no longer
  an error. `compose/1` answered `{:error, …}` for `sqlite` on the
  scaled deployment, which is what it answers for a set of services
  that is wrong; since the three compose files are baked at a
  project's birth (2026-09-27), that error stopped
  `./wb.sh new --database sqlite3` altogether. It answers
  `{:unavailable, reason}` now: the project is born with its dev and
  prod files and a note, a scaled file baked before the insert is
  removed in the insert's commit, and `bake --deploy scaled`, the
  status and the console give the reason — each replica would keep its
  own database file, so what a request reads depends on the replica
  that answers it (DESIGN §3.5, with what was considered and left out).

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
