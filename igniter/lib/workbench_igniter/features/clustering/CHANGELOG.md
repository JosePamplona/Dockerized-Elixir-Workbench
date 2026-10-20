# Changelog — clustering

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a change in the boot script's block, the
templates or the environment entry is a minor, a change that breaks a
project already carrying them (a renamed variable, a node name of a
different shape) is a major.

## v0.3.1 - (2026-10-20)

### Fixed

- **The DESIGN describes the setup that exists.** §2.7, §3.3 and §3.6
  still spoke of two setup lines, "opinionated" and "vanilla", which
  became one on 2026-08-31. Today no setup runs `mix release.init`, so
  `rel/` comes from this cartridge, from a developer's own
  `release.init`, or from an adopted project. The conclusions stand
  with that reason. Two smaller fixes go with it: §5 drops the
  pending item on the opinionated line's `readme.eex`, which went with
  the line, and reference [12] drops the file. What the cartridge
  installs is unchanged.

## v0.3.0 - (2026-10-20)

### Fixed

- **The default `DNS_CLUSTER_QUERY` names a Service that can exist.**
  It was `<app>.default.svc.cluster.local` with the app name as is.
  A Kubernetes Service name is an RFC 1123 label, so for `lorem_ipsum`
  it named a Service nobody could create. Nothing said the Service had
  to be headless either. A normal one answers with its cluster IP, and
  the cluster never formed, with nothing in the log. The default is
  `<app>-headless` now, the app name with hyphens
  (`lorem-ipsum-headless`).
- **The namespace is the pod's own.** The name is short, and DNSCluster's
  resolver (`:inet_res`) completes it from the `search` list of
  `/etc/resolv.conf`; in a pod, the first entry is its own namespace.
  This was measured in a release image on Docker.

### Added

- **Notes for each platform above the value**, in `.env` and
  `.env.sample`: the headless Service on Kubernetes, `<app>.internal` on
  Fly.io, and a service name or shared alias on Compose. They are
  comments, not commented `KEY=` lines, so the file keeps one
  declaration. `--dns-query` replaces only the value.
- **The README shows the headless Service** the default expects, as
  YAML.

## v0.2.2 - (2026-10-20)

### Fixed

- **The papers give the right reason for two facts.** "POSIX `sh`
  only: the production runner image has no bash", in the README and in
  the code's comment, was wrong: the Debian runner has bash, and the
  compose healthcheck uses it. The constraint is that the release
  script sources `env.sh` from `#!/bin/sh`, which is dash there. And
  the other three `mix release.init` templates do not "have to exist
  alongside `env.sh.eex`": Mix falls back to its default for each one
  that is absent; the cartridge writes them because the setup leaves
  `release.init` to it. What it installs is unchanged.

### Added

- **A test runs the `env.sh` it writes under dash**, the sh of the
  release's runner image: it exits cleanly, names the node
  `test@<address>`, and keeps a `RELEASE_NODE` given from outside. A
  bashism in the block failed it; `dash -n` would have let it through.
  Skipped where `dash` is not installed.

## v0.2.1 - (2026-09-22)

### Fixed

- **An empty `--dns-query` gets the default.** A form's field left
  blank arrived as `""` and was written as `DNS_CLUSTER_QUERY=""`: a
  release that queries nothing, and a state reading an empty name.
- **A `--dns-query` that is not a DNS name is refused**, before
  anything is written: it is declared `:dns_name` (`formats/0`) and
  checked where every cartridge's options are. The value goes between
  the quotes of a `.env` line, and a quote or a line break would end it
  early and break the file for every variable after it.

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
