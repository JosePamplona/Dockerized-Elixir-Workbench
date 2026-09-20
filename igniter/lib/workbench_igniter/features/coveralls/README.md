# Cartridge: coveralls

Test coverage with ExCoveralls, the workbench HTML report and the
`mix cover` task.

* **Task**: `mix workbench.install.coveralls`
* **Inserted by**: `wb.sh add coveralls`
* **Options**: `--interface <i>` `[--theme <t>]` `[--exdoc]` `[--build]` — whether
  the project has html (the components folder to leave out) is read off
  the project.

## Description

Measures test coverage: when the test suite runs, it records which lines
of code were actually exercised and which were never touched, and turns
that into a percentage and a visual HTML report — which files are well
covered, and which have spots nobody is testing. Coverage doesn't prove
the code is correct, but it shows precisely where the tests aren't
looking.

That number becomes the project's quality gate. A minimum percentage is
agreed (80% by default), and if a run falls below it the check fails —
locally or in CI — flagging that code is being added without its safety
net before it accumulates. The report makes the conversation concrete:
instead of "we should test more", the team sees exactly which module needs
attention.

The cartridge also ties coverage into the project's documentation: the
`mix cover` task runs the suite and produces `TESTING.md` — execution
result board, coverage table and per-module sections in one report —
which the ExDoc feature publishes as a page of the documentation site. Test results stop being something only the person who
ran them sees and become part of what the project shows about itself.

## What it installs

* Dep `{:excoveralls, "~> 0.18", only: :test}`.
* `mix.exs`: `test_coverage: [tool: ExCoveralls]` and the
  `preferred_envs` (`cover`, `coveralls`,
  `coveralls.detail|post|html|cobertura` → `:test`).
* `coveralls.json`: output to the standard `cover/` dir (already
  gitignored by phx.new), report template path, minimum coverage and skip list
  (with `--interface rest` it skips the `open_api` files; without
  `--no-html` it skips the components folder).
* The chosen HTML report theme (`--theme`) under `assets/cover/template/`.
  Themes live in `priv/features/coveralls/assets/template/<theme>/`, one
  directory each with the
  three files excoveralls renders (`coverage.html.eex`, `_script.html.eex`,
  `_style.html.eex`); adding a theme is adding a directory:
  * `exdoc-ish` (default) — mimics the ExDoc pages: same layout, palette, light/dark
    theme (synced through ExDoc's own `ex_doc:settings` key), Lato and
    Remixicon picked up from `doc/dist/` when the docs are built, file
    filter, coverage vs. minimum target cards.
  * `custom` — the original workbench report.
* With `--exdoc`: composes `workbench.install.test_doubles --double
  mimic` and registers `File` in its own block of
  `test/test_helper.exs` — the task's tests read the report it would
  have written instead of writing it, and `File` is nobody's module to
  declare a behaviour for. They run `async: true`, which `mock`'s
  VM-wide replacement cost them. Plants the
  `mix cover` task (`lib/mix/tasks/cover.ex` + formatter + test) that
  generates `TESTING.md` for ExDoc, and gitignores it.

**Idempotency**: if `coveralls.json` already exists, notice and no-op.

## Options

* `--minimum-coverage` - Minimum percentage. Default: `80`.
* `--interface` - `rest` skips `open_api` files in the report. Default:
  `rest`.
* `--exdoc` - Install the `mix cover` task (ExDoc integration).
* `--theme` - Report theme: `exdoc-ish` | `custom`. Default:
  `exdoc-ish`.
* `--build` - Run the suite once the insert is applied, so the report
  has numbers. Off by default: it needs the dependencies compiled and,
  on a project with Ecto, a test database — the installer queues
  `ecto.create` and `ecto.migrate` before `mix cover`, but the compose
  must actually carry a database service (`./wb.sh bake`).

## Contents

Templates and assets live under `priv/features/coveralls/`:

| File | Role |
| --- | --- |
| `coveralls.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Coveralls` shell |
| `templates/coveralls_json.eex` | `coveralls.json` |
| `assets/template/<theme>/*.html.eex` | HTML report themes (verbatim: their `<%= %>` tags belong to the target project) |
| `assets/cover.ex` | `mix cover` task |
| `assets/formatter.ex` | The task's ExUnit formatter |
| `assets/cover_test.exs` | The task's unit test |

Cartridge test: `test/workbench_igniter/features/coveralls_test.exs`.
