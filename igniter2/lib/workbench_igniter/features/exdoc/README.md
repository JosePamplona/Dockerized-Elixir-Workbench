# Cartridge: exdoc

ExDoc documentation site served by the app itself at `/dev/docs`, with
per-feature extra pages (coverage, auth token, database diagram).

* **Task**: `mix workbench.install.exdoc`
* **Enabled by**: `--exdoc` (config.conf: `EXDOC`)
* **Argv from setup**: `--project-name` `--repo-url`
  `[--guidelines-url]` `[--coveralls --auth0 --openai --stripe]`
  `[--no-ecto]`

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
* Placeholders: `COVERAGE.md`/`TESTING.md` (overwritten by `mix cover`),
  `database.md` (overwritten by enhancements' `mix db`), and dummy pages
  in `doc/` so the test suite passes before the first `mix docs` run.
* With `--guidelines-url`: downloads the style guide as
  `assets/exdoc/coding.md` (placeholder + warning if the download fails).

**Idempotency**: if `ExDocController` already exists, notice and no-op.

## Contents

| File | Role |
|---|---|
| `exdoc.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Exdoc` shell |
| `templates/controller.eex` | `ExDocController` |
| `templates/controller_test.eex` | Controller test |
| `templates/before_closing.eex` | `before_closing_*_tag` functions |
| `assets/js/docs_config.js` | Site config |
| `assets/js/themedImage.js` | Light/dark theme images |
| `assets/js/token.js` | Token retrieval (auth0 only) |
| `assets/token.md` | "Get access tokens" page (auth0 only) |
| `assets/coverage.md`, `assets/testing.md` | `mix cover` placeholders |

The PNG logo (binary, ~760K) lives outside the compiled module, in
`priv/features/exdoc/images/app-logo.png`, read with
`WorkbenchIgniter.feature_asset/2`.

Cartridge test: `test/workbench_igniter/features/exdoc_test.exs`.
