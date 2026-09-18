# Changelog — versioning

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.2.0 - (2026-09-17)

### Added

- `--task`: the `mix version NEW` task and its test, moved here from
  enhancements, where it was a lodger — the version is this cartridge's
  decision, and the task is that decision's tool. Rewritten for a stock
  project: it writes the number into `mix.exs`, closes the changelog's
  `Unreleased` as that version under the commented template line this
  cartridge's changelog keeps for it, and updates the README's badge
  only when there is one. It used to fail on any README without a
  badge, since the retired setup's README template always had one. Its
  test runs in a directory of its own instead of mocking `File`.
- `--readme-badge`: the shields.io version badge under the README's
  title, at the version the project has.
- `rerun: :adds`: a second run adds the task or the badge when asked and
  missing, and still never moves the version. `state/1` reads the two
  back.

## v0.1.0 - (2026-08-30)

### Added

- The `version:` of `mix.exs` (`--version`, default `0.0.0`) and the
  `CHANGELOG.md` opened at it, both rescued from the retired
  `workbench.setup`: they were its `INIT_VERSION` and its
  `changelog.eex` template, which travelled with it.
- `state/1` reading back the version `mix.exs` declares.
