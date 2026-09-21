# precommit: the hook across the mount

Revision: cartridge v0.1.0 (2026-09-20)

## Abstract

A pre-commit hook in a workbench project has to cross a boundary no
ordinary Elixir project has: `git commit` runs on the host, and the
project's `mix` lives in a container. This cartridge installs the
crossing (`.githooks/mix`), the checks (`.githooks/pre-commit`, a
script the project owns, one block per cartridge) and the wiring that
puts the shim in `.git/hooks` and takes it away again (`git_hooks`,
configured once). Its own options are the checks that come with Elixir
and belong to no cartridge; a cartridge with a check of its own brings
it through `check/4` and owns its block.

## Problem

The box existed before this revision as `githooks`, and it installed a
dependency and nothing else. What it gave a project was the *ability*
to configure hooks, which is what `mix deps.get` already gives it; the
decisions — which checks, in what order, how `mix` is reached from the
host, what happens when two cartridges both want a line — were left to
the reader. Three of them are not the reader's to make in this
environment:

1. **`mix` is not on the host.** The workbench's premise is that the
   machine carries Docker and nothing else. Git runs the hook on that
   machine: "Before Git invokes a hook, it changes its working
   directory to … the root of the working tree" [1], and whatever the
   hook calls, it calls there. A hook configured with `{:cmd, "mix
   format --check-formatted"}` — the library's own first example [2] —
   cannot run.
2. **The plan had the shelf absorbing this box into credo and
   coverage**, an option each. That would leave the formatter, the
   compiler's warnings and the suite with no owner at all: they come
   with Elixir, no cartridge installs them, and they are the checks a
   pre-commit hook is *for*.
3. **Two cartridges write one file.** credo's line and coverage's go in
   the same hook, in sequence, where the first failure cuts the rest.
   Appending is wrong and rewriting is worse — the second cartridge
   erases the first.

## Background

**The library.** `git_hooks` (qgadrian), read on 2026-09-20 in **two**
versions, because the cartridge's requirement admits both and a
workspace shows which one arrives: 0.7.3, the copy in an existing
workspace's `deps/`, and 0.9.0, which is what hex resolves for `~> 0.7`
today and what the probe below actually ran. It installs a shim per
configured hook, from `priv/hook_template`:

```sh
[ "$project_path" != "" ] && cd "$project_path"
$mix_path git_hooks.run $git_hook "$@"
```

`$mix_path` and `$project_path` are substituted at install time.
Installation runs from the module body of `GitHooks` — `if
Application.get_env(:git_hooks, :auto_install, true) do
Install.run(["--quiet"]) end` in 0.7.3, `Application.compile_env/3` in
0.9.0 — so it happens when the dependency compiles, in dev, and not on
every mix invocation.

The two versions differ in exactly one thing that matters here, and it
is the crossing. 0.7.3 defaults `project_path` to
`File.cwd!()` and bakes it into the shim; 0.9.0 defaults it to the
literal `"$(git rev-parse --show-toplevel)"`, resolved when the hook
runs — "let the hook find the working tree when it runs, so one shared
hook works from any worktree". It backs up an
existing hook to `<name>.pre_git_hooks_backup`, records what it
installed in `.git/hooks/git_hooks.db`, and removes a hook whose
configuration has gone ("Remove old git hook … and restore backup").

Tasks come in four shapes: `{:mix_task, …}` ("the preferred option to
run mix tasks, as it will provide the best execution feedback"),
`{:cmd, …}`, `{:file, …}` and an MFA. `Cmd` splits the string on spaces
and calls `System.cmd/3` — no shell — and `File` runs
`Path.absname(path)` directly, which needs the executable bit.

**Git.** `pre-commit` "is invoked by git-commit(1), and can be bypassed
with the `--no-verify` option … Exiting with a non-zero status from
this script causes the git commit command to abort" [1]. Hooks live in
`$GIT_DIR/hooks` unless `core.hooksPath` says otherwise, and "hooks
that don't have the executable bit set are ignored" [1]. `.git/hooks`
is not part of a clone: what the repository can carry is a directory of
its own, never the installed hook.

## Design

### 1. A box, not an option of credo

The checks that belong to no cartridge decide it. `mix format
--check-formatted`, `mix compile --warnings-as-errors`, `mix test` and
`mix deps.unlock --check-unused` are Elixir's, and under the absorption
plan nothing would install them. They are this box's `--checks`.

The rejected alternative is the plan's: githooks absorbed, one
`--githook` per tool box. It was right about *participation* — a tool's
check is its own option, and this design keeps that — and wrong about
the mechanism, which has to exist somewhere. The other rejected shape
is the broad one the author weighed first, a "definition of done" box
that owns every quality gate: it overstates what a hook is. A hook runs
for the person who installed it and `--no-verify` skips it; a promise
to a team is CI's (`ci`, Phase 3 of the release plan), and the two
should not share a name.

### 2. The checks in a script, not in the configuration

`config/dev.exs` gets one hook with one task, `{:cmd, "sh
.githooks/pre-commit"}`, and no cartridge writes there again.

Against `{:mix_task, :format}` and friends, which the library
recommends for feedback: the tasks list is a nested keyword list in
Elixir source, and a cartridge adding its check would have to edit
somebody else's AST — appending to a list it does not own, matching a
tuple to eject it. In a shell script each cartridge owns a delimited
block (`WorkbenchIgniter.BlockFile`, written for this file and for
`test_helper.exs`): `put/5` replaces the block where it stands, `drop/4`
leaves the file as if the cartridge had never passed, `owners/2` says
who wrote there. The developer gets a file they can read, reorder and
run by hand (`sh .githooks/pre-commit`), which a keyword list in
`dev.exs` is not.

`{:cmd, "sh …"}` and not `{:file, …}`: a file task is executed
directly, and "hooks that don't have the executable bit set are
ignored" [1] applies to anything else Git or the library runs the same
way. Igniter writes files without an executable bit, and the workbench
has been bitten by exactly that (`core.fileMode false` and a stashed
`wb.sh` losing `+x`). `sh <path>` needs no bit.

### 3. `mix` means the container

`mix_path: "sh .githooks/mix"`, and that script is `docker compose
exec -T --workdir /app/src app mix "$@"` when the app is running,
`docker compose run --rm -T …` when it is not — the two paths the
workbench's own `mix` verb takes, in the ambient Docker context, so the
hook agrees with what `docker compose` would do from that directory.
The library documents the shape (`mix_path: "docker-compose exec mix"`,
and an issue's `docker exec --tty $(docker-compose ps -q web) mix` for
TTY trouble [2]); `-T` is this cartridge's answer to the same trouble,
since a hook invoked from an editor has no terminal.

It reaches Docker through the project's own compose file, not through
`wb.sh`: the project owes the workbench nothing, and a hook that named
a script outside the repository would be a contract running the wrong
way.

![The commit that crosses the mount: git runs the shim git_hooks installed in .git/hooks, which calls .githooks/mix on the host; that script reaches the app container with docker compose exec, where mix git_hooks.run executes the project's .githooks/pre-commit — set -e, each cartridge's block in order — and the non-zero status walks back across the mount to abort the commit; in the else region, the library's own example runs mix on the host, finds no Elixir and cannot enter the container's path, so the arrow never leaves it](../../../../../assets/diagrams/precommit/the-crossing.svg)

*The gold arrow is the crossing, and the two files in gold are the ones
the cartridge writes. The `else` region is the same commit configured
the way the library's README shows it, on a machine that carries Docker
and nothing else.*

`project_path: "."` is the second half of the crossing. On 0.7.x the
library writes `File.cwd!()` into the shim, and the shim is installed
from inside the container, where the project is `/app/src` — a path
that does not exist on the host, and a `cd` the hook would fail on
every commit. A dot is true on both sides of the mount, and Git has
already put the hook's working directory at the root of the working
tree [1], so there is nothing to cd to. On 0.9.0 the setting is
**redundant** — that version resolves the top level at run time, which
is right for this too — and harmless, and the cartridge writes it
because its requirement (`~> 0.7`) admits a project that resolved the
older one. It is the kind of line that looks like decoration until the
version underneath it moves.

### 4. Two stages, and a block is born at one of them

The skeleton carries a comment line dividing the fast checks from the
ones that compile the project or run the suite. `check/4` takes `stage:
:fast | :slow` and places a *new* block above or below it; a block
already in the file is replaced where it stands, because a project that
moved it meant to. The box's own block is born where its slowest check
belongs — in the fast section until `test` is one of them.

Ordering by insert order alone was the alternative, and it is what the
file would have without the divider: correct, and silently wrong the
first time a cheap check lands behind the suite.

### 5. `mix credo`, not `mix credo --strict`

credo's block runs the plain task. A hook that refuses the first commit
after it is inserted — and `--strict` on a stock `phx.new` project
does — is a hook the developer turns off within the hour. `--strict` is
one word away in a file the project owns.

## Evaluation

**In a real project, on 2026-09-20** — a scratch mix project with the
cartridge inserted by its own installer, an app container off the
workbench image, and the source bind-mounted at `/app/src`: `mix deps.compile` inside the container installed
`.git/hooks/pre-commit`, mode 0755, carrying `cd_path="."` and `sh
.githooks/mix git_hooks.run pre_commit` — the substitution the
configuration asked for. A `git commit` **on the host**, with a badly
formatted file staged, crossed into the container and was refused
there: *"mix format failed due to --check-formatted … /app/src/lib/bad.ex"*,
and `git log` had no new commit. The same commit with the file
formatted went through. That is the whole crossing — host git, host
Docker, container mix — end to end, and the version hex resolved for
`~> 0.7` was 0.9.0.

What was verified in the cartridge's own suite (`precommit_test.exs`)
and in generated projects: the dependency and the
configuration; both files planted; the default check in the
cartridge's block; the chosen checks in the box's order and not the
argv's; a second run adding a check to the one block instead of
opening a second; the refusal for a check that does not exist;
`state/1` saying back what was inserted; a second cartridge's block
landing after the divider with both surviving; a fast block landing
before it; `forget/2` taking one cartridge's lines and leaving the
rest.

What was **not** measured: the wall-clock cost of a commit with the
hook in, on a cold container — the one-off `docker compose run` path
starts a container per check run, and the honest statement is that it
is the slow path by construction, not a number. Nor was the library's
behaviour on a project whose `.git` is a worktree or a submodule; it
resolves the hooks directory through `git rev-parse --git-path`, which
is the right call for both, and neither was tried.

## Limitations

* **The container has to be reachable at commit time.** Docker down
  means the commit is refused with the reason, and `--no-verify` is the
  way through. A check that ran on the host instead would need an
  Elixir there, which is the thing the workbench exists to avoid.
* **`auto_install` happens when the dependency compiles**, not on every
  mix run. Between `wb.sh add precommit` and the next `deps.get` or
  `deps.compile`, the shim is not in `.git/hooks` yet; the cartridge
  says so in its `afterwards`, and `git_hooks.install` is one command.
* **One block per cartridge means a cartridge's checks are
  contiguous.** With `--checks test`, the whole of this box's block
  moves below the divider, so its `format` runs after another
  cartridge's fast check. Moving the block is the remedy, and the file
  supports it.
* **`--check` is not available as an option name.** Igniter carries
  `check: :boolean` among the global switches of every task, so a
  cartridge declaring `--check` is shadowed on the command line with no
  warning — a composed call still works, which is why only a run in a
  real project showed it. The option is `--checks`.
* **The installed hook is per clone.** `.githooks/` travels with the
  repository; `.git/hooks/pre-commit` never does. That is a property of
  Git, stated in the NEED rather than worked around.

## References

1. `githooks(5)` and `git-config(1)`, git 2.54.0, read 2026-09-20:
   the hook's working directory, the executable bit, `core.hooksPath`,
   `pre-commit` and `--no-verify`.
2. `git_hooks` — README and source read 2026-09-20 in two versions:
   0.7.3 (`lib/git_hooks.ex`, `lib/git/path.ex`,
   `lib/tasks/{cmd,file}.ex`, `lib/mix/tasks/git_hooks/install.ex`,
   `priv/hook_template`), from the copy in `_workspaces/pitchers/deps/`;
   and 0.9.0 (`lib/git_hooks.ex`, `lib/git/git_path.ex`,
   `lib/mix/tasks/git_hooks/install.ex`, `priv/hook_template`), the one
   hex resolves for `~> 0.7` and the one the probe ran.
3. `WorkbenchIgniter.BlockFile` — the workbench's own tool for an
   ordered file several cartridges write into.
