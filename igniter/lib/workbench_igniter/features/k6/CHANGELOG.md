# Changelog — k6

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-09-06)

### Added

- `k6/smoke.js`, a smoke test to start from, and the `k6` service
  declared for `mix workbench.compose` — `grafana/k6` under a compose
  profile `up` never starts, `BASE_URL` set per topology, run by
  `./wb.sh k6` (scripts/PLAN.md, step 3).
