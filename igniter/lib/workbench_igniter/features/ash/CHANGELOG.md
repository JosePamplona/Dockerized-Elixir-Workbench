# Changelog — ash

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a change in the command it queues or in
the options that build it is a minor, a change that breaks a project
already carrying what that command installed is a major.

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
