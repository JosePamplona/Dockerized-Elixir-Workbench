# Changelog — changelog

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.5.0 - (2026-09-21)

### Added

- **The changelog is a page of the docs site, when there is one.** A
  `docs:` block with `extras:` in `mix.exs` — exdoc's — gets
  `{"CHANGELOG.md", [title: "Changelog"]}` among its extras and the
  file in its `Project` group, beside the README. exdoc lists it itself
  when the file is there first; this is the other order. A second run
  finds it listed, and a `docs:` the project wrote without that group
  gets the page and no group. Without a docs block nothing is written.

## v0.4.0 - (2026-09-20)

### Changed

- The cartridge is `changelog`, not `versioning`: `wb.sh add changelog`,
  `mix workbench.install.changelog`. It is named for what it puts in the
  project — the file its mark looks for — instead of for the discipline
  around it, which the box cannot install and whose one undecidable
  part, when `0.1.0` becomes `0.2.0`, it leaves to whoever cuts the
  release. On the shelf it no longer reads as a pair with
  `version_manager`, which shares nothing with it but the word.
- What it installs is unchanged: the same `CHANGELOG.md` at the same
  version, the same `mix version` task and the same README badge, under
  the same options.

## v0.3.0 - (2026-09-18)

### Changed

- `--version` is `--init-version`, and its default is the version
  `mix.exs` has, not `0.0.0`: the history opens where the project is,
  new or well under way, and `mix.exs` is left untouched unless another
  version is asked for. `0.0.0` had been argued against `phx.new`'s
  `0.1.0`, which is the start SemVer's own FAQ recommends; and on a
  project already released it took the number back. DESIGN.md, new with
  this version, has the sources.
- `--task` is `--mix-task`: what it plants is a Mix task, and `task`
  alone said no more than the installer it is an option of. `state/1`
  answers `mix_task`.
- `state/1` answers `init_version`: the oldest release title of the
  changelog (the house's `## v1.2.3` or Keep a Changelog's
  `## [1.2.3]`), where the history opens for as long as the file lives —
  not `mix.exs`'s number, which moves with every release.
- The changelog's opening entry: "This changelog: the project's notable
  changes are recorded here from this version on." instead of "Brand
  new project created.", which a project two years old is not.

- The README badge is `lightgrey`, not `white`: shields.io's named
  colour for the message half. `mix version` keeps whatever colour the
  badge it finds has, so a project that carries the white one keeps it.

### Fixed

- A version Mix would not compile (`1.2`) is refused, by the installer
  and by the planted `mix version`, before anything is written: a
  `mix.exs` carrying one stops every Mix task, this installer included.
- `version: @version` is read (the shelf's `mix_project_value/2` reads
  a module attribute through to its literal) and written: by the
  installer through Igniter, by `mix version` on the `@version "…"`
  line. It was `nil` to the first and an error to the second.
- A pre-release's dash is doubled in the badge's URL
  (`version-2.0.0--rc.1-lightgrey.svg`), as shields.io asks, and `mix
  version` reads the doubled form back. It produced a broken badge and
  then could not find it.

- Releases are dated by the developer's day, not UTC's: the changelog
  the installer opens and the title `mix version` writes took
  `Date.utc_today/0`, and an insert at 18:50 in UTC-6 came out dated the
  next day. Found on the probe project (DESIGN.md, 4).

## v0.2.0 - (2026-09-17)

### Added

- `--task`: the `mix version NEW` task and its test, moved here from
  enhancements, where it was a lodger — the version is this cartridge's
  decision, and the task is that decision's tool. Rewritten for a stock
  project: it writes the number into `mix.exs`, closes the changelog's
  `Unreleased` as that version under the commented template line this
  cartridge's changelog keeps for it, and updates the README's badge
  only when there is one. It used to fail on any README without a
  badge, since the retired setup's README template always had one. Its
  test runs in a directory of its own instead of mocking `File`.
- `--readme-badge`: the shields.io version badge under the README's
  title, at the version the project has.
- `rerun: :adds`: a second run adds the task or the badge when asked and
  missing, and still never moves the version. `state/1` reads the two
  back.

## v0.1.0 - (2026-08-30)

### Added

- The `version:` of `mix.exs` (`--version`, default `0.0.0`) and the
  `CHANGELOG.md` opened at it, both rescued from the retired
  `workbench.setup`: they were its `INIT_VERSION` and its
  `changelog.eex` template, which travelled with it.
- `state/1` reading back the version `mix.exs` declares.
