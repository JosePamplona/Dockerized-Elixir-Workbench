# Cartridge: exdoc

ExDoc's documentation site for the project, with per-feature extra pages
(the test suite report, the database diagram), served by the console.

* **Task**: `mix workbench.install.exdoc`
* **Inserted by**: `wb.sh add exdoc`
* **Options**: `[--project-name]` `[--repo-url]` `[--homepage-url <url>]` `[--app-logo]`
  `[--module-groups <preset>]` `[--no-readme]` `[--changelog]` `[--coverage]`

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
  feature-conditional extras and groups, regex-based module groups).
* With `--homepage-url`, the website the sidebar's name and logo link
  to; without it the line is written commented, a placeholder to fill
  in, as `source_url` is, and until then they open the docs' main page,
  as ExDoc does.
* The site's sources under the project's `guides/` — outside `assets/`,
  which is the release build's input: `config/docs_config.js`; with
  `--app-logo`, `images/app-logo.png` and the `logo:` that names it.

### An image for each theme

ExDoc hides an image whose URL carries `#gh-dark-mode-only` in the light
theme and one with `#gh-light-mode-only` in the dark one, since v0.27.
A page that wants both writes them one after the other:

```markdown
![Model](./assets/model-light.svg#gh-light-mode-only)
![Model](./assets/model-dark.svg#gh-dark-mode-only)
```

The fragment is GitHub's own, so the same page reads right in the
repository too. Until v0.4.0 this box planted a script of its own for
it (`guides/js/themedImage.js`, in the `before_closing_body_tag`); the
fragments do the same thing with nothing installed.
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
  reference. With no `README.md` yet the two entries are written
  **commented out**, the slot where the page goes, and `main:` is left
  out with them: `mix docs` stops on an extra whose file is missing.
* With `--changelog`, the changelog among the extras and in the
  `Project` group. The option **builds on the [changelog](../changelog/)
  cartridge**, which writes that file: asked for without it, the run is
  refused naming it. Off by default, and for the other order there is
  nothing to ask — a changelog opened after the site lists its own page.
* With `--coverage` — which **builds on the [coverage](../coverage/)
  cartridge with `--md-report`**, the flag that plants the `mix cover`
  extras, and ExCoveralls' output dir copied into the site's root
  (`"cover" => "/"`), so the report and the page link each other by
  relative paths. The page is listed live when the report is there and
  waits commented out when it is not, as the README's entries do — this
  box writes no page of its own for it.
The insert runs nothing: `./wb.sh mix docs` writes the site, and so
does **build** on the docs door in the console, where the output of the
run is read as it happens.

Until v0.2.0 the application served the site itself: a controller, a
`Plug.Static` pipeline and `/dev/docs` routes in the router, the
auth0 token page (`--auth0`) and dummy pages under `doc/` for the
controller's test (`--version`). [DESIGN.md](DESIGN.md) says why they
left.

**Idempotency**: if `guides/config/docs_config.js` (or v0.1.0's
`assets/exdoc/config/docs_config.js`) already exists,
notice and no-op.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/exdoc/` | The cartridge: its code and its papers |
| `├── 📄 exdoc.ex` | `mix.exs`'s `docs:`, the sources under `guides/` |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why the project serves nothing, each option |
|  |  |
| `📁 priv/features/exdoc/` | What it writes into the project |
| `├── 📁 templates/` | Code for `mix.exs` |
| `│   ├── 📄 groups_layers.eex` | The sidebar by layer |
| `│   ├── 📄 groups_ash.eex` | The sidebar by role in the Ash DSL |
| `│   ├── 📄 groups_contexts.eex` | One group per context, read at build |
| `│   └── 📄 groups_web.eex` | The web layer's helpers, for every preset |
| `├── 📁 assets/` | Copied verbatim |
| `│   └── 📁 js/` |  |
| `│       ├── 📄 docs_config.js` | The site's config |
| `└── 📁 images/` |  |
| `    └── 📄 app-logo.png` | The placeholder logo (`--app-logo`), binary |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 exdoc_test.exs` | Its options, the pages, the state |
