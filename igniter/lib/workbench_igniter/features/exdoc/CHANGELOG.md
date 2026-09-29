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

## v0.9.0 - (2026-09-29)

### Added

- **`--output`: where `mix docs` writes the site.** ExDoc's own
  `output`, a directory inside the project, `doc` by default — which is
  what the box wrote until now, and what phx.new gitignores. Under
  `priv/static/` the app serves the site itself. The value is checked
  as a directory of the project's own (`:dir`: relative, no `..`),
  since the console serves it off the workspace. `state/1` reads it
  back off `mix.exs` — ExDoc's default when the line is not there — so
  a project that moved its docs by hand reports the move like one that
  asked for it, and the docs door follows: it is `{output}` now, filled
  with what the project says, where it used to name `doc` and read
  *nothing built* on a project that had moved it (tunez, to
  `priv/static/doc`).

### Changed

- **`--coverage` copies the report from where the coverage box writes
  it**, read off that box's `state/1` (`output_dir`), where it assumed
  `cover`.

## v0.8.0 - (2026-09-23)

### Changed

- **The pin is `~> 0.40`.** It was `~> 0.38` while the box's own design
  paper quoted ExDoc at 0.40.4, and `~> 0.38` resolves to neither 0.39
  nor 0.40. Since 0.40 `mix docs` writes three formats into `doc/`: the
  HTML site the console serves, a Markdown tree with `llms.txt` — its
  table of contents for whoever reads the project with a language model
  — and the EPUB it always wrote. They are ExDoc's own defaults and the
  box leaves them alone; `doc/` is gitignored, so nothing the project
  carries changes. Verified in a probe: a stock `phx.new` project with
  this cartridge in builds its site on 0.40.4, past the validations
  0.39 and 0.40 added for extras, reserved filenames and `:assets`.

## v0.7.0 - (2026-09-22)

### Changed

- **`--changelog` builds on the changelog cartridge, and is off by
  default.** The option lists a file another box writes, so it asks for
  that box the way credo's `--githook` asks for precommit: without it
  the run is refused naming it, and the console draws the option unlit
  with a door to that box. Off by default, so `add exdoc` still works
  on any project; with it on, the file is there and the entries go in
  live — the commented slot v0.5.0 wrote for the changelog is gone with
  the case that needed it. The other order is unchanged: a changelog
  opened after the site lists its own page.
- **`--coverage` builds on the coverage cartridge with `--md-report`**,
  the flag that plants the `mix cover` task which writes the page this
  lists (`{"coverage", md_report: true}`). Asked for without it, the run
  is refused naming it and saying which half is missing — the box, or
  the flag. The page itself is no longer planted here: `TESTING.md` is
  coverage's file, and this box does with it what it does with the
  README — lists it live when it is there, and leaves its two entries
  commented out when it is not.
- **`--readme` reads the file.** It is on by default still, and nobody
  owns `README.md` — `phx.new` writes it and the shelf has no box that
  would — so with none there the two entries are written commented out,
  the slot one written later takes, and `main: "readme"` is left out
  with them: `mix docs` stops on an extra whose file is missing, and a
  `main:` naming a page nobody listed is not validated at all — the
  site's index redirects to a page that is not there. `state/1` reads
  the live entry alone.

## v0.6.0 - (2026-09-22)

### Removed

- **`--build`.** The insert wrote files and queued `mix docs` behind
  them; the console's docs door now offers *build* where the site is
  not there, running the same command as a job whose output the reader
  watches — and `./wb.sh mix docs` was always the other way. An option
  that only queued a command the box already names (`afterwards/0`,
  `build:` in its door) was a third place saying it, and the one that
  reported nothing back: it left no mark, so `state/1` answered `nil`
  for it.

## v0.5.0 - (2026-09-22)

### Added

- **`--changelog`, on by default: the changelog is a page of the site
  because the insert says so, not because the file happened to be
  there.** With a `CHANGELOG.md` the extra and the `Project` group's
  entry are written live, as before. Without one they are written
  **commented out** — the slot where the page goes, the way
  `source_url` and `homepage_url` wait for a repository and a website:
  `mix docs`, which stops on an extra whose file is missing, never
  reads a comment, and the reader of `mix.exs` sees the place kept.
  `--no-changelog` leaves neither entry, whatever the project keeps.
- **`uncomment_page/4`, beside `list_page/4`.** It fills the slot: the
  commented entries go and `list_page/4` writes them live. The
  [changelog](../changelog/) cartridge calls it when it opens a
  changelog on a project that already has the site, and lists nothing
  when the site is in with `--no-changelog`. `list_page/4`'s contract
  is unchanged — guidelines calls it for its own page.

### Changed

- `state/1` answers `changelog:` off the **live** entry: a commented
  slot is a place kept, not a page the site lists.

- **`--repo-url` and `--homepage-url` are checked before they are
  written.** Both are declared `:url` (`formats/0`), so a value that is
  not an address a browser opens ends the run instead of landing in
  `mix.exs`, where it made every source link a 404 and sent the
  sidebar's logo nowhere. The console asks for them with a URL field.

## v0.4.1 - (2026-09-22)

### Removed

- **The database page.** `guides/database.md` is no longer planted as a
  placeholder, no longer listed among the extras and under Support, and
  the project's Ecto is no longer read here at all. It is
  [dbschema](../dbschema/)'s page: that cartridge writes it, and lists
  it in this site when there is one, the way changelog lists its own.
  This cartridge knew a page would be overwritten by a task it did not
  install, which is one box reasoning about another. A project that
  already carries the page and the listing keeps both.

## v0.4.0 - (2026-09-22)

### Removed

- **The theme script.** `guides/js/themedImage.js`, the
  `before_closing_head_tag`/`before_closing_body_tag` functions of
  `mix.exs` and the `"guides/js" => "/assets"` asset entry are gone.
  ExDoc has done this itself since v0.27: it hides an image whose URL
  carries `#gh-dark-mode-only` in the light theme and one with
  `#gh-light-mode-only` in the dark one — GitHub's own fragment, so the
  page reads right in the repository too. The script also named one
  pair of files, the database model's, so it served one page and no
  other. A project that carries the script keeps working; its mix.exs
  can drop the two functions and the file with them. The README says
  how to write a two-theme image now.

## v0.3.1 - (2026-09-22)

### Changed

- **`--homepage-url` unasked is a placeholder, commented**, the way
  `source_url` is when no repository is found:
  `# homepage_url: "https://example.com",` in the `docs:` block, so the
  key waits where it goes instead of being absent. The sidebar still
  opens the docs' main page until it is filled in; `state/1` reads only
  the live line, so the placeholder says back no website.

## v0.3.0 - (2026-09-21)

### Added

- **`--readme`**, on by default: the project's `README.md` as the
  Overview page and the one the site opens on, as before. `--no-readme`
  leaves it out of the extras and of the Project group and drops
  `main: "readme"`, so the site opens on ExDoc's API reference — for a
  README written for the repository's front page, not for the docs.

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
