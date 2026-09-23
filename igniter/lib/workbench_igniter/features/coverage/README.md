# Cartridge: coverage

Test coverage with ExCoveralls, the workbench HTML report and the
`mix cover` task.

* **Task**: `mix workbench.install.coverage`
* **Inserted by**: `wb.sh add coverage`
* **Requires**: nothing of itself; `--md-report` builds on
  [test_doubles](../test_doubles/) with Mimic, and `--githook` on
  [precommit](../precommit/).
* **Options**: `[--ignore-files <g,…>]` `[--minimum-coverage <n>]`
  `[--file-column-width <n>]` `[--theme <t>]` `[--md-report]` `[--githook]`

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

The cartridge also writes the report as **Markdown**: `mix cover`
(`--md-report`) runs the suite and produces `TESTING.md` at the
project's root — execution result board, coverage table and per-module
sections in one page — which any reader of the repository opens, and
which a documentation site lists if the project has one (that listing
is [exdoc](../exdoc/)'s `--coverage`, not this box's business). Test results stop being something only
the person who ran them sees and become part of what the project shows
about itself.

## What it installs

* Dep `{:excoveralls, "~> 0.18", only: :test}`.
* `mix.exs`: `test_coverage: [tool: ExCoveralls]` and the
  `preferred_envs` (`cover`, `coveralls`,
  `coveralls.detail|post|html|cobertura` → `:test`).
* `coveralls.json`: output to the standard `cover/` dir (already
  gitignored by phx.new), report template path, minimum coverage and
  the list of what the report leaves out (`--ignore-files`).
* The chosen HTML report theme (`--html-theme`) under `test/coverage/template/`
  — dev-tool source, kept out of `assets/`, the release build's input.
  Themes live in `priv/features/coverage/assets/template/<theme>/`, one
  directory each with the
  three files excoveralls renders (`coverage.html.eex`, `_script.html.eex`,
  `_style.html.eex`); adding a theme is adding a directory:
  * `custom` (default) — the workbench's own report.
  * `exdoc-ish` — mimics the ExDoc pages: same layout, palette, light/dark
    theme (synced through ExDoc's own `ex_doc:settings` key), Lato and
    Remixicon picked up from `doc/dist/` when the docs are built, file
    filter, coverage vs. minimum target cards.
* With `--md-report`: the `mix cover` task, its ExUnit formatter, their
  tests, `/TESTING.md` in `.gitignore` (the report is generated) and the
  page that waits at `TESTING.md` until the first run. It also registers
  `File` in its own block of
  `test/test_helper.exs` — the task's tests read the report it would
  have written instead of writing it, and `File` is nobody's module to
  declare a behaviour for. They run `async: true`, which `mock`'s
  VM-wide replacement cost them. Plants the
  `mix cover` task (`lib/mix/tasks/cover.ex` + formatter + test) that
  writes `TESTING.md`, the page that waits until it runs, and gitignores
  the report.

**Idempotency**: if `coveralls.json` already exists, notice and no-op —
except the hook block, which a second run adds when it is missing, so
`--githook` on a project that took coverage without it is honoured
instead of skipped along with the rest.

## Options

* `--minimum-coverage` - Minimum percentage, a whole number from 0 to
  100; anything else is refused. Default: `80`.
* `--file-column-width` - How wide the file column of the terminal
  table is, in characters (ExCoveralls' `file_column_width`), a whole
  number from 40 to 999. Default: `80`. A path longer than the column
  is cut, and with `--md-report` the `mix cover` task reads that table to
  build the report's own — so a cut path is a file the report loses. A
  project with deep module paths asks for more; ExCoveralls' own
  default is 40.
* `--ignore-files` - What the report leaves out, comma-separated. Each
  value is a group below or a path of your own, which is a regex
  excoveralls matches against each file's path
  (`--ignore-files boilerplate,lib/my_app/legacy`). `deps` and `test`
  go always. Default: `boilerplate,components`; `none` counts
  everything the project compiles.

  | Group | What it leaves out | Why |
  | --- | --- | --- |
  | `boilerplate` | `application.ex`, `release.ex`, `repo.ex`, `mailer.ex`, `<app>_web.ex`, `endpoint.ex`, `telemetry.ex`, `gettext.ex`, `router.ex`, `channels/user_socket.ex` | the wiring `phx.new` writes: no branch of it is a test's subject, and its uncovered lines are the same ones in every project |
  | `components` | `lib/<app>_web/components/` | the generated components and layouts — markup, and a lot of it |
  | `mix_tasks` | `lib/mix/tasks/` | the developer's own commands, which the app never runs |
  | `open_api` | `lib/<app>_web/open_api/` | a specification's modules: data, written out |
  | `none` | — | nothing: every file the project compiles is counted |

  **Only the paths the project has are written.** A group names files;
  the ones that are not there are left out of the file, so
  `coveralls.json` reads as the project it belongs to. A directory is
  written as asked, except `components`, which the project's own
  `components/layouts.ex` witnesses.
* `--html-theme` - The HTML report's theme: `custom` | `exdoc-ish`. Default: `custom`,
  the workbench's own report, which reads on its own wherever it is
  opened; `exdoc-ish` is for a project whose report is read inside a
  documentation site, where it blends in.
* `--md-report` - Install `mix cover`, the task that runs the suite and
  writes the report **as Markdown**: `TESTING.md` at the project's root,
  which any reader of the repository opens, and which a documentation
  site lists if it has one ([exdoc](../exdoc/)'s `--coverage` — whether
  the page is listed is that box's business, not this one's). The
  placeholder page goes in with the task, so there is something to open
  before the first run. Its own tests stand on a double of `File`, so it
  **builds on [test_doubles](../test_doubles/) with Mimic among its
  doubles**: insert that first (`./wb.sh add test_doubles`). Off by
  default.
* `--githook` - Run `mix coveralls` before every commit, in this
  cartridge's own block of `.githooks/pre-commit`. Builds on the
  **precommit** cartridge, which owns the hook: insert it first, the
  option refuses otherwise. Off by default: it is the suite plus
  its instrumentation, the slowest check a commit can wait for, and
  coverage's natural home is CI. Ejecting either box leaves the other's
  checks standing.
The insert runs nothing: `./wb.sh mix cover` (or `mix coveralls.html`
without `--md-report`) writes the report, and so does **build** on the
coverage door in the console. Either needs the database the suite
uses, which the deployment settles (`./wb.sh up`).

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/coverage/` | The cartridge: its code and its papers |
| `├── 📄 coverage.ex` | The dependency, `coveralls.json`, the report, `mix cover` |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why this tool, the two themes, the hook |
|  |  |
| `📁 priv/features/coverage/` | What it writes into the project |
| `├── 📁 templates/` |  |
| `│   └── 📄 coveralls_json.eex` | `coveralls.json` |
| `└── 📁 assets/` | Copied verbatim |
| `    ├── 📄 cover.ex` | The `mix cover` task (`--md-report`) |
| `    ├── 📄 formatter.ex` | The task's ExUnit formatter |
| `    ├── 📄 cover_test.exs` | The task's own test |
| `    ├── 📄 TESTING.md` | The report page until `mix cover` writes it |
| `    └── 📁 template/` | The HTML report, one directory per `--html-theme` |
| `        ├── 📁 custom/` | The workbench's own, the default |
| `        │   ├── 📄 coverage.html.eex` | The page (its `<%= %>` are the project's) |
| `        │   ├── 📄 _script.html.eex` | Its script |
| `        │   └── 📄 _style.html.eex` | Its style |
| `        └── 📁 exdoc-ish/` | ExDoc's look, for a report read in a site |
| `            ├── 📄 coverage.html.eex` | The page |
| `            ├── 📄 _script.html.eex` | Its script |
| `            └── 📄 _style.html.eex` | Its style |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 coverage_test.exs` | Its flags, the themes, `--githook` |
