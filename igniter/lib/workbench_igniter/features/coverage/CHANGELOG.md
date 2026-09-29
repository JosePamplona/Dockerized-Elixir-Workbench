# Changelog — coverage

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*: a change in the report or the task is a
minor, a change that breaks a project already carrying them is a major.

Backfilled at the version below, its first: the cartridge shipped
before a changelog was part of the anatomy, and gets one on its next
change, as the features index says.

## v0.12.0 - (2026-09-29)

### Added

- **`--output-dir`: where the HTML report is written.** ExCoveralls'
  own `output_dir`, a directory inside the project, `cover` by default
  — what the box wrote until now, and what phx.new gitignores. Checked
  as a directory of the project's own (`:dir`), since the console
  serves it off the workspace. `state/1` reads it back off
  `coveralls.json`, so a project that moved the report by hand reports
  the move too, and the coverage door follows: `{output_dir}`, filled
  with what the project says, where it used to name `cover`.

## v0.11.0 - (2026-09-25)

### Changed

- **`--html-theme default` is the new default: ExCoveralls' own
  report.** Nothing is planted under `test/coverage/template/` and
  `coveralls.json` carries no `template_path`, so the report is the
  one the tool renders. `custom` and `exdoc-ish` are asked for by name.
  `state/1` reads `default` off a `coveralls.json` with no
  `template_path`.
- **`deps` and `test` are `--ignore-files` groups, first in the list
  and in the default** (`deps,test,boilerplate,components`). Until now
  they were written always and were not options. The option's note
  speaks only of `coveralls.json`.

### Removed

- `--ignore-files none`. An empty answer is the default set; a project
  that wants everything counted edits its own `coveralls.json`.

## v0.10.1 - (2026-09-24)

### Changed

- `--ignore_files` carries a note for the form, what none of its
  groups can say: `deps` and `test` are left out always, and a path of
  the project's own goes in its `coveralls.json`. The form shows each
  group's doc under it and this under them all, in place of the
  option's command-line line.

## v0.10.0 - (2026-09-22)

### Changed

- **`--ignore-files` takes the groups this box knows, and no other
  value.** It also took a path of the reader's own, which made the form
  offer a free text field beside the four groups for a value the box
  could neither check nor explain — an entry of `skip_files` is a
  regex, and a regex the box did not write is one it cannot say
  anything about. A value that is not a group is refused now, naming
  them; a project that wants another path out of the report edits its
  own `coveralls.json`, and `state/1` still reads that path back as the
  path it is.

## v0.9.0 - (2026-09-22)

### Changed

- **`--exdoc` is `--md-report`, and the report page is this box's.**
  The flag named another cartridge, which is the one thing a box's
  papers never do; what it plants is the task that writes the report as
  Markdown — `TESTING.md` at the project's root, which any reader of
  the repository opens, site or no site. The page that waits until the
  first run is planted here too, since the file is this box's. Whether
  a documentation site *lists* it is the site's business: exdoc's
  `--coverage` reads the file and lists it, or leaves its entry
  commented out until the report is written.
- **`--theme` is `--html-theme`.** The box writes two reports now — the
  HTML one ExCoveralls renders and the Markdown one `mix cover` writes
  (`--md-report`) — so a bare `--theme` no longer says which it dresses.
  It defaults to `custom`, the workbench's own report, which
  reads on its own wherever it is opened; `exdoc-ish` mimics the ExDoc
  pages, for a project whose report is read inside a documentation
  site; it was the default while the box assumed there was one. The two
  are listed in that order now — the default first, as every list of
  values on the shelf reads — so the form offers them the same way.

## v0.8.0 - (2026-09-22)

### Changed

- **`--exdoc` builds on test_doubles instead of inserting it.** The
  `mix cover` task's own tests stand on a double of `File`, which is
  Mimic's side of that box; until now this cartridge composed
  `test_doubles --double mimic`, so a box nobody picked rode inside
  this one's commit and the choice of doubling library was made for the
  reader. The option now carries `{"test_doubles", double: "mimic"}` as
  its requirement: without that box, or with Mox alone, the run is
  refused naming the box and the double, and `./wb.sh add test_doubles`
  is the line it gives. It is the same move `--githook` made onto
  precommit in v0.4.0. What stays is the registration of `File` in this
  cartridge's own block of the test helper.

## v0.7.0 - (2026-09-22)

### Added

- **`--file-column-width`, and its default is 80.** How wide the file
  column of ExCoveralls' terminal table is: a path longer than it is
  cut, and with `--exdoc` the `mix cover` task reads that table to
  build the report's own, so a cut path is a file the report loses. The
  box wrote 128 always — never cutting, at the price of a wide terminal
  for every project. 80 holds a stock project's longest paths and
  leaves the choice where it belongs; a project with deeper modules
  raises it, and a whole number from 40 to 999 is the shape
  (`formats/0`), refused before anything is written.

## v0.6.1 - (2026-09-22)

### Fixed

- **A second run with `--exdoc` plants the `mix cover` task the first
  left out.** The box says `rerun: :adds`, and only the hook block was
  a piece it added: `--exdoc` on a project that already had
  `coveralls.json` was skipped in silence, so the only way to get the
  task was to eject the box and insert it again. Now the task, its
  formatter and its test go in when they are missing, and the notice
  names what a second run is still putting in instead of saying
  *skipping* alone.

## v0.6.0 - (2026-09-22)

### Added

- **`--ignore-files`: what the report leaves out, said in groups.**
  Comma-separated, each value a group the box knows — `boilerplate`
  (the wiring `phx.new` writes: the application, `<app>_web.ex`, the
  endpoint, the router, telemetry, gettext, the repo, the mailer, the
  release and the socket), `components`, `mix_tasks`, `open_api` — or a
  path of your own, which is a regex excoveralls matches against each
  file's path. Default `boilerplate,components`; `none` counts every
  file the project compiles. `deps` and `test` are left out always, as
  they were. Only the paths the project has are written, so
  `coveralls.json` reads as the project it belongs to, and `state/1`
  says the groups back — a path added by hand reads back as itself.

### Removed

- **`--interface`.** It decided one entry of `skip_files`, the
  `open_api` folder, by asking which API the project speaks — a
  question about a box this one does not install, and one that left
  the reader nothing to say about the rest of the report.
  `--ignore-files open_api` is the same answer, beside the others.

## v0.5.0 - (2026-09-22)

### Removed

- **`--build`.** It queued the suite — and, on a project with Ecto,
  `ecto.create` and `ecto.migrate` before it — so the report had
  numbers on first boot. The console's coverage door offers *build*
  now, running the box's own command as a job; the database it needs is
  the deployment's business, which `./wb.sh up` settles, and a run that
  could only work after a `bake` was a poor thing to hang on an insert.
  `./wb.sh mix cover` remains the other way.

## v0.4.2 - (2026-09-22)

### Added

- **The report's door says how it is made.** The box's `console/0`
  door now carries `build:` — `mix cover` where *this box* went in with
  `--exdoc`, which is what plants that task (`when: {:option, :exdoc}`,
  read off `state/1`, not off whether the exdoc cartridge is in, which
  says nothing about that file), and ExCoveralls' own
  `mix coveralls.html` otherwise — so the console can offer it where
  `cover/` is empty, and runs the project's own command instead of one
  of its making. Both run in the test env without being told: `cli/0`'s
  `preferred_envs`, which this box writes, says so.

## v0.4.1 - (2026-09-22)

### Fixed

- **`--minimum-coverage` takes a whole percentage from 0 to 100, and
  refuses anything else** before a file is written — declared as the
  option's shape (`formats: [minimum_coverage: {:integer, 0..100}]`)
  and checked where every cartridge's options are. The value went into
  `coveralls.json` bare, so `abc` left a file excoveralls cannot parse
  and `101` a gate no suite passes. It is written as parsed: `080`
  lands as `80`.
- **`--interface` takes `rest` or `graphql`, and refuses anything
  else**, naming the two. Every value but `rest` meant `graphql`
  silently, so a typo dropped the `open_api` skip without a word.

## v0.4.0 - (2026-09-21)

### Changed

- **`--githook` builds on precommit, and no longer inserts it.** The
  option refuses while the precommit cartridge is not in, a second run
  included, and writes nothing. Inserted along, precommit came in
  coverage's own commit, with no insert of its own to eject, and
  coverage's eject left its hook in `.git/hooks` calling a runner that
  was gone. The console shows the switch unlit while precommit is not
  in, and precommit's eject waits until coverage's block is gone.

- **The box is named for the need: `coverage`, not `coveralls`.** The
  old name was the dependency's, and read like the coveralls.io service
  the box never talks to. The task is `workbench.install.coverage`, the
  blocks it owns in `test/test_helper.exs` and in the pre-commit hook
  are `# >>> coverage`, and exdoc's flag is `--coverage`. What it
  installs is unchanged: ExCoveralls, `coveralls.json` (still the mark)
  and `mix coveralls` are the library's names and stay. A project that
  took the box under its old name reads as carrying it; its blocks keep
  the owner `coveralls`, so a later `--githook` would add a second one.

### Updated

- **The report's templates live under `test/coverage/template/`**, not
  `assets/cover/template/`. `assets/` is a Phoenix application's
  release build input — `phx.gen.release`'s Dockerfile copies it into
  its builder, tailwind scans it — and the templates are a dev tool's
  source. `test/` is left out of the Dockerfile's context by the same
  generator's `.dockerignore`, and nothing compiles a loose `.eex`
  there: only `test/support` is compiled, and `mix test` loads
  `*_test.exs`. `state/1` reads the theme wherever the project's
  `coveralls.json` says the templates are, so a project that has them
  under `assets/` still says its theme back.
- **The report and the report page link each other by relative
  paths.** The `exdoc-ish` theme's sidebar (`/dev/docs`,
  `/dev/docs/testing.html`, `/dev/docs/cover`), the `custom` theme's
  *Back* link and `mix cover`'s links into the report (`./cover`) named
  the routes exdoc v0.1.0 planted in the project. exdoc copies the
  coverage output dir into the site's root, so the report sits beside
  `testing.html`: `index.html`, `testing.html` and `excoveralls.html`
  resolve wherever the site is served — by the console since exdoc
  v0.2.0, and under `/dev/docs` in a project that still carries v0.1.0.

## v0.3.0 - (2026-09-20)

### Added

- **`--githook`**: `mix coveralls` before every commit. The hook, the
  way it reaches `mix` inside the container and the checks that come
  with Elixir belong to the **precommit** cartridge, which this one
  composes when asked; what coverage adds is a block of
  `.githooks/pre-commit` belonging to this cartridge alone
  (`WorkbenchIgniter.BlockFile`), so credo's block and this one stand
  in the same file and either can be ejected without touching the
  other. Off by default, and the README says why: the suite with its
  instrumentation is the slowest thing a commit can wait for, and the
  place coverage is owed to a team is CI. The block is born **below the
  hook's divider**, after every check that can refuse a commit in a
  second: `mix coveralls` compiles the project and runs the suite
  instrumented, and nothing in the hook is slower.
- `state/1` says whether the line stands in the project's hook, and
  `DESIGN.md`, the paper the anatomy asks of a cartridge on its next
  change.

### Updated

- **A second run adds the hook block.** The insert was a no-op once
  `coveralls.json` existed, which turned `--githook` on a project that
  already had coveralls into a silent nothing: the flag was asked for
  and the notice said *skipping*. The json, the themes and the report
  are still fixed at the insert — they are the project's to edit
  afterwards — but the hook block is a piece the installer adds when it
  is missing, and the notice now says which of the two happened. The
  cartridge is `rerun: :adds`.

## v0.2.0 - (2026-09-20)

### Updated

- **The cover task's tests stand on Mimic, not Mock**, and run
  concurrently again. `Mix.Tasks.CoverTest` doubles `File.write!/2` to
  read the report it would have written; with `mock` that replacement
  was global to the VM, so the file was `use ExUnit.Case` without
  `async: true`. It is `use ExUnit.Case, async: true` and `use Mimic`
  now, five `with_mocks` blocks become five `stub(File, :write!, …)`
  calls, and the double lives in the process that asks for it.
- **It composes `test_doubles` with `--double mimic`** in place of
  `mock`, and registers `File` in **its own block** of
  `test/test_helper.exs` through `WorkbenchIgniter.BlockFile`, so
  another cartridge's copies can stand in the same file and either can
  be ejected without touching the other. `File` is nobody's module to
  declare a behaviour for, which is why this side of the box is Mimic's
  and not Mox's.

## v0.1.0 - (2026-08-30)

### Added

- ExCoveralls with the workbench's HTML report: the dependency, the
  `test_coverage` and `preferred_envs` entries in `mix.exs`, the
  `coveralls.json` (`--minimum-coverage`, and the paths left out of the
  report — `open_api` on `--interface graphql`, the components folder
  when the project has no html, read off the project), the report
  template of `--theme` (`exdoc-ish` | `custom`, one directory each
  under the cartridge's assets) and the `mix cover` task, which writes
  `TESTING.md` for the docs when exdoc is in.
- `--build`: runs the suite once the insert is applied, so the report
  has numbers before anyone opens it. Off by default and queued, not
  inline: `mix cover` needs the dependencies compiled and — on a
  project with Ecto, read off the project — a test database, which the
  queued `ecto.create`/`ecto.migrate` prepare and the workspace's
  compose must actually carry (`./wb.sh bake`). `afterwards/0` names
  the command for whoever leaves it off.
