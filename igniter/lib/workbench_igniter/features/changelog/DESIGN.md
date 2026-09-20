# changelog — Design

*Revision: cartridge v0.3.0 (2026-09-18). Sources consulted on that
date; quotations are verbatim from the page as read then.*

## Abstract

Every Mix project has a `version:`, and most never move it: a number
with no record of what changes between one value and the next is not
versioning. This cartridge starts the record — a `CHANGELOG.md` opened
at the version the project is on — at any point of the project's life,
and on request plants the tool that cuts the next version (`mix
version`) and the badge that shows it. It opens the history at the
version `mix.exs` already has, because that is where the project *is*;
`--init-version` moves the opening elsewhere for the project that
decides so. The research behind this revision corrected four things the
box did wrong: its default (`0.0.0`, against SemVer's own `0.1.0`), its
silence on a version Mix cannot compile, its blindness to `@version`,
and a badge that broke on a pre-release.

## 1. Problem

A project without versioning cannot answer the questions asked of it
from outside: *which build is in production? what changed since the one
that worked? is it safe to upgrade?* The git log does not answer them —
it records every step and none of the differences that matter to a
reader; Keep a Changelog's opening line is "Don’t let your friends dump
git logs into changelogs." [2]

`mix new` and `phx.new` both write `version: "0.1.0"` [4][5], so the
number is there from the first minute. What is missing is everything
that makes it mean something: a place where changes are written down as
they are made, a moment when they are closed under a new number, and
the number moving with them. Without those the project stays at `0.1.0`
for years, and the number says nothing.

The need does not belong to new projects. A project two years in, in
production, still at `0.1.0` with no changelog, is the commoner case
and the one with more to gain. So the cartridge has to start the
capability *wherever the project is*: on the version it has, without
pretending that the history before it was recorded.

## 2. Background

### 2.1 What the number means, and where it starts

Semantic Versioning 2.0.0 [1]: "Given a version number
MAJOR.MINOR.PATCH, increment the: MAJOR version when you make
incompatible API changes, MINOR version when you add functionality in a
backward compatible manner, PATCH version when you make backward
compatible bug fixes".

On the start: "Major version zero (0.y.z) is for initial development.
Anything MAY change at any time." And its FAQ, to *How should I deal
with revisions in the 0.y.z initial development phase?*: "The simplest
thing to do is start your initial development release at 0.1.0 and then
increment the minor version for each subsequent release."

On a project well under way: "If your software is being used in
production, it should probably already be 1.0.0."

And on what a released number is: "Once a versioned package has been
released, the contents of that version MUST NOT be modified."

### 2.2 What Mix asks of it

`mix compile.app` validates the key on every compile [3]:

```elixir
if not (is_binary(version) and match?({:ok, _}, Version.parse(version))) do
  Mix.raise(
    "Expected :version to be a valid Version, got: #{inspect(version)} (see the Version module for more information)"
```

`Version.parse/1` is SemVer: three numbers, an optional pre-release
after a dash, optional build metadata after a plus. `1.2` is not a
version, and a `mix.exs` that says it does not compile.

### 2.3 The changelog

Keep a Changelog 1.1.0 [2] defines it: "A changelog is a file which
contains a curated, chronologically ordered list of notable changes for
each version of a project." Its principles, among them: "Changelogs are
*for humans*, not machines.", "There should be an entry for every
single version.", "The latest version comes first.", "The release date
of each version is displayed.", "Mention whether you follow Semantic
Versioning."

And the mechanism the cartridge's template is built on: "Keep an
`Unreleased` section at the top to track upcoming changes. […] At
release time, you can move the `Unreleased` section changes into a new
release version section."

It says nothing about starting one late, other than that it is fine to
work on one after the fact: to *Should you ever rewrite a changelog?*,
"Sure. There are always good reasons to improve a changelog."

### 2.4 The tools that already exist

* **git_ops** [6]: "A small tool to help generate changelogs from
  conventional commit messages." It manages the version too, and says
  how the project must hold it: "use a module attribute called
  `@version` to manage your application's version." It has an Igniter
  installer.
* **versioce** [7]: "a mix task to bump version of your project", with
  hooks; its changelog is generated "from your Git history".

Both derive the changelog from commits, which asks the team for a
commit-message discipline (Conventional Commits) and gives the reader
what 2.3 warns against: "The purpose of a commit is to document a step
in the evolution of the source code. […] The purpose of a changelog
entry is to document the noteworthy difference, often across multiple
commits, to communicate them clearly to end users." [2]

What they do establish is the convention an advanced project is likely
to follow: `@version "1.2.3"` at the top of `mix.exs` and `version:
@version` in `project/0`, so that `source_ref: "v#{@version}"` and the
package metadata can share it.

### 2.5 The badge

shields.io's static badge takes "Label, message and color separated by
a dash `-`", and its escaping table reads: URL input "Double dash
`--`", badge output "Dash `-`" [8]. A version with a pre-release carries
a dash.

## 3. Design

### 3.1 The history opens where the project is

The default for `--init-version` is the version `mix.exs` has. Through
v0.2.0 it was `0.0.0`, with the argument that "`phx.new` writes `0.1.0`
because a generator has to write something". By 2.1 that was wrong
twice: `0.1.0` is what SemVer tells a new project to start at, not an
accident of the generator; and on a project already at `2.3.1`, a
default of `0.0.0` rewrote the number of a released project to something
it never was — a bare `wb.sh add changelog` took the version *back*.

With the default on the project's own number, the ordinary insert
changes nothing the project has: `mix.exs` is not touched (not even
rewritten with the same value), and the changelog opens at that number.

`--init-version` stays, for the project that decides otherwise: `0.0.0`
for the one that holds nothing is released until it says so, `1.0.0`
for the one in production that takes SemVer's hint (2.1) and makes the
start of its record the moment it says so. These are decisions about
the project that nobody can read off its files, which is what makes
this an option and not a default.

The name changed from `--version` for two reasons. On a command line
`--version` asks a tool which version *it* is; and on this shelf
`--version` is the generic "the version of what the box brings" (a
service's image tag, exdoc's stamp). This option is neither: it names
the version of the *project*, and only at the moment the history opens
— a second run ignores it (3.4). `--init-version` says both.

### 3.2 A version is validated before it is written

By 2.2 a `mix.exs` with `version: "1.2"` stops compiling, and every
Mix task that compiles the project stops with it, this installer
included: the repair is by hand. `--init-version` goes through
`Version.parse/1` before anything is written, and so does the argument
of the planted `mix version`.
Refusing is an issue, not a notice: nothing is written.

### 3.3 The version is read and written through `@version`

`mix_project_value/2` — the shelf's reader of `mix.exs` — returned `nil`
for anything but a literal, so a project on the convention of 2.4 had no
readable version. It now reads a module attribute through to the literal
it holds. Writing already worked: Igniter's `MixProject.update/4` moves
the attribute's definition and leaves `version: @version` alone
(checked in the suite).

The planted `mix version` does the same with no Igniter to lean on: when
`project/0` says `version: @version` it rewrites the `@version "…"`
line, otherwise the `version: "…"` literal.

A version that is neither — `version: version()`, a `VERSION` file read
at compile time — cannot be read, and the insert says so and asks for
`--init-version` rather than guessing. See 5.

### 3.4 The mark is the changelog, and it guards the number

Unchanged from v0.1.0: `CHANGELOG.md` is the mark, since every project
has a `version:`. An existing changelog is never overwritten, and with
it there, `--init-version` is ignored: a number under a written history
is not the installer's to move (2.1: a released version "MUST NOT be
modified"). `rerun: :adds` applies to the two pieces only.

`state/1` had to change with the option. It answered `version:` with
`mix.exs`'s number, which was the option's value only until the first
release. It now answers `init_version:` with the **oldest release title
of the changelog** — by "the latest version comes first" (2.3), the last
`## ` title that carries a version — which is where the history opens
for as long as the file lives. Both the house's `## v1.2.3 - (date)` and
Keep a Changelog's `## [1.2.3] - date` are read, so a project that came
with its own changelog answers too.

### 3.5 The opening entry says what is true

The template's first release read "Brand new project created." On a
project two years old that is false, and the first thing its developer
would have to delete. It now reads: "This changelog: the project's
notable changes are recorded here from this version on." — true of a
project born this morning and of one that was not, and honest about
what the file does not hold. It goes under `Added`, which it is.

### 3.6 A hand-written changelog, and a planted task

The cartridge does not install git_ops or versioce (2.4). The changelog
it opens is the curated kind Keep a Changelog describes, written as the
work is done, in `Unreleased`; generating it from commits would ask the
project for a commit convention it may not have and produce the log the
format exists to replace. A project that does want that road has
`mix igniter.install git_ops`, and this cartridge's mark (the changelog)
is git_ops's file too — they are alternatives, not layers.

What is left to automate is small and mechanical: write the number in
the (up to) three places that carry it. That is `--mix-task`: a hundred
lines planted in `lib/mix/tasks/version.ex` with their test, which the
project owns and can change, rather than a dependency with a
configuration. It decides nothing: "Deciding the number is yours."

### 3.7 The badge

A static shields.io badge under the README's title — static because the
dynamic ones read hex.pm or a git host's releases, and an application
has neither by default. Being static it goes stale, which is why `mix
version` rewrites it. By 2.5 the version's dash is doubled in the URL
(`version-2.0.0--rc.1-lightgrey.svg`), both by the installer and by the
task, whose pattern reads the doubled form back.

### 3.8 What is deliberately absent

* **No git tag, no commit.** Tagging `v1.2.0` is part of a release, but
  the task writes files and stops: what goes in the release commit, and
  whether the tag is signed or pushed, is the project's flow. After `mix
  version 1.2.0` the diff is the release commit, ready to be read.
* **No bump words.** `mix version minor` would need the task to hold an
  opinion on pre-releases and on `0.y.z`; typing the number is shorter
  than learning the rules of a bumper.
* **No ordering check.** The task does not refuse a number lower than
  the current one. A typo that still parses is caught in the diff.
* **No backfill.** The history before the opening is not reconstructed
  from git; the opening entry says from where the record counts.

## 4. Evaluation

* The cartridge's suite (14 tests): the default leaves `mix.exs`
  unchanged and opens at its version; a project on `@version "2.3.1"`
  opens at `2.3.1`; `--init-version` writes a literal and moves an
  attribute; `1.2` is refused; an unreadable version asks for the
  option; a pre-release badge is escaped; the second run moves nothing;
  `state/1` reads the oldest title of a Keep a Changelog file written by
  hand.
* The planted task's own test (7 tests) was run for real, in a scratch
  Mix project outside the workbench, on Elixir 1.19.5 / OTP 27: the
  three files, `@version`, the pre-release badge written and read back,
  an invalid version refused with nothing written.
* The shelf's suite, 471 tests, with `mix_project_value/2` changed
  under exdoc and the catalog's `state/1` run on `--init-version 1.2.3`.

* A real project: `phx.new` 1.8.9 (`--no-ecto --no-html`), this package
  as a path dependency, `mix workbench.install.changelog --mix-task
  --readme-badge`: `mix.exs` untouched at `0.1.0`, the changelog opened
  there, the badge under the README's title; the planted test passes in
  the project (7 tests); two entries written under `Unreleased` and
  `mix version 0.2.0` moved the three files. The box's back shows that
  run. It also found what no test could, since the tests compared the
  date with the same clock: run at 18:50 in UTC-6, the release came out
  dated the next day. Both dates are the local day's now
  (`:calendar.local_time/0`); in a container, whose clock is UTC unless
  told otherwise, that is the same day as before.

Not verified: the rendered badge of a pre-release on shields.io itself
(the escaping is from its documentation [8], not from a request).

## 5. Limitations and open questions

* **A version that is not a literal.** `version: version()` or a
  `VERSION` file: the insert refuses without `--init-version`; *with*
  it, and a number other than the project's, Igniter replaces the call
  with a literal — the diff shows it before it is accepted, but it
  undoes a mechanism the project chose. The planted task fails on such
  a project ("carries no version this task can set"), which is the
  honest answer.
* **Umbrellas.** One `mix.exs` per app, and no version at the root. The
  cartridge reads and writes the root's; nothing here was tried on one.
* **The house's dress.** The template is Keep a Changelog's structure
  with the workbench's titles — `## v1.2.3 - (2026-09-18)`, not
  `## [1.2.3] - 2026-09-18`, no link references at the foot, and the
  wording of the change types and the link are 1.0.0's. It is the format
  this repository and every cartridge keep, and the one
  `Feature.changelog_version/1` reads. Moving the shelf to 1.1.0's
  letter is a decision for all of them at once, not for this box.
* **The init version of a changelog the project rewrote.** `state/1`
  reads the oldest title; a project that prunes old releases from its
  changelog moves it. It is what the project says about itself.

## References

1. *Semantic Versioning 2.0.0* — the spec, items 3–4, and its FAQ.
   <https://semver.org/spec/v2.0.0.html>
2. *Keep a Changelog 1.1.0*. <https://keepachangelog.com/en/1.1.0/>
3. Elixir, `lib/mix/lib/mix/tasks/compile.app.ex` —
   `validate_version!/1`.
   <https://github.com/elixir-lang/elixir/blob/main/lib/mix/lib/mix/tasks/compile.app.ex>
4. Elixir, `lib/mix/lib/mix/tasks/new.ex` — the `mix.exs` templates.
   <https://github.com/elixir-lang/elixir/blob/main/lib/mix/lib/mix/tasks/new.ex>
5. Phoenix, `installer/templates/phx_single/mix.exs.eex`.
   <https://github.com/phoenixframework/phoenix/blob/main/installer/templates/phx_single/mix.exs.eex>
6. git_ops, *README*. <https://github.com/zachdaniel/git_ops>
7. versioce, *README*. <https://github.com/mpanarin/versioce>
8. shields.io, `services/static-badge/static-badge.service.js` — the
   static badge's documentation.
   <https://github.com/badges/shields/blob/master/services/static-badge/static-badge.service.js>
