# Changelog — chiefs_setup

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs* — here, the recipe: a changed pick or
argv is a minor, a removed pick (a project counting on it stops getting
it) is a major.

## v0.3.0 - (2026-09-18)

### Added

- `version_manager` joins the recipe, ahead of `toolchain`: the
  `.tool-versions` toolchain wrote is that cartridge's now, so the
  collection still leaves what it left — the pin and the language
  server's ignore — as two commits instead of one. Elixir is pinned
  with its OTP (`1.19.6-otp-28`).

## v0.2.0 - (2026-08-30)

### Added

- The house's settings join the recipe, ahead of everything else:
  `ansi`, `toolchain` and `versioning` — the three boxes the rest of
  the retired setup's configuration became. A project outfitted by this
  collection now gets what the opinionated `new` used to write into it,
  as three commits it can revert one at a time.

## v0.1.0 - (2026-08-30)

### Added

- The recipe, inherited from the retired `mix workbench.setup`
  composition, trimmed to the picks that need no external account:
  osmon, psql_extras, credo, mock, exdebug, rest **or** graphql
  (`--interface`, default `rest`), coveralls (`--exdoc`), exdoc
  (`--coveralls`), enhancements (`--interface`, `--exdoc`, `--health`)
  and healthcheck — in the old composition order, which the marks build
  on. auth0, openai and stripe stay à la carte.
- `--interface rest | graphql`: the one choice the collection owns.
  Anything else the installer refuses with an issue.
- `members/1` in the manifest: the recipe `mix workbench.expand` reads,
  so `wb.sh add chiefs_setup` inserts each missing pick as its own
  commit. Run directly, the installer composes the same picks into one
  patch set.
- The delegated mark: installed when every fixed pick is in and one of
  the two interfaces is; `state/1` reports which. Re-running inserts
  the missing picks (`rerun: :adds`).
