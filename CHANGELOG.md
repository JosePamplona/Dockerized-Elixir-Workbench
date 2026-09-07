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
  app's does.
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

### Fixed

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
