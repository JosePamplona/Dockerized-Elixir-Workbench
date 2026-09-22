# Cartridge: exdoc

ExDoc's documentation site for the project, with per-feature extra pages
(the test suite report, the database diagram), served by the console.

* **Task**: `mix workbench.install.exdoc`
* **Inserted by**: `wb.sh add exdoc`
* **Options**: `[--project-name]` `[--repo-url]` `[--homepage-url <url>]` `[--app-logo]`
  `[--module-groups <preset>]` `[--coverage]` `[--build]` —
  whether the project has Ecto (the database page and diagram) is read
  off the project, not asked.

## Description

Builds the project's documentation site with ExDoc, the standard Elixir
documentation tool: it reads the documentation written alongside the code
(module and function docs) plus a set of curated pages, and renders them
as a browsable, searchable website. Because the source of the reference is
the code itself, regenerating the docs keeps them honest — there is no
separate document slowly drifting away from reality.

`mix docs` writes the site to `doc/`, and the console serves it from
there, on an origin of its own: the project carries no route, no
controller and no environment for it, and the docs can be read with the
app down. Anyone running the workbench has the full documentation one
click away, always matching the version of the code they are on.

The site is also where the other features surface what they produce,
making it the project's reading hub: the README and changelog, the coding
style guide ([guidelines](../guidelines/)), the database diagram that
`enhancements` generates, and the test and coverage reports that
`mix cover` refreshes. A new team member can onboard from a single place
instead of chasing scattered documents.

## What it installs

* Dep `{:ex_doc, "~> 0.38", only: :dev, runtime: false}`.
* `mix.exs`: `name` — the one it has, or the app's name in words,
  `lorem_ipsum` as `Lorem Ipsum` —, `source_url` — the one it has, or
  the `origin` of the project's own git repository, or a placeholder
  commented out until it is filled in —
  and the full `docs` section (assets,
  feature-conditional extras and groups, regex-based module groups), plus
  the `before_closing_*_tag` functions (the theme script).
* With `--homepage-url`, the website the sidebar's name and logo link
  to; without it they open the docs' main page, as ExDoc does.
* The site's sources under the project's `guides/` — outside `assets/`,
  which is the release build's input: `config/docs_config.js`,
  `js/themedImage.js`; with `--app-logo`, `images/app-logo.png` and the
  `logo:` that names it.
* The sidebar's module groups, `--module-groups`, read off the project
  when not given (`ash` when it depends on Ash, `layers` otherwise):

  | Preset | Groups |
  | --- | --- |
  | `layers` | Application · Contexts · Schemas · Live views · Controllers · Components · Plugs · Web · Mix tasks · Exceptions |
  | `ash` | Application · Domains · Changes · Validations · Calculations · Preparations · Checks · Types · Senders · Resources · the web layer |
  | `contexts` | one group per directory under `lib/<app>/`, read each time `mix docs` runs · Application · the web layer |
  | `none` | ExDoc's own flat list |

  A preset is functions of `mix.exs` (`groups_for_modules/0`,
  `web_groups/0`, `behaves?/2`, `in_dir?/2`): a live view or an Ash
  change is told by the behaviour it implements, which a name does not
  say.
* The README among the extras, as Overview and the page the site opens
  on — or, with `--no-readme`, left out, the site opening on ExDoc's API
  reference — and the changelog when the project keeps
  one — the [changelog](../changelog/) cartridge lists it when it opens
  one later.
* Placeholders: `TESTING.md` with `--coverage` (overwritten by
  `mix cover`), `database.md` (overwritten by enhancements' `mix db`).
* With `--coverage`: the Test Suite Report page among the extras, and
  ExCoveralls' output dir copied into the site's root (`"cover" => "/"`),
  so the report and the page link each other by relative paths.
* With `--build`: queues `mix docs`, so the site has pages the first
  time the door is opened. Off by default — it needs the dependencies
  fetched and compiled, which happens after the patch set is applied,
  so it is queued and never run inline.

Until v0.2.0 the application served the site itself: a controller, a
`Plug.Static` pipeline and `/dev/docs` routes in the router, the
auth0 token page (`--auth0`) and dummy pages under `doc/` for the
controller's test (`--version`). [DESIGN.md](DESIGN.md) says why they
left.

**Idempotency**: if `guides/config/docs_config.js` (or v0.1.0's
`assets/exdoc/config/docs_config.js`) already exists,
notice and no-op.

## Contents

Templates and assets live under `priv/features/exdoc/`:

| File | Role |
| --- | --- |
| `exdoc.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Exdoc` shell |
| `templates/before_closing.eex` | `before_closing_*_tag` functions |
| `assets/js/docs_config.js` | Site config |
| `assets/js/themedImage.js` | Light/dark theme images |
| `assets/TESTING.md` | `mix cover` placeholder |

The PNG logo (binary, ~1.9 MB) lives outside the compiled module, in the
cartridge's `priv/` mirror (`priv/features/exdoc/images/app-logo.png`),
planted byte-for-byte with `plant_binary_asset/3`.

Cartridge test: `test/workbench_igniter/features/exdoc_test.exs`.
