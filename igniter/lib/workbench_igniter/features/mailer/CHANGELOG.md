# Changelog — mailer

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs* — which here is what `phx.new` generates
for a mailer at the installer's version: a change in how the delta is
taken or merged is a minor, a change that breaks a project already
carrying it is a major.

## v0.2.0 - (2026-08-30)

### Updated

- The engine (`WorkbenchIgniter.PhxDelta`, shared by every base
  cartridge) merges the three versions of a file with their ends
  normalised to one newline: Igniter writes files that way and
  `phx.new`'s `AGENTS.md`, `errors.pot` and `app.js` do not, so a file
  an earlier insert had written conflicted with any capability that
  appends at its end (ecto on the `.pot`, html and live on `AGENTS.md`,
  live on `app.js`). Insert order no longer matters.
- The engine refuses, with an issue and nothing generated, when
  `Phx.New` is not loadable or when its version is not the one that
  generated the project (`{:phoenix, "~> x.y.z"}` in `mix.exs`): a
  delta taken by another `phx.new` conflicted on `mix.exs` for six
  capabilities out of seven.
- The engine reads `--no-agents-md` off the project (the file's
  absence): both generations then run without it, and a project that
  opted out no longer receives `AGENTS.md` from the first capability
  that changes it.
- The engine takes away the files a capability replaces — `phx.new`'s
  static placeholders under `priv/static/assets/`, for esbuild and
  tailwind — when they are, byte for byte, what `phx.new` put there; a
  placeholder the project rewrote stays.
- On a conflict, `<path>.phx-new` is written to disk beside the file
  instead of into the patch set an issue withholds, so it is there to
  merge from.

## v0.1.0 - (2026-08-29)

### Added

- `mix workbench.install.mailer` (`wb.sh add mailer`): Phoenix's Swoosh
  mailer for a project generated with `--no-mailer`, as the difference
  between the project generated with and without the flag
  (`WorkbenchIgniter.PhxDelta`), merged three ways onto the project's
  files. The first base cartridge.
