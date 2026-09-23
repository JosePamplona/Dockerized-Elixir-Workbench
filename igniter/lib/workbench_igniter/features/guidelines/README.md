# Cartridge: guidelines

The team's coding conventions as a page of the project's own docs.

* **Archived** (2026-09-22): the page is a download from a URL only the
  team has, and a shelf a project is picked from cannot hand it one.
  The box stays for the reading, and `wb.sh add --archived guidelines
  --url URL` still inserts it for a team that has that URL.
* **Task**: `mix workbench.install.guidelines`
* **Inserted by**: `wb.sh add guidelines --url URL`. The URL is the
  team's, and there is no sensible default.
* **Requires**: [exdoc](../exdoc/) — it owns the site and the `docs:`
  block this appends to.

## Description

Downloads a markdown and lists it in the ExDoc site under *Support*, so
the conventions sit beside the modules they talk about.

It used to be `--guidelines-url` inside exdoc, and it is a cartridge
now for a reason worth keeping: **it is the only installer that reaches
the network**. Inserting the documentation site should not depend on
someone's URL being up. Split out, exdoc has no network path at all,
and this box carries the failure mode alone.

## What it installs

* `guides/coding.md` — the page, downloaded from `--url`, beside the
  site's other sources.
* Its two entries in the `docs:` block of `mix.exs`: `extras` and
  `groups_for_extras[:Support]`.

The entries are **appended** to the lists exdoc wrote, never rewritten
— the same shape as clustering appending its exports to a release
script it does not own.

## Options

* `--url` - URL of the markdown to download. Required.

## When the download fails

The page is planted as a placeholder naming the URL, and a warning
says so. The site keeps building — `mix docs` would break on an extra
that does not exist — and replacing the file by hand finishes the job.

## The mark

`guides/coding.md`. A second run finds it and skips with a
notice: to point the page at another URL, eject and insert again.

## Contents

| File | Role |
| --- | --- |
| `guidelines.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Guidelines` shell |

Cartridge test: `test/workbench_igniter/features/guidelines_test.exs`.
