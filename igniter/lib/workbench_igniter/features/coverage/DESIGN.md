# coverage — Design

Revision: cartridge v0.11.0 (2026-09-25)

## Abstract

Coverage for a workbench project: the ExCoveralls dependency, a
`coveralls.json` the project owns, and two reports — the HTML one
ExCoveralls renders, its own or from a theme this box plants in the
project's own tree, and, with `--md-report`, the Markdown one `mix cover` writes
at the project's root for whoever reads the repository. With
`--githook`, the suite runs before every commit.

Five decisions carried the box, and each had a live alternative. The
first is why a dependency at all, when Elixir has had line coverage
built in for years. The second is that the HTML report is the tool's own
unless a theme is asked for, and a theme is planted as source the
project may edit instead of being served from the cartridge. The third is that what the report leaves out
is *asked*, in groups the box knows and can read back, and that only
the paths the project actually has are written. The fourth is that the
Markdown report is named and owned here — the option says what it
writes (`--md-report`), not who reads it, and the page it leaves is
this box's file — while whether a documentation site *lists* that page
belongs to the site. The fifth is where the pre-commit line lives,
which is the same answer credo's box gives from the other side.

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

**The library is dormant, and that is a fact of the choice.** Its last
release is 0.18.5 of 2025-01-26, and its repository's last commit is
the same day: about twenty months of silence when this was checked
against hex.pm on 2026-09-23 [6]. The pin `~> 0.18` is therefore
current and likely to stay current for the wrong reason. It does not
change the decision — the library works, its output is a file the
project owns, and nothing here depends on it growing — but it is why
§5 keeps the exit written down: what the box installs of it is a
dependency, a `coveralls.json` and a template, and a project that ever
had to leave would keep all three as its own files.

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
is a terminal summary — and it has grown: `:test_coverage` today takes
`:summary` with its `:threshold`, `:ignore_modules`, `:export` and
`:output` [1], which is the gate and the exclusion list this box also
writes. The overlap is real and worth saying plainly. What the
platform still does not give is the two things a summary cannot be: a
page a reviewer opens on a link, and a file a pipeline keeps. `mix test --cover` would answer the *measurement* and leave the
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

**The templates live under `test/`, not `assets/`.** Until v0.4.0 they
were planted under `assets/cover/template/`, and in a Phoenix
application `assets/` is the release build's input: the Dockerfile
`phx.gen.release` writes copies it into the builder stage, and tailwind
scans it for classes. The templates are a dev tool's source and reach
neither the release nor the pages it serves. `test/` is the place with
all three properties they need: the same generator's `.dockerignore`
leaves `/test/` out of the build's context; nothing compiles there but
`test/support` (`elixirc_paths(:test)`), and `mix test` loads only
`*_test.exs`; and a formatter reading `{config,lib,test}/**/*.{ex,exs}`
never opens an `.eex`. It is also what the templates are about: the
suite's report. Rejected: `.dockerignore` alone, which hides them from
Docker and not from tailwind; and a directory at the root, one more
for a reader to learn, where `test/` already says what it holds.
`state/1` reads the theme wherever `coveralls.json`'s `template_path`
points, so an older project, or one that moved them, still says it.

**A theme is planted; the default is none** (v0.11.0). With a theme, the
cartridge writes the `.eex` templates into `test/coverage/template/` and
points `template_path` at them. The reason is ownership: a report is a
page with the project's name on it, and the templates are `.eex` whose
tags belong to the target project, so they are planted verbatim. The
default, `default`, plants nothing and writes no `template_path`: the
report is ExCoveralls' own, as its author wrote it, and the project
carries no templates it did not ask for. Two themes, one directory each:
`custom`, the original workbench report, which reads on its own
wherever it is opened; and `exdoc-ish`, which
mimics the ExDoc pages — sidebar, light/dark, the same fonts — so the
report reads as one more page of the project's documentation.
Adding a theme is adding a directory: `@themes` is `default` and the
directory listing, `--html-theme` validates against it, and `themes/0` is what the
console offers. The rejected alternative was one theme — the argument
for it is that two faces is two things to maintain, and the answer is
that the second is three files of `.eex` nobody has had to touch since
the first, while the project that chose it would have had its report
changed under it by an upgrade.

**What the report leaves out is a decision, in groups** (v0.6.0).
Until then it was read, and through the wrong question: `--interface
rest|graphql` decided one entry of `skip_files` — the `open_api`
folder — and the components folder came off whether the project had
html. That made the box reason about an API it does not install, and
it left the reader nothing to say about the rest of the report: a
project that wanted its Mix tasks or a legacy directory out had to
edit `coveralls.json` by hand, and the box would then report a state
it did not recognise.

`--ignore-files` is the option instead, comma-separated, each value a
**group** the box knows or a path of the reader's own. The groups come
from reading what Elixir projects actually skip [6][7][8]: the
dependencies and the tests themselves, the wiring
`phx.new` writes and no test asserts (`application.ex`, `<app>_web.ex`,
`endpoint.ex`, `telemetry.ex`, `gettext.ex`, `repo.ex`, `mailer.ex`,
`release.ex`, `router.ex`, `channels/user_socket.ex`), the generated
components, the project's own Mix tasks and an API specification's
modules. They are groups and not a list of paths because the reader
picks by *reason* — "the wiring", "the generated components" — and the
paths behind each are the box's to keep current with `phx.new`.

Three rules keep it honest:

* **`deps` and `test` are groups like the rest** (v0.11.0). Neither is
  the project's code under test, and no project wants them counted, so
  both are in the default; until then they were written always and were
  not options, which made the form's note about them the one thing it
  said that was not about `coveralls.json`.
* **Only the paths the project has are written.** A group names ten
  files; a project without a socket or a mailer gets neither line, so
  `coveralls.json` reads as the project it belongs to instead of as a
  template. A directory cannot be tested for existence the same way, so
  it is written as asked, except `components`, whose
  `components/layouts.ex` witnesses it — the reading of the project
  that `--interface` used to do badly, kept where it belongs.
* **The list is closed** (v0.10.0). It took a path of the reader's own
  too, written as given — a fifth kind of value the form had to offer
  as a free text field beside the four groups, and one the box could
  neither check nor explain: `skip_files` entries are regexes [2], and
  a regex the box did not write is a regex it cannot say anything
  about. What the box offers is what it knows how to build and read
  back; a project that wants another path out of the report edits its
  own `coveralls.json`, which is its file, and `state/1` still reads
  that path back as the path it is — the reading of the project, which
  never depended on the option.

**What is not a group**, and why: `priv/repo/migrations`, which several
projects list [7]. Migrations are compiled by `Ecto.Migrator` while
`mix test`'s alias runs, before `cover` starts, so they are not in the
report to begin with; a group for them would be a line that never does
anything. A reader who does see them names the path, which is the
escape hatch working as intended. Nor is `test/support`: the blanket
`test` entry already covers it.

**An empty answer is the default** (v0.11.0). Igniter hands a `:csv`
option nobody answered as `[]`, which is also what an empty answer
looks like, so the default (`deps,test,boilerplate,components`) cannot
be told from an explicit "skip nothing" in the parsed options. Until
v0.11.0 `none` was the value that said it; it went with `deps` and
`test` becoming groups, since counting the dependencies and the tests
is a report no project wants. A project that does edits its own
`coveralls.json`.

**`file_column_width` is an option, and not a cosmetic one** (v0.7.0).
The `mix cover` task parses the coverage rows out of the terminal
output to build its table; a path wider than the column is cut, and a
cut path is a row the parser cannot match to a file — the report loses
it. ExCoveralls' own default, 40, cuts almost every Phoenix path; the
box wrote 128 always, which never cuts and makes a wide terminal the
price. The default is **80** now, which holds a stock project's
longest paths (`lib/<app>_web/components/core_components.ex` is in the
fifties), and the projects whose modules sit deeper say so with
`--file-column-width`. The shape is declared (`{:integer, 40..999}`),
so a value that is not a width is refused before the file is written,
and below 40 there is nothing to gain over the tool's own default. The
suite asserts both ends, so a later tidy-up does not quietly break the
report.

**The option is named for what it writes, not for who reads it**
(v0.9.0). It was `--exdoc`, which named another box — the one rule a
cartridge's papers keep, *a cartridge never names the boxes that pick
it*, broken in the one place a reader looks first. What the flag plants
is a task that writes the report **as Markdown**, so it is
`--md-report`: `TESTING.md` at the project's root, which any reader of
the repository opens, whether or not the project has a documentation
site. Whether that page is *listed* in a site is the site's business,
and exdoc's `--coverage` decides it — reading the file, live when it is
there and commented out when it is not, the way it reads the README.
The page that waits until the first run moved here with the same
argument: the file is this box's, so the box that owns it plants it.

**The default theme is ExCoveralls' own** (v0.11.0). From v0.9.0 to
v0.11.0 it was `custom`, and before that `exdoc-ish`. The two themes are not
better and worse but *for* different places: `custom` is the
workbench's own report, which reads on its own wherever it is opened,
and `exdoc-ish` mimics the ExDoc pages so a report read inside a
documentation site blends into it. `exdoc-ish` was the default while
the box assumed the report would be read in that site — the same
assumption `--exdoc` carried in its name. A box that does not know
whether the project has a site defaults to the report that needs none
— and a box that installs a tool installs it as its author wrote it,
so the report that needs nothing planted is the tool's own.

**`mix cover` is a task in the project, not in the workbench.** With
`--md-report` the cartridge plants `lib/mix/tasks/cover.ex`, an ExUnit
formatter and their tests, and the task writes `TESTING.md` — execution
board, coverage table, per-module sections — for ExDoc's site, where it
links the HTML report by a relative path (exdoc copies the coverage
output dir into the site's root, so both sit side by side wherever the
site is served; until v0.4.0 the links named exdoc's `/dev/docs`
routes). It belongs in the project because the person who runs it is the
project's developer, in the project's container, and because the report
is generated output: `TESTING.md` is gitignored, the task is source. The
alternative — the workbench generating the report from outside — needs
the workbench to know the project's suite, which is the contract the
workbench does not ask for.

**The task's tests double `File` with Mimic.** They read the report the
task would have written instead of writing it. `mock` did that
VM-wide, which cost the file `async: true`; Mimic's double lives in the
process that asks for it, so the tests are concurrent again. The
doubles are **test_doubles' box**, and since v0.8.0 the option builds on
it instead of inserting it: `--md-report` carries
`{"test_doubles", double: "mimic"}` as its requirement, so a project
without that box — or with Mox alone — is told which box and which
double, and the insert makes no commit. The same move `--githook` made
onto precommit (v0.4.0), for the same three reasons: one insert is one
cartridge and one commit, so nothing rides inside another box's; the
choice of doubling library is the reader's and belongs to the box whose
option it is; and what a project carries of a box is then that box's to
report, not something to infer from who composed whom. What this
cartridge does keep is the registration — `File` in **its own block** of
`test/test_helper.exs` (`WorkbenchIgniter.BlockFile`), through
`TestDoubles.copy/4` — so another cartridge's copies stand in the same
file untouched. Not Mox: `File` is nobody's module to declare a
behaviour for, and Mox wants a behaviour and an injected module.

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

**The insert does not run the suite** (v0.5.0). `--build` queued
`ecto.create`, `ecto.migrate` and `mix cover` behind the patch set, to
give the report numbers before anyone opened it. Two things were wrong
with hanging it on the insert: the run needs a database the workspace's
compose may not carry yet (`./wb.sh bake` first), and its output went
into an insert's log, which nobody reads for a coverage number. The
console's coverage door runs the same command as a job instead — `mix
cover` where `--md-report` planted it, `mix coveralls.html` otherwise
(`build:`) — and `afterwards/0` names it for the shell. The option also
left no mark for `state/1` to read, which is what an option that is a
one-shot action always does.

## 4. Evaluation

Verified in the cartridge's suite, option by option and both ways:
the dependency and the `mix.exs` entries; `coveralls.json` with its
defaults, its output dir and its template path; the minimum given, the
minimum unasked and a minimum that is not a whole percentage refused;
the file column given, unasked and refused outside 40..999; each group
of `--ignore-files` written with only the paths the project has, `deps` and
`test` read back by name, a value that is not a group refused, and the state
read back — groups as groups, and a path the project added to its own
`coveralls.json` as the path it is; no template planted by default,
both themes planted from their directories and an unknown theme refused; `--md-report` planting the
task, its formatter, its tests, the page that waits and the block of
the test helper, with `TESTING.md` gitignored — and, without it, none
of that and no doubles asked for; the refusal when test_doubles is not
in, or is in without Mimic; a second run planting the task the first
left out; the no-op notice; the recipe `chiefs_setup` composes it
with. For `--githook`: the precommit cartridge
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
* **The library has not shipped since January 2025.** Nothing here
  depends on it changing, and its output is the project's own file, so
  the exit is cheap if one is ever needed: the project keeps its
  `coveralls.json`, its template and its `mix cover` task, and what
  changes is the tool that reads them. Elixir's own `:test_coverage`
  has meanwhile grown a threshold and an `:ignore_modules` (§3), which
  is where that exit would begin.
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
6. ExCoveralls — README, `skip_files`: "Path should contain a string
   that can be compiled to Elixir regex", matched against the file's
   path; the default `coveralls.json` shipped in
   `lib/conf/coveralls.json` carries no `skip_files` at all, and its
   `file_column_width` is 40. Read 2026-09-22 from the repository, and
   checked again on 2026-09-23 against hex.pm and the sources by a
   subagent of this session: the pattern is matched with
   `Regex.match?/2` against the coverage entry's `:name`, the relative
   source path (`lib/excoveralls/stats.ex`); the latest release is
   0.18.5 of 2025-01-26, which is also the repository's last commit.
7. What Phoenix projects skip, read 2026-09-22: dwyl's phoenix-chat
   example (`test/`, `application.ex`, `<app>_web.ex`, `telemetry.ex`,
   `components/core_components.ex`, `channels/user_socket.ex`) and
   *Code hygiene with Elixir* (the same, plus `router.ex` and the error
   helpers) — "files such as application.ex, telemetry.ex,
   core_components.ex and user_socket.ex are ignored because they are
   not relevant for the functionality of the project".
8. parroty/excoveralls issue #89, *Files to ignore on a Phoenix
   project*: the question asked in 2018 and never answered with a list,
   which is why every project writes its own.
