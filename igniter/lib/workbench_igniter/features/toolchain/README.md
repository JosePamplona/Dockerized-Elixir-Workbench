# Cartridge: toolchain

What the project tells the **host's** toolchain — not the workbench's
image.

* **Task**: `mix workbench.install.toolchain`
* **Inserted by**: `wb.sh add toolchain`; a chiefs_setup pick.

## Description

Inside the container the stack comes from the image and nothing reads a
version file. Outside it — your editor, its language server, a `mix` in
your own shell — nothing knows which Elixir this project is. This
cartridge writes that down, and keeps the language server's droppings
out of git.

The versions are not asked for and not read off `mix.exs`: its
`elixir:` line is a requirement range (`~> 1.17`), not a version. The
installer runs *inside* the toolchain container, so it reports what is
actually running it — `System.version/0` and the OTP release — which is
the stack the image was built from. That is the one source that cannot
drift from the workspace.

## What it installs

* `.tool-versions`:

  ```text
  erlang 27.3.4.2
  elixir 1.19.5
  ```

  Read by [asdf](https://asdf-vm.com) and [mise](https://mise.jdx.dev);
  other version managers ignore it.
* `/.elixir_ls/` in `.gitignore`, under its comment.

## Options

* `--elixir`, `--erlang` - Pin something other than the versions
  running the installer. Rarely what you want: the point of the file is
  to agree with the image.

## The mark

`.tool-versions` itself. An existing one is never overwritten
(`on_exists: :skip`), so a project that pins its own versions keeps
them; `state/1` reads back what the file says, so the console can show
the pin beside the workspace's stack.

## Contents

| File | Role |
| --- | --- |
| `toolchain.ex` | Manifest + logic (`info/2`, `install/1`, `state/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Toolchain` shell |

Cartridge test: `test/workbench_igniter/features/toolchain_test.exs`.
