# Changelog — ash

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a change in the command it queues or in
the options that build it is a minor, a change that breaks a project
already carrying what that command installed is a major.

## v0.7.1 - (2026-09-25)

### Fixed

- `--api typescript` patches the production `Dockerfile` for the `npm
  install` ash_typescript's installer hooks into `assets.setup`:
  `nodejs npm` in the builder's `apt-get install`, and `COPY
  assets/package*.json assets/` before `RUN mix assets.setup`. The
  release build stopped at that step with `:enoent` (`_004`,
  2026-09-25): Phoenix's builder installs no node, and copies `assets/`
  after `assets.setup`, a step that in a phx.new project only downloads
  the bundler binaries. Only Phoenix's own Dockerfile with the assets
  steps in it is touched, once; another is left alone with a notice
  that says what it owes. The README said both of the project's images
  carried node: only the dev one did.

## v0.7.0 - (2026-09-25)

### Changed

- `--data-layer postgres` builds on ecto with `postgres`, and `sqlite`
  on ecto with `sqlite3`. The form shows the value that does not match
  the project unlit, with the reason, and the installer refuses it
  before anything is fetched. The two installers turn the same
  `<App>.Repo` into their own: asked together, `ash_sqlite.install`
  stopped on the repo `ash_postgres.install` had just turned, and
  `postgres` on a SQLite project left an `AshPostgres.Repo` with no
  Postgres configured. A project has one Ecto database, so the two
  never go in together now. On a project without Ecto, `./wb.sh add
  ecto` comes first. `csv` asks for nothing.
- `--automation ash_events` builds on ecto with `postgres` and brings
  the `postgres` data layer, placed with the data layers, before
  authentication. Its `ash_postgres` dependency is not optional, and
  once loaded it made `ash_authentication.install` create a Postgres
  `<App>.Repo` over a SQLite one: *repo.ex: File already exists*. The
  site says nothing of it; the value's line does now.
- The line after the insert says what does happen: the app container's
  `mix setup`, which Ash turns into `ash.setup`, creates the database
  at the next `./wb.sh up`. It named a `./wb.sh setup` that does not
  exist.

## v0.6.1 - (2026-09-24)

### Fixed

- The queued command fails when an installer reports issues. It is
  `mix workbench.igniter_install` now, with the same argv as `mix
  igniter.install`. Igniter alone printed the issues, wrote none of the
  installers' files, left the packages in `mix.exs` and exited with
  zero, so the insert was committed with the packages alone.
- `--api typescript` is refused, with both paths in the message, on a
  project whose app has a digit after an underscore (`:lorem_ipsum_2`).
  ash_typescript's installer looks for the web layer under the
  underscored web module (`lib/lorem_ipsum2_web/`), not where phx.new
  put it (`lib/lorem_ipsum_2_web/`), and stops at `root.html.heex`.
- `--components mishka_chelekom` finishes when run from the console.
  Its installer draws an Owl spinner whenever ANSI is on, and the
  console turns ANSI on over a pipe. With no terminal, Owl's LiveScreen
  never starts, and the spinner's stop died of a 5 s timeout waiting
  for a render. The queued task now stands a LiveScreen up on a device
  that reports 80×24 and prints nothing, so the spinner draws nowhere
  and the rest of the output keeps its colours.

## v0.6.0 - (2026-09-24)

### Changed

- `--data-layer` has no default and no `none`: left out, Ash goes in
  with no data layer, and a data layer is one the reader named. It
  took `postgres` when not given, which made `none` the only way to
  leave it out. A bare `mix workbench.install.ash` queues `ash
  ash_phoenix`; `--data-layer none` is now an unknown value.
- `state` reports no `data_layer` for Ash in without one, where it
  said `["none"]`.
- `--auth` is a closed list: the catalog no longer marks it open, so a
  form offers its strategies and no field for another one that
  `add_strategy` would refuse.
- `--auth oauth2` is back, as the site's OAuth2 option does it: both
  packages and no strategy, since `add_strategy` has none for it
  (v0.5.1 had dropped it for that). Its line in the catalog says the
  provider is configured by hand and links the OAuth2 strategy's DSL;
  `mix workbench.ash.site` matches the site's option to it again.
- The form's help, one line per value: `--data-layer` carries a note,
  "Left out, Ash goes in with no data layer", and an advanced package
  the site's command brings a companion with says so in its own line
  (`ash_double_entry` brings `ash_money` too), which only the option's
  command-line line said.

## v0.5.1 - (2026-09-24)

### Fixed

- `--auth` offers what the released `ash_authentication.add_strategy`
  accepts: `password`, `magic_link`, `api_key`. Its list had been read
  from `main`, and every other strategy (`auth0`, `github`, `oauth2`,
  `otp`…) stopped the insert with "Invalid strategy provided".
- `mix workbench.ash.site` reports the site's OAuth2 option, which
  installs `ash_authentication` with no strategy, as waiting (`..`)
  instead of matching it to an `oauth2` strategy.

## v0.5.0 - (2026-09-24)

### Added

- Six doors beside `admin`, each behind the option that brings its
  package: `oban` (`/oban`, with `ash_oban`), `sign in` (`/sign-in`,
  with a strategy that has pages), `swagger` and `openapi`
  (`/api/json/swaggerui`, `/api/json/open_api`, with `json_api`),
  `graphiql` (`/gql/playground`, with `graphql`) and `typescript`
  (`/ash-typescript`, with `typescript`). Checked against a project
  carrying every package: all seven answer 200.
- `origins/2`: where each package in its insert commit came from. The
  ones the queued command named carry that the options named them in
  the `mix igniter.install` it runs. The ones that command did not name carry that they came in
  at the request of the installer of a package it named. The console's
  Packages table says each under its own number.
- `mix workbench.ash.site` reads the site's sections too (the home
  page's `data-category`) and checks both ways: a package a section
  added, stopped listing or moved, a section opened or closed, and each
  strategy the site offers against `--auth`. What the site marks
  "Installer coming soon" is reported as waiting (`..`) and no longer
  fails the run. A weekly job runs it
  (`.github/workflows/ash-site.yml`); the README says what it is for,
  how to run it and how to read it.
- README: *What each installer writes*, installer by installer.
  DESIGN §2.6: the whole command read in the installed sources, and
  where each package of the insert commit came from; §3.8: why the
  notes are the cartridge's.

### Changed

- `--with` is six options, one per section of the site's *Advanced
  Options*: `--ai`, `--finance`, `--automation`, `--security`,
  `--dev-tools`, `--components`, each closed on the packages the site
  offers there and queued in the site's order. A package a section
  does not offer is refused, naming the ones it does. The open field is
  gone: `mix workbench.ash.site` found the cartridge lacking only
  `appsignal` and `opentelemetry`, whose installers the site marks
  "coming soon", so the field only took packages the site does not
  offer, which is `mix igniter.install`'s job. `state` reports the
  packages by section, and the `admin` and `oban` doors read
  `dev_tools` and `automation`. An insert made with `--with` keeps its
  line; its packages read as brought by the installers in the Packages
  notes, since the option is not parsed any more.
- `state` reports `auth` as the strategies the user resource declares
  (`password`, `remember_me`, `magic_link`, …), read off its
  `strategies do` block, where it said `true` whenever
  `ash_authentication` was in. API keys alone have no sign-in page, and
  the door has to tell.

## v0.4.0 - (2026-08-30)

### Changed

- `--data-layer` takes several (`postgres,csv`), as the site's
  checkboxes do — each data layer is its own box there and a resource
  picks its own — in the site's order; `none` stands alone. `state`
  reports the list. `mix workbench.ash.site` also reads off the site's
  command builder whether the layers are still independent, and says
  so — the map carries no cardinality.

## v0.3.0 - (2026-08-30)

### Added

- What each value builds on, in workbench cartridges, beside it in the
  catalog (`{value, doc, requires}`): every `--auth` strategy but
  `api_key` on live; `password`, `magic_link` and `otp` on mailer too;
  `ash_admin`, `live_debugger`, `cinder`, `mishka_chelekom` and
  `ash_oban` on live. The installer refuses with an issue naming what to
  insert first while it is not in the project — the site assumes a
  default `phx.new` project and never says.

## v0.2.0 - (2026-08-29)

### Updated

- The command is the site's, exactly, read off the feature map that
  drives its installer widget ([DESIGN.md](DESIGN.md) [17]): `--with
  ash_oban` also puts in `oban_web`, `ash_cloak` comes after `cloak`,
  `ash_double_entry` brings `ash_money` first (the site's option
  requires Money), `--api typescript` hands `ash_typescript` the
  site's `--framework react`, and `--auth api_key` alone adds
  `ash_authentication` without its Phoenix half. A project that took
  `ash_oban` or `ash_cloak` before this gets the companion on its next
  `--with` of the same package (only the missing one is queued).
- `mix workbench.ash.site` (`site.ex`): fetches that map as it is today
  and reports what the cartridge would do differently — packages,
  arguments, tooltips, options the site has and the cartridge does not.
- The catalog's choices say what each stands for, in ash-hq.org's own
  words: the package and the first line of the tooltip the site's
  installer widget shows on hover (`postgres` → `ash_postgres · The
  swiss army knife of databases…`, `ash_archival` → `A lightweight
  extension to ensure that data is only ever soft deleted.`), the four
  authentication options the site offers included. The text is not in
  the page's HTML but in its app bundle (`assets/app-*.js`), read on
  2026-08-29 [DESIGN.md, ref. 17]. Nothing in what the cartridge
  installs changes.

## v0.1.0 - (2026-08-28)

### Added

- `mix workbench.install.ash` (`wb.sh add ash`): the choices of
  ash-hq.org's *Get Your Installer* for an existing app, as options —
  `--data-layer postgres|sqlite|csv|none` (default `postgres`),
  `--api json_api,graphql,typescript`, `--auth <strategies>` (`ash_authentication` and
  `ash_authentication_phoenix`, handed `--auth-strategy`), `--with <packages>`
  for the site's *Advanced Options*, `--example` for Ash's example
  resources — turned into the command the site generates and queued
  to run once the patch set is applied:
  `mix igniter.install ash <data layer> ash_phoenix ... <flags>`.
- Packages already in `mix.exs` are left out of the command; when none
  is left nothing is queued and a notice says so.
- With `--auth`, `TOKEN_SIGNING_SECRET` in `.env` (generated) and
  `.env.sample` (blank): the variable `ash_authentication`'s installer
  makes `config/runtime.exs` require in `:prod`.
- Unknown `--data-layer` and `--api` values are issues; `--auth` and
  `--with` are validated by Ash's installers.
