# Changelog — html

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for it at the installer's
version, as [mailer](../mailer/CHANGELOG.md) says.

## Unreleased

### Updated

- `--live` without esbuild is said before the insert as well as after
  it: the manifest declares it (`advises/0`, esbuild, and why), the
  catalog carries it on the switch, and the console shows it beside
  the switch, still lit. The notice is the shared one (`advise/3`):
  "--live is in without esbuild: … Add it with: ./wb.sh add esbuild".

## v0.3.0 - (2026-09-19)

### Updated

- Like every base cartridge: a file the project has not moved is
  written as `phx.new` writes it, byte for byte (engine, mailer
  v0.3.0).
- The engine (`WorkbenchIgniter.PhxDelta`) applies the router's change
  as operations on its pipelines, scopes and routes
  (`WorkbenchIgniter.RouterFile`), not as a text merge: an API with a
  route in its `scope "/api"` conflicted, since html turns that scope
  into a comment; the scope now stays, active, with the page's `scope
  "/"` and `:browser` pipeline beside it. Each item is known by what it
  is, not by its line; what the project changed stays as the project
  has it, with a notice; and when the operations cannot turn
  `phx.new`'s base into its theirs, the router is merged as text as
  before. [mailer](../mailer/DESIGN.md) §3.4, §4.6.

## v0.2.0 - (2026-09-18)

### Added

- `--live`, on by default: LiveView on top of html — its configuration,
  the LiveSocket in `app.js` and the endpoint, the JS commands of the
  core components, the LiveView section of `AGENTS.md` — as the
  difference between the project generated with and without
  `--no-live`. It was the `live` cartridge (v0.1.1): in the generator
  live is `html && live`, a condition inside html's templates with no
  file of its own, so it is html's decision and not a box. `--no-live`
  leaves it out; a second run adds it to a project that has html
  without it (`rerun: :adds`); `state/1` reads it back off LiveView's
  configuration, the one block only `--live` writes; the notice when
  the project has no esbuild came with it. A cartridge that needs
  LiveView requires `{"html", live: true}`.

## v0.1.0 - (2026-08-30)

### Added

- `mix workbench.install.html` (`wb.sh add html`): hTML — Phoenix.HTML, the browser pipeline, the layouts and core components, the page controller
  for a project generated with `--no-html`, as the difference between
  the project generated with and without the flag
  (`WorkbenchIgniter.PhxDelta`).
