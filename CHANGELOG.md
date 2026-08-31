<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and the format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/):

- `Added` for new features.
- `Updated` for changes in existing functionality.
- `Deprecated` for once-stable features removed in upcoming releases.
- `Removed` for deprecated features removed in this release.
- `Fixed` for any bug fixes.
- `Security` to invite users to upgrade in case of vulnerabilities.

## Unreleased

### Added

- One kind of cartridge. `workbench.setup` — the task that composed the
  opinionated project — is retired and reborn as **chiefs_setup**, a
  *collection*: a cartridge whose installer inserts other cartridges.
  Its recipe (`members/1` in the manifest) is the old composition,
  trimmed to the picks that need no external account — the dep-only
  quintet, rest **or** graphql (`--interface`, the one choice the
  collection owns), coveralls, exdoc, enhancements and healthcheck —
  in the old composition order. auth0, openai and stripe stay à la
  carte, their old `implies` turned into `requires`: the installer now
  refuses, naming the missing box, instead of silently pulling it in.
  With setup gone the composed/standalone split dies with it: the
  behaviour loses `flag/enabled?/implies/argv/enabled_by`, the registry
  is one list in shelf order, and the catalog marks `collection` (with
  its members) instead of `standalone`/flag.
- `mix workbench.expand`: the planning half of `wb.sh add` — one
  `plan> NAME [ARGS]` line per install to run. A plain cartridge
  expands to itself; a collection to its missing members, read off each
  member's own mark. `wb.sh add` now expands first and inserts each
  line as its own container run and its own `Insert NAME` commit, so
  `eject` keeps reverting one cartridge alone — a collection leaves no
  commit of its own, and re-adding it only inserts what is missing.
- The design rule for collections, in the features README: a
  collection's option must be a decision the collection itself owns,
  explainable on the box without naming a member's switch; whoever
  needs a member's option inserts the member. The rationale is
  chiefs_setup's DESIGN.md.
- Four cartridges for what the retired setup configured, each the one
  decision it is, the first three joined to the chief's recipe:
  **ansi** (`config :elixir, ansi_enabled: true`, so logs read through
  Docker come out coloured), **toolchain** (`.tool-versions` written
  from the versions actually running the installer — `mix.exs` only
  carries a range — plus `/.elixir_ls/` in `.gitignore`: the two halves
  of working on the project outside the container), **versioning** (the
  initial version in `mix.exs` and the `CHANGELOG.md` opened at it) and
  **guidelines** (the team's coding conventions downloaded from `--url`
  into the docs site). guidelines builds on exdoc and *appends* its page
  to the two lists exdoc's `docs:` block keeps, which takes the only
  network call out of the exdoc installer.
- `--build` on exdoc and coveralls: generate the site, and run the
  suite, once the insert is applied — the `documentation` step the
  retired creation ran, as an option of the cartridges that own it.
  Queued (`Igniter.add_task/3`), off by default, and not in the chief's
  recipe: it needs the dependencies compiled and, for coveralls on a
  project with Ecto, a test database. `afterwards/0` on both names the
  command for whoever leaves it off.
- The generators and migration types (`migration_primary_key`,
  `migration_timestamps`, `generators: [timestamp_type: …]`) are back,
  inside **enhancements** rather than as a box of their own: they are
  the configuration half of its `--id-type` and `--timestamps`, and two
  cartridges writing one policy could contradict each other. Without
  them `mix phx.gen.*` kept emitting `phx.new`'s defaults, so the
  tables drifted from the schemas `MyApp.Schema` defines.
- Changelogs backfilled for exdoc, coveralls and enhancements, as the
  anatomy asks of a cartridge that predates the rule and gets changed.

### Removed

- `./wb.sh new` (opinionated) and `mix workbench.setup` (27 options,
  `config.conf`-driven): `new2`/`setup2` take their names — the vanilla
  creation is the only one. `config.conf` loses the whole "composed
  project configuration" section (`INIT_VERSION`, `ID_TYPE`,
  `TIMESTAMPS`, `INTERFACE`, `ENHANCE`, `EXDOC`, `COVERALLS`,
  `COVERAGE_THEME`, `HEALTH`, `AUTH0`, `OPENAI`, `STRIPE`,
  `CODING_GUIDELINES_URL`): features are cartridges now, and a
  cartridge's options are set on its own installer. What those
  variables configured has owners again — `versioning`, `toolchain`,
  `enhancements`, `coveralls` and `guidelines` — reached by inserting
  the box, not by editing this file.
- The retired setup's `README.md` template, with no owner: a generated
  README has to know every cartridge to list what the project carries,
  which is the coupling this structure exists to remove. `phx.new`
  writes one; the project writes its own from there.
- The entrypoint's `documentation` branch, which ran `mix docs` and
  `mix cover` after the opinionated creation: it is `--build` on exdoc
  and coveralls now.

- The workbench reads its own catalog. Every cartridge declares
  `installed?/1` — off the *same mark its installer's guard reads*, a
  module, a file or a dependency, so a status query and a re-run of the
  installer can never disagree — and the registry now lists the
  standalone cartridges beside the composed ones, so `catalog/0` names
  every one of them, stripe's pending manifest included. Two mix tasks
  read it: `mix workbench.catalog` (name,
  version off the cartridge's CHANGELOG.md, summary off its task's
  `@shortdoc`, flag, implied flags, the installer's options; `--covers
  DIR` adds which sealed box covers exist) and `mix workbench.status`
  (the same, plus what this project carries). Both take `--json`.
  Cartridges whose options take a known set of values say so with
  `choices/0` — ash's `--data-layer` and `--api` closed, `--auth` and
  `--with` open with what ash-hq.org offers, coveralls' `--theme` off
  its template directories — and the catalog carries them, each value
  with the one-line doc the cartridge gives it (the package a choice
  stands for, what a theme looks like), for a form to show beside it. So do
  `option_docs/0` (one line per option, from which the task shell's
  "## Options" section is now rendered — the docs and the catalog read
  one text) and `enabled_by/0` (what turns a cartridge on under setup
  when it is not its own flag: `:enhance` for the trivial group, the
  interface for rest and graphql).
- `./wb.sh catalog [--json]` and `./wb.sh status [--json]`: the front of
  those tasks, run on a bare toolchain container with the source and
  the workbench mounted — no compose, no database. `status` adds what
  the host knows: the workspace's ports, which deployments were baked,
  and the containers of its compose project (dev and prod share their
  service names, so the image is what tells them apart).
- Base cartridges: a capability `phx.new` decides at generation time,
  added after the fact. `WorkbenchIgniter.PhxDelta` generates the
  project twice with `phx.new`'s own generator, on a scratch directory —
  with the flags that describe it today, read off the project, and with
  the capability on — and merges the difference three ways onto the
  project's files (`git merge-file`), so the delta is what `phx.new`
  writes at the installer's version and the project's edits survive; a
  conflict leaves the file alone with `phx.new`'s version beside it.
  Every capability `phx.new` can leave out: `mailer` (Swoosh; mark: the
  `swoosh` dependency), `gettext` (mark: `gettext`), `ecto` with
  `--database postgres|mysql|mssql|sqlite3` (the repo, its
  configuration, the data case, plus `DATABASE_URL` — `DATABASE_PATH`
  on SQLite — in `.env`; mark: `ecto_sql`), `esbuild`, `tailwind`,
  `html`, `live` (mark: `config :phoenix_live_view`, the one thing only
  `--live` brings) and `dashboard`. A default project shows them all
  inserted.
- `NEED.md` in the cartridge anatomy: the developer's need the
  cartridge answers, in their situation and not the mechanism's — one
  sentence, then *Before*, *After* and *Not for*. `need/0` reads it off
  the file the way `version/0` reads the changelog; the catalog carries
  it (`need`), `mix workbench.catalog` and the console's shelf show its
  line instead of the task's `@shortdoc`, and the box art starts from
  it. Every cartridge has one, pending stripe included; the catalog
  test refuses one without. Written because the first eight base
  cartridge covers were proposed from the papers and came out as
  pictures of the engine with nobody's problem in them.
- A `DESIGN.md` for each of the eight base cartridges, written from
  `phx.new`'s generator and templates, the libraries' own installation
  guides and Phoenix's guides, with the engine's argument in mailer's
  and each cartridge's own decisions in its own. The READMEs say what
  each capability is, per those guides, and what the papers measured
  on real projects. Two engine faults the probes found are fixed
  (mailer v0.2.0): a file an earlier insert had written conflicted
  when the next capability appended at its end — Igniter writes one
  trailing newline, `phx.new`'s `AGENTS.md`, `errors.pot` and `app.js`
  do not — so the merge now normalises the three ends and insert
  order no longer matters; and a delta taken by a `phx_new` other than
  the one that generated the project conflicted on `mix.exs` for six
  capabilities out of seven, so the engine now refuses with an issue
  when the archive's version is not the `{:phoenix, "~> x.y.z"}` of
  `mix.exs`, or when `Phx.New` is not loadable at all. And the
  toolchain pins the installer: `PHX_NEW_VERSION` in `config.conf`,
  baked into the workspace's `Dockerfile.local` and into the toolchain
  image's tag (`workbench:<elixir>-<otp>-phx<version>`), so a new
  installer is a new image and a workspace keeps the one that made its
  project. Three smaller things the papers had listed as open are
  closed with them: `--no-agents-md` is read off the project, so a
  project that opted out no longer receives `AGENTS.md` from an
  insert; `phx.new`'s static placeholders under `priv/static/assets/`
  are taken away by esbuild and tailwind when untouched; and on a
  conflict `<path>.phx-new` is written beside the file rather than
  into the patch set the issue withholds. tailwind (v0.1.1) says when
  the build will lack html's LiveView compiler, live (v0.1.1) when the
  browser will lack esbuild's `app.js`.
- `requires/0` in the manifest: the cartridges one builds on, by name
  (live on html — `phx.new` generates live only with html). The
  installer refuses with an issue naming what to insert first; the
  catalog carries the list as `requires`. A choice value can say the
  same for itself (`{value, doc, requires}` in `choices/0`; ash's
  `--auth password` on live and mailer, `--with ash_admin` on live):
  the catalog carries it beside the value and the installer refuses
  the same way.
- `status --json` carries `phx`: the project's shape in `phx.new`'s
  terms — each capability, the database, the adapter, and the flags that
  would generate it today — read off the project as the base cartridges
  read it. The table says the flags too.
- The cartridges that adapt to what the project has of `phx.new`'s
  capabilities read it off the project (`PhxDelta.facts`) instead of
  asking: `enhancements` (the Ecto group; the page, dashboard and
  mailbox tests), `exdoc` (the database page) and `coveralls` (the
  components folder) lost their `--no-ecto`/`--no-html`/`--no-mailer`/
  `--no-dashboard` options, and `setup` no longer passes them. `exdoc`
  also lost `--openai` and `--stripe`, which nothing read. Every option
  left is documented (the catalog and the task docs say what each does).
- The console (`console/`, `./wb.sh console [up|down|logs|build]`): a
  Phoenix LiveView app run as a container with Docker's socket and the
  workbench mounted at its host path. It reads `status --json` and
  `catalog --json`, runs every action as a `wb.sh` job with its output
  streamed to a tray, and ports the mock's board, shelf, box and tray
  with the mock's own styles. First slice: Deploy (up/down per target,
  setup, bake), Cartridges (the shelf, a box's options, insert, eject).
- ash v0.4.0: `--data-layer` takes several, as ash-hq.org's checkboxes
  do; `mix workbench.ash.site` checks that the site still treats them
  as independent.
- `./wb.sh stacks [--json | -n N | use TAG]`: the usable technology
  stacks, asked of Docker Hub itself (recent `hexpm/elixir`
  `-debian-*-slim` tags, no RCs, version-sorted). `use TAG` checks the
  image exists (`docker manifest inspect`) and writes the three
  versions into `config.conf` — whose hand-kept tag list is gone: it
  was a cache that only went stale. The console's Config form shows
  four synced combos (stack ⇄ elixir · erlang · debian): the stack sets
  the three, editing one looks the exact tag back up, and a combination
  without a published image leaves the stack unpicked, the odd value
  saying so.
- `config.conf` is grouped by when a setting takes effect: what both
  creation commands read (name, stack, installer), git, the service
  images — and, at the end, what only the composed line (`new`) reads.
  CONFIG.md mirrors the grouping (and documents `COVERAGE_THEME`); the
  console's Config form tags each field honestly (`new · new2`,
  `every commit`, `every bake`, `toolchain build`, `new only`) instead
  of calling everything "new only". A comment block now belongs to
  whatever follows it with no blank line between — an `export` takes it
  as its help, a blank line leaves it to the section — so
  `GIT_IDENTITY`'s paragraph is the field's again and not the Git
  section's blurb, `POSTGRES_IMAGE_VERSION` keeps its link, and the
  notes a section closes with (there is no ports configuration, and no
  feature configuration either) are read at last, where they were
  dropped. A `# -- Group --` line inside a section is a heading in the
  form, not the help of whatever field came next.
- `console/0` in the manifest — the cartridges light the console up:
  the doors a cartridge opens on the app's port (exdoc `/dev/docs`,
  coveralls `/dev/docs/cover` with exdoc, rest `/dev/swagger` and
  `/dev/openapi`, graphql `/graphiql`, dashboard `/dev/dashboard`,
  mailer `/dev/mailbox`, ash `/admin` with `ash_admin`), the probes it
  answers (healthcheck2 `{path}/live` and `{path}/ready`, healthcheck
  `{endpoint}`), the tabs it turns on (clustering → Cluster). The
  catalog carries it as `console`; healthcheck2 reports the prefix it
  was inserted with (`state`). The console's board has a *Doors*
  section; the mock reads the same catalog instead of a table of its own.
- `afterwards/0` in the manifest: what follows the insert, when
  something does, as one sentence with the command (ecto's `bake`,
  clustering's scaled deployment, ash's `bake` with a database data
  layer). The catalog carries it, with `base` — whether the cartridge
  is a `phx.new` capability, in from birth unless left out.
- Console mock: the *New project* card offers the base cartridges as
  what they are — eight boxes in from birth, uncheck one to leave it
  out (`--no-x`; html takes live with it, as `phx.new` does) — with
  ecto's own options (`--database`, `--binary-id`: `phx.new` flags only
  Ecto reads, so the cartridge's) hanging from its box, and `--adapter`
  as the one generation-only choice. The *Afterwards* row of the box
  reads the manifest. It offers nothing else: `new` is vanilla and the
  card stops at creation — the collection is picked up from the shelf,
  like every other box.
- `./wb.sh bake`: bakes the workspace's `docker-compose.yml` again from
  the seed for the project as it is now, keeping its ports, as one
  commit — what `add ecto` asks for next (`setup` then creates the
  database). The compose drops the database and pgAdmin services on
  SQLite projects too, not only on projects without Ecto.
- Cartridges are commits. `new`/`new2` make the workspace's first commit
  (`New project: …`), `add` refuses a tree with changes git does not
  have and commits what it inserted as `Insert FEATURE …`, and the new
  `./wb.sh eject FEATURE` reverts that commit — refusing when the
  cartridge's files changed since, which is the honest answer. `./wb.sh
  commit [MESSAGE]` commits pending changes. All of it runs git inside
  the toolchain container, where the project's hooks can run mix, signed
  as `GIT_IDENTITY` in `config.conf` says: `user` (the host's identity,
  falling back to the workbench's own) or `workbench`. `status` reports
  the tree, HEAD and the inserts.
- The manifest says what a second run does — `rerun/0`: `:noop` (the
  default) or `:adds` (ash: every option is a package, so running again
  with more grows the install) — and `state/1`, what the project
  carries of an adding cartridge's options, read off the project;
  `status --json` carries both.
- `./wb.sh -y|--yes COMMAND` answers every confirmation (`new` over an
  existing project, `delete`), for scripts and for whatever drives the
  workbench without a terminal; `demo` hands it down.

- `assets/design/`: the house's design tokens, one source for every
  visual thing that is not a cover — a palette of four named values
  (the covers' violet and the seal's gold), roles with a light and a
  dark value (ground, surface, line, ink, muted, accent, the semantic
  three, the terminal, the service colours), and three type families by
  role. `build.py` projects them to `generated/tokens.css`, which the
  console mock now reads instead of a hand-written `:root{}`, and to the
  diagram-design skill's style guide, installed as the `workbench`
  profile the repository's `.diagram-design` marker names; `--check`
  fails when a projection is stale.

- `assets/diagrams/`: the cartridges' figures, one script for all of
  them. The clustering README shows the scaled deployment and the edge
  the cartridge opens inside it (Deployment); the ash README, what its
  queued command wires into the project (Architecture); the ash DESIGN
  §3.1, who writes what and when — why the cartridge's diff is empty
  (Sequence). Drawn to the diagram-design skill's rules with the house's
  skin, as SVGs that theme themselves with `prefers-color-scheme`; the
  console mock puts them in the page inline.

- The clustering cartridge's `DESIGN.md`: DNSCluster kept over
  libcluster and static names, the release pair in `rel/env.sh.eex`
  against `.env`, `vm.args` and the Dockerfile (the boot script sources
  it before applying its own defaults, and only there is the container
  address known), the four `release.init` templates from Mix's own
  functions with `mix release.init` queued as the fallback, the scaled
  compose's shared `app` alias against scaling the pod, why a workspace
  cannot cluster with itself and why one image means one cookie, and
  the mark `installed?/1` and `wb.sh` both read. Read against the
  sources — `dns_cluster` 0.2.0, Mix 1.19.5's release script, the two
  compose seeds, `wb.sh` — and the scaled deployment repeated on
  `test_28` with the output kept. Two README sentences it found
  imprecise are listed as open items. A second figure joins
  `assets/diagrams/clustering/`: the boot as a sequence, and what the
  same boot does without the block. The cartridge gets its
  `CHANGELOG.md` with it — v0.1.0 for what it has installed since
  2026-08-25, v0.2.0 for the manifest additions and the paper — so the
  catalog shows it versioned like the rest.

### Fixed

- `status` starts one container instead of four: its git queries run
  with the git at hand when there is one (the console's container has
  it; a host may), the toolchain container's otherwise — writes (commit,
  revert) stay there, where the project's hooks find mix — and the
  igniter query tasks compile the package and run in one Mix boot.
- `status --json` and `catalog --json` are valid JSON even when mix
  has something to compile on the way to the task — a dependency the
  last cartridge brought, the project, the package itself — which it
  prints on stdout before the answer: the readers keep from the first
  JSON line on.
- `add` compiles the igniter package before running the installer: as
  a path dependency on the mounted workbench, Mix did not always notice
  it had changed, and an installer edited since the last run could run
  in its previous form.

### Updated

- The README's *Architecture* section — a table of services and a
  diagram of one topology — is replaced by *The workspace*: what holds
  for every project (the workspace owns its orchestration, the pod
  pattern, the ports) and the orchestration files. The shape of a
  project is no longer described in one place, because there is no one
  shape: each cartridge's README says what it installs and wires, each
  deployment what it brings up, and `./wb.sh status` and `catalog` what
  is there and what could be. `assets/arq.svg` goes with the section.
- An existing workspace names itself: every command but `new` and
  `new2` reads the compose project name and the dev image from the
  workspace's own `docker-compose.yml`, not from `config.conf` —
  which may since have been edited to name the next project, and used
  to rename the one-off containers and the `:local` image `delete`
  removes.

- New `healthcheck2` cartridge (`./wb.sh add healthcheck2`): liveness
  and readiness probes as the first plug of the endpoint — the vanilla
  counterpart of `healthcheck`, in the sense `new2` is of `new`. A
  `MyAppWeb.Plugs.Health` answers `GET /health/live` with 200 while the
  VM answers, checking nothing else on purpose (an orchestrator
  restarts the container on that failure, and a restart does not fix a
  database that is down), and `GET /health/ready` with 200 or 503 from
  a `SELECT 1` on the repo with a one-second timeout, so a saturated
  pool fails inside the platform's probe window instead of hanging it.
  Mounted before `Plug.Static`, a probe never reaches `Plug.SSL`, the
  logger, the parsers, the session or the router. No dependency, no
  config, no router change; a `--no-ecto` project gets a readiness that
  answers like liveness. Its README carries the Kubernetes, Fly.io and
  AWS ECS wiring; its `DESIGN.md`, the reasoning behind the split.
- New `ash` cartridge (`./wb.sh add ash`): the Ash framework, with
  the choices of ash-hq.org's *Get Your Installer* for an existing app
  as options — `--data-layer postgres|sqlite|csv|none`, `--api
  json_api,graphql,typescript`, `--auth <strategies>`, `--with
  <packages>` for the site's *Advanced Options*, `--example` — turned
  into the command the site generates and queued to run once the patch
  set is applied: `mix igniter.install ash <data layer> ash_phoenix ...
  <flags>`. Every Ash package carries its own Igniter installer, so
  the cartridge writes no file itself and second-guesses nothing Ash
  does; packages the project already declares are left out of the
  command; with `--auth`, `TOKEN_SIGNING_SECRET` lands in `.env`
  (generated) and `.env.sample` (blank), the variable
  `ash_authentication` makes `runtime.exs` require in `:prod`.
  Standalone, on the vanilla line: the opinionated setup's own users
  table and Ecto scaffolding are what Ash replaces. Its `DESIGN.md`
  says why a queued command and not composed installers, and what the
  real run taught (the Phoenix auth installer's prompt).
- `WorkbenchIgniter.env_entry/4`: an optional body for `.env.sample`,
  so a cartridge can write a secret to `.env` and its blank line to
  the committed sample.
- Two files join the cartridge anatomy, `healthcheck2` being the
  reference for both: a `CHANGELOG.md` per cartridge (Keep a Changelog,
  semver over what the cartridge installs, independent of the workbench
  release), and a `DESIGN.md` — the design rationale in the shape of a
  short paper: problem, background quoting the primary sources, each
  decision against its alternatives, what was verified and what was
  not, open questions, numbered references. Older cartridges get both
  on their next change.

## v0.8.0 - (2026-08-24)

### Added

- New `new2` command: the vanilla project creation. It generates a stock
  `phx.new` project and applies only what the dockerized workspace
  requires to boot it — the dev endpoint bound to `0.0.0.0` (the compose
  pod pattern delivers the published port on the namespace interface,
  never on loopback), the `.env`/`.env.sample` pair the compose
  `env_file` declaration requires, and the `.env` entry in `.gitignore`.
  The application and feature settings in `config.conf` are ignored, so
  no base config, no `README.md`/`CHANGELOG.md`/`.tool-versions` and no
  feature installer: they are added afterwards with `add`. It is driven
  by the new `mix workbench.setup2` task (6 options, `composes: []`),
  and is the base for the ongoing restructuring of the igniter package.
- New `clustering` cartridge (`./wb.sh add clustering`): boots the
  production release as a named distributed node so DNSCluster can
  connect the replicas. `phx.new` already ships the `:dns_cluster`
  dependency, its supervision-tree child and the `DNS_CLUSTER_QUERY`
  read in `config/runtime.exs`; what it leaves open is the release
  running in distributed mode, which the cartridge writes into
  `rel/env.sh.eex` along with the other three `mix release.init`
  templates — generated from the running Elixir rather than copied into
  this repo — and `DNS_CLUSTER_QUERY` in the environment files. Nothing
  to cluster with inside a single-container workspace: it prepares the
  project for a multi-replica deployment.

- New `scaled` deployment (`up --deploy scaled`): production replicas of
  the release image, baked from `scripts/docker-compose.scaled.seed.yml`.
  It drops the pod pattern on purpose — replicas sharing a network
  namespace would share one IP and one port, so only the first would
  bind the server and every `RELEASE_NODE` would collide — and puts the
  replicas on a bridge network with one host port each and a shared
  `app` network alias, which makes Docker's DNS answer that single name
  with every address. Leaving the pod means the database is reached by
  name, so `DATABASE_URL` is overridden and a one-shot `migrate` service
  runs before the replicas start.
  With the `clustering` feature installed the replicas also form a real
  BEAM cluster, since that alias is what `DNSCluster` queries. Without it
  they run isolated — a valid deployment for a stateless application — so
  `up` and `build` warn and carry on rather than refusing, and the compose
  leaves `DNS_CLUSTER_QUERY` unset, keeping `DNSCluster` out of the
  supervision tree instead of letting it poll for peers a short-named
  release could never reach.
- The scaled deployment puts an nginx balancer in front of the replicas
  (single entry point, WebSocket upgrade for LiveView and Channels, and
  an `X-Served-By` header carrying the address of the replica that
  answered — the same address its node name shows). The per-replica
  ports stay published so a specific node can still be addressed.
  `up` and `build` take `--replicas N` (default 4) and `--no-balancer`;
  both only shape how the compose file is baked, so `logs`, `ps`, `stop`
  and `down` never need them. New `NGINX_IMAGE_VERSION` in `config.conf`.

### Updated

- `new2` no longer runs `mix release.init`. Its four `rel/*.eex` files
  are customization scaffolding whose defaults Mix already carries built
  in, and they now belong to the clustering cartridge. `new` keeps
  running it from the entrypoint, unchanged.
- Deployments are selected with `--deploy`, not `--env`: `up`, `build`,
  `logs`, `ps`, `stop`, `down`, `iex` and `bash` pick a compose file, not
  an environment, and the third value (`scaled`) is a topology rather than
  a `MIX_ENV`. The old spelling is rejected with a message pointing at the
  new one instead of being silently accepted. `setup` and `demo` keep
  `--env`, where the value really is `MIX_ENV`.
- `up` and `down` pass `--remove-orphans`. Every deployment of a
  workspace shares one compose project but not the same services — dev
  has `app`, the scaled one has `app1..N` plus `balancer` and `migrate`, and
  `--replicas`/`--no-balancer` change that set between runs — so the
  containers of the previous shape used to stay up, unmanaged and
  invisible to `ps`. `stop` and `ps` do not accept the flag.
- `new` and `new2` share their body in the `create_project` function,
  and the template planting, the `SECRET_KEY_BASE` generation and the
  new `env_entry/3` (the `.env`/`.env.sample` counterpart of
  `gitignore_entry/3`, so a cartridge owns its own variables) live in
  `WorkbenchIgniter`.
- The `.env` template no longer carries `DATABASE_URL`, `ECTO_IPV6` and
  `POOL_SIZE` in projects generated with `--no-ecto`.
- `DNS_CLUSTER_QUERY`, `RELEASE_DISTRIBUTION` and `RELEASE_NODE` left the
  `workbench.setup` `.env` template, where they sat commented out. The
  clustering cartridge owns them now, each where it belongs: the query in
  `.env`/`.env.sample`, the release pair in `rel/env.sh.eex`.

## v0.7.0 - (2026-08-23)

### Fixed

- Igniter features planted their files under module-derived directories
  (`Macro.underscore/1`), which diverge from the phx.new app-name
  directories when the app name carries digits (app `:lorem_3` →
  `Lorem3Web` → `lib/lorem3_web/` instead of `lib/lorem_3_web/`),
  forking a parallel source tree with duplicated modules whose tests
  mask each other. Every feature now derives `web_dir`/`app_dir` from
  the app name, exactly like phx.new.

### Added

- Igniter cartridges now hold only code: every non-code file — EEx
  templates, verbatim assets, binaries — moved from
  `lib/workbench_igniter/features/<f>/{templates,assets}/` to
  `priv/features/<f>/`, where nothing is compiled, so Elixir assets drop
  the `.asset` suffix (`cover.ex.asset` → `cover.ex`). `embed_templates`/
  `embed_assets` resolve the cartridge's `priv/features/<name>/`
  directory automatically.
- Coverage report themes for the coveralls feature: the excoveralls HTML
  template is now picked from
  `priv/features/coveralls/assets/template/<theme>/` in the igniter
  cartridge, selected with `mix workbench.install.coveralls --theme` (or
  `COVERAGE_THEME` in `config.conf`, forwarded by `workbench.setup
  --coverage-theme`). `custom` keeps the original report; the new
  `exdoc-ish` theme (default) mimics the ExDoc pages (sidebar with project logo and
  tabs, search-style file filter, light/dark synced with ExDoc's own
  setting, Lato and Remixicon reused from `doc/dist/`, coverage vs.
  minimum target cards, lines covered / missed / line hits stats).
- `mix cover`: a failing module is flagged with a leading ❌ in its
  `TESTING.md` heading, so broken modules stand out in the ExDoc sidebar
  (passing modules stay unmarked).
- `mix cover`: `COVERAGE.md` and `TESTING.md` merged into a single
  `TESTING.md` ("Test Suite Report"): execution result board, then the
  coverage section, then the per-module sections. The report links
  (overview and per file) point at the `/dev/docs/cover` route instead
  of `excoveralls.html`, and the report page moved to
  `/dev/docs/testing.html`.

- `wb.sh` lifecycle commands over the workspace compose, Makefile-style:
  `logs [SERVICE...]` (follow, Ctrl+C detaches), `stop`, `down` and `ps`.
- `build [-e, --env ENV] [OPTIONS]` command: (re)builds the workspace's
  app image without deploying it — the dev image from the project-owned
  `Dockerfile.local` (previously only `new` built it, destructively), or
  the production release image with `-e prod`. Extra OPTIONS go to
  `docker compose build` (e.g. `--no-cache`). The production compose
  baking moved into a `bake_prod_compose` function, shared by `build`
  and `up --env prod`.
- `wb.sh` session commands running on the **already running** app
  container via `docker compose exec` (instant, and exiting never stops
  the application): `iex` (IEx shell), `bash`, and `mix [ARGS...]` for
  any mix task (`cover`, `docs`, `test`...). With the system down, `mix`
  falls back to a one-off container, starting the database dependency.

### Updated

- `igniter/` is now the restructured cartridge edition: the legacy
  package and the first cartridge edition (`igniter2/`) were removed, and
  with a single edition left the `IGNITER_DIR` override is gone too.
  - Every cartridge is a directory with its own `README.md` — the
    dep-only ones (credo, mock, exdebug, psql_extras, osmon, githooks,
    exmachina, stripe) split into `<feature>.ex` + `task.ex` like the
    rest; the "single-file cartridge" format is gone.
  - One test file per cartridge: the parameterized `deps_test.exs`
    became `credo_test.exs`, `mock_test.exs`, etc.
  - `priv/assets/` disappeared: the DbSchema diagrams and Postman
    collections are text, so they moved into the enhancements cartridge
    (`assets/{db_schema,postman}/`, embedded like any other asset); the
    setup templates moved to `priv/setup/templates/`. `priv/features/`
    mirrors the cartridges for binary assets only (the exdoc logo).
    `WorkbenchIgniter.asset/1` was removed; cartridges reach `priv/` with
    the local `priv_asset/1` / `plant_binary_asset/3`, derived from the
    cartridge directory name.
- `up` now deploys **detached** (both dev and prod): the terminal stays
  free, and the command prints the application URL plus the `logs`/`stop`
  hints. Previously it followed the containers in the foreground and
  Ctrl+C stopped them.
- `demo` follows the logs between `up` and `delete`: the demo blocks
  while the application is tried out, and Ctrl+C moves on to the
  teardown (a no-op SIGINT trap keeps the script alive through the
  Ctrl+C that detaches the log follower).

### Removed

- `run` command (and its entrypoint branch): it was a workaround to run
  `iex` and mix tasks, superseded by the `iex`/`mix`/`bash` exec
  commands. Its blocking "Press any key" prompt is gone with it.
- `prune` command: it stopped ALL containers on the host and ran
  `docker system prune -a --volumes` — a machine-wide blast radius out
  of the workbench's scope. Workspace cleanup is covered by `delete`
  (`down --volumes --rmi local`) and the new `stop`/`down`.

### Fixed

- The generated `mix cover` task broke the production image build: it
  read `coveralls.json` at compile time (`File.read!` in a module
  attribute) and the production Dockerfile never copies that file. It
  now falls back to defaults when the file is absent — harmless, since
  releases carry no Mix and the task cannot run in them — and declares
  `@external_resource`, so editing `coveralls.json` recompiles the task
  (before, a changed `minimum_coverage` was silently ignored until a
  forced recompile). Fixed in both igniter editions and documented here
  because the asset ships into every generated project.
- Misleading guidance removed: comments in `wb.sh` and the compose seed
  suggested switching the workspace's `docker-compose.yml` to the
  production Dockerfile by hand. That breaks every toolchain command
  (`setup`, `add`, `mix`, `iex` run through the same app service) — the
  production deployment has its own `docker-compose.prod.yml`, baked by
  `up --env prod`. The entrypoint now also fails with a clear message
  when it lands in a mix-less production image instead of a cryptic
  "mix: command not found".
- `workbench.setup` (cartridge edition) now re-resolves the dependency
  lock — `deps.unlock --all` + `deps.get`, queued ahead of every feature
  task — instead of leaving the known phx.new-lock conflict (idna 7.x vs
  the `auth0_jwks`→hackney chain needing ~> 6.1) to the entrypoint's
  after-setup fallback. Igniter's automatic post-apply fetch tolerates
  that resolution failure, but the queued binary-asset task runs `mix`
  in the project and aborted setup on the unresolved deps, so auth0
  projects failed to generate. The moved medicine also fixes standalone
  `mix workbench.setup` runs without the workbench script.
- Binary assets are no longer routed through the igniter rewrite
  pipeline, which normalizes every file it writes
  (`String.trim_trailing/1` plus a final newline) and corrupts binaries
  — the planted ExDoc logo carried an appended byte, and a binary
  ending in whitespace-like bytes would have been truncated. The
  cartridge edition now plants them verbatim: a new internal
  `mix workbench.plant_asset` task copies the file byte-for-byte, and
  installers compose it via `WorkbenchIgniter.plant_binary_asset/4`
  (an `Igniter.add_task/3` after-apply step, so dry-run semantics stay
  intact). The legacy edition keeps the old behavior: it is on its way
  out once the cartridge edition proves itself.
- Internal container ports are no longer magic numbers: the `:4000` in
  the host-port parser and the `:5050` anchors now reference
  `APP_INTERNAL_PORT` / the new `PGADMIN_INTERNAL_PORT`, and the compose
  seed takes pgAdmin's listen port as a `%{pgadmin_internal_port}`
  placeholder.

## v0.6.0 - (2026-08-21)

### Added

- Generated Dockerfiles renamed to the conventional `Dockerfile`
  (production) and `Dockerfile.local` (self-contained local image). The
  local image is self-initializing (`mix setup && mix phx.server` on
  start), accepts `--build-arg MIX_ENV`, runs `mix assets.setup`
  explicitly, and no longer installs the `phx_new` archive; asset steps
  are omitted on `--no-assets` projects in both Dockerfiles.
- `workbench_igniter` Elixir package (`igniter/`): all project configuration
  is now applied semantically (AST-based) via `mix workbench.setup` and one
  `mix workbench.install.*` task per feature, with a 93-test suite.
- `wb.sh`: thin Docker wrapper replacing `app.sh`. New `add FEATURE`
  command to install features on an existing project.
- `WORKSPACE_PATH` (config.conf): projects are generated into a workspace
  directory (default `./_workspace`); the workbench stays permanently in
  its own directory and is mounted read-only at `/app/workbench`.
- Conditional `workbench_dep/0` injected in the generated `mix.exs`: the
  project stays self-contained when the workbench is not mounted.
- Each workspace owns its `docker-compose.yml`, baked with real values
  (name, ports, images) at creation — the source of truth of its
  orchestration. Host ports are auto-assigned (first available from 4000 /
  5050) so several workspaces run simultaneously without conflicts, and
  there is no ports configuration in `config.conf` anymore. The workspace
  services form a **pod**: a minimal `network` holder service owns the
  namespace and the published ports (the role of the "pause" container in
  a Kubernetes pod) and `app`, `database` and `pgadmin` join it — they all
  reach each other through `localhost`, so the project keeps Phoenix's
  default database configuration untouched and the database is not
  published to the host. The images are born with the identity of the
  launching HOST user (`ARG UID/GID` baked at build — they are always
  built locally): everything written into the workspace belongs to them,
  never to root, with no runtime `user:` configuration anywhere. The app image is project-owned (`<app>:local`, buildable from its
  own `Dockerfile.local`); the workbench seeds it as a zero-cost alias
  (`docker tag`) of the shared toolchain image `workbench:<elixir>-<otp>`. pgAdmin is fully self-contained (inline
  `configs.content` servers.json and entrypoint-generated pgpass). The
  workspace compose builds from the project-owned `Dockerfile.local`;
  switching to the production `Dockerfile` is a manual edit of the compose
  file. The workbench tooling (`Dockerfile.app`, `entrypoint.sh`) never
  leaves the workbench. The `setup` and `documentation` container runs no
  longer publish the application port.
- Generated `.env.sample`: same template as `.env` with the secret blanked
  out, meant to be committed (`cp .env.sample .env` flow). The generated
  README was expanded: table of contents, environment variables reference
  (deployment/required/default per variable, including the standard
  Phoenix release variables), asdf/mise setup from `.tool-versions`,
  Docker Compose start/stop instructions and, on `--exdoc` projects, a
  documentation section covering `mix docs`, `doc/` and `llms.txt`.
- `mix cover` now generates a structured markdown report instead of a
  terminal dump: coverage table per file with anchor links into the
  excoveralls HTML report and a totals row, ExUnit run metadata (seed,
  max_cases, timings), a totals summary table, one section per test
  module with per-test rows linking to the source line on GitHub
  (derived from the ExDoc `source_url` config, degrading to plain text),
  failure detail blocks, and skipped-test handling. The report is
  written to `TESTING.md` at the project root (gitignored; a placeholder
  keeps `mix docs` working before the first run) and the runner became a
  `mix coveralls.html` subprocess whose exit code participates in the
  validation. `coveralls.json` widens `file_column_width` to 128 so the
  parsed rows keep full file paths, and the generated `homepage_url` now
  reuses `repo_url` instead of inventing a domain.
- Generated outputs moved to the standard directories: the excoveralls
  HTML report goes to `cover/` and the ExDoc output to `doc/` (the
  defaults, already covered by phx.new's stock `.gitignore` and
  `.dockerignore` — so they neither pollute the repo nor ship in the
  production image, which used to copy `priv/static/doc` via `priv/`).
  `assets/` now holds only source files (the report template lives in
  `assets/cover/template/`), `Plug.Static` and the ExDoc controller
  serve `doc/` relative to the VM cwd (dev-only routes), and the test
  dummy pages are planted in plain `doc/` instead of `_build/test`. The
  gitignored `TESTING.md` entry is added via a shared
  `WorkbenchIgniter.gitignore_entry/3` helper.
- Coverage report template (`_style.html.eex`): added the unprefixed
  `border-radius`, `box-shadow` and `transition` properties (only the
  long-dead `-webkit-`/`-moz-` prefixed forms were present, so modern
  browsers rendered the report without those styles) and removed a stray
  quote inside the `#menu` rule.

### Removed

- `app.sh` and the whole sed/seed approach it implemented: `seeds/` (moved
  to `igniter/priv` as EEx templates and assets), `scripts/contexts/`
  (replaced by direct generation of the final schemas), the legacy `scripts/entrypoint.sh`
  (rewritten for the igniter flow), root `assets/` and `pgadmin/`
  (moved to `igniter/priv/assets` and setup templates), the
  `CUSTOM_SCHEMAS` configuration, the `*_CONTAINER_NAME` settings, and the
  generated `priv/repo/pgadmin/` credential files.

### Fixed

- Latent issues inherited from `app.sh`, corrected in the igniter port:
  healthcheck OpenAPI schema written over `user.ex`, `datbase.dbs` typo,
  helper tests coupled to Auth0, `mix db` failing on fresh projects,
  Finch pool missing on `--no-mailer` projects, Hex lock conflicts
  after feature installs, duplicated migration timestamps when composing
  auth0+openai, the database healthcheck passing the password as the
  database name (`pg_isready -d`), the application healthcheck always
  failing because `curl` was missing from the dev image, and flaky Hex
  fetches during image builds (`HEX_HTTP_CONCURRENCY=1`).
- Generated README no longer embeds the `.env` content — it used to leak
  the generated `SECRET_KEY_BASE` into a committable file; it now points
  to `.env.sample`. The env export instruction became
  `set -a && source .env && set +a` (the previous
  `export $(grep -v '^#' .env | xargs)` broke on values with spaces), and
  `.env` starts with `PHX_HOST="localhost"` instead of a placeholder
  domain that failed WebSocket origin checks locally.
- Markdown tables in the generated README were broken: EEx `:trim` leaves
  stray newlines around block tags, splitting conditional table rows with
  blank lines. Conditional rows are now rendered inline and `plant/5`
  collapses residual blank-line runs.

## Unreleased

> During development, milestones can be added to this section. Once finished working on them, it's only needed to copy the commented title template line, adjust the title version & date and uncomment it.
<!-- ## v0.0.0 - (0000-00-00) -->
### Added

<!-- # BETTER SERVICE STRUCTURE -->
- remove dev dockerfile even devinvoriment. the image must be compiled in prod, its very dangerous to have dev images with doc and source code in circulation, de docs coverage, monitoring must be run only in local

- ajustar parche en config.dev "localhost"

<!-- # CONTINUE -->
- Configuration file documentation.
- **Remove workbench** command in workbench script.
  - adjust docker-compose to work independently from script
- Workbench script implementation: **Stripe**.
- Workbench script implementation: **GraphQL**.
- Generated all missing documentation for functions in `app` script.

### Fixed

- DB port change breaks pgadmin maybe back?

## v0.4.2 - (2025-11-09)

### Added

- Different Dockerfile generation for `dev` and `prod` deployments.

## v0.4.1 - (2025-08-10)

### Added

- Project configuration completed with `mix release` generation files and suggested `.dockerignore` file.
- **Watchman** was added to the `Dockerfile.dev` configuration since the updated Phoenix version `1.8` uses it.

### Changed

- The **coverage report HTML styles** template was updated, with new CSS styles.
- The sections in **Testing Reports** were reordered.

### Fixed

- ExDoc unlocked from version `0.35` due error on **DomLoaded event listening**. With better understanding of the new front-end framework (`"swup"` and `"exdoc"` events), now the **Get Access Tokens** and **Database** sections in ExDocs does not need to reload the page to get the scripts works properly.
- Adjustments for elixir `1.18` support.
  - Deprecations on **CLI prefered envs**.
  - `lib/lorem_ipsum/application.ex` file changes.

## v0.4.0 - (2025-03-01)

### Added

- Workbench script implementation for **Auth0**.
- Workbench script implementation for **DbSchema** documentation.
- Mix task `mix db` to format _DbSchema_ database files for inclusion in _ExDoc_ documentation.
- Workbench script implementation: **AI Assistant** demo.
- Refinement of migrations and schema files (general post-implementation task).
- Complete unit testing with 100% success and coverage.
- Project code documentation.
- Functional API-REST documentation.
- Multiple _Postman Collection_ JSON files for different project configurations.
- Multiple _DbSchema_ SVG database diagrams for different project configurations.
- A uniquely branded application icon, instead of the temporary _ExDebug_ icon.

### Updated

- Redesigned architectural diagrams for different project configurations.
- Updated `Get access token` interface in _ExDoc_ documentation.
- If the project is configured without an **Ecto** implementation, the _Postgres_ database and _PgAdmin_ services will not be set up in the `docker-compose.yml` file.

### Removed

- Workbench script implementation: **Flame On**.
- Workbench script implementation: **ExMachina**.

## v0.3.0 - (2024-10-24)

### Added

- Generate `.tool-versions` file for [ASDF Version Manager](https://asdf-vm.com/) compatibility.
- Updating the workbench script version at the beginning of the file will update the version badge in the `README.md` file during the next script run.
- Workbench script implementation: **ExDoc**. The pages and content are adjusted following `config.conf` file.
- Workbench script in _ExDoc_ documentation.
- Multiple architecture images and content for different project configurations in the _ExDoc_ workbench documentation.
- Workbench script implementation: **Coveralls**.
- Mix task `mix cover` for test report generation for ExDoc.
- Workbench script implementation: **Healthcheck**.
- Workbench script implementation: **OpenAPI**.
- **Delete** command in workbench script.
- **Demo** command in workbench script.
- **Help** command in workbench script.
- Workbench script implementation: **Flame On**.
- Mix task `mix version` for update project version on `mix.exs` and `README.md` file.
- Workbench script implementation: **Ex Debug**.
- Workbench script implementation: **OS mon**.

### Updated

- `README.md` adjustments.
- Workbench script refactor.
- The workspace script and its files are moved to a subfolder, leaving the new project files in root directory instead of creating the project in a subfolder.

## v0.2.0 - (2024-10-07)

Second version after _Pitcher's_ testing cycle (Untracked changes).
