# Changelog — clustering

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a change in the boot script's block, the
templates or the environment entry is a minor, a change that breaks a
project already carrying them (a renamed variable, a node name of a
different shape) is a major.

## v0.2.0 - (2026-08-30)

### Added

- `installed?/1`: the mark is the block's header comment
  `# Workbench clustering:` in `rel/env.sh.eex` — the same substring the
  installer's guard tests and the same one `wb.sh` greps before baking
  the scaled compose, so the catalog, a re-run and the deployment read
  one mark. `mix workbench.status` and `./wb.sh status` report it.
- `option_docs/0` (`--dns-query`, from which the task's *Options*
  section is now rendered) and `afterwards/0` (`./wb.sh up --deploy
  scaled`, for the catalog and the console's box).
- `DESIGN.md`: DNSCluster over libcluster and static names, the release
  pair in `rel/env.sh.eex` against `.env`, `vm.args` and the Dockerfile,
  the four `release.init` templates from Mix's own functions, the
  scaled topology, why a workspace cannot cluster with itself, the
  mark — each against the sources — and the scaled deployment repeated
  on `test_28` with its output. Two figures in `assets/diagrams/clustering/`:
  the scaled deployment (README, *Seeing it work*) and the boot as a
  sequence (DESIGN, §3.2).

Nothing the cartridge installs changes.

## v0.1.0 - (2026-08-25)

### Added

- `mix workbench.install.clustering` (`wb.sh add clustering`),
  standalone: boots the production release as a named distributed node
  for the `DNSCluster` `phx.new` already puts in the supervision tree.
- `rel/env.sh.eex` with the distributed block appended to Mix's default
  template: `RELEASE_NODE="$RELEASE_NAME@<container address>"` from
  `hostname -i` at boot (an externally provided `RELEASE_NODE` wins,
  `127.0.0.1` when no address resolves) and
  `RELEASE_DISTRIBUTION=name`. POSIX `sh`.
- `rel/vm.args.eex`, `rel/remote.vm.args.eex`, `rel/env.bat.eex`: the
  other three `mix release.init` templates, generated from the running
  Elixir's `Mix.Tasks.Release.Init` functions, inside the patch set;
  `mix release.init` queued as the fallback should an Elixir drop them.
- `DNS_CLUSTER_QUERY` in `.env` and `.env.sample`, `--dns-query` to set
  it (default `<app>.default.svc.cluster.local`).
- Re-running is a no-op: existing `rel/*.eex` kept, the block appended
  only when its header is absent, the entry only when the variable is
  not declared.
