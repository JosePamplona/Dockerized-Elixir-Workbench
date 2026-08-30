# Changelog — live

Versioned on its own, independently of the workbench release that ships
it; semver over what `phx.new` generates for it at the installer's
version, as [mailer](../mailer/CHANGELOG.md) says.

## v0.1.1 - (2026-08-30)

### Added

- A notice when the project has no esbuild: the `LiveSocket` lives in
  `assets/js/app.js`, which only a bundler brings, so LiveView is
  served and configured and nothing in the browser connects to it
  until esbuild is in.

## v0.1.0 - (2026-08-30)

### Added

- `mix workbench.install.live` (`wb.sh add live`): liveView — its configuration, the live socket in app.js and the endpoint, the JS commands of the core components
  for a project generated with `--no-live`, as the difference between
  the project generated with and without the flag
  (`WorkbenchIgniter.PhxDelta`). Refuses without html.
