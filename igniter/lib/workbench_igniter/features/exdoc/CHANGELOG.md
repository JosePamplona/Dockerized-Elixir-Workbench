# Changelog — exdoc

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a new page or route is a minor, a change
that breaks a project already carrying the generated code (a renamed
module, a moved route) is a major.

Backfilled at the version below, its first: the cartridge shipped
before a changelog was part of the anatomy, and gets one on its next
change, as the features index says.

## v0.2.0 - (2026-09-21)

### Added

- **`--app-logo`**, off by default: the placeholder logo and the
  `logo:` naming it. Until now both went in always — a 1.9 MB image
  with somebody else's name on it, committed into the project. The
  line and the file go together, since ExDoc refuses a `logo:` whose
  file is missing.
- **`--homepage-url`**: the website the sidebar's name and logo link
  to. v0.1.0 wrote `--repo-url` there, so the logo opened the
  repository; unasked, the sidebar now opens the docs' main page, as
  ExDoc does.
- **`--module-groups`**: `layers`, `ash`, `contexts` or `none`, read off
  the project when not given — `ash` when it depends on Ash, `layers`
  otherwise. The one set of regexes v0.1.0 wrote grouped an Ash
  project's changes, calculations and senders as schemas, its live
  views as plain web, and left the repo, the mailer and the Mix tasks
  out. A preset reads a module's behaviours and directory, which ExDoc
  hands a group's functions, so a live view or an Ash change is told by
  what it is; `contexts` lists `lib/<app>/` when the docs are built, a
  group per context, for the project that has many.
- `Exdoc.list_page/4`: another cartridge lists a page of its own in the
  site — guidelines' coding guide, changelog's `CHANGELOG.md` — through
  the cartridge that writes the block.

### Removed

- **The project serves nothing.** The `ExDocController` and its test,
  the `:exdoc` pipeline with its `Plug.Static` and the `/dev/docs`
  routes (`/dev/docs/cover` with `--coveralls`) are no longer planted:
  `mix docs` writes `doc/` and the console serves it off the workspace,
  on an origin of its own, with the app up or not. It was the
  workbench's reading carried by the project, in dev only.
- The dummy pages under `doc/` (`index.html`, `404.html`,
  `excoveralls.html`), which existed for the controller's test, and
  with them **`--version`**, which only stamped their titles.
- **`--auth0`** and the "Get access tokens" page with its scripts. The
  page asks Auth0 to redirect to the page's own origin and calls the
  app's API; served by the console it has neither the app's origin nor
  a fixed one. auth0 is archived; the page is its to carry when it
  comes back.

### Updated

- **The repository is found.** `--repo-url` defaulted to
  `https://github.com/user/repo`, written into every project. Now it is
  the `source_url:` mix.exs has, or the `origin` remote of the project's
  own git repository made a browsable URL (`git@github.com:acme/app.git`
  is `https://github.com/acme/app`), and only when neither says it the
  placeholder — commented out, since a live one made every "source"
  link of the site a 404, and without `authors:`, whose owner it named. A project directory inside another repository — a
  workspace under the workbench's — does not take that one's remote.
  `detected/0` names the three options found this way, and the console
  shows *read off the project* in their fields.
- **The site's name is found, in words.** Unasked, `--project-name`
  was `String.capitalize/1` of the app — `lorem_ipsum` became
  `Lorem_ipsum` — read off the Mix project running the task. Now it is
  the `name:` mix.exs already has, which is not rewritten, or else the
  app's name capitalized and spaced, `Lorem Ipsum`
  (`WorkbenchIgniter.Feature.display_name/1`, for the cartridges that
  take the same flag).
- **The changelog is listed only when the project keeps one.** It was
  listed always, and `mix docs` stops on a missing extra: a project
  without the changelog cartridge had a site that did not build. The
  changelog cartridge lists it when it opens the file later.
- **The site's sources live under `guides/`**, not `assets/exdoc/`:
  `assets/` is the release build's input — the Dockerfile copies it,
  tailwind scans it — and the site's config and scripts are a dev
  tool's code, the logo 1.9 MB, none of it the release's.
  `guides/config/` lands at the site's root and `guides/js/` and
  `guides/images/` under its `assets/`, as before; the pages
  (`database.md`, guidelines' `coding.md`) sit beside them. `guides/`
  is where Elixir projects keep their docs' sources (Ecto's logo is
  `guides/images/e.png`).
- The mark is `guides/config/docs_config.js`, the one file every
  edition planted, or v0.1.0's `assets/exdoc/config/docs_config.js`,
  so a project that carries v0.1.0 — controller and all — reads as
  exdoc still. `state/1` reads `--coverage` off the
  report page among the `docs:` extras.
- **`--coveralls` is `--coverage`**, after the box it names, which
  took the need's name. The page and the report it joins are the same.
- `DESIGN.md`, the paper the anatomy asks of a cartridge on its next
  change.

## v0.1.0 - (2026-08-30)

### Added

- The ExDoc site served by the application at `/dev/docs`: the
  `ex_doc` dependency, the `MyAppWeb.ExDocController` and its test, the
  `docs:` block of `mix.exs` (extras, groups, the workbench theme's
  `before_closing_*_tag` hooks), the theme assets and logo, and the
  per-feature extra pages — the coverage report with coveralls, the
  access-token page with auth0, the database page when the project has
  Ecto (read off the project, not asked).
- `--build`: runs `mix docs` once the insert is applied, so the door
  has pages the first time it is opened. Off by default, and queued
  rather than run inline — the site needs the dependencies fetched and
  compiled, which only happens after the files land. `afterwards/0`
  names the command for whoever leaves it off.

### Removed

- `--guidelines-url`, and with it the only network call this installer
  made. The coding-guidelines page is the [guidelines](../guidelines/)
  cartridge now: it downloads the markdown and appends its entries to
  the two lists this cartridge's `docs:` block keeps.
