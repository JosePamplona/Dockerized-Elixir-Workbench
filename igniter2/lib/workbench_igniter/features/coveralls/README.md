# Cartridge: coveralls

Test coverage with ExCoveralls, the workbench HTML report and the
`mix cover` task.

* **Task**: `mix workbench.install.coveralls`
* **Enabled by**: `--coveralls` (config.conf: `COVERALLS`)
* **Argv from setup**: `--interface <i>` `[--exdoc]` `[--no-html]`

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
`mix cover` task runs the suite and produces `COVERAGE.md` and
`TESTING.md`, which the ExDoc feature publishes as pages of the
documentation site. Test results stop being something only the person who
ran them sees and become part of what the project shows about itself.

## What it installs

* Dep `{:excoveralls, "~> 0.18", only: :test}`.
* `mix.exs`: `test_coverage: [tool: ExCoveralls]` and the
  `preferred_envs` (`cover`, `coveralls`,
  `coveralls.detail|post|html|cobertura` → `:test`).
* `coveralls.json`: output to the standard `cover/` dir (already
  gitignored by phx.new), custom template, minimum coverage and skip list
  (with `--interface rest` it skips the `open_api` files; without
  `--no-html` it skips the components folder).
* The custom HTML report template under `assets/cover/template/`.
* With `--exdoc`: composes `workbench.install.mock`, plants the
  `mix cover` task (`lib/mix/tasks/cover.ex` + formatter + test) that
  generates `COVERAGE.md`/`TESTING.md` for ExDoc, and gitignores them.

**Idempotency**: if `coveralls.json` already exists, notice and no-op.

## Options

* `--minimum-coverage` - Minimum percentage. Default: `80`.
* `--interface` - `rest` skips `open_api` files in the report. Default:
  `rest`.
* `--no-html` - The project was created with `--no-html`.
* `--exdoc` - Install the `mix cover` task (ExDoc integration).

## Contents

| File | Role |
| --- | --- |
| `coveralls.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Coveralls` shell |
| `templates/coveralls_json.eex` | `coveralls.json` |
| `assets/template/*.html.eex` | HTML report template (verbatim: its `<%= %>` tags belong to the target project) |
| `assets/cover.ex.asset` | `mix cover` task (`.asset` suffix keeps mix from compiling it here) |
| `assets/formatter.ex.asset` | The task's ExUnit formatter |
| `assets/cover_test.exs` | The task's unit test |

Cartridge test: `test/workbench_igniter/features/coveralls_test.exs`.
