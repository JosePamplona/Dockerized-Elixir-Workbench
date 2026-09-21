# Cartridge: credo

Credo static code analysis, and the check before the commit.

* **Task**: `mix workbench.install.credo`
* **Inserted by**: `wb.sh add credo [--githook]`

## Description

An automated reviewer that flags style and structure before they reach
a human reviewer: `mix credo` reads the source and reports what a team
would otherwise argue about in every pull request.

With `--githook` it also runs before every commit. The hook itself is
not this cartridge's — the **precommit** box owns the file, the way it
reaches `mix` inside the container, and the checks that come with
Elixir — and this one inserts that box and writes a block of its own in
`.githooks/pre-commit`. Ejecting either leaves the other's checks
standing.

## What it installs

* `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` in the project deps.
* With `--githook`: the **precommit** cartridge, and `mix credo` in this
  cartridge's block of `.githooks/pre-commit`.

**Idempotency**: `on_exists: :skip` for the dependency; the hook line is
written once, and a second run adds it if it is missing.

## Options

| Option | What it does |
| --- | --- |
| `--githook` | Run `mix credo` before every commit, in this cartridge's own block of the pre-commit hook. Default: off. |

The line is `mix credo`, not `mix credo --strict`: a hook that refuses
the first commit after it is inserted is a hook the developer turns
off. `--strict` is one word away, in a file the project owns.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/credo/` | The cartridge: its code and its papers |
| `├── 📄 credo.ex` | Manifest, the dependency and the hook block |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why this reviewer, and why the hook is not its file |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 credo_test.exs` | The dependency, and the block before the commit |
