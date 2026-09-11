# Changelog — adminer

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-09-09)

### Added

- `adminer/login-servers.php`, the one server Adminer opens with — the
  workspace's database: driver and user off the project's adapter,
  where it is and which database off the compose — and
  `adminer/password.php`, the password Adminer verifies itself and
  never sends on; the `adminer` service declared for `mix
  workbench.compose`, on every adapter. The à-la-carte counterpart of
  pgadmin, as healthcheck2 is of healthcheck.
