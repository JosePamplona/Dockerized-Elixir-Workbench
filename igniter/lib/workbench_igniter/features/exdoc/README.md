# Cartridge: exdoc

ExDoc documentation site served by the app itself at `/dev/docs`, with
per-feature extra pages (coverage, auth token, database diagram).

* **Task**: `mix workbench.install.exdoc`
* **Inserted by**: `wb.sh add exdoc`; a chiefs_setup pick.
* **Options**: `--project-name` `--repo-url` `[--coveralls --auth0]`
  `[--build]` — whether the project has Ecto (the database page and
  diagram) is read off the project, not asked. As a chiefs_setup pick
  it receives `--coveralls`.

## Description

Builds the project's documentation site with ExDoc, the standard Elixir
documentation tool: it reads the documentation written alongside the code
(module and function docs) plus a set of curated pages, and renders them
as a browsable, searchable website. Because the source of the reference is
the code itself, regenerating the docs keeps them honest — there is no
separate document slowly drifting away from reality.

The application serves that site itself during development, at
`/dev/docs`, so nothing needs external hosting or a separate server:
anyone running the project has the full documentation one URL away, always
matching the version of the code they are on.

The site is also where the other features surface what they produce,
making it the project's reading hub: the README and changelog, the coding
style guide (downloaded at setup), the database diagram that
`enhancements` generates, the "how to get access tokens" page when auth0
is on, and the test and coverage reports that `mix cover` refreshes. A new
team member can onboard from a single place instead of chasing scattered
documents.

## What it installs

* Dep `{:ex_doc, "~> 0.38", only: :dev, runtime: false}`.
* `mix.exs`: `name`, `source_url` and the full `docs` section (assets,
  feature-conditional extras and groups, regex-based module groups), plus
  the `before_closing_*_tag` functions (theme scripts; with auth0, the
  Auth0 SDK scripts and `token.js`).
* `MyAppWeb.ExDocController` (index / cover / 404 fallback) + its test.
* Router: `:exdoc` pipeline (`Plug.Static` over the standard `doc/`
  output dir, dev-only) and `/dev/docs` routes (with `--coveralls`, also
  `/docs/cover`).
* Assets under the project's `assets/exdoc/`: `docs_config.js`, logo,
  `themedImage.js`; with auth0, `token.js` and the `token.md` page.
* Placeholders: `TESTING.md` (overwritten by `mix cover`),
  `database.md` (overwritten by enhancements' `mix db`), and dummy pages
  in `doc/` so the test suite passes before the first `mix docs` run.
* With `--build`: queues `mix docs`, so the site has pages the first
  time the door is opened. Off by default — it needs the dependencies
  fetched and compiled, which happens after the patch set is applied,
  so it is queued and never run inline.

The team's coding guidelines used to be an option here
(`--guidelines-url`) and are the [guidelines](../guidelines/) cartridge
now: this installer no longer touches the network.

**Idempotency**: if `ExDocController` already exists, notice and no-op.

## Contents

Templates and assets live under `priv/features/exdoc/`:

| File | Role |
| --- | --- |
| `exdoc.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Exdoc` shell |
| `templates/controller.eex` | `ExDocController` |
| `templates/controller_test.eex` | Controller test |
| `templates/before_closing.eex` | `before_closing_*_tag` functions |
| `assets/js/docs_config.js` | Site config |
| `assets/js/themedImage.js` | Light/dark theme images |
| `assets/js/token.js` | Token retrieval (auth0 only) |
| `assets/token.md` | "Get access tokens" page (auth0 only) |
| `assets/TESTING.md` | `mix cover` placeholder |

The PNG logo (binary, ~1.9 MB) lives outside the compiled module, in the
cartridge's `priv/` mirror (`priv/features/exdoc/images/app-logo.png`),
planted byte-for-byte with `plant_binary_asset/3`.

Cartridge test: `test/workbench_igniter/features/exdoc_test.exs`.
