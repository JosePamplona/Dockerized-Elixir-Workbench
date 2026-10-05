# Cartridge: version_manager

The project's Erlang and Elixir, in the file a version manager reads —
so your machine can hold many projects, each on its own versions.

* **Task**: `mix workbench.install.version_manager`
* **Inserted by**: `wb.sh add version_manager`

## Description

A machine has one `elixir` on its `PATH`, and projects do not agree on
which it should be: the one you maintain is on the Elixir it was
written for, the new one on the latest. A **version manager**
([asdf](https://asdf-vm.com), [mise](https://mise.jdx.dev)) keeps
several versions installed side by side and picks one per directory,
from a file in it. `cd` into a project and `mix`, `iex` and the
editor's language server run that project's Erlang and Elixir; `cd`
into the next and they run the next one's. Nothing to remember and
nothing to switch by hand.

The file does three things at once:

* it **switches**: the manager reads it wherever you stand, in the
  project's directory and below;
* it **informs**: anyone opening the repository reads which Erlang and
  Elixir this project is on — `mix.exs` only says a range (`~> 1.17`);
* it **keeps the record**: it is committed, so the versions change in a
  commit, with the code that needed the change, and a clone gets them.

This cartridge writes that file.

### Where the versions come from

Not an option, and not read off `mix.exs`. The installer runs inside
the workspace's toolchain container, so it reports what is actually
running it — `System.version/0` and the OTP release — which is the
stack the project runs on in the workbench. The host then matches the
container: `mix` in your shell and `./wb.sh mix` are the same Elixir.

Elixir is pinned **with its OTP**: `1.19.6-otp-28`, not `1.19.6`. Both
managers download Elixir precompiled, and the bare version is the build
against the *oldest* OTP that Elixir supports, whatever Erlang the file
pins beside it. [DESIGN.md](DESIGN.md) has the sources.

## What it installs

One file, by `--manager`:

* `asdf` (the default) — `.tool-versions`:

  ```text
  erlang 28.5.0.6
  elixir 1.19.6-otp-28
  ```

  [asdf](https://asdf-vm.com)'s file, and [mise](https://mise.jdx.dev)
  reads it too: the default serves both.
* `mise` — `mise.toml`, the file mise recommends over asdf's:

  ```toml
  [tools]
  erlang = "28.5.0.6"
  elixir = "1.19.6-otp-28"
  ```

Then, on your machine, once: `asdf install` (with its erlang and elixir
plugins added) or `mise install` — the manager installs what the file
names, beside whatever your other projects use. From then on the switch
is the `cd`. Inside the container nothing reads the file: the stack
there is the image's.

## Options

* `--manager` - `asdf` or `mise`: which file is written. Default:
  `asdf`.

The versions are not options: the file's point is to agree with what
runs the project, and the installer knows that better than whoever
types it. A project that wants another pin — a `ref:`, a patch its
manager lists — edits the file, which is its own from the insert on.

## The mark

A version file of either manager: `.tool-versions`, `mise.toml` or
`.mise.toml`. An existing one is never overwritten, so a project that
pins its own versions keeps them — and a project on mise is not handed
an asdf file beside its own. `state/1` says the manager back, off which
file is there; the versions are no option, so the file says them, not
the state.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/version_manager/` | The cartridge: its code and its papers |
| `├── 📄 version_manager.ex` | The file, asdf's or mise's, and its mark |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why one box, which file, why `-otp-NN` |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 version_manager_test.exs` | Each manager's file, and the mark |
