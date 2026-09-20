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

- **A box says which containers it brings.** The Spec of a box in hand
  gained a **Brings** row, beside Needs and Opens: the compose services
  the cartridge raises, each with its role's colour, the port it
  listens on and the deployments it enters. Once the cartridge is in,
  the project says it and the row repeats it, engine and all. While it
  is on the shelf there is no project to ask, so the row reads the
  catalog's new `offers` — every container the cartridge could raise,
  each with the choices it comes `with` — and lights the ones the form
  is holding, which is why the row moves with the switches instead of
  promising all four databases to a reader who has picked one. What no
  switch can bring is still shown, unlit, with the reason: a cartridge
  whose form is locked blames the state it went in with («ecto is in
  with database sqlite3»), not a switch nobody can move.

  `offers` is derived, never written down twice: the manifest asks the
  cartridge for `services(:any)` and then asks again one choice at a
  time, so the answer is the cartridge's own. That matters because the
  name in the compose is not the name of the choice — ecto's four
  engines all arrive as one `database`, and `--database sqlite3` brings
  no server at all, SQLite being a file, but the one-shot that makes a
  place for it. Where the choice decides something the service does not
  — the image and the port of `database` differ per engine — the menu
  says nothing rather than the first engine's, and the project that has
  the cartridge says it.

  The rows that name cartridges or containers — Needs, Inserts, Brings,
  Opens — now stand one item per line. Thirteen picks of a collection
  were a paragraph that wrapped; they are a list, and read as one.

- **A cartridge's promise about its own services is checked.**
  `services(:any)` is each cartridge's word that these are all of its
  containers whatever you choose, and two readers stand on it —
  `Compose.images/0`, which tells the workbench's images from a
  daemon's, and the catalog's `offers`. Neither would notice it broken:
  add an engine, forget the `:any` line, and the new image quietly
  stops being the house's while every test passes. A conformance suite
  now walks the real shelf and holds the promise to what the cartridges
  actually answer, in both directions.

- **The Record's flags cite their source.** The head of the «in
  phx.new's words» column is a link to `mix phx.new`'s page on hexdocs,
  which the column quotes — at the version that generated the project,
  off the Dockerfile's `PHX_NEW` stamp (phx_new and phoenix share a
  number, and hexdocs keeps a page per release), so the options read
  there are the ones this project had; the current page when there is
  no stamp. One link on the head, not one per row: every row points at
  the same page.

- **db_admin: the database admin in the browser, one box, four
  admins.** The fourth box of the shelf's migration (`SCRIPT.md`, the
  author's selection: db admin). pgadmin and adminer were one need —
  look at the database without its shell client — split by mechanism,
  the second written as the consolation for the first's refusal off
  Postgres. The box takes the admin as its option, `--admin`, one or
  several, a second run adding another (`rerun: :adds`), and brings two
  more: **phpMyAdmin**, MySQL's own, and **CloudBeaver**, DBeaver in
  the browser. Each admin declares which of ecto's databases it serves
  as a requirement on its value — `pgadmin` on postgres, `phpmyadmin`
  on mysql, `cloudbeaver` on postgres, mysql or mssql, `adminer` on any
  — read off ecto's `state/1`, so the catalog carries it per value and
  the console's form shows what the project's database does not serve
  unlit, with the reason; asked for anyway, it refuses the run with
  what the project has. For that a **requirement's state takes a list,
  met by any one of its values** (`database: ["postgres", "mysql",
  "mssql"]`), said as one ("ecto with database postgres, mysql or
  mssql") in the resolver and in the console, and the refusal of a
  chosen value is one function (`Feature.refuse_values/2`, ash's too).
  Without `--admin` the box is shaped by the database, as
  dashboard_extras is: the database's own admin where it has one,
  Adminer on SQL Server and SQLite, which have none. Every admin is a
  file the project owns — who signs in, on which driver, off the
  adapter — and a container the compose carries, told where the
  database is: phpMyAdmin's `config.user.inc.php` on the server its
  image has just made, its Apache moved to 8081 since the pod is one
  network namespace; CloudBeaver's `data-sources.json` mounted
  read-only where the image keeps the seed of a fresh workspace —
  because the server rewrites its live one — with three variables that
  skip its setup wizard, the connection granted to whoever opens the
  page, and its own switch for environment variables in a connection,
  so the compose says host, port and database. Not on SQLite, a driver
  its server ships disabled with no variable to enable it: the
  requirement says so and the DESIGN keeps what it would take. The
  project's files do not move, so a project that got pgAdmin or
  Adminer from the old boxes reads as carrying this one. Measured
  beside MySQL, Postgres and SQL Server in one network namespace, and
  in a copy of a live workspace: pgAdmin from the old box read as
  `admin: [pgadmin]`, phpMyAdmin refused on Postgres, Adminer and
  CloudBeaver added in one commit with the compose, the three
  answering. `PHPMYADMIN_IMAGE_VERSION` and `CLOUDBEAVER_IMAGE_VERSION`
  join `config.conf`. chiefs_setup picks it bare in place of pgadmin,
  and no longer stops there off Postgres (db_admin v0.1.0,
  chiefs_setup v0.5.0, 2026-09-18).

- **dashboard_extras: LiveDashboard's two dark pages, one box.** The
  third box of the shelf's migration (`SCRIPT.md`, the author's
  selection: dashboard enhancements). osmon and psql_extras were one
  need split by mechanism — an OTP application, a Hex dependency — and
  the second was closed to every database but Postgres while
  LiveDashboard had a library for three. The box lights OS Data
  (`:os_mon` in `extra_applications`, always) and Ecto Stats by the
  extras of the database the project is on, read off ecto's `state/1`:
  `ecto_psql_extras`, `ecto_mysql_extras` or `ecto_sqlite3_extras`.
  It is the state requirement read the other way: **shaped by the
  state, not refused for it** — with no database, or on SQL Server
  (which LiveDashboard has no stats for), it installs OS Data alone and
  a notice says why, and a second run adds the extras once there is a
  database (`rerun: :adds`). What it does require is `dashboard`:
  without it no sentence on the box comes true. The extras lose
  psql_extras' `only: :dev` — they go where `phx.new` puts the
  dashboard itself, every environment, so a dashboard taken to
  production is not dark there for a reason buried in a dependency's
  options. Two console doors, `os data` and (with ecto) `ecto stats`.
  What the research found, and the README says: `os_mon` does not only
  answer, it watches, and on a machine past 80% of disk or memory the
  app boots with `:alarm_handler` notices in the log; and the slowest
  queries on Postgres (*Calls*, *Outliers*) need `pg_stat_statements`,
  a server setting no dependency brings, so the NEED does not promise
  them. Verified on a real `phx.new` project against Postgres: before,
  OS Data greyed and Ecto Stats a card asking for a library; after,
  both pages with data, 31 queries on the repo. MySQL's and SQLite's
  extras verified as a patch and as a resolution beside LiveDashboard
  0.8.7, not on a running project. chiefs_setup picks it in place of
  the two, fourteen picks, and no longer stops there on MySQL
  (dashboard_extras v0.1.0, chiefs_setup v0.4.0, 2026-09-18).

- **version_manager: the host's pin is a box of its own.** The first
  box of the shelf's migration (`SCRIPT.md`, the author's selection:
  asdf/mise). toolchain held two capsules of knowledge — the
  `.tool-versions` a version manager reads and the `/.elixir_ls/` a
  language server leaves — and a project may want either without the
  other. The pin is `version_manager` now, with the manager as its
  option: `--manager asdf` (the default) writes `.tool-versions`,
  asdf's file, which mise reads too; `--manager mise` writes
  `mise.toml`, the file mise recommends over it. The option changes the
  file, so the file is the state: `state/1` says the manager back off
  the one that is there, and any version file of either manager
  (`.mise.toml` included) is the mark — never overwritten, and a
  project on mise is not handed an asdf file beside its own. What the
  split found: toolchain wrote `elixir 1.19.6`, and both managers
  install Elixir precompiled, where the bare version is the build
  against the *oldest* OTP that Elixir supports (asdf-elixir's README),
  not the Erlang pinned on the line above. The installer knows the OTP
  it runs on, so it writes `1.19.6-otp-28`. toolchain's `--elixir` and
  `--erlang` did not come along: typing the versions contradicts the
  file's one claim, and another pin is an edit of a file that is the
  project's. Read back by a real mise
  (2026.9.11, in a container) from both files; the names checked
  against asdf's listings. toolchain keeps the language server's
  ignore, its mark now that entry, its name and scope to settle in its
  own session; chiefs_setup inserts both, fifteen picks (version_manager
  v0.1.0, toolchain v0.2.0, chiefs_setup v0.3.0, 2026-09-18).

- **A requirement can name the state it needs.** `requires/0` took
  names, and a cartridge that needed more — pgadmin and psql_extras, on
  Postgres and nothing else — checked it by hand after the names, each
  with its own refusal. Now a requirement is a name or `{name, state}`:
  `{"ecto", database: "postgres"}`, read off the required cartridge's
  own `state/1`, the project as it is, born with it or inserted, never
  what an insert was asked. One resolver (`missing_requirements/2`)
  reads names and states alike and says what is absent and what is in
  but short; one refusal (`Feature.refuse/3`) writes the issue every
  cartridge used to write for itself, seven copies gone: "live builds
  on html, not in the project yet. Insert that first: ./wb.sh add
  html"; "pgadmin builds on ecto with database postgres, and this
  project's database is mysql". The remedy carries the state as the
  installer's switches. The catalog carries the names as `requires`,
  as before, and the states as `conditions`; the console's box says
  both under Needs and unlights Insert for a state the project lacks.
  The road to live as an option of html, and to a dependency on
  "html with live", is this (pgadmin v0.1.1, psql_extras v0.1.1,
  2026-09-18).
- **healthcheck2's option is tested by what the plug answers.** There
  is no phx.new to measure this cartridge against, so the rod is what
  it is for: the plug the installer writes is compiled and called
  (`Plug.Test`), under a name of its own per test. Every way of
  spelling `--path` — none, `/status/`, `status`, `/api/v1/healthz`,
  `//up//`, `/` — answers 200 at `<prefix>/live` and `<prefix>/ready`,
  with `no-store`, and nowhere else: not a deeper path, not another
  prefix, not the default's once it moved, not a POST. Readiness is
  the repo's answer — 503 when the query fails, raises or the pool is
  gone, never a raise — and liveness looks at nothing. The repo checked
  is the project's own on a project born with Ecto, none on one born
  without (phx.new's own `--no-ecto`, not a file removed by hand). And
  whoever reads the prefix back reads the same one: the project's
  state, the plug's own words, the test the project is given — which
  is parsed, on every shape and prefix. A second insert with another
  prefix leaves the first.
- **Every option of ecto is measured with phx.new's own flag.** A
  cartridge's tests looked for the strings someone thought of looking
  for (`binary_id: true` in `config.exs`, `:ecto_sqlite3` in `mix.exs`);
  now `add ecto --database mysql --binary-id` onto a project without
  Ecto is compared, whole and file by file, with the project phx.new
  makes with `--database mysql --binary-id` — the four databases, with
  and without binary ids, onto a project with everything else and onto
  a bare one, and no option at all against phx.new's defaults. And what
  an option means to the workbench, which phx.new knows nothing of, per
  database: what the project reports (`state/1`), the service it asks
  the workspace for, what that service is (image, port, its own client
  as the first shell), the `.env` line with the credentials the compose
  gives the server, the dev compose with the app waiting for it —
  SQLite asking for no server but a volume in a release, and
  `--binary-id` changing nothing of it. The rod is shared now
  (`WorkbenchIgniter.Grown`, in the test helper): born, add, grow and
  what may differ, said once for every cartridge that is to be
  measured this way.
- **Born bare and grown is born whole, as a test.** The experiment made
  by hand on 2026-09-17 — `./wb.sh new` with every `--no-*`, the eight
  base cartridges added one by one, against a plain `./wb.sh new` —
  which found a production Dockerfile without assets, a release
  without `bin/migrate` and a compose without its database, runs with
  the igniter's suite now (`grown_vs_born_test.exs`, seconds, no
  Docker): phx.new's own generator makes both projects, the installers
  run as `wb.sh add` runs them, each applied before the next, and the
  trees are compared file by file — then the project's shape, the
  services it asks for and the dev and prod composes. The eight go in
  in 13 440 orders (live and the dashboard build on html), so four
  layers, each at its price: a **covering set** worked out when the
  test compiles — every three cartridges in every order they can go
  in, since a conflict is born where cartridges write into one stretch
  of a file — with the orders that failed once pinned beside it; **five
  orders drawn by the run's seed**, so every run looks somewhere new
  and a failure prints the order to pin; **one step from a shape** —
  phx.new makes any subset outright, a cartridge goes onto it, against
  the next subset born: sixty of the 560 steps by the seed; and
  **all of them**, the whole tree of orders walked on every core with
  a shared beginning grown once, and the 560 steps, behind a tag —
  `mix test --only exhaustive`, before a release or after touching
  `PhxDelta`. What
  may differ is written down in the test and nowhere else: the secrets
  phx.new draws, how a file ends, the order of `mix.exs`'s lists and of
  `.gitignore`'s patterns, and the environment files a birth gets from
  `workbench.setup`. The igniter's test environment has
  `phoenix_live_view` and `ecto_sql` now: without what a grown
  project's `.formatter.exs` names, Igniter could not read that file,
  fell back on the default formatter and wrote `plug(:accepts)` — nine
  tests had been asserting that artefact, and assert what a real
  project gets.
- **`WorkbenchIgniter.ComposeFile`: the compose files have a module of
  their own**, as `mix.exs` has `MixFile` — the first step of giving
  each service back to the cartridge that needs it. Today a service is
  a name in its cartridge (`services/1`) and everything else somewhere
  else: its block in two central templates, its port and version in
  `Compose.Plan`, a flag of its own in three bakes of `wb.sh`, a
  variable in `config.conf`. The module holds both halves of working
  on that file as text (Igniter has nothing for YAML, and a parse and
  an emit would lose the comments a baked compose explains itself
  with). **Read**: `services/1`, the names a file declares
  (`Deployments.declared/1` delegates to it); `published/1`, the ports
  each service publishes, which the console's Record had a parser of
  its own for and now asks here; `host_port/2`, the host port a file
  publishes a container's port on. **Written**: `ComposeFile.Service`,
  what one service contributes — its block, the ports it publishes
  with their comments and defaults, what the app waits for because of
  it, its top-level volumes and configs, the deployments it enters —
  `slots/3`, which gathers the contributions of a deployment's services
  into the text of each slot of a skeleton, and `host_ports/3`, which
  keeps each port where the file already has it and asks the host for a
  free one only for the new.
- **A service is defined in the cartridge that needs it, whole.** A new
  callback, `compose/1`, beside `services/1`: for the names the
  cartridge asks for, what each is in the file being rendered — a
  `ComposeFile.Service`. The YAML lives with the cartridge, under
  `priv/features/<name>/compose/pod/` and `scaled/` (`embed_compose/0`,
  which trims nothing: a fragment is the file's text). **ecto** owns the
  three servers, the release's one-shots (`migrate`, MSSQL's
  `create`, SQLite's `volume_init`), what the app waits for, the
  data volume and the `DATABASE_URL` of the bridge network; **pgadmin**
  and **adminer** their block, their port on the pod and pgAdmin's
  config; **k6** its block on both topologies; **monitoring** Prometheus
  and Grafana, their configs, Grafana's port and what the app owes it
  (the wait, `GRAFANA_HOST`). A fragment reads the whole context
  (`Compose.context/1`), so a service sees its neighbours: k6 writes to
  Prometheus when it is there, Adminer opens the engine the project has.
  The two templates under `priv/compose/` are skeletons now — the pod
  and the app, the replicas and the balancer — with seven slots
  (`ports`, `services`, `app_waits`, `app_volumes`, `app_environment`,
  `volumes`, `configs`); `position` orders the services in the file.
  `Compose.service_names/2` is read off the same contributions instead
  of a list of names kept beside the templates. Not one byte of any
  compose changed: the 40 golden files pass as they were, and a bake of
  a workspace born whole said "nothing to bake".
- **No service is named outside its cartridge any more: ports and
  versions are generic.** `mix workbench.compose` lost its eighteen
  per-service flags (`--pgadmin-port`, `--grafana-internal-port`,
  `--postgres-version`…) for two, as many times as there are:
  `--port NAME=PORT` and `--version NAME=TAG` — the cartridge has the
  default tag, in its fragment, and the port its service listens on.
  A port lives in the file that publishes it: `--keep-ports-of FILE`
  keeps the ones the deployment's file already has, so a bake moves
  nothing, and one that comes from nowhere is a **need** — the task
  writes nothing, prints `need> NAME DEFAULT` and exits 3 — because
  free is a question for the host. `wb.sh` answers it in one place,
  `compose_render`, which the three bakes go through: the first free
  port from the cartridge's default on, then the task again. Its
  `version_flags` hands over every `NAME_IMAGE_VERSION` that
  `config.conf` sets, so that file reads as before. Gone from the
  script: the three `*_INTERNAL_PORT`, `workspace_pgadmin_port` and
  its two siblings, the ports of `compose_ports` and of `new`. The
  status's `ports` is `{"app": N, "published": {"5050": 5051}}`, by the
  port each service listens on, and the report for a person labels a
  door with the file's own word for it — a cartridge opens the comment
  over a port with what it is (`# pgAdmin port, …`). What
  `WorkbenchIgniter.Compose` knew of databases went to **ecto**: one at
  most, none on SQLite for replicas (`compose/1` may refuse a set of
  services, with its reason), and `Ecto.database/1`, which Adminer asks
  to say where the database is. `ComposeFile.Service` has `listens`, the
  port a service answers on inside; `Compose.brought/2` says, per
  cartridge, the services it brings with that port and the ones
  published — in the catalog (`compose`, whatever the state) and in the
  status (as the project has them: ecto's `database` on 3306 for MySQL).
  The console's Record reads them there: its table of internal ports,
  which said `:5432` of any database, and its list of which cartridge
  has which service are gone. Verified on a copy of a workspace:
  pgAdmin inserted and baked took 5050 through the need; moved to 5077
  by hand in the file, it stayed there through the next bake, which
  gave Adminer 8080. The 40 golden files still pass byte for byte.
- **One module per project file Igniter has nothing for.** Beside
  `MixFile` and `ComposeFile`: `WorkbenchIgniter.EnvFile` (`entry/4`, a
  cartridge's variables into `.env` and `.env.sample`, the secret and
  its blanked-out line), `WorkbenchIgniter.IgnoreFile` (`entry/3`,
  `merge/3` — the set merge that ended the `.gitignore` conflicts — and
  `ignore_file?/1`) and `WorkbenchIgniter.Dockerfile` (`stack/1`, the
  stack read back off the production Dockerfile, and `binding/2`, as
  each Phoenix's template names it), over `WorkbenchIgniter.TextFile`,
  the append-once the first two share. They were `env_entry/4` and
  `gitignore_entry/3` in the package's root module, and `merge_set/3`,
  `docker_of/1` and a private binding inside `PhxDelta`, which is back
  to what it is about: asking phx.new what a capability is. No
  delegates left behind; the cartridges call the modules. Each has its
  own test file now. No behaviour changed.
- **A cartridge's commit carries the services it brings, and its
  eject takes them away.** The old script wrote the compose in the same
  act as the project, knowing what it had; since the cartridges, an
  insert committed and the compose waited for a `bake` nobody
  remembered (a project grown cartridge by cartridge came out without
  its `database`, 2026-09-17). `wb.sh add` now renders the workspace's
  compose files again — dev, and prod and scaled when they are baked,
  the scaled one with the replicas and the balancer it has — after the
  installer and before the commit: one commit is the whole cartridge.
  `eject` stages the revert, renders them again for the project without
  the cartridge, and commits the two as one `Revert "Insert …"`. A
  compose is a derived file, so it is never reverted as text: a
  cartridge inserted since wrote its block right beside, and the revert
  conflicted — a conflict on the workbench's own composes alone is
  settled by keeping the file and rendering it. **A compose the reader
  edited is left alone**: `compose_is_ours` asks git, and no container,
  whether the last commit that touched the file is the workbench's
  (`New project:`, `Bake`, `Insert`, `Revert "Insert`); one that is not
  is named in a note at the end, when it is behind, with the way out —
  `bake` writes it again, keeping its ports and nothing else of the
  edit, and the file is the workbench's from then on. A render that
  fails leaves the file as it was and does not undo the cartridge. The
  scaled bake keeps its ports too now, as the other two did, while it
  is asked for the same shape: a bake moves nothing, and a deployment
  that is up is not handed ports it does not hold. The cartridges'
  after-insert words no longer send the reader to `bake`. Verified on a
  copy of a workspace: pgAdmin and Adminer each in one commit with the
  compose; pgAdmin ejected from between them, the conflict settled by
  the render; a hand-edited compose left alone by `add k6`, then taken
  back by `bake`; k6 ejected from the dev and the scaled file at once.
- **The console knows no cartridge's service by name: a service says
  what it is, and a colour is a role's.** What was left in the console
  was not presentation but knowledge kept by name — which containers
  take a session and with what, their order, their colour, which
  images are the house's — and a service from a cartridge nobody here
  has seen would have had none of it. `ComposeFile.Service` carries it
  now: a `title`, the `shells` a session can be (a label and the
  command; none for k6, which runs to completion) and a `role`, one
  word of the vocabulary the clouds sort their own services by
  (`ComposeFile.roles/0`: compute, database, cache, storage, messaging,
  search, network, observability, identity, devtools, job). The image
  is not declared: it is read off the service's own block
  (`ComposeFile.image/1`). `Compose.brought/2` hands all of it over,
  per cartridge, across the three deployments (`deploys`), and
  `Compose.images/0` is every image the house may run — the skeletons'
  and each cartridge's, whichever name a project asks by
  (`services(:any)`: ecto answers one per engine). In the console,
  `ConsoleWeb.Services` is the one place that answers: the terminal's
  targets, shells and argv, the order of Docker's containers, the
  house's images and their Hub links, and the colour of a service in
  logs, events and sessions. **A prompt is derived, never declared**:
  for `sh` and `bash`, the user and the directory the container's
  image says (`homes`, new in `wb.sh status --json`, off `docker
  inspect`; no user is root, as `docker exec` has it); for anything
  else, the command's name (`psql> `). The `svc-*` tokens are by role —
  `svc-compute`, `svc-database`, `svc-devtools`, `svc-observability`,
  `svc-network`, `svc-job`, and the balancer's own — several roles on
  one token until one needs telling apart, the plainest for a role or
  a container the console has not heard of; the logs' hook reads the
  answer off the page (`#svc-colors`) instead of a list of its own.
  Fixed on the way: a MySQL or MSSQL project was offered `psql` and
  shown `postgres=#` (ecto now says `mysql`, `sqlcmd`); Prometheus and
  Grafana asked for colour tokens that did not exist; the events
  still matched the pod by its old name; every `*_IMAGE_VERSION` but
  two was labelled "new" in the config drawer, where all take effect
  at every bake. The console names three services still, on purpose:
  the skeleton's `app`, `pod` and `balancer`, which are no cartridge's.
- **Remove on the Docker screen's images and volumes.** Each row of
  Images and of Volumes has a Remove, `./wb.sh prune NAME…` — every
  name an image wears, a volume's — confirmed in Jobs like the other
  prunes; unlit, naming them, while a container uses or mounts it —
  the console's own on the workbench's image and build volume — since
  docker would refuse it too, and while a removal is already asked. A
  volume's title and confirmation say what an image's need not: its
  data goes with it and does not come back; that is the way to start a
  project's database clean without deleting the project, after a
  `down`, since a stopped container still mounts it. `prune NAME…` is
  the verb, refused on the same ground from the terminal, and an
  image's row knows its users off `container inspect`.
- **The console restarts itself.** Restart on its own row of the
  Docker screen was refused ("./wb.sh console starts it again, from
  the host"); it runs `docker restart workbench_console` now, sent to
  the daemon from a process of its own so it is carried out whether
  the console lives to see it, and the page reconnects when it is
  back. The container keeps its image, mounts, env and port: a new
  image or another workspace is still `./wb.sh console` from the host,
  as the console says where it applies.
- **The `project-design` skill.** How a project the workbench hosts is
  designed before it is generated, from the business to the shelf:
  the criteria that hold across the steps in its SKILL.md — every step
  opens with its terms, its shape and one example; the author knows
  the floor and is asked through scenarios; the glossary is the door
  and the process a loop; the drawer of questions no story names;
  ownership and language; where the workbench stops — and one brief per
  step in `references/steps.md`. Written from `DESIGN_PROCESS.md`, the
  draft of the first run, which retires with it (2026-09-16).
- **The reference project's design, run once end to end.** Plant
  maintenance, a light CMMS on Ash for the industry around Querétaro:
  its papers are in `reference/` — the stories and the glossary in the
  plant's Spanish, the events, the rules with their examples, five ADRs,
  the three Ash domains with resources, actions and policies, and two
  entity diagrams drawn with the workbench's script from a script of
  the project's own. `SCRIPT.md`, at the root, is the crossing with the
  shelf: twenty-four steps against the box that answers each, what is
  domain code, what is missing, and the nine chapters of the series.
  Its findings went to RELEASE_PLAN.md: no collection for the Ash
  line, `ash --with ash_oban` for the reference, the shelf to say which
  line a box is on. Every step's finding is in `DESIGN_PROCESS.md`,
  the draft the design skill is written from (2026-09-15/16).
- **The terminal's colours are the reader's.** Under the Interface
  tab's Terminal fold, beside its face: the terminal's ground,
  ink and dim, and the six ANSI colours a line wears — red an error's,
  yellow a warning's — and the lines' grounds, the wash under a line
  of error and one of warning on Logs and the tint of the line under
  the pointer (the diff's hunk head wears it too), each a hex the sheet
  lays at its share: twelve swatches a ground, kept in this browser
  (`wb-console-term`) and written on the root over `tokens.css`, so
  every terminal surface takes them: the jobs' output, the logs, the
  Terminal screen, Docker's events, and the miniature's terminal, where
  the change shows. They travel in the interface's file under
  `workbench.colorCustomizations` by VS Code's own names
  (`terminal.background`, `terminal.ansiRed`,
  `editor.lineHighlightBackground`, …; the two washes under
  `dew.terminal.errorLine` and `dew.terminal.warningLine`, which are
  this console's), so a VS Code theme pasted in dresses the terminal
  too.
- **The interface as a file.** The jsonc that was the syntax
  palette's, under Language Syntax, is the whole interface's now, in a
  section of its own under the three folds: the overlay under
  `dew.interface` (the band's side, the rail's, the ground), the
  diff's four and the terminal's nine under
  `workbench.colorCustomizations` by VS Code's names for them, and
  every language's palette under
  `editor.tokenColorCustomizations` as before. Read mine reads it out
  for this ground; Apply takes what a pasted one has — this file's, or
  a VS Code theme's `tokenColors` and `colors` — the ground first, so
  the colours land where the file meant them.
- **The Interface tab folds in three, one a surface.** Its controls
  sit under three heads that fold as the rail's sections do, the
  chevron square at the end of each: Overlay, the frame and the
  ground; Terminal, its face and its colours; Files, the files' face,
  the syntax palette and the diff's four. Which are folded is kept in
  this browser (`wb-console-ui-folds`).

- **Restart on the rail's containers.** A second button on each
  container's row, beside Logs — the shell's went (2026-09-16: the
  Terminal is where a session is opened, the rail says what runs) and
  the row's columns size themselves now, the name taking what the
  chip and the two buttons leave — the Docker screen's one act on a
  single container brought
  to the rail: `./wb.sh restart --deploy
  DEPLOY SERVICE`, the same service and image up again with the
  deployment whole. Unlit with the reason while the container is not
  running, while a job on the deployment runs — a restart counts as
  one now, for the Deploy tab's buttons too — and on the pause
  container, whose network namespace the others share.
- **The diff's colours are the reader's.** A Diff section under the
  Interface tab's Files fold, after the syntax palette, in two groups, Added and
  Removed, of two swatches each: the code's ground, and the colour of
  its line number, which the sign wears too. Four a ground, kept in
  this browser as the palettes are (`wb-console-diff`) and applied as
  `--diff-<key>` on the root, which the Files sheet's diffs and the
  tab's own sample read. The code wears its ground at 66%, the
  terminal showing through, and the number's plate wears it whole,
  where the plate wore the line's wash at half strength and the sign
  the house's good or bad. The dark ground's four are set: code
  `#00212d` and line number `#529fc7` for an added line, `#3f0600` and
  `#db5a5a` for a removed one; the light ground keeps the two numbers
  and washes the code pale, `#c0eeff` and `#ffd6d2`.
- **Ctrl+C interrupts in the Terminal tab.** With nothing selected, the
  key stops what the session runs: under bash, sh or rpc every process
  the shell started gets SIGINT and the shell stays, as a terminal
  signals its foreground job; iex opens the BEAM's BREAK menu, `c` to
  go on and `a` to leave, and psql cancels its query. With text
  selected, in the input or on the screen, Ctrl+C is still Copy, and
  Ctrl+Shift+C and ⌘C always are. A session is a pipe, with no terminal
  to turn the key into a signal: its command now prints the PID `exec`
  hands it on a line the screen never shows, and the console signals
  that PID with a second `docker exec` in the same container, finding
  the processes under it through `/proc`, since the slim images carry
  no `pkill`. The workbench's one-off container has a name for that. A
  session opened before this has no PID to signal, and the key does
  nothing there (2026-09-15).
- **A release plan.** `RELEASE_PLAN.md`, at the root, is the plan to
  publish the workbench as a portfolio piece and the checklist of what
  is left: land the branch on `main`, prune the shelf, the `ci`
  cartridge, the README for the 90-second reviewer, the profile site,
  the console in exhibition mode over a recorded workspace, and the
  series. It retires with the release: what is still open then moves
  to issues, and the file goes. Its Phase 0 (2026-09-15) is a
  reference project, a multi-tenant SaaS on Ash in a domain of the
  author's, whose script — each step, its need, the box that answers
  it — the shelf is pruned against; it already names three cartridges
  for after 1.0: a collection for the Ash line, stripe finished, and
  `agents`. `DESIGN_PROCESS.md`, beside it, is the draft of the design
  process that project is run through: one dated entry per finding,
  the raw material of a design skill written after the first run. Its
  first entry: a step opens with its terms, the shape of its
  deliverable and one filled example, before any creative work — the
  three senses of *domain* told apart, and the candidates table.
- **Insert and Eject on the shelf's rows.** The last column of the
  Inserted list ejects the row's cartridge — the bare `eject NAME`,
  unlit with the reason when the tree is dirty, when another cartridge
  builds on it, when it came in from birth or by hand and left no
  commit to revert, or when it is a collection, whose eject is its
  box's — and On the shelf and Not done lead to theirs: the row's
  Insert opens the box on its Installation screen, where the options
  are picked and the box's own Insert says what it runs, or why it
  cannot. It sent the bare `add NAME` for a day (2026-09-10), unlit with
  the reason; a verb with options to pick is pressed where they are,
  and the screen reads for every box, the one without an installer
  included. The rows are no longer links, as the Inserted rows were
  not: the mention opens the box.
- **On the shelf and Not done read in the Inserted list's table**,
  columns included: the parameters each cartridge takes with their
  type — or their values, when the cartridge declares choices
  (`postgres | mysql | mssql | sqlite3`; an open choice ends in `…`, a
  long one shows four and the count, the whole list in the title) —
  and the addresses it would open, shut, `not inserted` for the
  reason. The summary rides on the name's title.
- **Every job wears its number**, `#7`, first on its row and on the
  tray's bar: this console's jobs from 1, in the order asked. The id
  names the job in the DOM and the queue; the number is what the
  reader counts by.
- **A conformance suite for the cartridge contract**, beside the
  catalog test that already installs every cartridge and checks its
  mark lights for it alone. Every cartridge with options is inserted
  with values none of which is the default and asked what the project
  carries: `state/1` must answer with exactly the schema's keys and say
  each value back, or `nil` for an option that leaves no mark, listed
  in the suite with its reason (`--build` runs once and its output is
  gitignored; exdoc's `--version` stamps the gitignored `doc/` dummies
  only; guidelines' `--url` is kept nowhere once the page is
  downloaded; auth0's and openai's `--project-name` are read by no
  template; enhancements' `--stripe` plants the auth0 diagrams). A
  cartridge with options and no run in the suite does not compile it.
  The composition side: the installer's source is scanned for every
  `compose_task("workbench.install.…")`, which must be declared, and
  what lights up beside a cartridge must be accounted for by its
  `requires` and `composes` — the hand-kept list of who brings whom
  is gone. And `mix workbench.dependents` has a test at last, on an
  in-memory project, through its walk made public
  (`Mix.Tasks.Workbench.Dependents.dependents/2`).
- **The adminer cartridge**, à la carte beside pgadmin as healthcheck2
  is beside healthcheck: Adminer on the workspace's database whatever
  the adapter — Postgres, MySQL, MSSQL, SQLite — on its own port, the
  first free one from 8080. The project owns the login it opens with,
  `adminer/login.php`: one Adminer plugin fixing the server and the
  driver off the adapter, filling the user and the database in, and
  holding the password Adminer checks itself (`pass`; on MSSQL, sa's
  own) — which Adminer 6's own rule makes necessary, since Postgres
  trusts 127.0.0.1 inside the pod, MySQL's root has no password and
  SQLite none at all. Where the database is and which one to open are
  the deployment's, handed over by the compose as `WORKBENCH_SERVER`
  and `WORKBENCH_DATABASE`; on SQLite the container mounts the file and
  runs as its owner. `ADMINER_IMAGE_VERSION` in `config.conf`,
  `--adminer-port` and `--adminer-version` on `mix workbench.compose`,
  the container in the console's lists and the Record's ports. The
  login was measured through the image on all four servers (the
  cartridge's DESIGN.md).
- **The Record paper, first on the Project tab.** What the project is,
  drawn off the status and nothing else, in three tenses. *Birth*: the
  toolchain and installer stamped in Dockerfile.local, the `mix phx.new`
  that generated it, and each flag with whether it was given, its
  argument, phx.new's own words and the base cartridge that owns it —
  all read off the first commit (`project.birth`), with a warn `now …`
  on any fact that moved since and `installer now …` when the
  toolchain's phx_new is not the generator. *Cartridges*: the shelf's
  own row — cover, mention, origin, edition — with the installation
  parameters as the flags `add` took (a default dimmed) and every
  address the cartridge opens, a route on the app's port with what it
  answered when the console called, or the port of the service it asks
  for with what `docker compose ps` says of it; the reload button in the
  column's head calls every route again. *Deployments*: dev, prod and
  scaled, each with its compose file
  baked, out of sync or not baked, the in-sync check with what is stray
  or missing, up or down, and its services as ports. `ConsoleWeb.Record`
  is the plan, `ConsoleWeb.RecordSheet` the sheet; Doors, the paper,
  retires into it, and `ConsoleWeb.Doors` keeps only the call. The
  ribbon reads Record · .env · README · CHANGELOG, Record's sublabel the
  first commit's sha. The layer classes on `.door-ref` are `door-route`,
  and `door-port`, prefixed because `.console` is the
  LiveView console's own root.
- **`mix workbench.status` publishes the birth and the deployments.** Two
  more facts the Record paper reads, both from what the project already
  has. `birth`, off the first commit and never inferred
  (`WorkbenchIgniter.Birth`): the sha, date and subject, phx.new's shape
  as generation left it — the same marks `PhxDelta.facts/1` reads today,
  now also readable off text, `facts_of/3`, for the files `git show`
  hands over — and Dockerfile.local's four stamps then; null for a
  project not born in a workspace. `deployments`
  (`WorkbenchIgniter.Deployments`): each compose file beside the
  project, baked or not, the services it declares, and whether it is in
  sync with what the cartridges ask for now — the names
  `Compose.service_names/2` renders for those asks, off the templates'
  own conditions — with what is stray or missing when it is not. Asked
  of test_001 it says what nobody had seen: the prod file still declares
  prometheus and grafana after monitoring's revert, which `compose_behind`
  cannot see because it bakes and compares the dev file alone. The text
  report says both in a line each.
- **A decision page for the Project tab's Record paper.**
  `console/el-estado-del-proyecto.html`, drawn on `_workspaces/test_001`
  as it stood on 2026-09-08, settles where a project's state is read and
  shown. The finding: there is no state file — the truth is the
  project's own code and git, Dockerfile.local, the baked composes and
  Docker, joined only by `status --json` — and the Deploy card had been
  mixing that with config.conf's intention. The paper, **Record**, first
  on the Project ribbon and drawn off the status like Doors was: *Birth*,
  read off the first commit and never inferred (the toolchain and
  installer stamped in Dockerfile.local, the `mix phx.new` command and
  each flag with its value, phx.new's own words and the base cartridge
  that owns it, a warn `now …` where a fact has moved since);
  *Cartridges*, the shelf's own row plus the installation parameters as
  `add` flags and every address the cartridge opens; *Deployments*, the
  console first and then dev, prod and scaled with their compose file's
  state, whether it is in sync with what the cartridges ask for, and
  their services. What it decided on the way: doors and probes are one
  face — `probes:` leaves the manifest, since the project owes the
  workbench nothing — with the reading attached inside the border and
  an 8px square for the layer (a port the compose publishes, a route
  the project offers, the console); a `.commit-ref` for every sha,
  opening History on that commit; Git's two documents fold into the
  Project tab; the service is named by its role, `database`; and
  test_001's prod compose is out of sync for real — it still declares
  prometheus and grafana after monitoring's revert, which
  `compose_behind` cannot see because it only compares dev.
- **Monitoring: PromEx, Prometheus and Grafana.** Step 5 of
  `scripts/PLAN.md`, the **monitoring** cartridge. In the app, `prom_ex`
  and a `MyApp.PromEx` module with the plugins the project's shape calls
  for — Application, Beam and Phoenix; Ecto with a repo; LiveView with
  `phoenix_live_view` — first in the supervision tree, its `/metrics`
  served by the endpoint before `Plug.Telemetry`, off in test, and the
  Grafana client read at runtime off `GRAFANA_HOST`. In the workspace,
  the `prometheus` and `grafana` services the compose renders: Prometheus
  on the app's `/metrics`, Grafana on Prometheus, published beside the
  app's port (the first free one from `3000`), anonymous as admin so the
  door opens without a form, and healthy before the app starts, so the
  dashboards PromEx uploads on start find it there. Each container opens
  with a file the project owns, `monitoring/prometheus.yml` and
  `monitoring/grafana/datasource.yml`; what is the topology's the
  compose writes — Prometheus's targets file (`localhost` in the pod, one
  line per replica by name on the scaled network), `PROMETHEUS_URL` for
  the datasource, `GRAFANA_HOST` for the app — so one insert serves the
  three deployments. With k6 in, its results go to Prometheus by remote
  write (`K6_OUT`, and the receiver flag on Prometheus). `./wb.sh status`
  and the console's board and Doors show Grafana's address; the terminal
  and the Docker screen open a shell on both containers.
  `PROMETHEUS_IMAGE_VERSION` and `GRAFANA_IMAGE_VERSION` join
  `config.conf`. Run live on 2026-09-08 on a fresh Postgres workspace,
  dev and prod, k6 included: Grafana's first start on a fresh volume
  ran its 813 migrations for four and a half minutes beside the app
  compiling, past a 30 s start period, and the app's `depends_on` then
  failed the whole `up` — its healthcheck allows five minutes now, as
  SQL Server's allows three. No cover yet.
- **Doors, a paper of the Project tab.** The plan of every address the
  project answers to, drawn off the status: the workbench's own app and
  pgAdmin; the doors the inserted cartridges open, each called once with
  what it answered beside it as a chip; the doors an inserted cartridge
  keeps shut, unlit with what would open them — `--with ash_admin`,
  exdoc inserted — which the rail's Doors section, filtered to the open
  ones, could never say; the probes the cartridges have the console
  call; and the doors of the cartridges not in yet. The rail stays the
  bell, this is the map. Its ribbon tab wears the app's port where the
  others wear a file's name, and it is never unlit for want of a file.
- **A palette a language.** The colours of the Interface tab are kept
  per language as well as per ground: Elixir; HTML and its templates;
  CSS and SCSS; TypeScript and JavaScript; JSON; Markdown; and Godot,
  whose scripts, shaders, scenes and project file share one — each
  naming only the rules it has (JSON has keys and no keywords), each
  with a sample of its own, and each stamped on the Files sheet's
  `.src` as `data-lang`. A pasted jsonc sorts itself by the language
  its scopes name, a scope with no language reaching every language
  that lists one under it, and reads back out with every language at
  once. Three lexers come in for it: `makeup_ts` for `.ts`,
  `makeup_css` for `.css`, and `makeup_syntect` — the Rust NIF the
  highlighter's notes named as the escape hatch — for `.md`, `.scss`,
  `.gd`, `.gdshader` (through GLSL), `.tscn`, `.tres` and
  `project.godot` (through INI), so the README, AGENTS.md and guides a
  cartridge writes read coloured on the sheet. Numbers moved from the
  operators' rule to the constants', where the jsonc has them, and
  types to the modules'; CSS's properties and Godot's annotations take
  a rule of their own where their class would have meant another thing.
- **The code follows the ground.** The terminal — jobs' output, the
  logs, the Terminal screen, `.env` and `config.conf`, the papers'
  blocks, the Files sheet — was dark on both grounds; on the light one
  it is paper now. `term`, `term-ink`, `term-dim`, `term-line` and
  `term-scroll` carry a light value in `assets/design/tokens.json`,
  `term-tint` washes a hovered line or a diff's gutter, and six
  `ansi-*` roles replace every colour the console wrote by hand on a
  terminal surface. The Files sheet's twelve are One Light on the light
  ground, One Dark's pair; the Interface tab keeps a palette a ground
  and edits the one being read. `assets/design/fuente-claro.html` is
  the page the palette was chosen on.
- **The colours are the reader's.** The Interface tab of the workbench
  drawer gains *The colours*: the twelve rules of
  `console/elixir_color_theme.jsonc` as swatches, a sample of Elixir set
  in them, and a box a VS Code jsonc pastes into — its
  `editor.tokenColorCustomizations`, a theme's `tokenColors`, or the bare
  rules, matched to the twelve by scope — and reads back out of, in the
  same shape, to carry to VS Code. The twelve are properties of the root,
  kept in this browser like the faces, so the Files sheet and the sample
  change as they are set. One palette for every language the console
  colours: every Makeup lexer speaks the same classes.
- **Every push runs the checks.** A GitHub Actions workflow
  (`.github/workflows/ci.yml`) puts the two scripts through ShellCheck
  and each Elixir package — `igniter/`, `console/` — through
  `mix format --check-formatted`, `mix credo --strict`, `mix dialyzer`
  and `mix test`, on the Elixir and OTP the package's own
  `.tool-versions` names. Credo and dialyxir are dev/test dependencies
  of both; each package has its `.credo.exs`, the igniter gains the
  `.formatter.exs` it never had, and the PLT lives in `priv/plts/`
  (ignored, cached by CI). One check is off, in the igniter only:
  `AliasUsage`, because Igniter's API is spelled by its full path by
  convention and a cartridge calls a dozen of its modules. The README
  says how to run the same checks before pushing.

### Updated

- **ecto's release one-shots are named for what they do: `create` and
  `volume_init`.** They were `database_init` and `data_init` — three
  letters apart, and variants of one word for two different jobs.

  MSSQL's is now **`create`**, which is what it is: an idempotent
  `CREATE DATABASE` run before the migrator, the other half of Ecto's
  own pair beside `migrate`, which has been called that all along and
  runs `bin/migrate` from `phx.gen.release`. Two verbs a reader already
  knows, in the order they happen. It shares a word with `docker
  compose create`, which is cosmetic: a service name is always in
  argument position, and `wb.sh` wraps the commands anyway.

  SQLite's is now **`volume_init`**, because `data_init` initialises no
  data — it hands `/app/data` to `nobody`, a named volume mounted where
  the image has no directory coming up owned by root while the release
  does not run as root. It stays a noun deliberately: `create` and
  `migrate` are Ecto operations, and this one is not, so the asymmetry
  says something true.

  Both named by the job and not by the engine, as ecto's `database` is
  — db_admin's adminer waits on `volume_init` because the volume has to
  be ready, not because the project is on SQLite.

- **A cartridge's Contents is a tree of its files.** The table at the
  foot of a cartridge's README draws the cartridge's own files as a
  tree — its directory, its `priv/`, its test, each a root after an
  empty row, 📁 for a directory and 📄 for a file — with each file's
  role beside it, kept to one line. Files the old tables left out
  (`NEED.md`, `CHANGELOG.md`, ecto's compose blocks, the shared
  `base_cartridges_test.exs`) are in it. Drawn in version_manager,
  versioning, dashboard_extras and the seven base cartridges; the rule
  is in the features README's anatomy. The console reads such a table
  as a tree (`Console.Papers.mark_trees/1`): the branch keeps its
  spaces and loses its code chip, and the rows close up so `│` runs on
  from one to the next. **The paper fills its column**: the Markdown
  block no longer stops at 68ch, and reaches the index — text, tables
  and code at one width.

- **A box's needs are the cartridges alone, and what is in says it by
  its box.** The mentions under the specs' Needs and a value that builds
  on what the project lacks both wore the `need` class — the one the
  need paper's panel is drawn with — so each came framed in its accent
  edge; they are `req` and `lacks` now, and the paper keeps its own. A
  value the project has lost its `in` tag: a box checked and shut says
  it, as it already did when the whole form is locked, and the only tag
  left is the one that says why a shut box is not checked (`needs ecto
  with database mysql`). A cartridge that adds on a second run (`rerun:
  adds`) with nothing left to add — every value in, or out of the
  project's reach, as db_admin with every admin its database serves —
  has its Add unlit, and the note says why.

- **The box's Manual comes before its Installation.** The drawer's row
  of screens read Box, Installation, Files, Manual — the papers last,
  after the form they explain. It reads Box, Manual, Installation,
  Files now: what the box is, what it says about itself, how it goes
  in, what it wrote. Only the order of the row; the URLs and the
  screens are the same.

- **versioning starts where the project is.** Its README said the
  generator's `0.1.0` was nobody's decision and defaulted the project
  to `0.0.0`; its DESIGN, written now with the sources, found that
  `0.1.0` is the start SemVer's own FAQ recommends — and that on a
  project already released the default took the number back. The box
  is told again from the problem it solves — a project with a version
  number and no versioning, new or two years in — and the option is
  `--init-version`, defaulting to the version `mix.exs` has, which is
  then left untouched; the rest (`--mix-task`, as `--task` is called
  now, and `--readme-badge`) are amenities. `state/1` reads where the history opens off the
  changelog's oldest title, and the opening entry no longer says
  "Brand new project created." of a project that may not be. The same
  research fixed three things: a version Mix would not compile is
  refused by the installer and by the planted `mix version` before
  anything is written; `version: @version` is read — by the shelf's
  `mix_project_value/2`, so exdoc's `@source_url` reads too — and
  written; and a pre-release's dash is doubled in the shields.io badge,
  which it used to break. A probe in a real project found a fourth:
  releases were dated by UTC's day, and are by the developer's now. A
  chiefs_setup project is born at `0.1.0` now, not `0.0.0` (versioning
  v0.3.0, 2026-09-18).
- **A cartridge does not name the collection that picks it.** Twenty
  READMEs and ten moduledocs said "a chiefs_setup pick", "not a
  chiefs_setup pick", or the argv the collection hands them. The
  knowledge runs one way: the collection names its members and their
  argv (`members/1`, its README), and the shelf's README says who picks
  what; a box says what it is, what it needs (an account, a URL) and
  what it excludes (rest and graphql), which is its own. ash's README
  names the two boxes it fights with, enhancements and auth0, instead
  of "the chiefs_setup picks". The CHANGELOGs keep theirs: history.
- **`--no-ecto` stands before `--database` on the Record's flags.** Ecto's
  own flag first, then the two that only mean something with it.

- **LiveView is html's option, not a box.** The `live` cartridge is
  gone into html as `--live`, on by default as in `phx.new`: `wb.sh add
  html` brings both, `--no-live` leaves LiveView out, and html run again
  on a project born `--no-live` adds it (`rerun: :adds`). In the
  generator live is `html && live`, a condition inside html's templates
  with no file and no dependency of its own — a decision that only
  exists inside another's is that other's option. `state/1` reads it
  back off LiveView's configuration, the block that was the box's mark;
  the esbuild notice moved with it; ash's `--auth` strategies and
  `--with ash_admin` require `{"html", live: true}`, and the refusal's
  remedy is `./wb.sh add html --live`. The shelf has seven base
  cartridges; the console's new-project card offers `--no-live` as
  html's switch, the way it offers ecto's `--database`, and the box's
  form can turn a switch that is on by default off. Cost, written in
  html's paper: LiveView is no longer ejected alone (html v0.2.0,
  2026-09-18).
- **Both images carry node and npm.** `ash --api typescript` failed
  inside the workbench's container with `:enoent` on `npm`: ash_typescript's
  installer, handed `--framework react`, hooks `npm install` into the
  project's `assets.setup`, and neither image had node. Debian's
  `nodejs` and `npm` join the shared first step of the project seed and
  the workbench's Dockerfile — the one apt line both open with, so the
  layer stays shared — rather than the workbench's alone, because
  `mix setup` runs `assets.setup` at every boot of the app's container
  too. The workbench image is rebuilt when missing, so an existing one
  is removed to take it; a workspace takes the seed on its next `bake`
  and `up`. The production Dockerfile is Phoenix's own and still knows
  no node: a project on TypeScript adds it there itself (2026-09-17).
- **`mix version` is versioning's, on request.** The task lived in
  enhancements, where it was a lodger and, worse, its mark: it moved to
  versioning as `--task`, since the version is that cartridge's
  decision and the task is the decision's tool, and was rewritten for a
  stock project — it writes the number into `mix.exs`, closes the
  changelog's `Unreleased` as that version under the commented
  template line, and updates the README badge only when there is one;
  it used to fail on any README without the badge the retired setup's
  template put there. `--readme-badge` puts that badge under the
  README's title. Both are pieces (`rerun: :adds`) and off by default,
  so a chiefs_setup project no longer gets the task: a recipe may not
  pass a member's switch, a limit to revisit. enhancements' mark is
  `test/support/fixtures.ex` now, the one file every shape of it
  writes (versioning v0.2.0, enhancements v1.0.0, 2026-09-17).
- **An eject that does not apply says where, and who wrote there.**
  `eject ecto` on a project that took seven cartridges after it said
  only that files had changed since. Now, before the revert is
  abandoned, it names each file in conflict with the lines the markers
  enclose and who wrote there after the insert — the cartridges that
  came later, newest first, which is the order to eject them in, or a
  commit of the reader's own by its subject. On that project:
  `.formatter.exs` by html; `AGENTS.md` by live, tailwind, html;
  `mix.exs` and `mix.lock` by six. Not one of them an edit by hand —
  a cartridge appends where the one before it ended, and git's revert
  cannot tell that apart from an edit. Ejecting what came after first
  is the way for now; a base cartridge undone as it was done, the
  delta the other way round, is the next.
- **Stop stands before Down on a deployment's row.** Bake, Build, Stop,
  Down: the one that keeps the containers before the one that removes
  them. Down stood first since the order turned on 2026-09-10.

- **The terminal's sixteen are Nord's, and a Nord light of the
  house's making on paper.** `Console.ANSI` told the sixteen colours
  apart already; the sheet painted the bright row with the normal
  row's and gave black and white nothing. Each has its token now, a
  ground each. Nord was chosen among the five most ported terminal
  themes on `console/temas-de-terminal.html` — Catppuccin, Tokyo
  Night, Gruvbox, Nord, Dracula, against the house's own, each with
  its contrasts on the console's grounds — for its sobriety and its
  fit with the console; its red reads 4.7:1 on the dark ground, just
  over the line. Nord has no light, so the house derives one: Nord's
  hues deepened on paper to 6:1 the normal row and 4.5:1 the bright,
  with a floor on saturation so the muted hues do not turn to mud,
  and Polar Night and Snow Storm for ink, black and white
  (`assets/design/palette.py`, `nord_light`). Dim (SGR 2) is opacity
  now, so a dim red stays red. The- **The Docker screen's controls are the daemon's box's,** in a strip
  under its lines, the way the Logs screen and a job's output carry
  theirs: This workspace, The daemon and, on Containers, Stats, one
  framed box over every document. And on Images a name links to its
  page at the registry where there is one: Docker Hub's official
  images (`postgres:16`) and repositories (`hexpm/elixir`), Microsoft's
  registry for SQL Server; a local image, the workbench's own, or a
  registry with no page stay names.
- **The disk is in the daemon's box.** The four rows of `docker system
  df` — images, containers, volumes, build cache, each with its count,
  size, how many are in use and what is reclaimable — were a table
  under Volumes; they are four lines of the daemon's box now, over
  every document of the Docker screen, after the storage line that
  names the root. Measured once per visit, saying so until it lands —
  seconds, tens of them on a daemon with a hundred volumes — and again
  after a job of the verbs that move the disk: up, build, bake, new,
  delete, prune, a removal, an insert or eject, mix.
- **A container's ports on the Docker screen wear no square.** The
  address kept the rail's shape but its square was painted in the
  service's colour, the same mark with another meaning; the table is
  Docker's view, every port a published one, and the service is the
  row's first column. The square goes, the address stays.
- **The pod's service is `pod`.** The pause container that owns the
  workspace's network namespace was the service `network`, the word
  Compose and Docker use for a network: `network_mode: service:network`
  read as a riddle, and a `network` row on the console read as a
  network. It is `pod` now, in the compose template, its fixtures, the
  console (the container's order, its shell-less row, its restart's
  reason, the colour its log lines wear, `svc-pod` in the tokens) and
  the igniter's README. A workspace baked before keeps `network` in its
  files until its next `bake`; a deployment that is up then must come
  down before the next `up`, since its old container holds the ports
  the new `pod` publishes — `up` says so and refuses, rather than
  failing on the ports after the build.
- **The door on the host is the app's.** A port the compose publishes
  belongs to the service that listens on it, not to the one that
  declares it: in the pod the `network` container owns the network
  namespace and so declares every port, and Services & Doors and the
  Record's deployments said `network localhost:4000` with `app` inside.
  Now `app` wears `localhost:4000`, and Services & Doors lists only the
  doors on the host — the ports the compose publishes and the routes;
  a port inside the pod (`database :5432`), the pod itself and the
  one-shot `migrate` are on Containers and on the Deployments sheet,
  the whole map, where an inside port wears the hollow square. The
  Docker screen keeps Docker's own view. A port no service claims
  stays with its publisher.
- **A port inside the pod wears a hollow square.** On Services &
  Doors and the Record's addresses, a service the compose publishes on
  the host (`localhost:4001`) keeps its solid blue square, and one
  whose port lives inside the pod only (`:5432`) wears the same blue as
  an outline: the layer kept, the opening not. It was one solid square
  for both, told apart only by which could be pressed. A third kind of
  address, `inside`, beside `route` and `port`.
- **Project before Cartridges in the tab row.** The two swap places:
  Deploy, Jobs, Logs, Terminal, Project, Cartridges, Cluster, Docker,
  in the miniature of the Interface tab too.
- **`./wb.sh help` reads like a CLI's.** One line of summary a
  command, in the imperative, and its options in an aligned list with
  their defaults; the reasons and the history went where they were
  already, the README and this file. Every command and option is
  still there, in 170 lines where there were 284, and the entries
  written first — `login`, `demo`, `delete`, `help` — read in the
  same voice as the rest, each body indented under its command as a
  man page does. The headings are the usual ones (SYNOPSIS for
  SYNTAXIS), and 'Defalut' is spelled at last. And the script's colour
  codes go out only when a terminal reads them — stdout a tty,
  `NO_COLOR` unset, `TERM` not dumb — or when `WB_ANSI=always` asks,
  as the console's jobs do; `help | less` and a script capturing
  `status` get plain text.
- **The workbench and the project have an image each, from a
  Dockerfile each.** The workbench's is
  `dew-exELIXIR-erlOTP-phxVERSION:WORKBENCH` — the stack and the
  installer name the repository, so `docker images` lists one line per
  pair, and the workbench's own version is the tag, so a new workbench
  builds its own and an old one keeps what it ran on (it was
  `dockerized-elixir-workbench:exELIXIR-erlOTP-phxVERSION` until
  2026-09-15) — built straight from `scripts/Dockerfile.workbench` with
  the stack and the installer as build arguments: the toolchain,
  phx_new, and the Docker CLI with buildx and compose. Everything the workbench does in a
  container of its own runs there, `add`, `expand`, git and the
  catalog included, and so does the console; its image is built on the
  first command that needs it. The project's `Dockerfile.local` keeps
  only what the app uses: no phx_new, no Docker CLI, no workbench
  directories, no default-branch setting, and the `ARG PHX_NEW` line
  stays as the record of its generator. Its compose builds it on the
  first `up`, from the same first steps, so the two images share those
  layers. There were two images before as well, `workbench:…` and
  `workbench-console:…` built on it, and they read as two versions of
  one thing: the second named neither its base nor its installer, and
  the project's image was an alias of the first, carrying the
  generator it never runs. `console/Dockerfile` is gone. With no
  project to name an installer, the image is the one config.conf names
  or the newest the daemon has for the stack. And wb.sh runs a command
  in the console's own container only when it asks for the image the
  console runs on: a `new` that resolves another phx_new, or a stack
  changed in config.conf, goes to a container of its own image instead
  of generating with the wrong one (2026-09-14). The Terminal tab's
  one-off target, when nothing runs, is **workbench** and not
  toolchain: a container of the workbench's image with the workbench
  mounted and its build volumes over `_build` and `deps`, as wb.sh's
  own runs have. It was a container of the app's dev image with the
  source alone, so an `iex -S mix` there compiled through the bind
  mount into the workspace's own directory, and since the dev image is
  built on the first `up`, it had no image at all right after `new`.
  The resident, away from the console's mount, runs on the same image
  for the same reason (2026-09-15).
- **A job's verbs are buttons in a strip under its output**, inside
  the frame, the strip the Logs and Terminal boxes have: Run it and
  Drop it while it waits for a word, Drop it while it waits its turn,
  Stop it while it runs — and, asked, Stop it beside Let it finish —
  Run it again when it stopped or failed. They were a line of prose
  with underlined links under the last line of output, inside the pane
  that scrolls under the reader's cap, so on a long job Stop it was at
  the foot of hundreds of lines. The strip stays in sight; its few
  words say where the job stands, the reason at length rides on the
  button, and a job that ended well wears no strip. The same in the
  three places a job is read: the Jobs screen, a cartridge's box, the
  tray (2026-09-12).
- **Every terminal session is its own process, and the buttons switch
  between them.** A session is one per container and shell — `app ·
  bash`, `app · iex`, `database · psql` — under `Console.Terminals`, a
  supervisor of the console's and not the page's: it holds the Port
  and the last 2000 lines of its screen, so reloading the page, changing
  tab or losing the socket leaves the `iex -S mix` where it was. The
  container and shell buttons are never dark while a session runs; each
  wears its sessions — a full dot where the process runs, a hollow one
  where it ended with its trail — and pressing one switches the screen
  to what that session has, its own ↑↓ history with it. A container
  pressed opens on the shell with a session there, else on its first
  shell, so the database opens on psql again. When the process in the
  container ends the session stays with its trail and the exit code
  until Open a session replaces it or Discard forgets it, and a
  container that left the status keeps its button while a session on it
  is there. Ctrl+L forgets the trail, so coming back reads the same. The
  meta line counts the others open, and the Terminal tab pulses while
  any session runs, from every screen (2026-09-12).
- **The Project tab's papers are Birth, History and Changes.** The
  first was Record, a name for the three sections it once held: the
  deployments went to Deploy and the cartridges to the shelf, and what
  was left was the birth, so the paper is called that and its one
  heading reads as a line, *Born 2026-09-08 07:44 at 1a0546c*. The
  third was Pending, a word the jobs tray already uses for a job that
  waits to be confirmed; Changes is what a commit would take, the term
  every git client uses, and the sublabel still says *clean* or how
  many files. History keeps its name: Git left the label on 2026-09-09
  because the repository is the project's, and the HEAD in the
  sublabel says whose history it is. The rail's button follows,
  *Commit changes*; the keys in the URL do not move.
- **The Interface tab is the controls on the left and the console in
  miniature on the right.** It was a column of seven rows, 1647px tall
  in a pane of 695 — two screens and a half for four things: the frame,
  the ground, the type, the colours. Now the column is 320px, the grid
  the drawer's body already reserves, and scrolls on its own; beside it
  a fifth of the console — the band, the rail, a terminal and a sheet —
  drawn from the same body classes and root properties the screen
  reads, so what is set on the left lands on the right where it will
  land on the screen. The frame's three toggles, each a sentence to
  read before clicking, are two segmented controls with a pictogram per
  position, the band's two and the rail's three — hidden is a position
  of the rail, not a setting of its own — the way DevTools docks its
  panel; the miniature's band and rail are controls too. The ground is
  three cards with a thumbnail, Light, Dark and System, and the third
  puts back the state the console boots in, which once a choice was
  made could not be had again. The type's two profiles keep their
  picks; their samples are now the miniature's terminal, real lines —
  a warning of Elixir's compiler as a terminal colours it, a Phoenix
  boot, a request, an error of Bandit's — drawn as the Logs screen
  draws them, and the miniature's sheet, the Files sheet's own drawing
  of the tab's sample, gutters and all: the old sample was a `pre` with
  three colours that looked like no surface of the console. The
  colours' twelve roles read in two columns under their language, and
  the jsonc box — 96px and three buttons always in view for what is
  done once — folds behind the house's `.fold`. Decided on 2026-09-12
  among four compositions drawn on the real content: the sibling
  Config's row grammar, three docked tabs, this, and a booklet with an
  index; this one shows the most, at the cost of a second drawing of
  the frame that has to follow the first.

- **The square icon button is one component, and its drawings are
  files.** Six squares sat in five rules of the console's CSS — the
  knock's bell on the rail and the shelf, the eye on a compose file,
  the cog on a given, the reload of a fetch, the `×` of the jobs bar
  and the rail's toggle — four with a drawing inline and two with a
  character set in the body face, and `.go` named both the squares and
  the golden GO. Now `ConsoleWeb.Square` draws every one: a mark from
  a sprite, `console/priv/static/images/icons.svg`, that
  `assets/design/build.py` gathers from one file a drawing under
  `assets/design/icons/`, and a name for the screen reader that the
  component will not go without. What a square is — `.sq`, 2em of its
  neighbour's type — is the house's, in `components.css` and
  the design README; where each stands stays the console's. Its size
  is the field's height, 2.5em of the field's type in whole pixels,
  which the reload had and every square has now, so the mark sits
  centred; a section head with a bell is as tall as the bell and
  centres on it. A second size, small, is a line's, 2em of 11px: the
  jobs bar's `×`, the cogs on New Project's rows, the two knocks, and
  the folds of the rail's sections, which were a caret on the head and
  are a small square at its edge now, the caret drawn from its
  `aria-expanded` and turned when folded; the head still folds where
  it is pressed, since it carries the same click itself — LiveView
  fires only the binding closest to the click, so the knock's bell
  keeps its own. (A hit layer over the head did this for an hour and
  sat over the bell whatever its z-index said.) The `×`
  is a drawing now, at the weight the other marks have.

- **On History, the commit whose diff is open folds it when pressed
  again.** The mention led to the same address twice, so a second press
  did nothing; open, it now leads to History without a commit, wears
  `aria-pressed`, and its title says so.

- **The terminal's and the Logs screen's controls are inside their
  box.** What to open a session on, with what, and the opening sit in a
  strip under the terminal's command line; the services, the level,
  the search, Following, Timestamps and Clear in a strip under the
  lines of Logs; the services alone in a strip on top of each box,
  Logs' chips and the terminal's containers. The row above each box is gone, and so are the two
  boxes' words for being empty. On the Files sheet the file's row no
  longer draws a line under itself: the row's ground is the edge. And
  the rail's toggle is two squares, Left then Right always, each
  drawing the frame it would set with the rail's column solid: the
  other side moves the rail, the side it is on puts it away, and
  either brings it back on its own side; the one in force is pressed. A file's
  row on the Files sheet carries its caret at the far end, past the
  counts, as a job's row does, and folds wherever it is pressed but on
  a cartridge's mention. And a changed line tints its number plates too, a
  shade deeper than the line, as GitHub does, so the ruler shows where
  the changes are when the code has scrolled off to the right.

- **The Jobs screen lists its jobs in the framed list a box's Runs
  are.** The rows were one component already — the same chip, number,
  fold, grip and words at the foot — but the box framed them, a
  hairline and a rounded corner hugging the rows, and the Jobs screen
  ran the same rows unframed across its viewport, 28px in from either
  side, a table without an end. The frame is `.jobs-list` now, in both
  places, flush with the command line and the count above it; the
  viewport keeps the pane's air above and below. And on the
  Files sheet the line numbers' plate is the file row's own ground,
  so ruler and row read as one furniture around the text.

- **The rail's air is 22px on both sides.** Its right padding gives
  back the gutter the rail keeps for its scrollbar, measured by the
  Rail hook, so the content no longer stood 37px from the right edge
  and 22 from the left; the rail's toggle and the section heads' squares
  share that edge. And the danger zone on Deploy wears its red on the
  left edge, as the house marks a block, not along the top.

- **The Logs screen's service column is as wide as the longest service
  name**, in the face's own characters — it was 72px whatever the
  names, so every message stood a hand's width from a short one — and
  the Interface tab's miniature draws the same column: its terminal now
  carries lines of the database and of pgadmin beside the app's, each
  in its service's colour, with the Logs screen's own service chips
  above them, pressed to show, and its Timestamps button, as on the
  screen; its band is the band — the mark, the name, the state, the
  clock, the two cells — and its tabs are the screens' (2026-09-12), and between its terminal and its sheet the Jobs screen's
  grip, which splits the screen between the two and keeps the split
  in this browser; and its sheet shows
  every language's sample as a patch, one line changed — a removal and
  an addition, the Files sheet's colours — with the hunk and the count
  on the file's row, as the sheet has them. And the sheet's two
  number columns, on the Files sheet and in the miniature alike, are
  as wide as the file's widest line number — they were 3.4em for any
  file, a plate three digits wide beside a file of twelve lines — and
  never narrower than two digits, the way GitHub sizes a gutter; the
  number sits centred in its plate, a size smaller than the code, and
  the plates run to the sheet's edges, with no air above the first
  line or under the last. The tab's sections read Terminal, Code
  Files and Language Syntax (2026-09-12). And the rail has a toggle in
  its corner, the way hexdocs folds its sidebar: the same square puts
  the rail away and, from the screen's corner, brings it back — the
  tab's Hidden, kept the same way, and the two agree whichever was
  pressed.

- **The jobs tray is on every screen but Jobs**, once anything has run
  — it kept to the screens that start jobs, and a job's answer went
  unseen on the others — and the bar's link to Jobs is a square that
  puts the tray away until the next job. Its fold is the last job's:
  kept while the tray is put away, and what the Jobs screen opens that
  job to on arrival; folding the last job there folds the tray. The
  chip on the bar is the job's own, as its row wears it (`exit 0`,
  `exit 2`, `running`), no longer a count of the list, and the bar's
  title is gone. The box sits to the bar as a job's output sits to its
  row, 7px, and a row on the Jobs screen ends as close under its box.
- **A flag in ink, what follows it dimmed.** The installation
  parameters read `--endpoint` with `/health` dimmed after it — on the
  shelf the type or the values in its place — and the Birth table's
  arguments the same; a flag at its default is said in its title, no
  longer by dimming the whole flag. The `in` mark beside a choice goes
  when the box is locked: everything checked is in.
- **The rail's Containers section drops its note** — *No deployment is
  up and these are still here: Deploy → Down removes them* — written
  when the Deployments section could only say `down`. It reads
  `stopped` on the deployment whose containers are there, with Up and
  Down lit, and the note only offered the destructive one.
- **`state/1` is what the project carries of a cartridge's options,
  and every cartridge with options answers it.** The contract called
  it optional — "for an `:adds` cartridge", `%{}` by default — while
  four readers depended on it: the status, the console's Inserted
  list, a door's `{option}` path and `services/1`. A silence read as
  an answer, and eight cartridges with options were silent: rest,
  coveralls, exdoc, guidelines, enhancements, auth0, openai and
  clustering. The contract (`WorkbenchIgniter.Feature`, the features
  README) says now: required of every cartridge whose `info/2`
  declares a schema, exactly the schema's keys, each with what was
  found — a string, a list, `true`/`false` — or `nil` for an option
  that leaves no mark the project keeps, said beside the read. Every
  read is off a mark the project has for its own sake, never a record
  kept for the workbench: rest reads the title, the bearer scheme and
  the tags off its `OpenApi.Spec`; coveralls the minimum and the
  skipped folder off `coveralls.json`, the `mix cover` task, and the
  theme by matching the planted report template against its own;
  exdoc the name and `source_url` off `mix.exs`, the `cover` action,
  the token page; enhancements the key and timestamp types and
  `@before_compile` off `MyApp.Schema`, the interface off the error
  view's shape, auth0 and openai off the model's tables or the Postman
  collection's sections, health off the collection; auth0 and openai
  `rest` off their controller; clustering the query off `.env`, or
  `.env.sample` when `.env` is not there. healthcheck says `open_api:
  false` now instead of leaving the key out, and versioning reads its
  version through the new `WorkbenchIgniter.Feature.mix_project_value/2`,
  which exdoc shares; `file_content/2` is the other helper the reads
  share. Two options turn out to be dead — auth0's and openai's
  `--project-name`, read by no template — and are reported as such
  rather than removed: that is phase 2's.
- **What a cartridge composes is in its manifest: `composes`.**
  healthcheck, coveralls and enhancements insert mock from inside their
  installer, and nothing outside the installer knew: the catalog entry
  carries `composes` now, read off the `composes` each installer's
  `info/2` already declares to Igniter (the collection's members are
  its recipe, not this), and `mix workbench.status --json` prints it.
  It is not `requires`: that says what must be in first and the
  installer refuses without, this says what the cartridge brings along.
- **The compose files read under the Record's deployments, not under
  Docker.** Docker's *Deploys* document — the three files as a YAML
  sheet with the secrets masked, one picked on a toolbar — moves whole
  to the Record, under the deployments table, where each row is
  already the file's summary; the files are the workspace's, not the
  daemon's, and Docker keeps its five documents. The table and the
  file are one sheet, `ConsoleWeb.Deployments`: an eye on every row
  before the file's chip opens that file in a code box under its row,
  wearing its name — pressed on the one open, and pressed again it
  closes; unlit with the remedy while not baked. One box at a time
  and none until the reader asks, named in the URL
  (`/deploy?compose=prod`). The box is as tall as the reader leaves it, with the
  jobs' own grip under it — the `JobOut` hook now rides any pane
  wearing `data-tall`, and the compose box keeps its height across
  papers where a job that has left the tray is forgotten. A status
  arriving reads the files again, since a bake may have rewritten one. In the same round the rail and the Record share
  the deployment row — up, stopped or down; Up or Stop, Down and Bake —
  every sha the console shows is a `.commit-ref`, the rail's Cartridges
  wear the facts chips before the origin, and the rail's Services &
  Doors lists one address a line.
- **The deployments read on the Deploy tab, one card that picks and
  shows.** The table — each compose file baked or not, in sync or
  drifted, up, stopped or down, its services, and Stop, Down and Bake
  on its row — and the file's box under a row leave the Record for the
  Deploy tab, where the reader is when the question is what is baked
  and running; the Record keeps what the project *is*, its birth and
  its cartridges. There it folds the Deployment card into itself: the
  three boxes of the picker were the table's three rows again, so the
  row carries the radio, what the deployment is under its name, and
  scaled's replicas and balancer; Up and Build of the row picked sit
  under the table with the `wb.sh` line they are, and the "nothing is
  up" chip goes, the status column says it row by row. The open file
  is `/deploy?compose=prod`, read when the tab is taken and again when
  a status arrives. The table is the tab's, not the project's: with
  the workspace empty its three rows are there, not baked, every eye
  and button unlit with the one reason.
- **`bake --deploy prod|scaled` bakes that file alone.** The prod and
  scaled composes were written only on the way to their own `up` or
  `build`, so the console's Bake button on those rows had to send
  `build --deploy`, and built the release image to rewrite a YAML.
  `bake` takes `--deploy` now, with `--replicas` and `--no-balancer`
  for scaled, writes that file for the project as it is now — its
  ports kept — and commits it as it commits the dev file; a file that
  already says what the project asks for is left alone. The image the
  file names stays `build --deploy`'s, or up's. The three Bake buttons
  send `bake` and say the same thing. A prod or scaled file an `up`
  left untracked has to be committed before, as any bake asks.
- **What comes off the project is dimmed while it is being read
  again.** A full status boots Mix in a container and takes seconds;
  a fast one lands meanwhile — the daemon's events ask for one — and
  carries the project's facts as they were, so a row said *baked* for
  the seconds between an insert and the reading that knew of it. The
  facts that only a full reading changes — the compose file in sync or
  not and its differences, on the Deploy tab and in the rail, the
  cartridges in the rail and on the Record — wear `.stale` while one
  is in flight: dimmed, with "reading the project again" in the title,
  and pressable still, which is why it is not `.unlit`. Unlit, not
  asserted.
- **A service's web face is a door.** pgAdmin and Grafana publish a port
  on the host, and the status already names it (`ports.pgadmin`,
  `ports.grafana`): the cartridge's row now wears it as a door, `PGADMIN
  :5050/`, opened by the reader and read by the knock like any route —
  the root answers a redirect, which is an answer — and shut with the
  reason while its container is not running. Nothing is asked of the
  cartridge: the compose service it already brings says it all. The
  layer's rule is restated with it (`assets/design/README.md`): violet
  is an address the reader opens and the knock reads by HTTP, whoever
  offers it; blue is a service's port, read off `docker compose ps` —
  what the face does, not who offers it. So the same pgAdmin is a
  violet door on its cartridge's row and a blue port on its
  deployment's. On the way the Record's table of inside ports said
  pgAdmin `:80`, the image's default; the compose has it listen on
  5050.
- **Knock: the doors are called only when the reader rings.** One
  reading for the whole page, shared by the rail's Services & Doors and
  the Record's addresses, and taken only when the reader presses the
  bell on either — the square button of `.fetch`, wearing a bell now,
  ringing while the knock is out. Never on a mount, a status or a
  clock: every call lands in the app's logs, and a line the reader did
  not cause is noise there (an automatic knock lasted a day). A status
  arriving wipes what was heard, since a job changed the world. What
  each door answered goes on its face in both places. Deployments in
  the rail and on the Record gain Bake, Stop and Down beside Up — Stop
  keeps the containers, Down removes them and is lit only while there
  are some — and the rail opens with Services & Doors, the workspace's
  own app link gone since the section's first line is that port.
- **The rail's Inserted is Cartridges, Doors is Services & Doors, and
  Deployments says in sync.** *Cartridges*: the mention, then the
  origin, then the edition, the Record's order. *Deployments* gains the
  in-sync check beside the file's chip — baked, out of sync or not baked,
  as on the paper — under column heads. *Services & Doors* is the old
  Doors section widened: first the services of the deployment that is
  up (dev's file when none is) as ports with what `docker compose ps`
  says of each, then every door the inserted cartridges open, with the
  mention of who opened it — the Record's faces, without a reading on
  the doors since the rail calls nothing. Putting each address under
  its own cartridge or deployment was tried first and does not fit: at
  380px a port face is wider than the columns beside it.
  `ConsoleWeb.Record.addresses/4` and `deployments/1` are the rows,
  lent to the rail and the paper alike.
- **The Project card on Deploy is intention again.** Its rows say what
  the next `new` would use, off config.conf and nothing else: the
  installer row no longer answers with the stamp of the project born
  here, which was the state slipping into the form. What this project
  is has its paper now, and the card links to it — "what it is", the
  Record. One crossing stays, because it is about creating: the warn on
  the stack row when the project was built on another one, since
  creating again would move it.
- **Git's two documents are papers of the Project tab.** The repository
  is the project's, so Pending and History follow Record, .env, README
  and CHANGELOG on the Project ribbon, and the Git tab goes; the top row
  reads Deploy, Jobs, Logs, Terminal, Cartridges, Project, Cluster,
  Docker. Pending's sublabel is the tree (clean, dirty, or the files a
  commit would take), History's the HEAD. `/project?paper=history&commit=SHA`
  opens History on that commit with its diff — where a `.commit-ref`
  lands, the Record's birth first. Without a repository the two are
  unlit with the reason, as CHANGELOG is without its file. The rail's
  "Commit pending changes" lands on Pending. `ConsoleWeb.GitScreen` keeps
  the two documents, `git_pending/1` and `git_history/1`;
  `Console.Project.carried/1` reads the status now, since which papers
  there are depends on the project and its repository, not on files
  alone.
- **The address component: one face, the layer as a square, the reading
  attached.** `.door-ref` in the design system now says which layer
  answers at an address — an 8px square before the label, the mark the
  logs' service filter already uses: violet (`addr-route`) for a route
  the project offers on the app's port, blue (`addr-port`) for a port
  the compose publishes — and carries what the address answered
  *inside* its border, at the right edge, as the chip's plate behind the
  box's own line, so a reading in a wrapping row can never drift to the
  wrong door. A route is written on its port, `:4001/dev/mailbox`. The
  two roles join `tokens.json`; `Refs.door_ref/1` takes `kind`, `port`
  and `read`; the rail's and Doors' own addresses are ports. `.probe-ref`
  is gone from `components.css` with the probe itself, and
  `assets/design/puertas-y-sondas.html` — the page that split door from
  probe on the premise that nobody presses a probe — is superseded by
  the Record paper's finding that the premise was false. New beside the
  two references: `.commit-ref`, a mention of a commit — the short sha,
  boxed because it opens History on that commit with its diff, the
  subject and date in the title — and `Refs.commit_ref/1`, for every
  place a sha was written by hand.
- **The daemon is set as code, a key a line.** Docker's version and
  platform, the host's CPUs and memory, the storage driver and its root,
  the OS and the kernel sat in one sentence, a note at the toolbar's
  right cut with an ellipsis at any width the rail left. They are a
  `.code-box` now — the terminal's ground and face in a row of their own
  under the scope buttons — five lines, `docker`, `host`, `storage`,
  `os`, `kernel`, the key dim in a column of nine cells.
  `Console.Docker.daemon/0` returns those pairs instead of the sentence.
- **The subordinate row's open tab is outlined.** The `docked` ribbon —
  a screen's documents, a box's papers — drew its selected tab as a fill
  that opened into the pane; it now carries the row's own hairline on
  its left, right and top too, a folder tab closed on three sides.
- **Git is the first fold of the rail.** Under the workspace, the
  rail's sections read Git, Doors, Deployments, Containers, Inserted;
  the tree and the branch used to sit fourth.
- **The compose files are rendered by the igniter, not carved by `sed`.**
  Step 1 of `scripts/PLAN.md`: `mix workbench.compose` renders the dev,
  prod and scaled files from EEx templates under `igniter/priv/compose/`
  — one skeleton per topology, the pod and the bridge — off flags
  alone, and `wb.sh`'s three bakes hand it what they still decide: the
  ports, the images, the two facts they grep off the project. The seeds
  and their range deletions are gone; a bake that fails leaves the file
  as it was. The output is the same to the byte: thirteen fixtures
  under `igniter/test/fixtures/compose/`, generated from the bash bake
  before it went (`test/support/compose_golden.sh`), are what the
  templates are tested against. The one cost: a bake is a run of the
  package in the toolchain image, seconds, where it was a `sed`.
- **The compose serves every adapter ecto offers.** Step 4 of
  `scripts/PLAN.md`. Ecto declares its engine as the service it needs —
  `postgres`, `mysql`, `mssql`, or `sqlite` for a place to keep the
  file — and the compose runs the server as `database` with a
  healthcheck of its own: MySQL pinged over TCP, since its image's init
  answers on the socket before the real server listens (the same trap
  `pg_isready -h` avoids); SQL Server through `sqlcmd`, with a one-shot
  `database_init` in the release deployments because its image creates
  no database. Each is configured to phx.new's own dev credentials, so
  the project's configuration stays untouched, and the release's
  `DATABASE_URL` — written by ecto's installer and by `new` off one
  table now — matches; `new --database mysql` used to get a Postgres
  URL. On SQLite the production deployment mounts a `data` volume,
  chowns it for the release's `nobody` in a one-shot `data_init`, and
  migrates as with a server; a scaled deployment refuses SQLite.
  `MYSQL_IMAGE_VERSION` and `MSSQL_IMAGE_VERSION` join `config.conf`.
  Run for real on 2026-09-07, each engine through `new`, `up` and
  `up --deploy prod`: SQL Server's first start on a fresh volume
  outlasted its healthcheck's retries and compose gave up on it, so its
  healthcheck carries a `start_period` of three minutes now, as the
  app's does — and so do MySQL's (90 s: its first start initialises the
  data directory and runs a temporary server first, longer than its
  retries allowed on a busy host, so the job failed and the next `up`
  found it healthy) and Postgres's (30 s). The images run as they come,
  no init switches: the allowance is the whole fix.
- **pgadmin and k6 are cartridges.** Step 3 of `scripts/PLAN.md`: the
  first two cartridges that bring a container rather than Elixir code.
  **pgadmin** installs `pgadmin/servers.json` — the servers pgAdmin
  opens with, which the compose used to carry inline — requires ecto on
  postgres, and asks for the `pgadmin` service; ecto asks for `postgres`
  alone now, so a vanilla `new` brings the database and no pgAdmin, and
  `chiefs_setup` inserts pgadmin among its picks. **k6** installs
  `k6/smoke.js` and asks for a `k6` service under a compose profile
  `up` never starts, with the project's `k6/` mounted as its scripts and
  `BASE_URL` set for the topology — `localhost` in the pod, the balancer
  or the `app` alias on the bridge. `./wb.sh k6 [--deploy TARGET]
  [SCRIPT] [K6_OPTIONS...]` runs one against the deployment that is up;
  the console knows the verb. `K6_IMAGE_VERSION` joins `config.conf`.
  The no-database compose files lose the dangling `configs:` block the
  bash left. Neither cartridge has a cover yet.
- **The cartridges say which services the compose carries.** Step 2 of
  `scripts/PLAN.md`. A cartridge's manifest gains `services/1`: the
  compose services it needs, by name, given its state — ecto on
  postgres asks for `postgres` and `pgadmin` (the latter rides along
  until it is a cartridge of its own), any other adapter for none. The
  status publishes the list (`status --json`'s `project.services`, the
  resident's answer, a `Services:` line in the listing), and
  `mix workbench.compose` reads it off the project when its `--services`
  flag is not given — which is how `wb.sh` calls it now, on the project,
  writing into the workspace with `--out`. The grep over `config.exs`
  and `mix.exs` that decided the database is gone; so is the guess it
  made for mysql and mssql, which got a Postgres they never used. The
  published ports are read back off the file a bake rewrites — the prod
  file's pgAdmin port too, which used to be chosen anew each time — and
  `add` says the compose is behind by rendering it again and comparing,
  not by grepping for a service.

- **The console's LiveView is split by screen.** `ConsoleWeb.ConsoleLive`
  held every screen's state handling in one module of 1 500 lines. Each
  screen's state now lives under its name — `ConsoleWeb.ConsoleLive.Docker`,
  `.Git`, `.Term`, `.Drawer` (the workbench's) and `.Hand` (the box in
  hand) — with `take/2` off the URL, `event/3`, `info/2` and `async/3`,
  and the LiveView delegates by event prefix. The band's state pill and
  the Logs screen are components of their own (`ConsoleWeb.Band`,
  `ConsoleWeb.LogsScreen`). Nothing changes on the page.
- **The scripts are ShellCheck-clean**, style findings included:
  variables quoted where a value is one word, arrays where a string was
  split on purpose (`CONTAINER_ENTRYPOINT`, `DOCKER_TTY_FLAGS`,
  `BUILD_VOLUMES`, `SESSION_COMMAND`), `read -r`, `cd … || exit`, `$*`
  where `$@` sat inside a string, and the unused `REPO_URL` and
  `ENTRYPOINT_COMMAND` gone. The few lines that split on purpose carry a
  directive saying so.
- **Both packages are formatted**, the console's heex included — the
  first time the HTML formatter ran over its components. Three
  interpolations it broke into a stair are helpers now (`probe_word/1`,
  `files_word/1`, the drawer's prose parts), and the igniter's
  `template/2` compiles its EEx and evaluates it apart, since
  `EEx.eval_string/3` hands its options to `Code.eval_quoted/3` and
  dialyzer read every installer that renders a template as code that
  never returns.
- **Credo's refactoring findings addressed.** In the igniter: the
  member's question in `workbench.expand` is a function of its own,
  `.gitignore` and the env files share one `append_entry/4`, the ash
  site comparison judges one feature per function, `PhxDelta` reads a
  file's secrets and merges one changed file in functions of their own,
  and two `cond`s with one condition are `if`s. In the console: the
  long readers — `Docker.card/1`, `Diffs.worktree/1`, `Config.line/2`,
  `Box.argv/2`, the LiveView's mount and status handler — are split
  along the seams they had, `with`s of one clause are `case`s, and
  `Jobs.signal/2` calls `System.cmd/3` instead of `:os.cmd/1`. No check
  was relaxed and no line carries a disable directive.

- **The workbench compiles into its own build.** Two BEAMs compiled the
  workspace into one `_build`: the app service, and the console's
  resident — with every `mix` the console ran in-process, and every
  one-off `add` from the host, which ran as the compose's `app`. They
  were kept apart by Mix's build lock alone, which exists since Elixir
  1.18 and nothing required. Every run of the workbench now compiles
  into `<project>_workbench_build`, a volume of its own labelled under
  the project for `prune`, mounted over `_build` in the console's
  container and in the one-off runs; the app's `build` volume is the
  app's alone. `add` and `expand` from the host run on the workspace's
  dev image directly, no longer as a compose one-off waiting for the
  database they never used. The two sides share `deps/` — sources only,
  and only `deps.get` writes there — so `stacks use` and `new` refuse
  an Elixir below 1.18, where Mix locks that directory too. The price:
  what an insert changes compiles twice, incrementally; a build's worth
  of disk per workspace; the first `up` after `new` compiles the
  project once more. `prune --build` and `delete` remove the new volume.
  The resident stays, and `console/PLAN.md` says why `:erpc` does not
  replace it.
- **A deployment's row keeps its three buttons, in the order the row
  is read.** Bake, Down and Stop — Bake answers the compose file's
  column, Down and Stop answer the status column, so the group no
  longer has to be read backwards to pair each button with its motive;
  the rail's short row does the same, with Up and Stop sharing one
  slot, the state saying which. A verb the row cannot do now is unlit
  with its reason instead of gone: *not baked: Bake writes its compose
  file first*, *not up: nothing to stop*, *nothing to take down: no
  containers of this deployment*. The three slots hold still down the
  table, and a row says what it could do, not only what it can. Three
  buttons in a line is what the row wants, not what it needs: the cell
  asks for the line and settles for less, so as the sheet narrows they
  stack on their own — a column doing what a table column does — and
  the width goes to the services column, which was the one paying for
  them. Narrower than that the sheet measures itself, not the window
  (the grip moves the split under a still window): the target column
  gives a line of prose, the addresses close up and shorten to an
  ellipsis — the whole one is in the title, as always — and last the
  reading drops under the service's name; each address is only as wide
  as what it says, a floor of nine ems having made a short service
  (*migrate*) as wide as a long one for nothing. Stacked, the buttons are
  eight pixels apart, the same air they have side by side — the
  buttons' own margin, since an inline-block gives the line its margin
  box, and not a taller line, which would have padded the whole cell.
  Nothing is cut and nothing paints over the buttons, as the addresses
  did before.
- **The Project card reads in the Record's order, and the workspace
  wears its own reading.** The chip that says whether a project is in
  the workspace — the one that also warns that creating overwrites
  every file in it — leaves the card's heading for the workspace's own
  row, where its subject is. The stack, one line of three versions,
  becomes three rows — elixir, erlang, debian — so the card reads row
  for row like the Record's Birth table, and so the row that has moved
  since birth is the row that says so: `born on 1.17.3` sits on the
  elixir row alone, where it used to speak for the three. The installer
  says `phx.new 1.8.13`, the Record's own words for it, not the hex
  package's `phx_new`, and the flags row is `mix phx.new`, which is the
  command the Record prints above the one it reconstructs. Each row
  ends in a cog — the eye's own square icon button — where it used to
  say "change in config" in words, six times down one card. The
  workspace's own chip is two words, `empty` or `existing project`, on the
  row that names the path — the path is the subject, so the chip need
  not repeat it — and the second is `good`, not `bad`: a project in the
  workspace is the healthy state, the same green as *baked* and *up*,
  and the danger of overwriting it belongs to the Create button, which
  asks before it does it.
- **The jobs tray reads the job, not only names it.** Its bar is now a
  fold: pressed, the last job's output unfurls *upward* from it — the
  tray is `flex:none` under a screen that is `flex:1`, so the screen
  gives the height and scrolls, and the bar stays pinned to the
  window's foot where it was pressed. Nothing is covered, and the
  table you are about to act on is still under your eyes when the
  answer to the last press comes back; `→ jobs` beside the bar is
  still the way to the whole list. It is the same output the Jobs
  screen shows — `job_out/1`, lifted out of `job_row/1` so a job reads
  the same wherever it is met, with its own words about itself under
  the last line: run it again, drop it, stop it. The tray keeps its
  own fold, and reads whichever job is last, so the Jobs screen's list
  stays folded as its reader left it. The pane has the jobs' grip, at
  its top and not under it, since the edge that moves is the one away
  from the bar: `data-grip="up"` turns the drag and the arrow keys
  over for it, and the tray's height is remembered by name across
  papers, as the compose box's is.
- **One button for every line of `wb.sh`, and the line is written where
  it can be right.** `ConsoleWeb.Refs.job_button/1` is the single shape
  behind Bake, Down, Stop, Up, Build, Create, Delete and the Docker
  screen's removals — the unlit with its reason, the command in the
  title, the click that sends it — where five hand-rolled copies had
  already drifted apart (the deploy buttons put the command in their
  title, the prunes put a sentence). `bake_button/1`, `deploy_button/1`
  and `prune_button/1` keep what is theirs, which is deciding *why* a
  button cannot be pressed, and hand the rest over.

  With it, the hazard Create was cured of in its day is cured for the
  rest. A button whose line is composed out of a form — the deployment
  picked, `--replicas`, `--no-balancer` — was rendered with that form
  as it was, so a change and a click in the same instant ran the line
  as it stood BEFORE the change: `--replicas 6` typed, `--replicas 4`
  run. Those buttons now submit the picker (`phx-submit="deploy_run"`)
  with `name`/`value` saying which was pressed, and the line is written
  on the server out of what travelled — `ConsoleWeb.Deploy.line/2`,
  which is a pure function and has its own test. What is rendered on
  the button is only what it *says*. The ones whose line is only itself
  — Stop, Down, Delete, a prune — still travel on the click, and an
  unlit submit is rendered as a plain button so the form cannot leave
  by it either.
- **The Inserted list says what a cartridge went in with, even when
  the cartridge does not.** Its *installation parameters* column is
  drawn from what each cartridge reports of itself (`state/1`), and
  `healthcheck` reported nothing — it had no `state/1`, so it answered
  the default `%{}` and a project inserted with `--endpoint /health3
  --open-api` showed an empty cell. Two fixes, one on each side.
  `ecto` reported its database alone, so a project born with
  `--binary-id` read as if it had not been; it reports `binary_id` too
  now, off the generators entry `phx.new --binary-id` writes. And
  `healthcheck` reads its state back off what its install wrote: the
  endpoint is the router scope that routes `HealthcheckController`,
  and the OpenApiSpex variant is there when its schema module is. And
  the console, when a cartridge reports nothing, reads the parameters
  off the cartridge's Insert commit (`ConsoleWeb.Record.params/3`),
  marking the ones that say the default as the project's own reading
  does. What the project reports wins; the commit is what is left to
  read when it says nothing — a cartridge without `state/1`, or an
  edition from before it had one. And the column now spaces its flags:
  its rules stayed behind with the Birth table when the list moved to
  the shelf, so two flags ran together (`--endpoint /health3--open-api`)
  and broke in the middle of the second; they wrap between flags now,
  never inside one.
- **A cartridge's box keeps what it went in with, and its foot is the
  console's own.** The Installation screen's line said `./wb.sh add
  ecto` of a cartridge inserted with `--database postgres`: it was
  written from the form's live values, and those are empty while the
  form is locked. It reads the insert's own argv there
  (`ConsoleWeb.Box.line_argv/4`), the form's values while the form is
  open, and the bare verb when there is nothing to read — a cartridge
  born with the project, or inserted by a hand that left no commit.
  The fields start from the insert too, and not only when they are
  locked: `ash` and `chiefs_setup` can be run again to add, so their
  form stayed open and went back to its defaults, forgetting what the
  cartridge went in with. What the reader has just said still wins.

  Each verb has its own foot, and only when it is a verb at all:
  Insert while the cartridge is not in — and still while it is, for the
  two that add on a second run, `ash` and the `chiefs_setup`
  collection, which is why a box can have both feet, one under the
  other — and Eject once it is in. A button reading *Already inserted*
  was a state wearing a button's clothes, not an action that cannot
  run: what is in is said by the mention's dot and by the note. Unlit
  is for the verbs that ARE conceivable and cannot run now — a dirty
  tree, a cartridge that has to go in first, no commit to revert.
  Eject gains the line it never showed, which for a collection is the
  chain of reverts in the order they have to happen
  (`./wb.sh eject a && ./wb.sh eject b`), until now only in a title.

  Insert and Eject are `ConsoleWeb.Refs.job_button/1` now, like every
  other button that asks for a line: unlit with the reason in the
  title where they were flatly `disabled` and the reason lived only in
  the sentence beside them. Insert sends the form, since the options
  are in it; Eject is a click, since it takes none. The two shapes
  they had of their own — the big accent `.go` and the outlined
  `.eject` — go with them: the button that does the thing is a
  `.btn.primary` here as it is on Deploy, and the one that undoes it a
  `.btn.danger`.
- **The cartridges the project carries move to the Cartridges tab, and
  the shelf reads one state at a time.** The ribbon was *all /
  collections / base / with a box* — a question the box already
  answers, since what a cartridge is rides on it as a fact (`base`,
  `inserts 4`, `not done`) in both views. It is the state now:
  **Inserted · On the shelf · Not done**, each with its count, and the
  three planks that said the same thing under one another go with it.

  *Inserted* is the state with more to say, and its list is the Record
  paper's second section, moved whole: a row per cartridge with where
  it came from, its edition, the parameters it was installed with, the
  addresses it opens and the bell that calls them all once — columns
  that only exist for a cartridge that is in. Not a column changed;
  what changed is that they are read where cartridges are read, and by
  a shelf that already knew which were in. In the covers view the
  boxes are the boxes, wherever they stand. A row of that list is not
  a link, though every other row of the shelf is: the mention is a
  button that opens the box and the addresses are doors, and an `<a>`
  around all of it closes itself at the first door inside — which
  hoisted the addresses out and dropped them under the row, full
  width.

  The tab opens on what the project carries, and on the shelf itself
  when there is no project (`ConsoleWeb.Shelf.first_doc/2`). The Record
  paper keeps what the project IS — its name and its birth — having now
  given a section to each place its reader already was: the
  deployments to Deploy, these to Cartridges.
- **Build leaves the deployments' foot for each row**, beside Bake:
  the file, then the image the file names, then the status. The foot
  keeps one verb, Up. In the foot Build read as Up without the deploy,
  and on 2026-09-10 it went to the CLI on that reading; the row says
  what it is for. The dev image `up` never rebuilds — Build is the road
  to a new one off the project's Dockerfile.local, and the next Up
  recreates the containers with it — and the release image prod and
  scaled share builds here with nothing going down, where `up --deploy`
  replaces the deployment on its way: a build that fails leaves what is
  up as it was. The button sends the line it says, `build --deploy
  NAME` with scaled's replicas and balancer as the picker has them;
  `--no-cache` and the rest of what `docker compose build` takes stay
  the CLI's, where Tab completes them from the catalog. Unlit with the
  reason while the workspace is empty or a job runs, as Bake is.
- **Git goes last on the rail**, under Cartridges: what has happened to
  the project, after what the project is — the workspace, what answers,
  what is baked and up, what is in it. It sat second, where it landed
  when Git stopped being a tab of its own.
- **The rail says what each section has, and nothing where it has
  nothing.** On the Deploy tab the same head drops its word instead:
  the table under it says what there is row by row, so *Topology*
  named only the section. On the rail, where the section is folded
  shut half the time, Deployments' head said *topology* — what the section is,
  not what it holds — so it was the one head a reader had to open to
  learn anything. It reads like its neighbours now: `none baked`,
  `2 baked · prod up`, `1 baked · nothing up`, beside `3 services · 2
  doors`, `3 of 4 running`, `clean` and `8 in`. And with every head
  saying it, the four paragraphs that said it again under an empty
  section go: *Nothing answers yet…*, *The workspace is empty: Deploy
  → Project.*, *phx.new initialises the repository…*, *Nothing
  inserted yet…*. An empty rail is now a column of heads with their
  readings, and the sentence each of those paragraphs taught is still
  where it is acted on — the Deploy tab's own unlit reasons say it
  where the button is.
- **Delete has a box of its own again, and the first card is named for
  what it does.** The card that creates is *New Project* — it says what
  the *next* creation would use, config.conf and nothing else, so
  naming it after the project that is already there was always a
  little off — and its foot keeps one button, Create. What cannot be
  taken back goes to *Danger zone*, the tab's last box, under
  Deployments, in the foot the other two boxes have: the line it is,
  `./wb.sh delete`, taking the width, the button at its right as Up
  and Create sit at theirs, and under the line what that line takes —
  every file of the project in the workspace, its containers, its
  images and its volumes, the database's data with them, and it asks
  first. The button is a primary in the bad colour, filled and the
  size of Create and Up: what it does is a verb of this tab like the
  other two, and hiding it in an outline would only make it look
  optional. It is centred on the line, not on the line and the note
  together, so a longer note never moves it. Delete had such a box until it was retired for being a
  heading over one button that said only what the confirmation says;
  this one says the scope of the damage before a hand is near it,
  which neither the button nor the confirmation does. It is still
  unlit with its reason on an empty workspace, and it still never runs
  on the first press.
- **The deployments table's third column is `sync diff`**, not
  `differences`: what it holds is the drift between the compose file
  and what the cartridges ask for, which is the same word the row's
  chip uses when the two have come apart.
- **The project's papers in the order they are asked for**: Record,
  History, Pending, .env, README, CHANGELOG. Pending and History were
  at the tail, where they landed when Git stopped being a tab of its
  own; what has happened to the project belongs beside what it is.

### Fixed

- **A service the project does not carry wore the wrong colour.**
  `ConsoleWeb.Services.color/2` finds a service's role by asking the
  project, and the project only knows the cartridges it carries, so
  anything else fell through to the plainest token — every container on
  a shelf box drawn in the colour of network, databases and dashboards
  alike. The module's own rule is that a colour is a *role's*, not a
  service's, and that step is now reachable on its own
  (`role_color/1`), for a drawer that already knows the role. `color/2`
  ends in it.

- **A README's badges are drawn in the console, to the byte.** The
  badge the versioning cartridge puts under a README's title is a
  shields.io picture, and the console's policy loads no image from
  another origin (`img-src` is this origin, `data:` and `blob:`), so
  Project → README showed a broken picture with its alt. The policy
  stays as it is. A shields.io static badge says everything in its own
  address — `/badge/<label>-<message>-<colour>`, the style and the
  overrides in the query — and what the service does with it is
  published, so `Console.Shields` does the same: badge-maker's
  renderer followed line by line (the route's expression and its
  escapes, shields' colour names and CSS's, the brightness past which
  the text turns dark, widths looked up in anafanafo's tables of
  Verdana's advances — `console/priv/shields/`, MIT — truncated,
  rounded up to odd and pinned with `textLength`, which is why the
  badge is the same on a machine without Verdana), in the four styles
  those tables cover: flat, flat-square, plastic and for-the-badge.
  The SVG goes in the `<img>` as its own text, a `data:` address,
  asking nobody and needing no network. Checked against the service:
  49 addresses asked of img.shields.io on 2026-09-19 and kept in
  `console/test/fixtures/shields/`, and the 46 of them that are
  drawable come out the same bytes — emoji, CJK, `hsl(1turn,…)` and a
  label colour with no label among them. What is not drawn says so and
  is a link to itself wearing its alt: the social style, a logo
  (simple-icons, a request), a dynamic badge, any other outside image.
  In the shared renderer, so a cartridge's papers and the workbench's
  own README read the same.

- **A cartridge edited while the console is up shows its new options.**
  The shelf is read in the console's own BEAM, off the workbench's
  package as a path dependency, and the re-reading a changed features
  directory sets off asked the same loaded modules again: versioning's
  box went on offering `--version` two hours after it had become
  `--init-version`, beside a README — read off the disk — that said the
  new name. Two gaps: Phoenix's code reloader reloaded `:console` alone
  (`reloadable_apps` now names `:workbench_igniter` too, in dev), and
  the stamp watched the directories' modification times, which an edit
  in place of a manifest does not move (it takes the files in each box
  now). Checked on a console left running: an option added to a
  manifest appeared on the next page, and went when it was taken out
  (2026-09-18).

- **The Record's `--no-live` row points at html.** It named the
  `live` cartridge, gone into html as `--live` on 2026-09-18, so the
  row wore an unknown box's name and never read as inserted. The
  capability's cartridge is html now, as the database's and the ids'
  is ecto.

- **Auth0's mark is its dependency, not the Accounts context.** The
  cartridge read as inserted off `MyApp.Accounts`, the first module its
  installer creates — and the domain Ash writes with its
  authentication, so with Ash in the catalog showed Auth0 inserted and
  `add auth0` skipped itself with «already exists». The mark is
  `auth0_jwks` in `mix.exs` now, which only Auth0 adds, as Ash's is
  `ash`. And an Accounts that is there without it — Ash's, the
  project's own — is refused, naming it, since the templates would
  have planted over it (`on_exists: :overwrite`) once the mark no
  longer stopped them.

- **`add healthcheck2 --path /` answers at `/live` and `/ready`.** The
  prefix was normalised to `"/"` and the plug appended `/live` to it:
  the probes sat at `//live`, which no request asks for, and every
  orchestrator would have seen the app dead. The root is the empty
  prefix now, and the project's state reads it back as such — the
  console fills the cartridge's doors from it (`/live`). Found by the
  tests below, which call the plug.
- **A flag moot at birth speaks again once its cartridge came in.** On
  a project born minimal (`--no-ecto --no-html`) with the base
  cartridges added afterwards, the Record's `--database`,
  `--binary-id` and `--no-live` rows stayed unlit with nothing to say:
  the birth's shape alone decided what was moot, and the row's `now`
  was thrown away with it. It holds only while what makes it moot is
  still out: with Ecto in, `--database` reads not given and `now
  postgres` — the birth's reading carries phx.new's default database
  under `--no-ecto`, which was no database, so today's is the news —
  and `--binary-id` lights, with `now in` when the ids are binary;
  with the HTML views in, `--no-live` reads not given and `now in`
  when LiveView came with them.

- **A formatted project takes the dashboard.** phx.new's router opens
  its dev routes with a blank line after `do`; the formatter — the
  `precommit` alias phx.new itself gives the project — takes it out,
  right where the dashboard writes, and `add dashboard` conflicted on a
  file nobody had edited. The three sides of an Elixir file are now
  merged in the one layout every formatter configuration agrees on — no
  blank line after a line that opens a block (`PhxDelta`) — so they
  differ by what was written, not by how it was laid out. The
  project's own formatter is not asked: after html it wants LiveView's
  plugin, which may not be loaded where the installer runs. Found by
  the test below, on its first run.
- **A base cartridge no longer trips on `.gitignore`.** `add esbuild`
  stopped with an issue on every project: phx.new appends esbuild's
  patterns at the end of `.gitignore`, the workbench had appended
  `.env` there at birth, and a three-way merge cannot order two appends
  after the same line. `.gitignore` is merged as what it is, a set of
  patterns: the capability's lines go in once, at the end, past the
  project's own; what it takes away goes; never a conflict
  (`PhxDelta.merge_set/3`). And an insert with issues is a failed
  insert now: Igniter showed them, wrote nothing and returned zero,
  and `add` took the zero for an insert that landed, committing what
  was on disk — `Insert esbuild` with nothing in it but the
  `.gitignore.phx-new` aside. Every installer's task ends with a
  failure on issues (`WorkbenchIgniter.Task`), `add` undoes the
  half-insert as for any failure and keeps the `.phx-new` aside for
  the reader, saying so. A project that got the empty commit: `eject
  esbuild` reverts it, and `add esbuild` again does the rest.
- **`mix.exs` is no longer merged as text: a base cartridge applies
  what it holds.** At birth the workbench writes its own dependency on
  the project's `deps:` line, `deps: deps() ++ workbench_dep()`, and
  phx.new's html puts `compilers:` on the line right after it: a
  change beside an insertion is a conflict to a three-way merge, so
  `add html` failed on every project. A dependency the project added
  where a cartridge's go did the same. `WorkbenchIgniter.MixFile` now
  reads phx.new's two generations as code — the keywords `def project`
  returns, the list `defp deps` ends in, the keywords of `defp
  aliases` — says what the capability adds or changes, and puts each
  in with Igniter: a keyword or alias where the project keeps it, a
  dependency appended after the project's own, written as phx.new
  writes it (`runtime: Mix.env() == :dev` stays an expression). A
  keyword the project itself changed from what phx.new had is the
  project's: an issue names it and nothing is overwritten. A
  dependency the project already has, in any version, stays. The
  edit of birth stays where it was: Igniter reads the project's
  dependencies off the literal list in `defp deps`, and a `] ++
  workbench_dep()` there would hide every dependency from every
  cartridge.
- **A base cartridge brings its share of what `phx.gen.release` wrote
  at birth.** The workbench runs `mix phx.gen.release --docker` right
  after phx.new, and that generator decides once, off what is there:
  `lib/<app>/release.ex` and `rel/overlays/bin/migrate` only with Ecto
  in the dependencies, the `Dockerfile`'s assets steps (`mix
  assets.setup`, `COPY assets`, `mix assets.deploy`) only with an
  `assets/` directory. A project born bare and grown cartridge by
  cartridge (test_01, 2026-09-17) ended up with a production image
  without CSS or JS and a migrate service (`command: /app/bin/migrate`
  in the pod and scaled composes) with nothing to run, where the same
  project born whole (test_02) had both. `PhxDelta.generate/2` now
  gives each generation, base and theirs, the release's files too,
  rendered from Phoenix's own `phx.gen.release` templates with the
  generator's binding — the stack read back off the project's
  `Dockerfile` `ARG` lines (`docker_of/1`), so no build server is asked
  — and the delta carries them: ecto creates the `Release` module and
  `bin/migrate`, executable once written (`mix workbench.executable`,
  queued by the cartridge); the first bundler, esbuild or tailwind,
  puts the assets steps into the Dockerfile, the second finds them
  there. A Dockerfile that is not the generator's is left alone. Both
  Dockerfile bindings, Phoenix 1.8.13's `debian`-`debian_vsn`-slim and
  1.8.14's whole `debian_vsn`, are served. `phoenix` is a test
  dependency of the igniter now, for the templates.
- **iex on a dev deployment attaches to the node that serves the
  port.** `./wb.sh iex` and the console's `app · iex` ran `iex -S mix`
  on the app container: a second VM, with a Swoosh mailbox, a Repo and
  a PubSub of its own, so a `deliver` from it never reached
  `/dev/mailbox` and nothing evaluated there touched the server. The
  dev image's CMD now boots the server as the named node
  `<app>@<container>` (`elixir --sname <app> -S mix phx.server`, baked
  from `Dockerfile.seed.local` with the app's name, mirrored in the
  compose's comment and the workbench entrypoint's default), and both
  attach with `iex --remsh <app>` — the short name, completed with the
  container's own hostname — as the release's `remote` already did. An
  existing workspace takes it with `./wb.sh build` and `up`, since the
  CMD is the image's. A remote shell that reads EOF stops the node it
  is attached to (measured 2026-09-16 on the remsh, as wb.sh already
  knew of the release's), so wb.sh refuses `iex` without a terminal in
  dev too, with `elixir --sname wb_rpc --rpc-eval <app> 'EXPR'` as the
  one-expression way, and the console closes an iex session by
  SIGTERM to the iex it announced, waiting for it to leave before the
  port — its stdin — is closed: killed so, the local VM shuts down and
  the server stays. The one-off terminal, where nothing runs, keeps
  `iex -S mix`; `bash` and `iex -S mix` there is still the way to a VM
  of one's own. IEx colours its results on the node that evaluates
  them, so a remsh came plain: the app's node is told to colour —
  `IEx.configure`, its own setting, not `ansi_enabled` and the Logger
  lines with it — by an rpc before iex attaches, in the console and
  in wb.sh alike; and the terminal's lines keep their leading spaces
  (`white-space: pre-wrap`), which the page folded before.

- **The containers table's since column no longer repeats the state.**
  It showed `Exited (0) 7 minutes ago`, the state word and the exit code
  the state column already carries, because only a running container's
  `Up 4 hours (healthy)` was trimmed. Every status is now trimmed the
  same way — the state word, its parenthesis, the health — to its time:
  `4 hours`, `7 minutes ago`, `5 seconds ago`, nothing for a container
  that never ran. The `ago` stays: how long it has been up and how long
  since it stopped are different times (2026-09-16).
- **A project made from the console gets port 4000.** `new` asks
  for the first free host port from 4000 by connecting to the
  loopback, and run inside the console's container that loopback is
  the container's own, where the console itself listens on 4000: every
  project made from the console was given 4001, and `up` from the
  console would have refused a workspace baked on 4000 as held by a
  host process. In the console the answer is Docker's now — the host
  ports its containers publish, over the socket the console mounts —
  and on the host the loopback's, as before (`port_held`).
- **Opening a compose file on Deploy no longer widens the rail's right
  air.** The rail's scrollbar gutter, measured by the Rail hook and
  given back by the rail's right padding, was written on the app's
  inline style, which every LiveView patch of the page dropped: 15px
  more air on the right after a compose file opened under its row, or
  a status arrived. It is written on the root now, as the rail's width
  is, where no patch reaches.
- **Opening a compose file on Deploy no longer presses the rail's Left
  square.** The two squares' pressed state and title are the Rail
  hook's, painted from the frame kept in this browser, but the
  template wrote them too, and every patch of the page — a compose
  file opened under its row, a status arriving — put the template's
  back until the hook's next repaint: Left pressed with the rail
  hidden. Invisible until the pressed state had a look (2026-09-15);
  the squares are `phx-update="ignore"` now, so a patch leaves their
  attributes alone.
- **A cartridge pressed on History opens its box over History.** A
  box, and the workbench drawer, open over the screen the reader is
  on, and the screen keeps its place under them: on Project, the paper
  and the commit open on it, which the drawer's links carry along
  (`/project?paper=history&commit=SHA&box=k6`) and which Put back,
  Close and the scrim come back to. Before, opening a box went to the
  bare tab, so pressing a cartridge's mention on History landed on the
  Record paper with the box over it, and closing the box left the
  reader there. A key the drawer's own query names — `paper`, the
  box's manual's and the workbench's — is left out of the URL for the
  screen and kept on the page instead, so the URL names it once
  (`Refs.over/2`).
- **A line's text sits centred in its line by its capitals**, on the
  Files sheet, the Logs screen and the Interface tab's miniature. A
  line box is the font's ascent and descent with the leading split
  above and below, and a face's descent is room most lines never use:
  in Fira Code a line of code sat three pixels high in a twenty-two
  pixel row, plainest on a row with a ground — an added line, an
  error. The line box is trimmed to cap height and baseline
  (`text-box: trim-both cap alphabetic`) and the leading given back as
  equal padding, so the capitals are centred in every face and the
  descenders hang below; the row keeps its height, leading times size,
  and the line numbers are centred the same way. Every width, air and
  line height that places the text is rounded to whole pixels
  (`round()`, as the drawer already rounds its own width), because a
  bitmap face — Tamzen, the VGA — blurs the moment its glyphs land on
  a fraction, and a `ch` or an `em` is a fraction more often than not:
  each row is exactly the rounded leading tall, and a line number is
  centred by arithmetic, the cell's leftover halved and rounded for its
  own count of digits, since `text-align` put a number one digit short
  of the widest on a half pixel — a bitmap digit is an odd number of
  pixels wide. A browser without
  `text-box` keeps the old line box.

- **A lexer that hands a lone codepoint as a token's value no longer
  throws the line cutter.** `Console.Highlight.token_lines/1` took the
  value for chardata; the Files sheet caught it and fell back to plain
  text for the whole file, and the Interface tab's sheet, which does
  not catch, went down with the drawer. The value is wrapped first.

- **A container that exited read `unhealthy`.** Docker keeps a stopped
  container's last health, and the reading put health before state:
  an app that crashed wore `unhealthy` beside its `Exited (1)`. Health
  counts while the container runs; a stopped one reads its exit code.
- **A base cartridge's box showed its fields empty** — `--binary-id`
  unchecked with the project saying true. The locked fields read the
  Insert commit alone, and a cartridge in from birth has none; they
  read what the project reports first (`state/1`), then the commit,
  then the default — the rule the Inserted list already had.
- **The page scrolled under a long screen, and the header went off
  with it** (Deploy). A `.sr` label (`position:absolute`) deep in the
  screen was placed against `.app` rather than the box that scrolls,
  and its 1px past the foot gave the whole page a scrollbar. The
  scroll boxes — the screen's and the rail's — are `position:relative`
  now, so what they hold is placed in them.
- **The output's grip moved nothing until the hand had crossed the
  box.** A drag started from the box's cap (`max-height`), which a
  short output never reaches — past its foot in the tray, past its
  head on the Jobs screen. It starts from the box as drawn.
- **`wb.sh eject mock` left healthcheck's tests without their
  library, and said nothing.** `mix workbench.dependents` read
  `requires` alone, and the three cartridges that compose mock declare
  no requirement on it; eject reverted the commit and no one was named.
  The walk reads `requires` and `composes` both now, in the reach and
  in the eject order: a cartridge that brought another in stands on it
  as much as one that required it.
- **The version and the help's name, empty when wb.sh is called by a
  relative path from elsewhere.** Two readers open the script's own file
  to answer — the version off line 3, the name off line 2 — and they
  opened it as `$0`, which the `cd` to `WORKBENCH_PATH` three lines into
  the script had already made meaningless: `repos/workbench/wb.sh help`
  from `~` printed two `sed: can't read` and left both fields blank.
  `WORKBENCH_SELF` is the script's file, absolute, and the three places
  that want it — those two and `demo` — take it from there. It is read
  off `BASH_SOURCE` and not `$0` now, so it holds when the script is
  sourced rather than run. The string comparisons became `[[ … == … ]]`
  while there: `==` is bash's operator, and `[ ]` only tolerated it.

- **Two warnings and an error at the end of every creation from the
  console.** Mix 1.19 deprecates the commas `mix do` took between
  tasks, and the three places wb.sh chained tasks that way — the
  workspace's igniter runs, in-process and in a container, and the
  package's — said so on every status the console read; they chain
  with `+` now. And `Error opening ETS file ~/.hex/cache.ets: :badfile`:
  Hex rewrites its registry cache in place, and since the workspace
  rides in the console's container the readers of the status opened it
  while the job's own mix was writing it, so Hex threw the cache away
  and fetched the registry again. The readers have a Hex home of their
  own now (`reader_igniter`), under the console's build volume; the jobs
  keep the user's, and no longer share it with anyone.
- **The console warned of the legacy builder on every build.** Its
  image carried Docker's static CLI and the compose plugin, pinned to
  the host's versions, and no buildx: a `docker build` from in there —
  the toolchain image of a new project, `bake`, `console build` — fell
  back to the deprecated builder and said so. The CLI and both plugins
  now come from Docker's apt repository for the image's Debian, no
  daemon, no versions to pin: the client negotiates its API with the
  engine on the socket, so the two build args wb.sh took off the host
  are gone with the warning.
- **Two workspaces made while each other slept were given the same
  port.** `first_free_port` asked only what listened at that moment, and
  a workspace that is down holds its ports as surely as one that is up:
  six workspaces ended up baked on 4001, to meet Docker's "port is
  already allocated" on their first `up` together. A free port is now
  one nothing listens on and no other workspace under `_workspaces/` has
  in a compose file of its own — the scaled files' replica ports
  included. And `up` checks the file's ports before compose does: one
  held by another workspace's containers is refused naming that
  workspace and a free port to move to; one held by a process on the
  host is said so. The fix is the port line in the file, which prod and
  scaled read on their next `up`.
- **A Postgres project without the pgadmin cartridge still published
  pgAdmin's port.** The port line on the pod's `network` service hung on
  Postgres being in, not on pgadmin, so the status read a port and the
  console drew a link to nothing on the rail and among the doors. It
  hangs on the cartridge now; a vanilla `new` publishes the app alone.
  `./wb.sh bake` takes the line out of a workspace baked before.
- **The console's «Create project» ran a stale command.** The line was
  rendered onto the button, and a change of the form and the click in
  the same instant sent it as it was before the change: a `--database
  mssql` chosen, a bare `new` run, a Postgres project born. Create is
  the form's submit now, and the server builds the line from what the
  form carries.
- **`up --deploy scaled` on a project without a database or clustering
  wrote a compose Compose rejects.** The app anchor kept an
  `environment:` with nothing under it but comments, and compose
  requires a mapping. Found when every fixture was put through
  `docker compose config`; the key is left out when nothing goes in it.
- **`up --deploy prod` wrote a truncated compose for a project without a
  database.** The no-database cut removed the app's `depends_on`, which
  was the line the prod cut of the volumes ended on, so `sed` cut to the
  end of the file: no healthcheck, no `configs:`. Found by the golden
  corpus; the rendered file carries everything.
- **A box's doors never read their `when`.** `Cartridges.holds?/3`
  matched any map with its first clause, so a door's `when` was
  unwrapped twice and always held: a door meant only for `--with x` or
  only with another cartridge in stood open regardless. Dialyzer found
  the dead clauses.
- **`app_repo/1` would have split a `nil` image.** The project's image
  can be unset; the repository is read only off a binary now.
- **`psql_extras`'s tests ran on a project without Ecto** and had
  refused since the cartridge learned to require it; they run on a
  Phoenix project now.
- **A box's runs are drawn on whole pixels.** The drawer sat wherever
  `margin:auto` left it — `94vw` is seldom whole, so it landed at x.03 —
  and a bitmap face such as Tamzen, drawn half a pixel off, is a blur.
  The drawer's width, height and corner are now rounded to the pixel,
  and a job's output rounds its leading too: 13px at 1.5 gave 19.5px
  lines that took turns at 19 and 20.

### Removed

- **The pgadmin and adminer boxes**, merged into db_admin (Added,
  above). Their files in a project are the new box's marks, so nothing
  is migrated: `wb.sh add pgadmin` is now `wb.sh add db_admin --admin
  pgadmin`, or bare on Postgres.
- **The osmon and psql_extras boxes**, merged into dashboard_extras
  (Added, above). A project that carries osmon's `:os_mon` reads as
  carrying the new box, whose mark it is; one with psql_extras alone
  reads as not, and inserting the box adds `:os_mon` and leaves the
  dependency as the project has it.
- **The Docker screen's three prune buttons** — the untagged images,
  this workspace's build volumes, what other workspaces left. What each
  removed is said in a note beside its table, with the `./wb.sh prune`
  line that does it from the terminal; the untagged count and their
  size stay on the note. Removing by the row is what the screen does
  now, and the three sweeps are the terminal's.
- **`probes:` leaves the cartridge manifest.** `console/0` had two kinds
  of address — the *doors* a cartridge opens on the app's port, and the
  *probes* "the console polls and shows on the board", which nothing
  ever polled. The only difference left was a face, `.probe-ref`, the
  door minus its box, and a promise the project would have been keeping
  for the workbench's sake. Decided on 2026-09-08, with the Record
  paper: the project owes the workbench nothing — a health endpoint is a
  route it has for its own reasons, and the console reads it and calls
  it like any other door. healthcheck and healthcheck2 now declare their
  paths as doors; the catalog's `console` carries `doors` and `tabs`;
  `Doors` has no probes row, the box no *Answers* row, `Refs` no
  `probe_ref`. The design system's `.probe-ref` and its decision page
  retire with the address component that follows.
- **The decision pages of the console.** `console/la-segunda-fila.html`,
  `console/docker-en-la-consola.html` and `console/colorear-el-codigo.html`
  are gone: each was made to settle one question of the interface — the
  second row of tabs, the Docker screen, the colour of the code — and
  each is settled, its answer in the console and in this file. They stay
  in the history for whoever wants the candidates.

## v0.11.0 - (2026-09-06)

### Added

- **The production deployment migrates before it boots.** `up --deploy
  prod` used to start the release against whatever the database had:
  `bin/server` runs no migrations, and the dev image's `mix setup` is
  not there. The dev/prod seed now carries the one-shot `migrate`
  service the scaled seed already had — `bin/migrate` from
  `phx.gen.release`, the same image, run to completion inside the pod
  — and `bake_compose` sorts it by Dockerfile: the dev file drops it
  (the dev image migrates itself on boot), the prod file hands the
  app's `depends_on` over to it. It is the release phase every
  platform has under its own name, and now both release deployments
  say so the same way. `logs`, `stop` and the help know the service.

- The postgres service of the dev/prod seed declares `POSTGRES_DB:
  APP_prod`: the image creates it when it initialises the data
  directory, which is the only moment it honours the variable. A
  release deployment migrates into a database `bin/migrate` does not
  create, and prod and scaled share this volume with dev — so it has
  to be there from the first init, whichever deployment does it.
  Verified on `test_83` from a fresh volume: `migrate` exited 0 and
  the release answered 200 on the first `up --deploy prod`.

- **A Git screen.** The rail said `dirty` and offered a commit it could
  not name. Two documents under the row: *Pending*, what a commit would
  take, file by file on the sheet the box's Files screen draws (the
  tracked changes as a diff, every untracked file whole), with the
  commit's title and body above it — the message travels to `wb.sh
  commit --message-file`, since a job's argv cannot carry a line; and
  *History*, the log with the cartridge inserts marked, each commit
  opening its diff on the same sheet. Narrow on purpose: no branches,
  no remotes, no discarding by file — `wb.sh` alone writes the
  workspace and the house's undo is `eject`. What it says that nobody
  did: a dirty tree stops `add` and `eject`, so the commit is what lets
  the next cartridge in. The rail's button now leads here.

- **The console listens to Docker.** `Console.Events` keeps one
  `docker events` open for as long as the console is, parses what
  arrives, drops the healthchecks' `exec_*` at the source, keeps the
  last 500 and broadcasts each one — and, the reason it comes first:
  a life event on a container of the workspace's project (`die`,
  `oom`, `health_status`, `start`, `destroy`…) asks the Bench for a
  fast status, settled over 800 ms. Until now the status was read
  after a job and never on a clock, so a container that died on its
  own went unnoticed until the next job. It has to be a stream and not
  a reading: the daemon holds only its last 256 events, and two
  healthchecks every 10 s fill that in seven minutes — measured on
  2026-09-05, `--since 2h` answered exactly 256 lines, all probes.

- **A Docker screen.** What Docker Desktop showed and the rail could
  not: six documents under the Project screen's row of tabs, settled
  in `console/docker-en-la-consola.html` (2026-09-05). *Containers*,
  the rail's table across the screen with since when, restarts, ports
  and — streamed only while the document is in front — cpu and
  memory, and each published port a door — the rail's notation for an
  address — one per line, opening on the host; the console itself a
  row, marked; the card of the container
  picked under the table: command, user, restart policy, network,
  healthcheck with its last probes, mounts, env with the secrets
  masked. *Images*, one per ID with every name it wears (the app's
  `:local` is the toolchain's, tagged per workspace). *Volumes*, with
  size and who mounts them, and the disk. *Networks*. *Events*, the
  feed, with the badge Jobs has: red, counting what died with a code,
  was killed for memory or turned unhealthy since the reader last
  looked. *Deploys*, each deployment's compose file read like the
  `.env`, the one not baked unlit. Two scopes on every document: this
  workspace, or the whole daemon — where the leftovers of the
  workspaces before this one are. `Console.Docker` reads it all with
  short `docker` commands; nothing starts a container. The two live
  columns do not dance: `.num` joined the design system with its rule
  (one unit per column, fixed decimals, a reserved width), the stream
  is normalised as it is read, and the README says why.

- **`wb.sh restart` and `wb.sh prune`.** The console's one act on a
  single container is Restart — `docker compose restart SERVICE`, the
  deployment left whole; Stop and Start of one are absent, not unlit,
  because the deployment is the unit. `prune` removes what no live
  workspace uses and never this workspace's deployment nor the
  console — nor anything on the daemon that is not a workspace of this
  workbench, which it tells by the seed's first line in the compose its
  containers name, or by the directory being under `_workspaces`: the
  stopped containers of the other workspaces with their anonymous
  volumes, and those workspaces' networks and named volumes, the build
  volumes made before `wb.sh` labelled them included (`prune`); the untagged images a prod bake leaves (`--images`); this
  workspace's two build volumes, refused while the app mounts them
  (`--build`). Always confirmed. `.env` masking learned YAML for the
  composes: `POSTGRES_PASSWORD: postgres` is a secret whatever the
  punctuation.

- **The code's and the files' faces, from the drawer.** Two rows beside
  the ground in the console's UI pane, each with a face, a size and a
  leading, kept in this browser like the frame and the ground: *The
  code* is what runs — the terminals, the jobs' output, the logs,
  Docker's events — and *The files* is what is read — the Files sheet,
  the diffs, `.env` and `config.conf`, the papers' code blocks. Each is
  three custom properties on the root (`--code-face`, `--code-size`,
  `--code-leading`; `--file-…` likewise) that every surface of the
  group reads with its own default in the fallback: the house's IBM
  Plex Mono at each surface's own size and leading is the properties
  absent. A sample under each row's selects — a log line and a line of
  code; a diff hunk — is set in the same properties, so it shows the
  choice before any screen does. The faces travel with the repository, the first that do
  (`console/priv/static/assets/fonts/`, with a README of sources and
  licences): Fira Code (OFL), Flexi IBM VGA (CC BY-SA 4.0) and Tamzen,
  a bitmap face whose seven drawings are the seven sizes it offers —
  the size select takes its options from the face. Chromium was made
  to draw every one at its pixel height before any of this was built.

- **A box's runs read as jobs.** The install screen of a cartridge's
  box showed the last insert or eject as a black pane under an "Output"
  label, always open, with its own stylesheet and its own empty words —
  a second way to meet a job. Now it lists the box's inserts and
  ejects, newest first, as the rows the Jobs screen draws: the same
  chip, command line and duration, the same fold and grip, the same
  words at the foot — confirm it, stop it, run it again. The row is one
  component, `job_row`, that both screens use; the unfold state is
  shared, because it is the same job. The pane `.log` stays for the
  cluster's probes, which are not jobs.

### Updated

- **One Project card on the Deploy tab.** "New project" is "Project",
  and "Delete the project" sits in its foot beside "Create project":
  what the one makes, the other takes away, and the card's chip — *the
  workspace is empty*, or the red *a project exists here* — already
  said which of the two applies. The button had a box of its own under
  "Workspace", the red-edged half of what was once "Database and
  workspace"; with the database errand gone (Removed, above), a heading
  over one button named only what its confirmation already says. The
  board's and the shelf's pointers say "Deploy → Project creates one".

- **The row of documents is one component, and the second row looks
  second.** Six rows of the console said which document of a screen or
  a drawer was being read, each written again with a small difference
  and each setting its own air, ground and margin. `ConsoleWeb.Ribbon`
  draws all six now, with the unlit tab `aria-disabled` in one place.
  And the docked ones — under a screen's tabs, under a drawer's — were
  the first row's grammar ten per cent smaller, which told the reader
  nothing about rank: they are a band of the house's second surface
  now, lower, with the document being read cut into the ground of the
  pane it opens, and the gold rule stays on the row that leads. Settled
  in `console/la-segunda-fila.html`.

- **No container of a deployment comes back on its own after a
  reboot.** The pod and the database carried `restart: unless-stopped`
  (the dev and the scaled compose) and the app and pgadmin did not, so
  a reboot of the host brought half a deployment back and the status
  could only say "no deployment is up and these are still here". The
  rule is that a deployment goes up and down whole, across a reboot
  too: no `restart:` anywhere, a reboot leaves everything exited, the
  status says down, Up raises it whole. What it gives up — a database
  that crashes is not restarted alone — the events feed says, and
  Restart is a click.

- **The scrollbar sits on the edge of the box that scrolls.** The
  console drew it in four places at once: on the panel's edge for the
  document tabs and the drawer's Files and faces, 28px in on Project,
  Git, Docker and the shelf, 32px in on the papers of a box and of the
  workbench, and halfway across the modal on Config and Interface,
  whose panes were also clamped to 860px. All the same cause — when a
  row was docked above a scroller the scroller went down a level, and
  the padding stayed on the wrapper around it. The bottom had the same
  fault: the filled panel kept 22px of ground under the scroller, so
  the last row of boxes was cut a strip above the band and the bar
  stopped short of it while the rail's ran to the edge. The air is now
  on the scroller (or on the row and the content beside it), the
  measure on the form's blocks, and every pane that can scroll says
  `scrollbar-gutter:stable`. Written as a rule of the house, in the
  scrollbar note of components.css and in assets/design/README.md.

- **The box is turned by hand.** A click on the box in the drawer's
  Box screen turns it over, and Enter or Space with it focused; the
  button that stood under it is gone. The cursor had promised a viewer
  since the mock, and the console never wired one: the lozenge a figure
  shows on hover now sits in the box's corner and opens the viewer on
  the side that shows, without turning the box.

- **Every paper with a section has its index.** The column of h2s
  beside a paper wanted three of them; with fewer the paper was read
  full-width, and a changelog — whose h2s are its versions — has one or
  two for most of its life, so it took a different shape from the
  README beside it. The index is there whenever there is an h2, and the
  rule lives once, in `Console.Papers.booklet/3`, where the three
  renderers (a cartridge's papers, the workbench's, the project's) had
  each carried a copy of the number.

- **`wb.sh` inside the console stops starting containers it is already
  in.** The console runs on the toolchain image, and `wb.sh` run in it
  went on starting a sibling container on that same image for every
  `mix` and `git` — about 4N container starts for an `add` of N
  cartridges. `./wb.sh console` now mounts the workspace at `/app/src`
  with the app's build volumes over it, as the app service has them,
  and says so (`WORKSPACE_MOUNT`); the four runners that need nothing
  but the toolchain (`workspace_igniter`, `workspace_git`, and
  `entrypoint_run` for `new`, `add` and `expand`) then run in this
  process, and in a container as before from a host. One command, one
  place that decides where; the verbs know nothing of it. The resident
  works from `/app/src` too, so it adds to the app's build instead of
  compiling the project a second time from the host path (Mix keys its
  manifests on the source path). What stays in a container: `setup`
  and the cold `mix` (the database is in the pod), builds and compose
  (the daemon), and the package's own tasks (they would compile
  through the workbench's bind mount). The mapping is in
  console/PLAN.md, *The console is the toolchain*. The resident makes
  the same check as `wb.sh` — the mount is the workspace config.conf
  names now, and the project's — and, failing it, runs as one container
  on the workspace's dev image with its volumes, as on a host; and a
  resident of a workspace config.conf no longer names is dropped for
  one on the workspace named. Before, a console started for one
  workspace and pointed at another reported the first workspace's
  cartridges on the second, and went on reporting them.

- **The console says which workspace it was started for, and starts
  again for another.** Its container mounts one workspace and that
  project's volumes, and cannot mount another: config.conf named
  another since, the board's workspace section says so and offers
  *Start again* — `console` run as a job. From inside, `wb.sh console`
  starts a helper container on the console's image that runs it from
  outside a moment later, since the console cannot remove the container
  it runs in without ending the job that asked. `wb.sh console` keeps
  the port of the console it replaces, so the address survives and the
  page reconnects on its own. And `wb.sh console` asks for the
  toolchain image only when it has to build the console's: built once,
  the console comes up on an empty workspace too, where `new` is the
  first act and the toolchain of a project not yet born has no tag.

- **Colour without a terminal, in jobs and in sessions.** A `Port` is a
  pipe, and on a pipe mix, hex, git and compose turn their colours off
  on their own while the console's page turns ANSI into spans. `wb.sh`
  takes `WB_ANSI=always` — Elixir by `ELIXIR_ERL_OPTIONS`, git by the
  config it reads from the environment, compose by `COMPOSE_ANSI` —
  and the console sets it on every job; the Terminal tab passes the
  same variables to its `docker exec` and `docker run`, so iex, mix
  and git colour their output there too. From a terminal, or unset,
  nothing changes. BuildKit stays plain: it colours only a real tty,
  and that road — a pseudo-terminal for jobs — is left for later.

### Removed

- **The `setup` command, and the Database zone of the console's Deploy
  tab.** It dropped, created, migrated and seeded the database of one
  `MIX_ENV`, and it was the step the README asked for before the first
  `up`. Both of its jobs have owners now: the dev image creates and
  migrates on boot (`mix setup`), the release deployments migrate into
  the database postgres created (`POSTGRES_DB`, the `migrate` service),
  and a reset with the seeds is `./wb.sh mix ecto.reset`, which the
  `mix` help now says. Its prod variant never fitted — `ecto.setup`
  under `MIX_ENV=prod` from the mounted source, with an entrypoint note
  excusing the "Could not warm up static assets" error — and it was one
  of the two commands keeping `--env` as `MIX_ENV`. The other, `demo`,
  now takes `--deploy TARGET` like every deploy command and runs new,
  up, logs and delete.

### Fixed

- **The box's Installation and Files screens did not scroll.** The
  drawer clips what passes its height, and only the papers and the UI
  pane scrolled inside it: a long options form, or the runs under it,
  ran out of reach on a short window. Every screen of the drawer
  scrolls on its own now, the box's two faces included.

- **A paper's figures opened the viewer only on the first paper.** The
  `Booklet` hook wrapped each figure — the expand hint, the click that
  opens the viewer — when it mounted, and the booklet is one element for
  every paper of a box: turning from the README to the DESIGN patched
  new figures into it, and they stayed bare images. The wrapping runs on
  every patch now, idempotently.

- **The scaled deployment over a dev database.** The clustering paper
  left it open (§5): `up --deploy scaled` recreated the dev `database`
  container carrying its anonymous volume over, so `POSTGRES_DB` was
  never honoured, `APP_prod` did not exist and `migrate` exited 1. With
  the dev seed now declaring the same `POSTGRES_DB`, the database is
  created by whichever deployment initialises the volume first.

- Both seeds' postgres healthcheck asks over TCP (`pg_isready -h
  localhost`). Without `-h` it asked the unix socket, which the image's
  init answers on its temporary server: a fresh volume said healthy
  before the real server listened, and the migrator's first connections
  were refused (Ecto's pool retried, so it only showed in the logs).

- **The console would not start on a clean daemon.** Its image is
  built on the toolchain's, and when that was missing `console` sent
  the reader to `new` — which builds the toolchain — so the first act
  sat behind the very screen that offers it, and `console build` said
  the same. Now `console` and `console build` build what they stand
  on: the installer's resolution and the toolchain's build came out of
  `new` into `resolve_installer` and `build_toolchain`, shared by both,
  so the toolchain the console builds is the one the project to come
  would have built, and `new` then finds it and builds nothing twice.

- **The dev app died by SIGKILL on every `down`.** The image's CMD was
  `sh -c "cd /app/src && mix setup && mix phx.server"`: the shell stayed
  PID 1 and forwarded nothing, so every stop waited compose's 10 s of
  grace and killed the app — `kill SIGTERM`, ten seconds, `kill
  SIGKILL`, `die exit 137`, read off the daemon's events on
  2026-09-05. One word, `exec`, on the last step (the seed Dockerfile
  and the entrypoint's default): the BEAM takes PID 1, gets the
  SIGTERM, stops the application in order and exits 0 — measured at
  3 s with `docker stop`. Prod was never affected: `bin/server` already
  `exec`s the release. Existing workspaces get it with their next
  `new`, or by putting the same line in their compose's `command:`.
  `init: true` on the app service besides, so docker's init reaps what
  the dev server's esbuild and tailwind watchers leave behind. And
  pgadmin had the same disease — its entrypoint is a shell that runs
  `/entrypoint.sh` — which the new events feed showed on its first
  restart from the Docker screen: `kill 15`, ten seconds, `kill 9`,
  `die exit 137`. The same word there.

- **The Cluster screen's "Who answers?" said "no answer" to a balancer
  that did.** The console reaches the app's port by the name it has for
  the host, `host.docker.internal`, and a prod endpoint's `force_ssl`
  leaves only `localhost` alone: under any other name it answers 301 to
  https, which the probe followed to port 443, where nothing listens.
  The probe now asks as the browser asks — the same port, the request
  naming `localhost` — and gets what the reader gets: `HTTP 200 ·
  X-Served-By: 172.26.0.5:4000`, a replica per request.

- **The console went deaf during a `new`.** Every line a job wrote put
  the whole job — all of its lines — on the PubSub topic, and every
  page rendered every line of every job again: quadratic, and two
  thousand lines of `new` left the reader's clicks queued behind the
  renders. `Console.Jobs` holds the output now and broadcasts it in
  batches of at most 50 ms as `{:job_lines, id, from, html}`; a
  `JobLines` hook writes them into a `phx-update="ignore"` element,
  on the Jobs screen and in the box's drawer alike, and asks for the
  backlog when it mounts. The assigns never carry a line again — the
  rule the Logs screen already followed.

- **The Logs screen mistook the `ansi` cartridge's colours for text.**
  With the cartridge in, the app's lines arrive with escapes, and
  `--no-color` only undresses compose's prefixes: the screen showed
  `[22m` and `[36m` as characters, and its level regexes — anchored at
  the start of the line, where the escape now stood — read every
  `[error]` and `[warning]` as info. `Console.Logs.parse` gives each
  line a `text` without escapes, for the level, the filter and the
  search, and an `html` with them as spans; a line that was nothing
  but a closing reset is no line.

- **A terminal session opened before the status arrived went to
  docker with an empty mount.** The tab is judged unlit only once the
  status is here, so before it the button was live, the targets were a
  guess and the source's path was nil: `-v :/app/src`, exit 125. The
  button stays dark with the reason until the status is read, and the
  server ignores the event meanwhile.

- **`up --deploy prod` died on `env file …/build:/app/src/_build not
  found`.** The bake stripped the app's `volumes:` block by deleting
  two lines, the key and the source mount, from a block that now has
  four: the two build volumes were left standing under `env_file:`,
  where compose read them as files. The block goes whole, up to
  `depends_on:`, and the top-level `volumes:` with it — a release has
  no `_build` and no `deps` to keep.

- **A new project would not build its assets.** The first `up` of a
  freshly created workspace ended in `Error: Can't resolve
  'daisyui/packages/bundle/daisyui'`, and heroicons right behind it.
  Since phx_new 1.8 daisyUI is a git dependency of the generated
  project, resolved through the `NODE_PATH` that `phx.new` writes into
  `config.exs` — the conventional `deps/` path, written without asking
  Mix, as `assets/vendor/heroicons.js` writes it too. The workspace
  kept its dependencies in a volume *outside* the project
  (`MIX_DEPS_PATH=/app/deps`), so that path pointed at nothing.
  **The volumes moved instead of the paths.** They now cover `_build`
  and `deps` where Mix looks for them, inside the source mount, and
  nothing is told anything: `MIX_BUILD_ROOT` and `MIX_DEPS_PATH` are
  gone from the toolchain image. Compiled code still never touches the
  bind mount — a volume covers the path, nothing is written through —
  and whatever the generator writes next, if it is where Mix looks, it
  is where the volume is. The reason the paths had been put outside the
  source was that "Mix keys its manifests on those paths"; measured, it
  keys them on the *source* path, and moving `_build` or `deps`
  elsewhere costs nothing. An existing workspace moves over with
  `./wb.sh bake && ./wb.sh up`. Only the console keeps the two
  variables, for its own build: its source is mounted at the
  workbench's host path, which no image can know, so there is no
  directory in its image for a fresh volume to take ownership from.

## v0.10.0 - (2026-09-02)

### Added

- **The console, out of the mock and into Phoenix.** The LiveView
  console (`console/`) now holds what the mock drew: the board, Deploy
  with the New project card and the Deployment card, Jobs with the
  `wb.sh` line and its history, live Logs, the shelf with its planks
  and its list, the box in hand with its four screens — Box,
  Installation with `expand`, Files off the workspace's git, Manual
  rendered with the HTML in it left out — the Project papers, the
  workbench's drawer with `config.conf` as a form, a line-oriented
  terminal, the cluster and the figure viewer. The screen and the box
  live in the URL. What the console knows is held once for every page
  (`Console.Bench`): a page mounting starts no container. The plan and
  the architecture are in `console/PLAN.md`.

- **What `wb.sh` owes the console.** `status --json` answers on an
  empty workspace, says which deployment is up, carries each
  container's address and each insert's argv, and `--fast` leaves out
  the one part that boots Mix; `catalog --json` answers without a
  project, off the package; `expand [--json]` is the planning half of
  `add` on its own; `config set KEY=VALUE` is the one writer of
  `config.conf` besides `stacks use`; `engine` picks which Docker the
  script talks to. The catalog's `need` carries its four parts.

- **`mix workbench.serve`**, the resident: one BEAM with the project
  loaded, answering `status` and `expand` on stdin for as long as the
  console runs, instead of a Mix boot in a fresh container per question.

- **A `specdd` cartridge, designed and pending.** SpecDD — spec-driven
  development with `.sdd` files beside the code — on a stock `phx.new`
  project: what `specdd init` writes (the bootstrap chain, the pointer
  on top of phx.new's `AGENTS.md`, `CLAUDE.md`), off release 1.5's
  files embedded in the cartridge, plus a `bootstrap.project.md` for an
  Elixir/Phoenix project and three starting specs (the project, `lib/`,
  `test/`). The manifest is registered so the shelf shows the box as
  pending; the templates and assets are in `priv/features/specdd/`; the
  installer is not written. The design (`DESIGN.md`) records what the
  CLI writes and touches on update, why the files are embedded rather
  than downloaded, and one thing its `resolve` proved: the root spec is
  found only under the directory's own name, so `--root` exists and the
  README's docker commands mount the project under it.

- **psql_extras says what it builds on, and where it does not belong.** It
  declared nothing and would install on any project: `ecto_psql_extras` is
  an Ecto extension whose queries are Postgres's own, and it would have
  gone into a project with no repo to run through, or a repo talking to
  MySQL. Two rules, kept apart because they are different in kind. Ecto is
  a cartridge, so it is `requires: ["ecto"]` — the machinery was already
  there, and the console now greys the box with *Insert ecto first* before
  anyone presses. The driver is not a cartridge — it is the value of
  ecto's own `--database` — so it is a refusal in the installer, and the
  question is put to the project (`PhxDelta.facts/1`, the same source
  `installed?/1` reads) rather than to the options this cartridge was
  inserted with: what a project's driver *is* now beats what it was told
  once, and for most cartridges the options are not on record at all —
  they survive only in the insert commit's subject, and only for what the
  workbench itself put in.

- **`eject` refuses while something still stands on the cartridge.** The
  insert side has kept this rule from the start — a cartridge whose
  `requires` are missing refuses, naming what to put in first — and the
  eject side had no mirror of it: it reverted the commit and left
  whoever built on that cartridge standing on nothing. `mix
  workbench.dependents NAME` answers the question, and `wb.sh eject`
  asks it: the installed cartridges that declare NAME in their
  `requires`, everything that builds on *those* in turn, in the order
  they have to come out. Both halves come from the project — `requires`
  off each manifest, installed off each cartridge's own `installed?/1`
  — so one inserted by hand or generated at birth counts exactly like
  one the workbench committed. The refusal names the chain to run
  (`./wb.sh eject openai && ./wb.sh eject stripe && ./wb.sh eject
  auth0`). It is asked after the insert commit is found, so an eject
  with nothing to revert costs no container, and a project that cannot
  be asked at all leaves the question unjudged rather than refusing —
  a check that cannot run is not a verdict.

- The console's **Eject** carries the same guard, and a collection grows
  an **Eject N** of its own. A collection leaves no commit under its own
  name, so its button walks its members' commits *newest first* — the
  only order git can revert them in, since a member inserted later may
  have written over an earlier one — running one `wb.sh eject` per
  cartridge, chained, so the run stops at the first cartridge whose
  files changed since. Members with no insert commit are named and left
  in place. Ejecting a single cartridge in the console refuses on the
  same dependents rule, one level deep: the shelf is in front of the
  reader and the next refusal is one click away, while the command line
  gets the whole chain because there it is the difference between one
  answer and five attempts.

- **`PHX_NEW_VERSION` is back in `config.conf`, as a choice and never as
  a record.** Empty — the ordinary case — and `new` resolves it; set, it
  is the standing installer for the projects to come; `--phx-new` still
  overrides it for one run. Nothing writes back to the file: what a
  creation resolved is stamped into the workspace's own
  `Dockerfile.local` (`ARG PHX_NEW`), which stays the source of truth
  for *which generator made this project* — the one the base cartridges
  take their delta with. The setting is captured into `PHX_NEW_SETTING`
  at startup and `PHX_NEW_VERSION` is cleared, so the two never stand in
  for each other: `new` reads the setting, every other command reads the
  stamp, and a workspace's toolchain tag is unaffected by a file that
  has since moved on to name the next project.

- **A named installer hex does not have is refused before anything is
  built.** `--phx-new 1.8.31` or a typo in `PHX_NEW_VERSION` used to have
  no requirement to weigh — `phx_new_elixir_requirement` comes back empty
  for a release that does not exist, and the pairing check stands aside
  on an empty requirement — so the mistake travelled three layers into
  the image build to be reported by `mix archive.install`, about a file
  nobody wrote. `new` now asks hex whether the release is there (a HEAD,
  so nothing comes back but the code) and refuses on a 404, naming both
  ways out. Only a 404 refuses: an unreachable hex judges nothing, as
  everywhere else here. A resolved version never needs this — it came
  out of hex's own list.

- **An unset installer now resolves to the newest `phx_new` the stack
  can run**, not to hex's newest full stop. `new` walks hex's releases
  newest first and takes the first whose declared Elixir this stack
  satisfies — normally the very newest, for the one call the pairing
  check would have made anyway, so the ordinary path costs nothing new.
  It walks only when the stack is behind, which was the case with no
  good answer before: the newest was resolved, then refused. This is a
  deliberate parting from `mix archive.install hex phx_new`, which takes
  the newest and fails loading it. The walk is release by release rather
  than one probe per minor line because the requirement moves *inside* a
  line — `phx_new` 1.8.0 to 1.8.5 ask for Elixir `~> 1.15` and 1.8.13
  asks for `~> 1.17` — so an Elixir 1.15 stack gets 1.8.8 rather than
  being dropped to the 1.7 line. When the answer is not hex's newest,
  `new` says which it took, for which Elixir, and what the newest would
  have needed; a named version is still taken as named and weighed
  against the stack. Twenty-five releases back it gives up and names the
  two remedies.

### Updated

- **Nothing compiles through the bind mount any more.** The toolchain
  image points Mix at `/app/build` and `/app/deps`, two named volumes
  the workspace's compose declares and every one-off run shares —
  compiling through a bind mount is the load Docker Desktop's file
  sharing bears worst, and its VM fell under it. `bake` bakes
  `Dockerfile.local` again when the seed moved, keeping the project's
  own Phoenix installer, and rebuilds the image, so an existing
  workspace moves over with `bake && up`. On Linux the native Docker
  Engine is the one to use; `./wb.sh engine native` picks it.

- One stylesheet for the mock and the console
  (`console/priv/static/assets/css/console.css`), inlined into the
  one and served by the other, and the house's tokens projected into
  both by `assets/design/build.py`.

### Fixed

- Two readers of the igniter at once fought over one container name
  and the second answered nothing; the name carries the pid now.

- **An insert that fails no longer leaves the workspace half-written.**
  `add` runs each cartridge in its own container and commits it when it
  lands; an installer that wrote its files and *then* failed — Hex
  refusing to solve a version, most plainly — left those files behind
  uncommitted, and that alone stopped everything after it, since `add`
  and `eject` both need a clean tree. The workbench was stuck until
  somebody cleaned up by hand. It now undoes exactly that insert's work
  and says where the workspace stands. It asks nothing because nothing
  of the reader's is at stake: `add` begins on a clean tree
  (`require_clean_workspace`, which counts untracked files too) and
  commits each insert as it lands, so whatever is uncommitted at that
  point was written moments earlier by the insert that just failed.
  Ignored paths are left alone — `deps/` and `_build/` are the
  container's work, not the cartridge's. The insert failing and the
  commit failing are now told apart, and end differently: a failed
  insert wrote half of something nobody asked for and goes; a failed
  commit leaves a cartridge that did land, for the reader to commit by
  hand.

## v0.9.0 - (2026-08-31)

### Added

- The console colours the code a cartridge writes, and the box grows an
  **Installation** screen that shows it. `Console.Highlight` in
  `console/` keeps the registry, as data: a treatment per filename and
  then per extension — a Makeup lexer, a drawing, plain text, or left
  out. Adding a language is a line there and its `makeup_*` dependency,
  since every Makeup lexer emits the same token classes and the palette
  (`console/elixir_color_theme.jsonc`, One Dark, on the dark ground the
  Logs screen uses) is written once. What the registry does not name is
  shown plain and never guessed at: the Elixir lexer on an `.eex`
  template does not leave it grey, it colours `in` and `with` as
  keywords inside a CSS comment. `mix console.highlight` answers the
  same for the mock's generator, so there is one opinion and not two.

- The box's **Installation** screen: what the cartridge did to this
  project, off its own insert commit. Nothing new had to be recorded —
  `add` refuses a dirty tree, so one commit is one cartridge's whole
  diff, and its sha already travelled in `status --json` and was already
  named in the eject button's tooltip. It makes eject legible: the diff
  of what pressing it undoes. A patch cannot be handed to a lexer, so
  both faces of each file are coloured whole and the hunks are put back
  together out of them — context and additions off the new face,
  removals off the old — and only the lines a patch renders are kept.
  *Summary* first, one row per cartridge with its commit, its subject
  and its counts, and the collection's own row last with its commit
  cells empty, because it leaves none. Its figures are read off the
  range its picks span, never off the column added up: a file several
  picks touch is one file, and a line one pick wrote and a later one
  took out was never there at the start nor at the end. The range is
  only taken when their commits are contiguous — a second pass, a member
  born with `phx.new`, one ejected in between — and otherwise the screen
  says so. *Files* under it, each naming the picks that touched it.
  `mix.lock` is in: its lines run past a thousand characters, but the
  package and the version are at the front of each one, and the lock is
  the only place a cartridge shows what it drags in.

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

- The console read once more with the eyes, and the repetitions taken
  out: the Jobs tab said what a job is three times over — the tray
  below, its own meta line, and the empty screen — so the tray steps
  aside while the tab is open and the empty screen says it alone, and
  the meta line that teaches unfolding turns into the way back once a
  job is open (they arrive unfolded, and a few commands are a wall);
  what Tab could not finish comes as a list to read — the candidates
  separated by bullets, standing three times as long as a notice, and a
  toast now cancels the one before it instead of cutting it short; the
  Terminal no longer prints a prompt under "No session. Open one"; the
  Project's documents read README, CHANGELOG, then the masked `.env`,
  not the secrets first; and a tick chip gives its right padding back
  when punctuation follows, which used to read as a space
  (`` `unavailable` ; ``). The board lost the *Probes* section — a poll
  of what one cartridge answers, told again by that cartridge's box —
  and reads its cartridges as a list, a line each, the same rows as the
  sections above it, where a grid of slot cards cost four times the
  height — each name wearing the house's reference (`.cart-ref`, the
  same mention a cartridge gets anywhere), not a label of its own. The
  board also reads in the order the work happens: deployments before
  containers — what you asked for before what runs because of it — and
  git last, after the cartridges whose inserts it records. And the jobs band only stands where a job could have come
  from: the screens that start one (Deploy, Cartridges, Cluster), never
  the Jobs tab itself, never with no job to show — and, running, it
  follows you anywhere. On the shelf, whether a cartridge is in is
  the box itself — the inserted keep their colour and take the accent
  ring, the rest sit grey — instead of a golden stamp that covered the
  cover's own band and part of its art; the caption carries the word,
  with the dot the cartridge chips use.

- Two placeholder boxes where there was one socket, a front and a back
  each. The **socket** (`cover_placeholder`, `back_placeholder`) stands
  in for a cartridge nobody has sealed a box for yet: the bare board,
  and its reverse side, which carries no lettering at all — a stand-in
  asserts nothing, and the workbench's name on a plate is typeset in
  the strip, never drawn into the art. The **empty**
  (`empty_cover_placeholder`, `empty_back_placeholder`) is for a
  cartridge that is not done — the drawing it would have been built
  from, stamped DRAFT and pending review, with the ink showing through
  the sheet when you turn it over. There is no cartridge to stand in
  for, and the drawing says so better than a caption could. The mock
  reads all four, on the shelf and in the hand. Two things the light
  drawing asked for: the caption's scrim turns light and its ink dark
  over it (the dark one written for the socket greyed the sheet and
  buried its stamp block), and a not-done box is no longer dimmed to
  nothing on the plank — the drawing already says what the dimming was
  saying.

- Console mock: the Config form's image row is named `DOCKER_IMAGE` and
  carries the link to the tags it is picked from, like every other
  version field. It is still the one row that is not a key of
  `config.conf` — the three versions under it are — but it is what the
  reader actually chooses, so it wears the same name shape.

- Console mock: the band's right end reads caveat, clock, `wb.sh` — the
  only button up there moved to the corner, where a control is looked
  for, answering the workbench's name at the other end of the band.

- Console mock: the deployment's buttons ask what `wb.sh` asks. All of
  them are refused without a project ("There is no project to build"),
  so all of them are off in an empty workspace, and the row says why —
  Up was offering a command that would have refused. And Build no
  longer waits for the target to be baked: `build --deploy prod|scaled`
  bakes its own compose before building, so a target nobody has baked
  yet is exactly when you would press it.

- Console mock: the box's kicker reads state first — `on the shelf` /
  `inserted` / `not done`, the two faces of it now both said — then the
  version, then what sort of box it is (`collection`, `base`). It no
  longer announces the design paper: the tab row above says DESIGN when
  there is one. Nor how many a collection inserts: the Specs panel
  below names every member.

- Console mock: a *Specs* panel in the box — what the cartridge is, as
  against what you are about to do with it. The mix task behind it
  first — its name in the workbench's own terms; then Kind (cartridge,
  base cartridge, collection) with what a second insert does; Needs,
  the manifest's and what the chosen options add, grouped by the switch
  that asked; Inserts, a collection's recipe with each member's argv;
  Opens, Answers and Lights, the doors, probes and tabs of `console/0`,
  their paths filled by the options; and After.
  Those facts were scattered — a kicker chip, two rows inside the
  insert form, and the console contributions nowhere at all — and the
  ones inside the form read as conditions of the insert rather than
  facts of the box. Empty rows never print, so most boxes show two or
  three. The panel is live: the rows an option moves say which switch
  moved them, rather than a fixed list contradicted below it. What is
  this project's business stays out of it — a value whose requirement
  is missing is disabled and says so, and Insert reads "Insert html
  first".

- The installer and the stack are weighed against each other before
  anything is built. Every `phx_new` release declares on hex the Elixir
  it runs on (`~> 1.17` for 1.8.13, `~> 1.14` for the whole 1.7 line),
  and `new` reads that requirement for the version it just resolved and
  refuses a stack below it, naming both remedies — a newer stack
  (`./wb.sh stacks`) or an older installer (`--phx-new`). Nothing was
  unchecked before: `mix archive.install` stops on the same pair
  ("You're trying to run :phx_new on Elixir v1.16.3 but it has declared
  … it supports only Elixir ~> 1.17"), only three layers into the image
  build, about a file nobody wrote, at the one moment the two versions
  it is talking about can no longer be chosen. Same verdict, said where
  the choice is. It stays a check and never becomes a derivation: the
  requirement is a floor and has no ceiling, so a Phoenix version
  answers *which Elixir is too old*, never *which Elixir*. Only hex's
  `~> MAJOR.MINOR` shape is read; any other form, an unreachable hex or
  a stack this cannot take apart is left to mix, since refusing a good
  stack on a guess is worse than the late error. Erlang never enters
  into it — Phoenix says nothing about OTP, and the Elixir/OTP pairing
  is already settled by the `hexpm/elixir` tag existing on Docker Hub.

- `status --json` carries `phx.generator`: which `phx.new` made the
  project, where that is recorded (`Dockerfile.local` for a workspace
  the workbench made, `mix.exs` for a project generated elsewhere), and
  which installer is at hand. The plain report says it in a line, and
  says what to do when the two differ. The base cartridges refuse on
  that difference, and until now nothing showed it until one of them
  did: a console can put it on the screen before anyone presses Insert.

- `PhxDelta.generator_check/1` reads that stamp instead of inferring the
  generator from `{:phoenix, "~> x.y.z"}`. The requirement was only ever
  a proxy — `phx.new` happens to write its own version there — and it
  said the wrong thing twice: bumping Phoenix, an ordinary thing, made
  every base cartridge refuse on a project it had not touched; and any
  other form of the requirement (`"~> 1.8"`, a pinned version, a moved
  dep) turned the check off silently. The stamp is written, is the
  project's, and survives both. `mix.exs` stays as the fallback for a
  project generated outside the workbench, and the refusal now names the
  remedy that works here — `./wb.sh build`, which rebuilds the toolchain
  from the workspace's own Dockerfile — instead of an `archive.install`
  thrown away with the container.

- One name for the state of a box that does not work yet: **not done**.
  It was `pending` on the chip, "Not ported yet" on the button, "Not
  written yet" on the shelf's plank and "not ported yet" in the box's
  summary — and the last two contradicted each other. Both of those
  words claimed something about where the work comes from, and neither
  is true: a box like stripe is designed from an implementation in
  another project, so it is no port and no blank page. "Not done" says
  only what the reader can act on; where the work comes from belongs in
  the box's own paper, which has room for it. The manifest keeps
  `pending?/0` — the wire name stays, the copy changes. Every surface
  says it now: the mock's chip, button, plank and caption, the
  LiveView console (which printed the state twice, once from `facts/1`
  and once from its own chip — the duplicate is gone), `workbench
  .expand`'s refusal, and the docs of `pending?/0` wherever they
  explained it, stripe's three papers included — whose NEED.md also
  stopped describing a world that ended with `workbench.setup`: what
  there is of the box is a manifest and its papers, and what happens if
  you ask for it is that `./wb.sh add stripe` refuses, naming it.

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

- **No Phoenix installer setting.** `PHX_NEW_VERSION` is gone from
  `config.conf`: `new` asks hex.pm for the newest `phx_new` — or takes
  `./wb.sh new --phx-new VERSION`, for when there is a reason to pin —
  and stamps whatever it resolved into the workspace's own
  `Dockerfile.local` (`ARG PHX_NEW`), which every other command reads
  back to name the toolchain image. Nobody chooses a version, and the
  choice is still written: it is the generator the base cartridges take
  their delta with, so it can be neither a moving target (the same repo
  built twice would give two toolchains) nor one global default for
  workspaces created months apart. A workspace made before the stamp
  names no installer and keeps the bare `workbench:<elixir>-<otp>` tag
  it was built with.

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

- `add COLLECTION` inserts every cartridge of the plan, not only the
  first. The plan reached the loop on stdin, and the container each
  insert runs in attaches to stdin and drank the rest of it: the loop
  then ended on EOF — quietly, and with a zero exit — one cartridge
  into a recipe of thirteen. `add chiefs_setup` had never put in more
  than its first missing member. The plan is read on its own descriptor
  now, so there is nothing on stdin for the container to take.

- The console mock keeps its JavaScript when a cartridge's diff or
  document carries a literal `</script>`, as exdoc's `mix.exs` and
  coveralls' `.html.eex` templates do. The HTML parser ends the block
  wherever it sees those characters, whatever the JavaScript around
  them says, so the page loaded with every function undefined and
  eleven syntax errors. Every JSON payload the page carries escapes the
  slash now — the documents as much as the diffs, since a README that
  writes the tag would have done the same without warning.

- `status --json` is valid JSON when a cartridge's NEED.md travels in
  it. The object was assembled around the task's answer with `echo`,
  which is free to read the `\n` a JSON string is made of, and a raw
  newline inside a string is what makes a reader call the whole answer
  invalid — a `--json` that exits zero and cannot be parsed. Every
  value goes in as a `printf` argument now, never as part of the
  format, and `json_string` escapes the control characters too and not
  only the backslash and the quote.

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
