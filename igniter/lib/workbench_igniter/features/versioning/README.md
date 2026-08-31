# Cartridge: versioning

A version the project chose, and the file where the next one gets its
reasons.

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

## Options

* `--version` - Version the project starts at. Default: `0.0.0`.

## The mark

`CHANGELOG.md`. Not the version in `mix.exs`: every project has one of
those already. An existing changelog is never overwritten, so a project
that keeps its own keeps it; `state/1` reads back the version `mix.exs`
declares, so the console can show where the project stands.

## Contents

| File | Role |
| --- | --- |
| `versioning.ex` | Manifest + logic (`info/2`, `install/1`, `state/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Versioning` shell |
| `priv/features/versioning/templates/changelog.eex` | The changelog it opens |

Cartridge test: `test/workbench_igniter/features/versioning_test.exs`.
