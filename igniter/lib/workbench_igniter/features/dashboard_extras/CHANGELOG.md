# Changelog — dashboard_extras

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-09-18)

### Added

- LiveDashboard's two dark pages in one box, which were two: osmon
  (`:os_mon` in `extra_applications`, as it was) and psql_extras
  (v0.1.1 there). OS Data always; Ecto Stats by the extras of the
  database the project is on, read off its dependencies:
  `{:ecto_psql_extras, "~> 0.8"}`, `{:ecto_mysql_extras, "~> 0.6"}` or
  `{:ecto_sqlite3_extras, "~> 1.2"}`. MySQL and SQLite are new:
  psql_extras refused both.
- Shaped by the project, not refused for it: without a database, or on
  SQL Server — which LiveDashboard has no stats for — it installs OS
  Data alone and a notice says why. A second run adds what is missing
  (`rerun: :adds`), so a project that gains a database gets its page
  then.
- Builds on **dashboard** (`requires`), which neither of the two
  did: without LiveDashboard there is no page to light.
- Console doors: `os data` (`/dev/dashboard/os_mon`) and, with ecto in
  the project, `ecto stats` (`/dev/dashboard/ecto_stats`).

### Changed

- The extras carry no `only: :dev`, which psql_extras wrote: they go
  in every environment, as `phx.new` declares the dashboard itself, so
  a project that takes the dashboard to production finds the page lit
  there too. A dependency the project already declares is left as it
  is.
