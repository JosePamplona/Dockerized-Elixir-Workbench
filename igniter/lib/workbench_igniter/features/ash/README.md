# ash

The [Ash framework](https://ash-hq.org), installed into the project
**the way ash-hq.org's installer does it for an existing app**.

Install it on demand with

```sh
./wb.sh add ash [OPTIONS]
mix workbench.install.ash --data-layer postgres --api json_api --auth password,magic_link
```

It wants a vanilla project: a stock `phx.new` project plus Ash.
enhancements brings its own Ecto schemas and generators, and auth0 its
`users` table, that Ash would fight with: see [DESIGN.md](DESIGN.md),
§3.5.

## What it installs

Nothing by hand. The *Get Your Installer* section of ash-hq.org is a
generator of one command, `mix igniter.install <packages> <flags>`, and
every Ash package carries its own Igniter installer. This cartridge
turns its options into that command and **queues it** to run once the
patch set is applied:

```text
mix igniter.install ash ash_postgres ash_phoenix ash_json_api ash_authentication ash_authentication_phoenix --auth-strategy password,magic_link --yes
```

Igniter then adds the packages to `mix.exs`, fetches and compiles them
and runs `ash.install`, `ash_postgres.install`, `ash_phoenix.install`,
`ash_json_api.install`, `ash_authentication.install` (which adds the
strategies) and `ash_authentication_phoenix.install`. What
Ash writes — the `MyApp.Accounts` domain with `User` and `Token`, the
repo turned into an `AshPostgres.Repo`, `config/config.exs`
(`ash_domains`, formatter imports, section order), the `ash.setup`
aliases, the migrations of `mix ash.codegen` — shows up in that
command's output, not in this cartridge's diff.

![What the queued command wires into the project: the cartridge queues one mix igniter.install command and writes TOKEN_SIGNING_SECRET into .env; the command's installers write the Accounts domain, the AshPostgres repo with its migrations, the API routes and the authentication strategies, and the authentication reads the secret at boot in production](../../../../../assets/diagrams/ash/queued-command.svg)

`ash_postgres.install` leaves the repo's block in `config/dev.exs`,
`test.exs` and `runtime.exs` alone when the repo is already configured
there, which a `phx.new` project always is: the workbench's
`DATABASE_URL` wiring survives untouched. What the config does get is
Ash's own: `ash_domains`, `show_policy_breakdowns?` in dev, and — with
`--auth` — a literal `token_signing_secret` in `dev.exs` and a
`TOKEN_SIGNING_SECRET` read in `runtime.exs` that raises in `:prod`
when missing.

That variable is the one thing the cartridge writes by hand. With
`--auth` it appends to `.env` (a generated 64-character secret) and
`.env.sample` (blank), before the queued command runs, so
`./wb.sh up -e prod` never meets the raise:

```sh
# Signs AshAuthentication's tokens (:prod; dev has its own in config/dev.exs). Generate with: mix phx.gen.secret
TOKEN_SIGNING_SECRET="…"
```

## Options

The site's sections, as flags. `ash` and `ash_phoenix` are always in —
the workbench only makes Phoenix projects.

| ash-hq.org | Option | Packages |
| --- | --- | --- |
| Data layer: Postgres / SQLite / CSV | `--data-layer postgres,sqlite,csv` (several, as the site's checkboxes; default `postgres`; `none` alone for no data layer) | `ash_postgres`, `ash_sqlite`, `ash_csv` |
| Web: JSON:API, GraphQL, TypeScript | `--api json_api,graphql,typescript` | `ash_json_api`, `ash_graphql`, `ash_typescript` (handed `--framework react`, as the site does; its installer hooks `npm install` into `assets.setup`, which the workbench's and the project's images carry node and npm for) |
| Authentication: Password, Magic Link, API Keys | `--auth password,magic_link,api_key` | `ash_authentication`, `ash_authentication_phoenix`, with `--auth-strategy <list>`; API keys alone bring `ash_authentication` only, as on the site |
| Advanced Options, by section | `--ai`, `--finance`, `--automation`, `--security`, `--dev-tools`, `--components` | the packages the site offers in that section (below) |
| — | `--example` | `ash.install --example`: the guide's example resources |

`--auth` takes whatever the released `ash_authentication.add_strategy`
does: `password`, `magic_link`, `api_key`. The site's OAuth2 option
installs the package with no strategy, and `add_strategy` has none for
it yet, so `--auth` does not offer it. The site's *Advanced
Options*, one option per section, each closed on the packages the site
offers there (anything else is refused, naming them), and queued in the
site's order:

| Section | Option | Packages |
| --- | --- | --- |
| AI | `--ai` | `tidewave`, `ash_ai`, `usage_rules` |
| Finance | `--finance` | `ash_money`, `ash_double_entry` (brings `ash_money` first, as the site requires) |
| Automation | `--automation` | `ash_oban` (with `oban_web`, as the site adds it), `ash_state_machine`, `ash_events` |
| Safety & Security | `--security` | `ash_archival`, `ash_paper_trail`, `ash_cloak` (with `cloak` before it, as the site adds it) |
| Dev Tools | `--dev-tools` | `live_debugger`, `ash_admin` |
| UI Components | `--components` | `mishka_chelekom`, `cinder` |

What the site offers besides — `appsignal`, `opentelemetry` — has no
installer yet ("coming soon", the site says); `mix workbench.ash.site`
reports it. Any other package with an installer is
`mix igniter.install <package>`'s, not this cartridge's.

Some of them need manual setup after the installer (the site says so
too): OAuth providers want their client ids in `.env`, `ash_oban`
wants a queue, `tidewave` and `live_debugger` are dev-only and their
installers set `only: :dev` themselves.

## What each installer writes

The queued command runs every package's installer on one igniter, in
the command's order, and writes once; then `mix ash.codegen` writes the
migrations, which `mix ash.setup` applies. What the project gets, read
in the installers' sources (the versions and lines are in
[DESIGN.md](DESIGN.md) §2.6):

| Installer | What the project gets |
| --- | --- |
| `ash` | `consolidate_protocols: Mix.env() != :dev`, the formatter's section order, Ash's config defaults; `spark.install` adds `sourceror` and the Spark formatter plugin. With `--example`, the `Support` domain with `Ticket` and `Representative` — without a data layer: they live in no table |
| `ash_postgres` | `Repo` turned into an `AshPostgres.Repo` in place (`installed_extensions`, `min_pg_version`, `prefer_transaction?`), the `setup` and `test` aliases on `ash.setup`; dev, test and runtime config left alone |
| `ash_phoenix` | `AshPhoenix.Plug.CheckCodegenStatus` after the code reloader; the Ecto and *Form handling* sections taken out of `AGENTS.md` |
| `ash_authentication` | the `Accounts` domain with `User`, `Token` and `Secrets`, the token signing secret in config, `citext` in the repo, its supervisor; per strategy: `password` (with `bcrypt_elixir`, confirmation and reset senders on the project's Mailer), `magic_link`, `api_key` (an `ApiKey` resource and a plug in `:api`) |
| `ash_authentication_phoenix` | `AuthController`, `LiveUserAuth`, the DaisyUI overrides, the auth routes in the router, `@source` in `app.css` |
| `ash_json_api` | its own router, at `/api/json`, with Swagger UI and the OpenAPI spec; `open_api_spex` |
| `ash_graphql` | a schema and a socket at `/gql`, GraphiQL at `/gql/playground`; `absinthe_phoenix` |
| `ash_typescript` | with `--framework react`: `package.json`, tsconfig, the SPA layout, `/ash-typescript`, the `/rpc` routes (empty, see below) |
| `ash_ai` | the dev MCP at `/ash_ai/mcp`; `req_llm` |
| `ash_admin` | `/admin` in the dev routes |
| `ash_oban`, `oban_web` | `oban` and its installer (the `add_oban` migration, config, the supervision child), the cron plugin, `/oban` in the dev routes |
| `ash_money`, `ash_double_entry` | the money type; `ex_money_sql` and its repo extension; the `Ledger` domain with `Account`, `Balance`, `Transfer` |
| `tidewave`, `live_debugger`, `cinder` | Tidewave's plug in dev; the debugger's tags in `root.html.heex`; Cinder's CSS in `app.css` |
| `usage_rules`, `req_llm`, `llm_db` | a notice, nothing written |
| `ash_archival`, `ash_paper_trail`, `ash_cloak`, `cloak`, `ash_events`, `ash_state_machine` | the package (and a formatter import, for the last two): no installer, or one that configures nothing more |

Packages the command did not name come in at the request of these
installers (`picosat_elixir` through Ash's policy authorizer, when a
resource first takes it): the console's Packages table says which is
which, one note each.

## Keeping up with the site

**What it is for.** Every option of this cartridge copies a choice of
ash-hq.org's *Get Your Installer*: the packages each one puts in the
command, the arguments it passes, the one-line description the catalog
shows, and the section it sits in — which names `--ai`, `--finance` and
the rest. The site changes on its own schedule and nobody tells the
cartridge. `mix workbench.ash.site` reads the site as it is today and
says, line by line, where the cartridge stopped copying it.

**How to use it.** From `igniter/`, with the network:

```sh
mix workbench.ash.site
```

It writes nothing. Run it before releasing a new version of the
cartridge, and whenever the site announces a package. CI also runs it
every Monday and on demand (`.github/workflows/ash-site.yml`, *Run
workflow*), apart from the build: a red run is a to-do list, not a
broken commit.

**What it reads.** Two things the site serves: the home page, whose
widget groups the features in sections (`<div data-category="AI">`,
one `<label id="feature-…">` each), and the app bundle it links
(`/assets/app-*.js`), whose feature map gives each feature its
packages, arguments and tooltip ([DESIGN.md](DESIGN.md) [17]).

**What it checks**, each line marked:

| Mark | Meaning |
| --- | --- |
| `ok` | A feature the cartridge puts in the command with the same packages, arguments and tooltip as the site. A section whose packages are exactly the ones its option offers (*Web* for `--api`, *Data Layers* for `--data-layer`, each *Advanced Options* section for its option). A strategy of the site's *Authentication* that `--auth` knows. |
| `..` | What the site offers with its installer "coming soon" (`appsignal`, `opentelemetry` today): nothing to follow yet. The day the installer lands the tooltip changes, and the line turns into a `!!`. |
| `!!` | A difference to act on: a feature whose packages, arguments or tooltip changed; one the site offers and the cartridge does not; a package a section added, stopped listing, or moved to another section; a section opened or closed; a strategy `--auth` does not list. |

It exits 1 when there is a `!!`, 0 otherwise. A session today ends:

```text
  ok  section «Dev Tools» (--dev-tools): as the site
  ..  appsignal: the site offers it (adds appsignal, ash_appsignal), the cartridge does not — its installer: coming soon, the site says
38 as the site, 2 waiting for an installer, 0 to look at.
```

**What to do with a `!!`.** Update the table it names in `ash.ex` —
`@data_layers`, `@apis`, `@advanced` and `@section_titles`,
`@companions`, `@tooltips` — and the reference [17] in DESIGN.md, then
run it again until it says `0 to look at`. A new section is a new
option (`info/2`, `option_docs/0`, `choices/0` pick it up from
`@advanced`).

**What it does not check.** The order the site lists features in:
the map's `order` field repeats numbers and puts Money at 999, so it
says nothing reliable, and the cartridge's order is its own
(ash_authentication before its Phoenix half, DESIGN.md §2.5). And
`--auth`'s full list: the site offers four strategies, `--auth` knows
the seventeen `ash_authentication.add_strategy` accepts — that list is
the installer's, not the site's. Presets like *LiveView* and *React*
are skipped: they are bundles of the others.

## In the console

The routes the packages' own installers write in the router, each shown
while the project carries what brings it:

| Door | Route | While the project has |
| --- | --- | --- |
| admin | `/admin` | `ash_admin` (dev routes) |
| oban | `/oban` | `ash_oban`, which brings `oban_web` (dev routes) |
| sign in | `/sign-in` | a strategy with pages: any but `api_key` |
| swagger, openapi | `/api/json/swaggerui`, `/api/json/open_api` | `json_api` |
| graphiql | `/gql/playground` | `graphql` |
| typescript | `/ash-typescript` | `typescript` |

The strategies are read off the user resource `ash_authentication.install`
writes (`<App>.Accounts.User`, its `strategies do` block), not off the
deps; a resource the installer's `--user` named otherwise reads as none.

`ash_typescript` 0.18.2 (the latest, 2026-09-24) writes its two RPC
routes with an empty path: `post "", AshTypescriptRpcController, :run`
and `:validate` (reported upstream as
[ash_typescript#95](https://github.com/ash-project/ash_typescript/issues/95),
open on 2026-09-24). Its installer reads `:run_endpoint` from the
application environment, where the config it has just written is not
loaded yet. `POST /rpc/run` then answers 404 and the generated
`assets/js/ash_rpc.ts` calls it. The `/ash-typescript` page renders all
the same: it makes no RPC call. The fix is the project's two lines —
`post "/rpc/run", …` and `post "/rpc/validate", …`, as
`config/config.exs` declares them; the cartridge installs the package
as its author wrote it and does not patch it.

## Idempotency

Packages already declared in `mix.exs` are left out of the command;
when none is left, nothing is queued and a notice says so. So a re-run
with the same options is a no-op, and a run with more (`--dev-tools
ash_admin` on a project that has Ash) queues only the new ones. The
`.env` entry is appended once (the key is its mark). The mark `status`
reads is the `ash` dependency.

## Requirements

Some choices build on cartridges the site takes for granted, because
it assumes a default `phx.new` project: every `--auth` strategy but
`api_key` installs `ash_authentication_phoenix`, whose LiveViews need
**html with LiveView** (`{"html", live: true}`); `password`
and `magic_link` generate senders that deliver with the project's
Mailer, so they need **mailer** too; and `ash_admin`, `live_debugger`,
`cinder`, `mishka_chelekom` and `ash_oban` (it brings `oban_web`) need
LiveView the same way. The cartridge says so beside each value in the
catalog (`requires`, with the state in `conditions`) and refuses,
naming what to insert first — `./wb.sh add html --live` on a project
born `--no-live` — while the project lacks it. `--data-layer
postgres` needs no Ecto cartridge — `ash_postgres` sets the repo up
itself — but a project born `--no-ecto` then has a database its compose
lacks: `./wb.sh add` says so and `./wb.sh bake` puts it in.

The queued command needs the network (Hex) — `./wb.sh add` runs it in
the toolchain container, which has it — and a Postgres the repo can
reach when `mix ash.setup` runs afterwards, which is what `./wb.sh
setup` does. Ash 3 wants Postgres ≥ 16 for the extensions
`ash_postgres.install` declares (`ash-functions`, `citext`); the
workspace's image is `postgres:latest`.

## Verified on

A stock `mix phx.new probe` (Phoenix 1.8, Elixir 1.19.5 / OTP 27,
Igniter 0.8.3) with this package as a path dep:
`mix workbench.install.ash --api json_api --auth password --yes` ran
the six installers (`ash` 3.x, `ash_postgres` 2.x, `ash_phoenix` 2.x,
`ash_json_api` 1.x, `ash_authentication` 4.x,
`ash_authentication_phoenix` 2.x) in 2 min 31 s, generated the
`Accounts` domain with `User` and `Token`, the two migrations and the
snapshots; a second run was a no-op with its notice; `mix test` there
(`ash.setup` against a local Postgres) passed 5/5. The first run had
hung on a prompt — see [DESIGN.md](DESIGN.md) §3.2 for what it taught.

## Contents

| File | Role |
| --- | --- |
| `ash.ex` | Manifest + logic (`info/2`, `install/1`, `packages/1`, `flags/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Ash` shell |
| `site.ex` | `mix workbench.ash.site`: the site's feature map and sections against the cartridge's tables |
| `CHANGELOG.md` | The cartridge's own version history |
| `DESIGN.md` | Why it queues a command instead of composing installers, with sources |

No `priv/features/ash/`: the cartridge writes no file of its own.

Cartridge test: `test/workbench_igniter/features/ash_test.exs`.
