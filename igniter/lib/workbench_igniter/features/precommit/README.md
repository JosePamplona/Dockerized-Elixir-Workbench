# Cartridge: precommit

The checks that run before the commit exists, in the project's own
container.

* **Task**: `mix workbench.install.precommit`
* **Inserted by**: `wb.sh add precommit [--checks format,compile]`

## Description

A pre-commit hook is the cheapest place to find what CI finds twenty
minutes later: the file nobody formatted, the warning that compiles
anyway, the lock file with a dependency nobody uses. Two things make
one awkward in a workbench project, and this cartridge is both of them
solved:

* **The hook runs on the host, and the host has no Elixir.** Committing
  happens on the machine with the editor; the project's Elixir lives in
  a container. The cartridge installs `.githooks/mix`, which is `docker
  compose exec app mix` with the workbench's own two paths — the
  running container when the workspace is up, a one-off container when
  it is not — and points `git_hooks` at it.
* **More than one cartridge wants a line in the same hook.** The checks
  live in `.githooks/pre-commit`, a plain shell script where each
  cartridge owns a delimited block (`WorkbenchIgniter.BlockFile`).
  credo's block and coverage's stand in one file, in order, and
  ejecting either takes its own lines and leaves the rest.

What this box installs itself are the checks that belong to **no**
cartridge: `mix format`, `mix compile`, `mix test` and `mix
deps.unlock` come with Elixir, and a shelf where the hook were an
option of credo would be a shelf that can run Credo before a commit and
not the formatter.

## What it installs

* `config :git_hooks` at the end of `config/dev.exs`: `auto_install: false`, `verbose`,
* `config :git_hooks` in `config/dev.exs`: `auto_install: false`, `verbose`,
  `project_path: "."`, `mix_path: "sh .githooks/mix"` and one hook,
  `pre_commit`, whose one task is the script below. No cartridge ever
  writes here again — what runs is the script's business.
* `.githooks/mix` — how the host reaches `mix`.
* `.githooks/pre-commit` — the checks, `set -e`, one block per
  cartridge, and a comment line dividing the fast checks from the ones
  that compile the project or run the suite.

The hook itself, `.git/hooks/pre-commit`, is written by `mix
git_hooks.install`, which the insert runs (it backs up whatever was
there first), and taken away by the eject, which puts back whatever it
had replaced: a revert cannot, since `.git/hooks` is outside what a
commit carries. It is not part of a clone: a fresh one runs `./wb.sh
mix git_hooks.install`.

## Options

| Option | What it does |
| --- | --- |
| `--checks` | Comma-separated, the checks this box installs: `format` (`mix format --check-formatted`), `unused_deps` (`mix deps.unlock --check-unused`), `compile` (`mix compile --warnings-as-errors`), `test` (`mix test`). Default: `format`. |

A second run adds the checks it is given and keeps the ones already
there. A cartridge's own check is that cartridge's option — `credo
--githook`, `coverage --githook` — never one of these.

## The file, after `credo --githook`

```sh
#!/bin/sh
# ...
set -e

# >>> precommit — the checks that come with Elixir, not with a cartridge
mix format --check-formatted
# <<< precommit

# >>> credo — the reviewer that never tires
mix credo
# <<< credo

# --- slow: what compiles the project or runs the suite ----------------------
```

Credo's block stands above the divider because Credo reads the source
and never compiles the project; coverage's `mix coveralls`, which runs
the suite, is born below it.

It is the project's file: add a line of your own outside the blocks,
or move a block past the divider to reorder it. A block is replaced
where it stands, so what you moved stays moved; only its own lines are
ever rewritten, and `sh .githooks/pre-commit` runs the lot without
committing.

## The way in, for a cartridge with a check of its own

```elixir
# the option builds on this box, and is refused while it is not in
def choices, do: [githook: [{true, "the check before the commit", ["precommit"]}]]

# in the installer, once missing_option_requirements/3 found nothing lacking
Precommit.check(igniter, "credo", ["mix credo"], note: "the reviewer that never tires")
```

Required, never inserted along: inserted along, this box would come in
the other cartridge's commit, and that cartridge's eject would leave
the hook behind in `.git/hooks`.

`stage: :fast` puts a new block above the divider; `:slow`, the
default, below it. `Precommit.forget/2` is what an eject owes, and
`Precommit.checks_of/2` is how the cartridge's own `state/1` reads
whether its check is there.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/precommit/` | The cartridge: its code and its papers |
| `├── 📄 precommit.ex` | The checks, the mark, and the way in |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | The hook across the mount, against its sources |
|  |  |
| `📁 priv/features/precommit/assets/` | Planted verbatim |
| `├── 📄 mix` | The host's way into the container |
| `└── 📄 pre-commit` | The script's skeleton, before any block |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 precommit_test.exs` | The checks, the stages, each cartridge's block |

The shared-file tool it writes through is the workbench's, not the
cartridge's: `WorkbenchIgniter.BlockFile`
(`lib/workbench_igniter/block_file.ex`, tested in
`test/workbench_igniter/block_file_test.exs`).
