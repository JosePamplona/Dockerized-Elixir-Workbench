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
