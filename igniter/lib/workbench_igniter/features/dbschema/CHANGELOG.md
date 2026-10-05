# Changelog — dbschema

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a new page or task is a minor, a change
that breaks a project already carrying the generated code (a renamed
task, a moved file) is a major.

## v0.1.0 - (2026-09-22)

### Added

- **The box.** The database's documentation, which was split between two
  cartridges, is one: `mix db` and its test, the DbSchema export under
  `assets/db_schema/`, the page `guides/database.md` and the two model
  diagrams under `guides/images/` — all of it here, with the
  `html_entities` dependency the task decodes with. enhancements planted
  the task and the sources; exdoc planted a placeholder page and listed
  it. Both let go: enhancements composes this installer when the project
  has Ecto, and exdoc no longer knows the page exists — it is listed the
  way the changelog is, by the cartridge that writes it.
- **`--combo`**, one of `none`, `auth0`, `auth0_openai`, `auth0_stripe`
  or `auth0_openai_stripe`: which sample export is planted, so the page
  and the diagram have content before anyone opens DbSchema. `none` is
  the default, a stock Phoenix database.
- **Both themes, ExDoc's own way.** The page names two images,
  `./assets/model-light.svg#gh-light-mode-only` and
  `./assets/model-dark.svg#gh-dark-mode-only`. ExDoc has hidden an image
  by that fragment since v0.27, so the diagram follows the reader's
  theme with no script in the site — where the old page named one image
  and leaned on exdoc's `themedImage.js`, retired in exdoc v0.4.0.
- **Builds on ecto** (`requires`): there is no database page without a
  database. It does *not* build on exdoc — the page and the images are
  written either way, and listed in the site only when the project has
  one.

### Archived

- Retired on the day it was extracted. DbSchema is a desktop tool
  outside the workbench, and this box only dresses its export; the
  reference project is on Ash, whose diagrams come from Ash itself. The
  papers stay for the reading, and a project that carries `mix db`
  keeps it — the file is the project's.
