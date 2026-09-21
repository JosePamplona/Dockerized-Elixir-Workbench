# Changelog — coveralls

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a change in the report or the task is a
minor, a change that breaks a project already carrying them is a major.

Backfilled at the version below, its first: the cartridge shipped
before a changelog was part of the anatomy, and gets one on its next
change, as the features index says.

## v0.3.0 - (2026-09-20)

### Added

- **`--githook`**: `mix coveralls` before every commit. The hook, the
  way it reaches `mix` inside the container and the checks that come
  with Elixir belong to the **precommit** cartridge, which this one
  composes when asked; what coverage adds is a block of
  `.githooks/pre-commit` belonging to this cartridge alone
  (`WorkbenchIgniter.BlockFile`), so credo's block and this one stand
  in the same file and either can be ejected without touching the
  other. Off by default, and the README says why: the suite with its
  instrumentation is the slowest thing a commit can wait for, and the
  place coverage is owed to a team is CI. The block is born **below the
  hook's divider**, after every check that can refuse a commit in a
  second: `mix coveralls` compiles the project and runs the suite
  instrumented, and nothing in the hook is slower.
- `state/1` says whether the line stands in the project's hook, and
  `DESIGN.md`, the paper the anatomy asks of a cartridge on its next
  change.

### Updated

- **A second run adds the hook block.** The insert was a no-op once
  `coveralls.json` existed, which turned `--githook` on a project that
  already had coveralls into a silent nothing: the flag was asked for
  and the notice said *skipping*. The json, the themes and the report
  are still fixed at the insert — they are the project's to edit
  afterwards — but the hook block is a piece the installer adds when it
  is missing, and the notice now says which of the two happened. The
  cartridge is `rerun: :adds`.

## v0.2.0 - (2026-09-20)

### Updated

- **The cover task's tests stand on Mimic, not Mock**, and run
  concurrently again. `Mix.Tasks.CoverTest` doubles `File.write!/2` to
  read the report it would have written; with `mock` that replacement
  was global to the VM, so the file was `use ExUnit.Case` without
  `async: true`. It is `use ExUnit.Case, async: true` and `use Mimic`
  now, five `with_mocks` blocks become five `stub(File, :write!, …)`
  calls, and the double lives in the process that asks for it.
- **It composes `test_doubles` with `--double mimic`** in place of
  `mock`, and registers `File` in **its own block** of
  `test/test_helper.exs` through `WorkbenchIgniter.BlockFile`, so
  another cartridge's copies can stand in the same file and either can
  be ejected without touching the other. `File` is nobody's module to
  declare a behaviour for, which is why this side of the box is Mimic's
  and not Mox's.

## v0.1.0 - (2026-08-30)

### Added

- ExCoveralls with the workbench's HTML report: the dependency, the
  `test_coverage` and `preferred_envs` entries in `mix.exs`, the
  `coveralls.json` (`--minimum-coverage`, and the paths left out of the
  report — `open_api` on `--interface graphql`, the components folder
  when the project has no html, read off the project), the report
  template of `--theme` (`exdoc-ish` | `custom`, one directory each
  under the cartridge's assets) and the `mix cover` task, which writes
  `TESTING.md` for the docs when exdoc is in.
- `--build`: runs the suite once the insert is applied, so the report
  has numbers before anyone opens it. Off by default and queued, not
  inline: `mix cover` needs the dependencies compiled and — on a
  project with Ecto, read off the project — a test database, which the
  queued `ecto.create`/`ecto.migrate` prepare and the workspace's
  compose must actually carry (`./wb.sh bake`). `afterwards/0` names
  the command for whoever leaves it off.
