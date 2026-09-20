# Cartridge: toolchain

> **Archived 2026-09-20**: split done — version_manager carries the host's
> versions, and the `.gitignore` half comes back under a name of its own. The
> box stays on the shelf for the reading — these papers are why it was made;
> it is no longer a pick for a new project, and `wb.sh add` refuses it unless
> `--archived` says so.

The editor's language server, kept out of git.

* **Task**: `mix workbench.install.toolchain`
* **Inserted by**: `wb.sh add --archived toolchain`

## Description

Open the project on your own machine with an editor whose language
server is ElixirLS and it builds the project into `.elixir_ls/`, beside
the source — a directory nobody wants in a commit and every clone has
to ignore again. This cartridge ignores it in the project, once.

Until v0.2.0 it also pinned the host's Erlang and Elixir
(`.tool-versions`). That is [version_manager](../version_manager/)'s
now: a version manager and a language server are two tools. What is
left here still carries the old name; the name and the scope — other
language servers keep directories of their own — are to settle in this
box's own session (`SCRIPT.md`, "The author's selection").

## What it installs

* `/.elixir_ls/` in `.gitignore`, under its comment.

## The mark

The entry itself, read in `.gitignore`: a second run finds it and
changes nothing, and so does a first run on a project that already
ignores the directory. No options, so no `state/1`.

## Contents

| File | Role |
| --- | --- |
| `toolchain.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Toolchain` shell |

Cartridge test: `test/workbench_igniter/features/toolchain_test.exs`.
