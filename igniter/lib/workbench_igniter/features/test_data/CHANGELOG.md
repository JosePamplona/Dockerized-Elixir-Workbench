<!-- markdownlint-disable MD024 -->
# Changelog: test_data

The cartridge's own versions, over what it installs in a project —
independent of the workbench release that ships it.

## v0.1.1 - (2026-09-21)

### Fixed

- **It builds on ecto, and says so** (`requires/0`). It refused a
  project without ecto_sql from inside the installer, but the catalog
  did not carry it, so the console offered the box lit on a project it
  would refuse. An Ash project without Ecto is refused with the rest.

## v0.1.0 - (2026-09-20)

The first version of the cartridge's own record, under its new name: it
was `exmachina`, a box that added the dependency and nothing else.

### Changed

- **Named for the need, not the package**: `exmachina` becomes
  `test_data`, beside `test_doubles` — that one replaces a
  collaborator, this one builds the data. A project that took the old
  box is recognised by its `ex_machina` dependency, and a second run
  adds what it lacked.

### Added

- **Faker**, `{:faker, "~> 0.19", only: :test}`, for the values no test
  asserts on. A value drawn in the test process repeats under `mix test
  --seed`. No locale: `:es` covers four of Faker's modules and answers
  the rest in English.
- **The factory module**, `test/support/factory.ex`, `use
  ExMachina.Ecto, repo: <App>.Repo`, with no factories — the box cannot
  know the schemas — and the rules in its `@moduledoc`: defaults minimal
  and valid, unique columns by `sequence/2` and never Faker,
  associations by `build`, Faker for what nobody asserts. One commented
  factory shows each.
- **The factory test**, `test/<app>/factory_test.exs`: every
  `*_factory/0`, found by name, inserted inside the sandbox, so a factory
  the database refuses fails by its name. ExMachina never runs the
  schema's changeset; this is as far as a generic test can close that.
- **The test-helper lines** both READMEs ask for, in this cartridge's
  block of `test/test_helper.exs` before `ExUnit.start()`.
- **The Ash shape.** On a project with `ash`, ExMachina is not
  installed: it writes through the repo, under the actions. The box
  writes `test/support/generator.ex`, `use Ash.Generator`, with its rules
  and one commented `changeset_generator`, and Faker used lazily inside
  it, as Ash's documentation does.
- A project with neither Ecto nor Ash is refused, naming ecto.
- `DESIGN.md` and this file.
