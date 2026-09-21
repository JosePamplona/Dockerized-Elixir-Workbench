<!-- markdownlint-disable MD024 -->
# Changelog: precommit

The cartridge's own versions, over what it installs in a project —
independent of the workbench release that ships it.

## v0.1.1 - (2026-09-21)

### Fixed

- The dependency compiles in a workspace. `auto_install` is `false`
  and the installer runs `git_hooks.install` itself, from the
  project's root. The library installs while `git_hooks` compiles, and
  Mix compiles a dependency from `deps/git_hooks`, which in a workspace
  is a Docker volume: git stopped at the filesystem boundary before
  reaching the project's `.git`, the dependency did not compile, and
  every Mix task after the insert failed with it — the next `add`
  among them, as *Could not expand*. The insert itself had reported
  success, because nothing in it compiled the dependency. Now the
  hook is in `.git/hooks` when the insert ends, or the insert fails.
- `.githooks/mix` runs `mix` in place when the commit is made inside
  the project's container — the source at `/app/src` and mix on the
  PATH, as in the workbench's console or a terminal — and reaches the
  container through Docker only from outside it. Such a container may
  have no Docker at all, and the commit failed there.

## v0.1.0 - (2026-09-20)

The box githooks becomes the box that owns the pre-commit hook: same
directory, renamed for the moment it acts on rather than for the
package it installs.

### Added

- **The hook, as a file the project owns.** `.githooks/pre-commit`:
  `set -e`, one block per cartridge (`WorkbenchIgniter.BlockFile`), a
  comment line dividing the fast checks from the ones that compile the
  project or run the suite. `Precommit.check/4` is the way in for a
  cartridge with a check of its own, `forget/2` what its eject owes and
  `checks_of/2` what its `state/1` reads. A block is born at the stage
  its caller asks for and replaced where it stands afterwards.
- **`.githooks/mix`, the host's way in.** The hook runs on the machine
  that commits, which has Docker and no Elixir: `docker compose exec`
  on the running app container, `run --rm` when the workspace is down —
  the workbench's own two paths — and a refusal in one line when Docker
  is not there at all.
- **`--checks`**: the checks that belong to no cartridge, comma-separated
  — `format` (the default), `unused_deps`, `compile`, `test`. A second
  run adds what it is given.
- **The configuration, once and in one place**: `config :git_hooks` in
  `config/dev.exs`, with one hook whose one task is the script.
  `project_path: "."`, because the library writes `File.cwd!()` into
  the hook it installs and installs it from inside the container, where
  that is `/app/src` — a path the host cannot enter.

### Updated

- Verified end to end in a real project: the shim installed from inside
  the container with `cd_path="."`, a host `git commit` refused by the
  formatter running in the container, and the same commit passing once
  the file was formatted. The version hex resolves for `~> 0.7` is
  0.9.0, which already resolves the working tree at run time;
  `project_path` is written all the same, for a project that resolved
  an older one.
- The mark is the hook file, not the dependency: a project that carries
  `git_hooks` and configured it its own way does not read as inserted.
