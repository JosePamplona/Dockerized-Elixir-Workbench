# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A workbench for creating Phoenix projects and running them on localhost with nothing on the host but Docker. Three parts:

- **`wb.sh`**: the whole CLI (`new`, `add`, `eject`, `bake`, `up`, `status`, `catalog`, `console`…; `./wb.sh help`). It reads `config.conf` and runs every mix/git step inside a container on the workbench image (`scripts/Dockerfile.workbench`). A project's own image comes from `scripts/Dockerfile.seed.local`. The first steps of both Dockerfiles are identical so the layers are shared, so change them together.
- **`igniter/`**: the `workbench_igniter` package. Each feature is a *cartridge*, an Igniter installer that patches the project through its AST. `wb.sh new` adds it to the project as a dependency, and its `workbench.*` Mix tasks (catalog, status, expand, compose, serve) are the contracts the other two parts read.
- **`console/`**: a Phoenix LiveView GUI that drives `wb.sh` as jobs and reads its `--json` contracts. It runs as a container on the workbench image (`./wb.sh console`), with the Docker socket and the workbench mounted at the same absolute path as on the host. It depends on `../igniter` as a path dep. `console/README.md` holds the settled architecture (*The architecture, as settled*); the port plan it grew from, `console/PLAN.md`, was closed on 2026-09-29 and lives in git history.

Projects are generated into `_workspaces/<dir>` (`WORKSPACE_PATH` in `config.conf`). Each one owns its `docker-compose.yml`, with ports and names baked in, so several can run at once.

## Cartridges

- One directory per cartridge under `igniter/lib/workbench_igniter/features/<name>/`: the manifest and installer `<name>.ex`, the task shell `task.ex`, `templates/`, and its papers (`README.md` for what it installs, `NEED.md` for the need it answers, `DESIGN.md` for why, with sources, and its own `CHANGELOG.md`). Binary assets mirror it under `igniter/priv/features/<name>/`. They are registered in `features.ex`, and `features/README.md` is the index.
- There is **one kind of cartridge**. A *collection* is a cartridge whose `members/1` inserts others. `collection`, `base`, `archived` and `pending` are facts derived from the manifest, not types. A collection's options must be decisions it owns and must never re-expose a member's switch.
- `wb.sh add` makes **one commit per cartridge** (`Insert NAME …`), and `eject` reverts that commit. `installed?/1` and the installer's guard read the same mark, so `status` and the installer never disagree. `Igniter.create_new_file(on_exists: :skip)` does not skip: use the `installed?` → notice → skip guard.
- **Base cartridges** (mailer, gettext, ecto, esbuild, tailwind, html, dashboard) are phx.new capabilities added afterwards through `WorkbenchIgniter.PhxDelta`. It generates the project twice, with and without the flag, at the project's own phx_new version (stamped in its `Dockerfile.local`) and 3-way merges the difference.
- **Each project file has one owning module** in `igniter/lib/workbench_igniter/` (`MixFile`, `ComposeFile`, `EnvFile`, `IgnoreFile`, `Dockerfile`, over `TextFile`). Check Igniter's native modules first; add a module only for a file Igniter has nothing for.
- **A compose service is defined entirely inside its cartridge** (`compose/1` → `ComposeFile.Service`, with fragments under `priv/features/<name>/compose/`). Nothing outside that cartridge, the console included, names a service. If something else needs to know about a service, extend `Compose.brought/2`. The golden compose files in the tests must keep passing byte for byte.
- **The project owes the workbench nothing.** Never add a route, file, marker or manifest field whose only reader is the workbench. Read what the project already has instead: its source, Docker, git.

## Commands

Each package pins its Erlang/Elixir in its own `.tool-versions` (asdf). Run mix from `igniter/` or `console/`, never the repo root.

```sh
# The same checks CI runs (.github/workflows/ci.yml)
shellcheck -x wb.sh scripts/entrypoint.sh
cd igniter && mix format --check-formatted && mix credo --strict && mix dialyzer && mix test
cd console && mix format --check-formatted && mix credo --strict && mix dialyzer && mix test

mix test test/workbench_igniter/features/credo_test.exs      # one cartridge
mix test test/workbench_igniter/features/credo_test.exs:42   # one test
mix test --only exhaustive   # igniter, excluded by default: ~1 hour. Run it in the background with no timeout (a cut-off run reports "0 tests, 0 failures")
```

- To read the workspace or the shelf from an agent: `./wb.sh status --json --fast --brief` (tenths of a second, 2 KB) and `./wb.sh catalog --json --brief` (one line, 20 KB). The full contracts are the console's: `status --json` boots Mix in a container (about a minute) and `catalog --json` carries every paper and option doc (130 KB).
- Export `DOCKER_CONTEXT=default` before `./wb.sh`, `docker compose` or the console's tests. The workspaces run on the native engine, and the shell's `desktop-linux` context shows nothing running.
- Console on the host: `PORT=<free port> mix phx.server` from `console/`. 4000 is taken, and the user may already have a console on 4123/4125, so check `ss -ltn` first. Run it with the sandbox disabled and stdin from `/dev/null`, or the BEAM dies when it spawns a second child. On boot it rewrites `config.conf`: back that file up first. It reads the catalog once at boot, so restart it after editing a manifest. After editing `console/assets/js/hooks.js`, run `mix esbuild console`.
- To see generated code compile in a real project: `MIX_ENV=test mix phx.new <scratch>/probe --no-install` from `igniter/`, copy `igniter/.tool-versions` into it, add `{:workbench_igniter, path: …}`, then run `mix workbench.install.<name> --yes < /dev/null`.

## Working in this repo safely

- **The workspaces and `config.conf` are live.** The user creates `_workspaces/test_N` and edits `config.conf` while you work. Never run `new`, `delete`, `bake` or `config set` on a workspace you did not create and check at that moment. For probes, use `_workspaces/claude_probe_*` and select them with the `WORKSPACE_PATH=… PROJECT_NAME=…` env overrides, never by editing `config.conf`. `./wb.sh new` takes no name: it targets `config.conf`'s workspace, so never run it bare.
- To test a service cartridge live: rsync a `test_N` to `claude_probe_X` (excluding `_build`/`deps`), `WORKSPACE_PATH=… ./wb.sh -y add X && … bake`, then `docker compose -p claude_probe_X -f … up -d --no-build <services>`. Never `wb.sh up` there.
- **Never `git stash`**. `core.fileMode` is false, so a pop strips `+x` from `wb.sh` and `assets/design/build.py`, and the console fails with `:eacces` (the fix is `chmod +x`). Compare against HEAD with `git show HEAD:path` or a worktree instead.
- **Never `git add -A`**. The tree usually carries the user's uncommitted work. Stage named paths, and commit by topic.
- The console's static maquette (`mock/`) was retired on 2026-09-05 and archived out of git on 2026-09-29 (`_archived/mock/`, in git history until then): never bring it back or reference it as alive.

## Papers and records

- The root `CHANGELOG.md` is the record of what was done and why. Each cartridge's own `CHANGELOG.md` versions that box.
- `RELEASE_PLAN.md` is the checklist for the portfolio release, judged by what a 90-second reviewer sees. `SCRIPT.md` lists the reference project's steps against the shelf. The reference project's design is in `reference/`.
- A cartridge's README/NEED opens with what the tool solves for anyone. A cartridge never names the collections that pick it.
- A visual or design question is settled with a standalone HTML page in the repo, never a Claude artifact. The page is deleted once decided, and the CHANGELOG keeps the record.
- The design tokens and components (`.cart-ref`, `.stamp`, `.unlit`) are in `assets/design/` (`build.py` → `generated/`). Show what is unavailable as disabled with a reason; never hide it.
