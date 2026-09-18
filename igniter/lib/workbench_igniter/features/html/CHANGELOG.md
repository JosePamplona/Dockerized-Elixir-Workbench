# Changelog — html

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for it at the installer's
version, as [mailer](../mailer/CHANGELOG.md) says.

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
