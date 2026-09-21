# Changelog — exdebug

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: another dependency or another line in
the project's config is a minor, a change that breaks a project already
carrying what this one wrote is a major.

Backfilled at the version below, its first: the cartridge shipped
before a changelog was part of the anatomy, and gets one on its next
change, as the features index says.

## v0.1.0 - (2026-09-20)

### Added

- `{:ex_debug, "~> 1.0"}` in the project deps, and nothing else — the
  dependency as its author writes it, with no `only:` restriction,
  because the guard lives inside `ExDebug.console/2` and not at the
  call site: a call left in a pipeline has to compile in `:prod` too.
  `on_exists: :skip`, so re-running is a no-op.

  Verified against a probe project built for the paper (`DESIGN.md`,
  Evaluation): the frame prints in `:dev`, nothing prints under
  `MIX_ENV=prod`, and the value passes through unchanged in both — and
  in a release started with the `MIX_ENV` its image sets. Started
  *without* it the call raises, which is the library's shape and is
  written down rather than patched.

  No `config :ex_debug` block is written. Every key it takes (`width`,
  `color`, `line_color`, `time_color`, `syntax_colors`) already has the
  same default inside the library, and `console/2` takes them per call:
  a generated block would be a file for the project to maintain that
  says what the library says.
