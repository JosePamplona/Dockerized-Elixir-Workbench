# ash

The [Ash framework](https://ash-hq.org), installed into the project
**the way ash-hq.org's installer does it for an existing app**.

Install it on demand with

```sh
./wb.sh add ash [OPTIONS]
mix workbench.install.ash --data-layer postgres --api json_api --auth password,magic_link
```

It wants a vanilla project: a stock `phx.new` project plus Ash. The
chiefs_setup picks bring their own Ecto schemas and generators
(enhancements) — and auth0 its `users` table — that Ash would fight
with: see [DESIGN.md](DESIGN.md), §3.5.

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
| Web: JSON:API, GraphQL, TypeScript | `--api json_api,graphql,typescript` | `ash_json_api`, `ash_graphql`, `ash_typescript` (handed `--framework react`, as the site does) |
| Authentication: Password, Magic Link, API Keys, OAuth2 | `--auth password,magic_link,api_key,oauth2,…` | `ash_authentication`, `ash_authentication_phoenix`, with `--auth-strategy <list>`; API keys alone bring `ash_authentication` only, as on the site |
| Advanced Options | `--with pkg,pkg` | any package with an installer |
| — | `--example` | `ash.install --example`: the guide's example resources |

`--auth` takes whatever `ash_authentication.add_strategy` does:
`password`, `magic_link`, `otp`, `api_key`, `totp`, `recovery_code`,
`github`, `google`, `apple`, `auth0`, `microsoft`, `okta`, `slack`,
`oidc`, `oauth2`, `dynamic_oidc`, `webauthn`. The site's *Advanced
Options*, by section, as the packages they stand for:

| Section | Packages |
| --- | --- |
| AI | `tidewave`, `ash_ai`, `usage_rules` |
| Finance | `ash_money`, `ash_double_entry` (brings `ash_money` first, as the site requires) |
| Automation | `ash_oban` (with `oban_web`, as the site adds it), `ash_state_machine`, `ash_events` |
| Safety & Security | `ash_archival`, `ash_paper_trail`, `ash_cloak` (with `cloak` before it, as the site adds it) |
| Dev Tools | `live_debugger`, `ash_admin` |
| UI Components | `mishka_chelekom`, `cinder` |

Some of them need manual setup after the installer (the site says so
too): OAuth providers want their client ids in `.env`, `ash_oban`
wants a queue, `tidewave` and `live_debugger` are dev-only and their
installers set `only: :dev` themselves.

## Keeping up with the site

Every table above, and the one-line comments the catalog shows beside
each choice, come from the feature map that drives the site's *Get
Your Installer* — not from its HTML but from its app bundle
(`/assets/app-*.js`; [DESIGN.md](DESIGN.md) [17]). The site moves;
the cartridge does not know when. So it can ask:

```sh
mix workbench.ash.site
```

fetches the map as it is today and reports, per option, whether the
cartridge would put the same packages and arguments in the command and
shows the same tooltip, plus the options the site has that the
cartridge does not (presets like *LiveView* and *React* are skipped:
they are bundles of the others). It writes nothing — the report is the
list of what to update by hand, in `ash.ex`'s tables and the DESIGN
reference. Run it before a release of the cartridge, and whenever the
site announces a new package.

## Idempotency

Packages already declared in `mix.exs` are left out of the command;
when none is left, nothing is queued and a notice says so. So a re-run
with the same options is a no-op, and a run with more (`--with
ash_admin` on a project that has Ash) queues only the new ones. The
`.env` entry is appended once (the key is its mark). The mark `status`
reads is the `ash` dependency.

## Requirements

Some choices build on cartridges the site takes for granted, because
it assumes a default `phx.new` project: every `--auth` strategy but
`api_key` installs `ash_authentication_phoenix`, whose LiveViews need
**live** (and so html); `password`, `magic_link` and `otp` generate
senders that deliver with the project's Mailer, so they need **mailer**
too; and `ash_admin`, `live_debugger`, `cinder`, `mishka_chelekom` and
`ash_oban` (it brings `oban_web`) need **live**. The cartridge says so
beside each value in the catalog (`requires`) and refuses, naming what
to insert first, while it is not in the project. `--data-layer
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
| `site.ex` | `mix workbench.ash.site`: the site's feature map against the cartridge's tables |
| `CHANGELOG.md` | The cartridge's own version history |
| `DESIGN.md` | Why it queues a command instead of composing installers, with sources |

No `priv/features/ash/`: the cartridge writes no file of its own.

Cartridge test: `test/workbench_igniter/features/ash_test.exs`.
