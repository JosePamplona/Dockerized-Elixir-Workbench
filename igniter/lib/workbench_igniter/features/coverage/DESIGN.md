# coverage — Design

Revision: cartridge v0.3.0 (2026-09-20)

## Abstract

Coverage for a workbench project: the ExCoveralls dependency, a
`coveralls.json` the project owns, an HTML report the cartridge plants
as a *template* in the project's own tree, a `mix cover` task that folds
the numbers into the documentation, and — with `--githook` — the suite
run before every commit.

Four decisions carried the box, and each had a live alternative. The
first is why a dependency at all, when Elixir has had line coverage
built in for years. The second is that the report is planted as source
the project may edit, in one of two themes, instead of being served from
the cartridge. The third is that what is left out of the report is
*read off the project* rather than asked. The fourth is where the
pre-commit line lives, which is the same answer credo's box gives from
the other side.

## 1. Problem

A project's suite says that what is tested passes. It says nothing about
what is not tested, and that silence grows quietly: a module goes in
without its tests, then a second, and by the time anybody looks the
question is no longer "what shall we test next" but "where do we even
start".

The workbench's job here is narrow. It is not to make the project's
tests better; it is to make the gap visible, in a form a reviewer can
open and a pipeline can refuse, without the project having to invent the
plumbing each time.

## 2. Background

**Elixir already measures coverage.** `mix test --cover` is built in:
"Elixir provides built-in line-based test coverage via the `--cover`
flag. The test coverages shows which lines of code and in which files
were executed" [1]. It is configured through `:test_coverage`, whose
`:summary` option "allows you to customize the summary generation and
defaults to `[threshold: 90]`" and where "the task will exit with status
of 1 if the total coverage is below the threshold" [1]. "By default, a
wrapper around OTP's `cover` is used as the default coverage tool", and
`:tool` takes "a module specifying the coverage tool to use" — "any
module that exports `start/2`" [1].

So the platform gives a percentage per module in the terminal, a
threshold, and a non-zero exit below it. What it does not give is a
report anybody outside the terminal can read.

**ExCoveralls is such a tool module.** 0.18.1 (parroty, read 2026-09-20
from `deps/excoveralls` in the workspace): "An Elixir library that
reports test coverage statistics, with the option to post to
coveralls.io service. It uses Erlang's cover to generate coverage
information" [2]. It plugs into the platform's own seam —
`test_coverage: [tool: ExCoveralls]` — so it is not a second coverage
engine, it is the same OTP `cover` with reports on top: HTML, JSON, XML,
Cobertura and lcov, each written to `cover/` "however, the path can be
specified by overwriting the `output_dir` coverage option" [2].

Three of its settings decide this cartridge's shape:

* **`template_path`** — "Custom reports can be created and utilized by
  defining `template_path` in `coveralls.json`. This directory should
  [hold the templates]" [2], defaulting "to the htmlcov report in the
  excoveralls lib" [2]. The HTML report is `.eex` the project can own.
* **`minimum_coverage`** — "When set to a number greater than 0, this
  setting causes the `mix coveralls` and `mix coveralls.html` tasks to
  exit with a status code of 1 if test coverage falls below the
  specified threshold (defaults to 0)" [2]. In the source the refusal is
  unconditional: `if result.coverage < minimum_coverage` it prints
  `"FAILED: Expected minimum coverage of …%, got …%."` and calls
  `exit({:shutdown, 1})` [3].
* **`skip_files`** — "If you want to exclude/ignore files from the
  coverage calculation add the `skip_files` key in the `coveralls.json`
  file. `skip_files` takes an array of file paths" [2].

**Where the two sources disagree** is the threshold's default, and it
matters because a project gets whichever one is written down: Mix's
`:summary` threshold is 90 and only colours and exits; ExCoveralls'
`minimum_coverage` is 0 — off — until the project sets it. Neither
number is a recommendation anybody defends; 80 is this cartridge's, and
§3 says why it is not 90.

## 3. Design

**ExCoveralls, and not the built-in `--cover`.** The platform's coverage
is a terminal summary. This box exists for the two things a summary
cannot be: a page a reviewer opens on a link, and a file a pipeline
keeps. `mix test --cover` would answer the *measurement* and leave the
report to be written by hand in every project the workbench makes, which
is exactly the plumbing a cartridge is for. The dependency is
`{:excoveralls, "~> 0.18", only: :test}`, and `test_coverage: [tool:
ExCoveralls]` with the coveralls tasks' `preferred_envs` in `mix.exs`:
the seam is the platform's own, so nothing here replaces `mix test`.

**`minimum_coverage: 80`, not 90 and not 0.** ExCoveralls' own default,
0, means the gate is off and the project has to discover the setting
exists. Mix's 90 is a number a project that already has tests can pass
and a project starting out cannot, and a gate that refuses from the
first day is a gate turned off on the second — the same argument credo's
box makes for `mix credo` over `mix credo --strict`. 80 is written into
`coveralls.json`, which is the project's file: raising it is editing one
number in the project's own tree, and the cartridge never rewrites it
(§"a second run", below).

**The report is planted, in one of two themes.** The cartridge writes
the `.eex` templates into `assets/cover/template/` and points
`template_path` at them, instead of leaving ExCoveralls' bundled report
in place. The reason is ownership: a report is a page with the project's
name on it, and the templates are `.eex` whose tags belong to the target
project, so they are planted verbatim. Two themes, one directory each:
`exdoc-ish`, the default, which mimics the ExDoc pages — sidebar,
light/dark, the same fonts — so the report reads as one more page of the
project's documentation; and `custom`, the original workbench report,
kept because it was the box's only face before the docs existed and a
project already carrying it should not be told its report is wrong.
Adding a theme is adding a directory: `@themes` is the directory
listing, `--theme` validates against it, and `themes/0` is what the
console offers. The rejected alternative was one theme — the argument
for it is that two faces is two things to maintain, and the answer is
that the second is three files of `.eex` nobody has had to touch since
the first, while the project that chose it would have had its report
changed under it by an upgrade.

**What is left out of the report is read, not asked.** `skip_files`
always drops `deps` and `test`; the two that vary are the API interface
folder and the components folder, and both are facts about the project:
`--interface graphql` means the `open_api` directory is not there to
skip, and whether the project has html is read off it
(`WorkbenchIgniter.PhxDelta.facts/1`), never asked. This is the "no
contract back" rule applied to an option: the workbench reads what the
project has instead of asking the project to declare it.

**`"file_column_width": 128`**, which looks like a cosmetic setting and
is not. The `mix cover` task parses the coverage rows out of the
terminal output to build its table; ExCoveralls' default column truncates
long paths, and a truncated path is a row the parser cannot match to a
file. The width is a consequence of the task, and the suite asserts it
so a later tidy-up does not quietly break the report.

**`mix cover` is a task in the project, not in the workbench.** With
`--exdoc` the cartridge plants `lib/mix/tasks/cover.ex`, an ExUnit
formatter and their tests, and the task writes `TESTING.md` — execution
board, coverage table, per-module sections — for ExDoc to serve. It
belongs in the project because the person who runs it is the project's
developer, in the project's container, and because the report is
generated output: `TESTING.md` is gitignored, the task is source. The
alternative — the workbench generating the report from outside — needs
the workbench to know the project's suite, which is the contract the
workbench does not ask for.

**The task's tests double `File` with Mimic.** They read the report the
task would have written instead of writing it. `mock` did that
VM-wide, which cost the file `async: true`; Mimic's double lives in the
process that asks for it, so the tests are concurrent again. The
cartridge composes `test_doubles --double mimic` and registers `File` in
**its own block** of `test/test_helper.exs` (`WorkbenchIgniter.BlockFile`),
so another cartridge's copies stand in the same file untouched. Not
Mox: `File` is nobody's module to declare a behaviour for, and Mox wants
a behaviour and an injected module.

**`--githook` writes in a file this cartridge does not own.** The
pre-commit hook, `.githooks/pre-commit`, is the **precommit** cartridge's:
it carries the crossing into the container, the checks that come with
Elixir, and the skeleton. This cartridge composes that installer and
calls `Precommit.check/4`, which hands it a delimited block of its own.
Three properties follow, and they are why the option is here rather than
in a box that would have to know about every tool: the block is this
cartridge's to write and to take away, `state/1` reads it back without
parsing anybody else's lines, and credo's block stands in the same file
untouched.

Two details of the line are decisions of their own:

* **Off by default.** `mix coveralls` compiles the project and runs the
  whole suite instrumented — the slowest thing a commit can wait for —
  and the place a team is owed coverage is CI, which sees every branch
  and not only the one being committed. The developer who wants it
  before the commit asks for it.
* **Below the divider.** `Precommit.check/4` takes `:stage`, and this
  block is born `:slow`, after every check that can refuse a commit in a
  second. The stage only decides where a block is *born*: a project that
  moves it meant to, and the block is replaced where it stands.

**A second run adds the hook block, and nothing else.** The insert is a
no-op once `coveralls.json` exists — the json, the themes and the report
are the project's to edit afterwards, and re-running must not undo an
edit. But the hook block is not like them: it is a piece the installer
adds when it is missing, so `--githook` on a project that already took
coverage writes the block and the notice says which of the two
happened. The cartridge is `rerun: :adds`. The rejected alternative is
what the box did until this revision: skip the whole install, notice
`skipping`, and leave a developer who asked for a hook with no hook and
no error — a silent nothing, which is the worst of the three answers.
The other alternative, eject and insert again, costs the project its
edited `coveralls.json` and its report template for the sake of one
line.

**`--build` is queued, not inline.** Running the suite once at insert
time is what gives the report numbers before anyone opens it, but `mix
cover` needs the dependencies compiled and, on a project with Ecto, a
test database — so the installer queues `ecto.create`, `ecto.migrate`
and `mix cover` rather than running them inside the patch set, and the
workspace's compose must actually carry a database (`./wb.sh bake`).
Off by default, and `afterwards/0` names the command for whoever leaves
it off. Its `state/1` value is `nil` on purpose: the option is a one-shot
action whose output is gitignored, so the project keeps no mark of it,
and `nil` says so instead of guessing.

## 4. Evaluation

Verified in the cartridge's suite: the dependency and the `mix.exs`
entries; `coveralls.json` with its defaults, its output dir, its
template path and the two `skip_files` entries that vary; the untruncated
column width; both themes planted from their directories and an unknown
theme refused; `--exdoc` planting the task, its formatter, its tests,
the Mimic dependency and the cartridge's block of the test helper, with
`TESTING.md` gitignored; the no-op notice on a second run; the recipe
`chiefs_setup` composes it with. For `--githook`: the precommit cartridge
coming with it, the block and its line, the block being born below the
divider, `state/1` saying it back, a second run adding it to a project
installed without it, and an eject leaving credo's block and the box's
own checks standing.

Not measured: **how long `mix coveralls` adds to a commit**. It is
argued from what it does — compile the project, run the suite under
OTP's `cover` — and not timed, which is exactly why the option is off
by default rather than on with a caveat. Also not measured: the report's
two themes side by side on a real project's numbers; the choice between
them was made on how the page reads beside the ExDoc pages, not on a
measurement.

## 5. Limitations and open questions

* **Nothing is posted anywhere.** ExCoveralls' reason for existing, per
  its own first line, is the option to post to coveralls.io [2], and
  this cartridge installs none of it: no token, no `coveralls.post`
  configuration. The service needs an account, which a portfolio
  project cannot have, and the local HTML report is what a reader
  actually opens. The `preferred_envs` entry for `coveralls.post` is
  there so the task runs in `:test` if a project ever wants it; the
  wiring is the project's.
* **Umbrella projects are outside the box.** `skip_files` "doesn't work
  directly in an umbrella project. If you need to exclude files within
  an app, you should create a separate `coveralls.json` at the root of
  the app's folder" [2]. The workbench makes single-app projects, so the
  cartridge writes one `coveralls.json` at the root and says nothing
  about umbrellas.
* **The threshold is one number for the whole project**, which is what
  ExCoveralls offers; there is no per-module minimum, so a project with
  one well-tested half sits above the line while the other half is
  untested. The report is what shows that, and the gate cannot.
* **Open: the hook's cost.** If `mix coveralls` before a commit turns
  out to be minutes rather than seconds on a real project, the honest
  answer may be that the option should not exist and CI is the only
  place for it. That is a measurement nobody has taken (§4).

## References

1. `mix test` — `:test_coverage`, `--cover` and the "Coverage" section,
   Elixir 1.19.5, read 2026-09-20 from
   `lib/mix/lib/mix/tasks/test.ex` in the toolchain's install.
2. ExCoveralls 0.18.1 — README: settings, coverage options,
   `skip_files`, the report tasks. Read 2026-09-20 from the copy in
   `_workspaces/pitchers/deps/excoveralls`.
3. ExCoveralls 0.18.1 — `lib/excoveralls/stats.ex`,
   `ensure_minimum_coverage/1` and `check_coverage_threshold/2`: the
   message and the `exit({:shutdown, 1})`. Same copy, same date.
4. `WorkbenchIgniter.Features.Precommit` — the hook, its stages and
   `check/4`; its DESIGN.md carries the crossing into the container.
5. `WorkbenchIgniter.Features.Credo` — the same option from the other
   side, and the argument for a line that passes on the first commit.
