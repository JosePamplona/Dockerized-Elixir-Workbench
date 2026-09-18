# Cartridge: versioning

A version the project chose, the file where the next one gets its
reasons, and — on request — the task that writes the next one and the
badge that shows it.

* **Task**: `mix workbench.install.versioning`
* **Inserted by**: `wb.sh add versioning`; a chiefs_setup pick.

## Description

`phx.new` writes `version: "0.1.0"` into `mix.exs` because a generator
has to write something. This makes the number a decision — `0.0.0` by
default, for a project that has released nothing — and creates the
`CHANGELOG.md` that gives the next number its reasons.

The changelog is [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
with the workbench's own note on closing a milestone: entries land in
`Unreleased`, and the commented title line above it is the template to
uncomment when a release is cut. It is the same format the cartridges
keep for themselves, which is where `version/0` reads them from.

## What it installs

* `version:` in `mix.exs`, set to `--version`.
* `CHANGELOG.md`, opened at that version with today's date.
* With `--task`: `lib/mix/tasks/version.ex` and its test. `mix version
  1.2.0` writes the number into `mix.exs` (the one thing it refuses
  without), closes the changelog's `Unreleased` as that version, dated
  today, by writing the release title under the commented template
  line, and updates the README's version badge when the README has
  one. A missing changelog or badge is skipped, with a note for the
  changelog. Deciding the number stays yours.
* With `--readme-badge`: a shields.io version badge under the README's
  title, at the version the project has, for `mix version` to keep
  current.

## Options

* `--version` - Version the project starts at. Default: `0.0.0`.
* `--task` - Installs the `mix version` task. Off by default.
* `--readme-badge` - Puts the version badge in the README. Off by default.

A second run never moves the version (the changelog is the mark), and
adds the task or the badge when asked and missing (`rerun: :adds`).

## The mark

`CHANGELOG.md`. Not the version in `mix.exs`: every project has one of
those already. An existing changelog is never overwritten, so a project
that keeps its own keeps it; `state/1` reads back the version `mix.exs`
declares, whether the task file is there, and whether the README carries
the badge (`nil` without a README), so the console can show where the
project stands.

## Contents

| File | Role |
| --- | --- |
| `versioning.ex` | Manifest + logic (`info/2`, `install/1`, `state/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Versioning` shell |
| `priv/features/versioning/templates/changelog.eex` | The changelog it opens |
| `priv/features/versioning/templates/version_task.eex` | The `mix version` task (`--task`) |
| `priv/features/versioning/templates/version_task_test.eex` | Its test, run in a directory of its own |

Cartridge test: `test/workbench_igniter/features/versioning_test.exs`.
