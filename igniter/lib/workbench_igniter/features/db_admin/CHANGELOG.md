# Changelog — db_admin

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-09-18)

### Added

- One box for the database admin in the browser, the admin as its
  option: `--admin pgadmin,phpmyadmin,adminer,cloudbeaver`, one or
  several, a second run adding another. It takes over from `pgadmin`
  (v0.1.1) and `adminer` (v0.1.0), which leave the shelf: the same
  files in the project (`pgadmin/servers.json`, `adminer/login.php`),
  the same containers, so a project that has them reads as carrying
  this box.
- Each admin declares the databases it serves as a requirement on its
  value — `pgadmin` on postgres, `phpmyadmin` on mysql, `cloudbeaver`
  on postgres, mysql or mssql, `adminer` on any — read off ecto's
  `state/1`; one that does not serve the project's database refuses the
  run with what the project has. Without `--admin`, the one for the
  database: `pgadmin`, `phpmyadmin`, and `adminer` on mssql and
  sqlite3.
- **phpMyAdmin**: `phpmyadmin/config.user.inc.php` (signed in with
  ecto's MySQL credentials) and the `phpmyadmin` service, `phpmyadmin:5`
  with its Apache on 8081.
- **CloudBeaver**: `cloudbeaver/data-sources.json`, one connection with
  the place left to the environment, mounted as the seed of the
  server's workspace, and the `cloudbeaver` service on 8978, configured
  by variables: no setup wizard, the connection open without a sign-in.
