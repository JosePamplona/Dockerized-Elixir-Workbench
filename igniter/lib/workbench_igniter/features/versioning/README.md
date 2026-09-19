# Cartridge: versioning

A project with a version number and no versioning, given the means to
have it — from wherever the project is today.

* **Task**: `mix workbench.install.versioning`
* **Inserted by**: `wb.sh add versioning`

## Description

Every Mix project has a `version:` — `mix new` and `phx.new` write
`0.1.0` — and most never move it. A number is not versioning. Without a
record of what changes between one number and the next:

* nobody can say **what a build carries**: which one is in production,
  and what it has that last month's did not;
* nobody can say **what changed since the one that worked**, short of
  reading the git log, which records every step and none of the
  differences that matter to whoever asks;
* a release is **not a moment**: nothing is ever closed, so nothing can
  be announced, rolled back to, or pointed at in a bug report;
* and so the number stays at `0.1.0` for years, in production, saying
  nothing.

Versioning is three things working together: a **number that names a
state of the code** ([Semantic Versioning](https://semver.org/spec/v2.0.0.html)
says what each of its parts promises), a **changelog** where the
notable changes are written down as they are made
([Keep a Changelog](https://keepachangelog.com/en/1.1.0/): for humans,
latest first, an `Unreleased` section on top), and a **release**, the
moment `Unreleased` is closed under a new number.

This cartridge starts that in a project. It opens a `CHANGELOG.md` at
the version the project is on, with the `Unreleased` section to write
into from now on and the line that closes it as a release.

### At any point of the project's life

The project does not have to be new. The history opens **at the version
`mix.exs` has**, and `mix.exs` is left untouched: a fresh project opens
at `0.1.0`, which is where SemVer tells a project to start; one two
years in opens at whatever it says, read through `@version` when that
is where the project keeps it. The first entry says what is true in
both — that changes are recorded from this version on — and claims
nothing about what came before.

A project that decides its history opens somewhere else says so with
`--init-version`: `1.0.0` for the one already in production that takes
the occasion to say it ("If your software is being used in production,
it should probably already be 1.0.0", SemVer's FAQ), `0.0.0` for the
one that considers nothing released yet. Then `mix.exs` is written too.

[DESIGN.md](DESIGN.md) has the sources, and why the changelog is
written by hand rather than generated from commits.

## What it installs

* `CHANGELOG.md`, opened at the project's version with today's date:

  ```markdown
  ## Unreleased

  > During development, milestones can be added to this section. […]
  <!-- ## v0.0.0 - (0000-00-00) -->

  ## v0.1.0 - (2026-09-18)

  ### Added

  - This changelog: the project's notable changes are recorded here from this version on.
  ```

  Entries go under `Unreleased` as the work is done. To cut a release,
  copy the commented title line, set its version and date, uncomment
  it: what was unreleased is now that version's.
* `version:` in `mix.exs` — only with an `--init-version` other than
  the one it has. Through `@version` when the project uses it.

The rest are amenities, each on request:

* `--mix-task`: `lib/mix/tasks/version.ex` and its test. `mix version
  1.2.0` does the cutting for you: writes the number into `mix.exs`
  (the literal or the `@version`; the one file it refuses without),
  closes the changelog's `Unreleased` as that version, dated today, and
  updates the README's badge when there is one. A missing changelog or
  badge is skipped. A number Mix would not compile (`1.2`) is refused
  before anything is written. Deciding the number stays yours, and so
  do the commit and the tag.
* `--readme-badge`: a shields.io version badge under the README's
  title, at the version the project has, for `mix version` to keep
  current.

## Options

* `--init-version` - Version the history opens at: the changelog's
  first release, and `mix.exs` when it says another. Default: the
  version `mix.exs` has. Must be one Mix accepts (`MAJOR.MINOR.PATCH`,
  `2.0.0-rc.1`); anything else is refused.
* `--mix-task` - Installs the `mix version` task. Off by default.
* `--readme-badge` - Puts the version badge in the README. Off by
  default.

A second run never moves the version — `--init-version` acts once, when
the history opens — and adds the task or the badge when asked and
missing (`rerun: :adds`).

## The mark

`CHANGELOG.md`. Not the version in `mix.exs`: every project has one of
those already. An existing changelog is never overwritten, so a project
that keeps its own keeps it, and its number with it. `state/1` reads
back where the history opens — the oldest release title of the
changelog, the house's `## v1.2.3` or Keep a Changelog's `## [1.2.3]`,
and not `mix.exs`'s number, which moves with every release — whether
the task file is there, and whether the README carries the badge (`nil`
without a README).

A version that is not a literal (`version: version()`, a `VERSION`
file) cannot be read: the insert says so and asks for `--init-version`.

## Contents

| File | Role |
| --- | --- |
| `versioning.ex` | Manifest + logic (`info/2`, `install/1`, `state/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Versioning` shell |
| `DESIGN.md` | Why the project's own version, why by hand, what is left out |
| `priv/features/versioning/templates/changelog.eex` | The changelog it opens |
| `priv/features/versioning/templates/version_task.eex` | The `mix version` task (`--mix-task`) |
| `priv/features/versioning/templates/version_task_test.eex` | Its test, run in a directory of its own |

Cartridge test: `test/workbench_igniter/features/versioning_test.exs`.
