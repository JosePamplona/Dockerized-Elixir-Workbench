# WorkbenchIgniter

The workbench's features as *cartridges*:
[Igniter](https://hexdocs.pm/igniter) installers that patch the target
project semantically (AST-based) instead of with `sed`, each one with
the papers that explain it. The package also carries the Mix tasks the
rest of the workbench reads: the catalog, the status, the compose
files. It began as a port of the legacy `app.sh` script; that history
lives in the git log.

Eight cartridges are *pending*, with no installer yet: specdd is
designed, and stripe, security_review, machine_learning, seo_aeo,
browser_tests, message_broker and event_stream are identified, their
need written and their design still to do. The index of every
cartridge is
[`lib/workbench_igniter/features/README.md`](lib/workbench_igniter/features/README.md).

## Structure

```text
📁 igniter/
├── 📄 mix.exs                                       # :workbench_igniter package
├── 📁 lib/
│   ├── 📄 workbench_igniter.ex                      # priv/ template/asset helpers
│   ├── 📁 workbench_igniter/
│   │   ├── 📄 feature.ex                            # Feature behaviour + embed_templates/embed_assets
│   │   ├── 📄 features.ex                           # registry: every cartridge, in shelf order — the catalog
│   │   ├── 📄 task.ex                               # what every installer's Mix task is: Igniter's, failing on an issue
│   │   ├── 📄 phx_delta.ex                          # a phx.new capability added after the fact, as the difference between two generations
│   │   ├── 📄 birth.ex                              # how the project was made, read off its first commit
│   │   ├── 📄 compose.ex                            # the workspace's compose files, rendered from a plan
│   │   ├── 📄 deployments.ex                        # the three compose files as they stand, and whether each is still current
│   │   ├── 📄 mix_file.ex, compose_file.ex,         # one module per project file: everything that reads
│   │   │      env_file.ex, ignore_file.ex,          #   or writes that file lives in it
│   │   │      dockerfile.ex, router_file.ex,
│   │   │      block_file.ex, text_file.ex
│   │   └── 📁 features/                             # one directory per cartridge:
│   │       ├── 📦 health_probe/                     #   the reference cartridge
│   │       │   ├── 📄 README.md                     #   what it installs, options, contents
│   │       │   ├── 📄 NEED.md                       #   the need it answers
│   │       │   ├── 📄 DESIGN.md                     #   why it is shaped like this, with sources
│   │       │   ├── 📄 CHANGELOG.md                  #   the cartridge's own version history
│   │       │   ├── 📄 health_probe.ex               #   manifest + install logic
│   │       │   └── 📄 task.ex                       #   Mix.Tasks.Workbench.Install.HealthProbe shell
│   │       ├── 📦 credo/, exdebug/, test_doubles/,  # dep-only cartridges: papers + <f>.ex + task.ex
│   │       │      dashboard_extras/, test_data/
│   │       ├── 📦 changelog/, version_manager/,     # one decision each, on a stock project
│   │       │      precommit/, coverage/, exdoc/
│   │       ├── 📦 clustering/                       # rel/*.eex + distributed exports
│   │       ├── 📦 ash/                              # queues the mix igniter.install of ash-hq.org
│   │       ├── 📦 db_admin/, k6/, monitoring/       # services of the workspace, declared for the compose
│   │       ├── 📦 mailer/, gettext/, ecto/,         # the base cartridges: phx.new's --no-* flags,
│   │       │      esbuild/, tailwind/, html/,       #   undone through phx_delta
│   │       │      dashboard/
│   │       ├── 📦 chiefs_setup/, ansi/, toolchain/, # archived: off the offer, their papers kept
│   │       │      mock/, rest/, graphql/, auth0/,
│   │       │      openai/, dbschema/, guidelines/,
│   │       │      enhancements/, health_endpoint/
│   │       ├── 📦 specdd/                           # pending, designed (DESIGN.md, priv/ files), installer not done
│   │       └── 📦 stripe/, security_review/,        # pending, identified: the need written (NEED.md), not designed yet
│   │              machine_learning/, seo_aeo/,
│   │              browser_tests/,
│   │              message_broker/, event_stream/
│   └── 📁 mix/tasks/
│       ├── 📄 workbench.setup.ex                    # vanilla setup: only what the workspace needs to boot
│       ├── 📄 workbench.catalog.ex                  # every cartridge's manifest, as a table or JSON
│       ├── 📄 workbench.status.ex                   # the catalog plus what this project carries
│       ├── 📄 workbench.expand.ex                   # a cartridge → the inserts wb.sh add runs (one commit each)
│       ├── 📄 workbench.dependents.ex               # which installed cartridges build on the named one
│       ├── 📄 workbench.compose.ex                  # writes one of the workspace's compose files
│       ├── 📄 workbench.serve.ex                    # answers the console's questions about this project, for as long as it is asked
│       ├── 📄 workbench.ejected.ex                  # takes away what an ejected cartridge left outside the tree
│       └── 📄 workbench.plant_asset.ex,             # internal plumbing, hidden from mix help
│              workbench.executable.ex,
│              workbench.igniter_install.ex
├── 📁 priv/
│   ├── 📁 setup/templates/                          # the setup task's .env template
│   ├── 📁 compose/                                  # the two topologies: pod.yml.eex, scaled.yml.eex
│   └── 📁 features/<feature>/                       # everything of a cartridge that is not code:
│       ├── 📁 templates/                            #   EEx templates, embedded at compile time
│       ├── 📁 assets/                               #   text files copied verbatim, embedded at compile time
│       ├── 📁 compose/                              #   the fragments of the services it brings
│       └── 📁 images/                               #   binaries, read or planted at runtime
└── 📁 test/
    ├── 📁 support/                                  # the golden compose files' script
    └── 📁 workbench_igniter/
        ├── 📄 catalog_test.exs                      # the registry, the catalog, installed?/1 of every cartridge
        ├── 📄 grown_vs_born_test.exs                # a project grown cartridge by cartridge is the project born whole
        ├── 📄 services_conformance_test.exs         # the promise every cartridge makes about its own services
        ├── 📄 compose_test.exs, phx_delta_test.exs, # one per module above
        │      mix_file_test.exs, …
        └── 📄 features/<feature>_test.exs           # one test per cartridge
```

Package modules use the `WorkbenchIgniter` prefix; the Mix tasks keep the
short `workbench.*` namespace as the command-line interface.

## Anatomy of a cartridge

Each feature is a *cartridge*: a folder under
`lib/workbench_igniter/features/<feature>/` that self-contains everything
defining it, so reviewing the folder equals knowing its full
functionality. Every cartridge — dep-only ones included — is a directory
with its own `README.md` explaining what it installs, how it is inserted
and the role of each file; the general index is
[`lib/workbench_igniter/features/README.md`](lib/workbench_igniter/features/README.md).
`health_probe/` is the reference:

- **`<feature>.ex`** — a `WorkbenchIgniter.Features.<Feature>` module with
  `use WorkbenchIgniter.Feature`. It gathers the *manifest* and the
  install logic:
  - `task/0` — installer mix task name (public interface, never changes).
  - `pending?/0` — documented, but its installer is not done yet.
  - `archived/0` — why it was retired, in one line opening with the
    date, or `nil` while it is current. The box stays on the shelf
    whole — its papers are the log of the reasoning that made it — and
    only stops being offered for a new project: `wb.sh add` refuses and
    names `--archived`, which inserts it anyway.
  - `members/1` — a collection's recipe: the cartridges its installer
    inserts, in order, with the argv each one gets (chiefs_setup, now
    archived, was the one collection). `[]`
    — the default — means a plain cartridge.
  - `requires/0` — the cartridges it builds on (db_admin on ecto): the
    installer refuses, naming them, until they are in.
  - `advises/0` — what a switch works fully only with, and why (html's
    `--live` with esbuild): never refused; the installer adds a notice
    while the project lacks it, and the console says it beside the
    switch, lit.
  - `origins/2` — where the packages its insert commit added came
    from, when it does not declare them: one note per origin, in its
    own words, given the options the insert went in with (ash: the
    `mix igniter.install` it ran, and what the installers of those
    packages added). A base cartridge's default says the `phx.new`
    delta; the console numbers the notes under the Packages table.
  - `installed?/1` — whether the target project already carries it,
    read off the *same mark the installer's guard reads* (a module, a
    file, a dependency), so `mix workbench.status` and a re-run of the
    installer can never disagree. `use WorkbenchIgniter.Feature` brings
    `dep_installed?/2`, `file_installed?/2` and `marker_installed?/3`
    for the common marks.
  - `choices/0` — the values an option takes, when the type (`:string`,
    `:csv`) does not say: a closed list, the same one the installer
    validates against; `{:open, list}` for suggestions; `{group,
    values}` pairs for sections. The catalog carries them so a form can
    draw radios and checkboxes instead of text fields (see ash).
  - `option_docs/0` — one line per option, keyed as the schema. The
    task shell's `@moduledoc` renders its "## Options" from it with
    `WorkbenchIgniter.Feature.options_doc/1`, so the docs and the
    catalog (and any form) read one text.
  - `rerun/0` and `state/1` — what a second run does (`:noop`, or
    `:adds` for a cartridge whose options are independent pieces, like
    ash's packages) and, for the latter, what the project already
    carries of them, read off the project.
  - `name/0`, `version/0`, `summary/0` — derived, not declared: the
    cartridge directory, the first entry of its `CHANGELOG.md`, and its
    task's `@shortdoc`. They are what the catalog prints.
  - `install/1` — the installer's `igniter/1` body.
  - Ordering constraints are documented in the `@moduledoc` and
    enforced by `requires/0`; inside a collection, the order is its
    `members/1` list.
- **`task.ex`** — a `Mix.Tasks.Workbench.Install.<Feature>` shell (~15
  lines) with `use WorkbenchIgniter.Task`, delegating `info/2` and
  `igniter/1` to the feature module, and rendering its "## Options"
  from the module's `option_docs/0`. Elixir doesn't require Mix tasks
  to live in `lib/mix/tasks/`: only the module name matters, so the
  task lives inside the cartridge. `WorkbenchIgniter.Task` is Igniter's
  task with one thing more: an issue ends it with a failure, so
  `wb.sh add` undoes a half-insert instead of committing it.
- **`priv/features/<feature>/`** — the cartridge directory holds only
  code and papers. Everything else lives in its mirror under `priv/`,
  never compiled, so a file keeps its final name (`cover.ex`):
  - `templates/*.eex` — embedded at compile time by `embed_templates()`
    (each one is an `@external_resource`: editing it recompiles).
    Rendered through the module's local `template/2`, with the same
    semantics as `WorkbenchIgniter.template/2`.
  - `assets/` — text files the feature copies verbatim (no rendering):
    `embed_assets()` embeds them as a local `asset/1` (see coverage).
  - `compose/` — the fragments of the services the cartridge declares
    (`compose/1`), for the workspace's compose files.
  - binaries (`images/`, the exdoc logo) — read at runtime with the
    local `priv_asset/1`, or planted byte-for-byte after the patch set
    is applied with `plant_binary_asset/3` (binaries must never go
    through the igniter rewrite pipeline, which normalizes trailing
    bytes). Both helpers derive the feature name from the cartridge
    directory.
- **test** — at `test/workbench_igniter/features/<feature>_test.exs`,
  exercising the task by name with `Igniter.Test`.
- **`NEED.md`** — the developer's need the cartridge answers: one
  sentence, then *Before*, *After* and *Not for*. The catalog reads the
  sentence off the file, and the catalog test refuses a cartridge
  without one.
- **`CHANGELOG.md`** — the cartridge's own version history, in the Keep
  a Changelog format, with semver applied to what it *installs*: a new
  file or route is a minor, anything that breaks a project already
  carrying the generated code (a renamed module, a moved route) is a
  major. It is independent of the workbench release that ships the
  cartridge. Cartridges older than this rule get theirs on their next
  change.
- **`DESIGN.md`** — the design rationale, paper-shaped: abstract,
  problem, background (with the platform and library documentation it
  rests on, quoted), each decision with the alternatives considered
  and why they lost, evaluation (what was verified, how, and what was
  *not* measured), limitations and open questions, numbered
  references. Where sources disagree it says so and takes a side. The
  README stays operational — what it installs, options, wiring — and
  links here for the why. A dep-only cartridge's is a page. Same
  backfill rule as the changelog; `health_probe/DESIGN.md` is the
  reference, and the criteria for writing one are in the features
  index, under *Writing a DESIGN.md*.

Dep-only cartridges (credo, exdebug, …) keep the same shape without a
`priv/features/<feature>/` directory: the papers, `<feature>.ex` and
`task.ex`.

Every feature is in cartridge form; `lib/mix/tasks/` only keeps the
tasks that are about the whole project and not one cartridge: the
setup, the two query tasks (`workbench.catalog`, `workbench.status`),
`workbench.expand` and `workbench.dependents`, the compose writer, the
console's `workbench.serve`, and the plumbing.

## The catalog

The registry knows every cartridge: `WorkbenchIgniter.Features.catalog/0`
is the one list, in shelf order, and `named/1` resolves the name
everything outside the package uses (`wb.sh add <name>`). Two tasks read
it, for tools as much as for people — `wb.sh catalog` and `wb.sh status`
are their front:

```sh
mix workbench.catalog [--json [--brief]] [--covers DIR]  # every cartridge's manifest: name, version,
                                                         # summary, collection members, installer options
mix workbench.status  [--json]                           # the same, plus 'installed' for this project
```

`status` asks each cartridge (`installed?/1`); nothing is compiled or
written. With `--covers`, the catalog also says which sealed box covers
exist under that directory, so whatever draws a shelf of cartridges
reads one JSON and not two trees.

## The setup, and the collection

`workbench.setup` is vanilla: a stock `phx.new` project plus *only* what
the dockerized workspace requires to boot it (two options,
`--internal-port` and `--ecto`; `composes: []`). The endpoint must bind `0.0.0.0` because the compose pod pattern
(`network_mode: "service:pod"`) delivers the published port on the
namespace interface and never on loopback; `.env` must exist because the
workspace compose declares `env_file: ./.env`. Everything else is a
workbench opinion, and is left to the `add` command. `./wb.sh new` is
the command that drives it.

The opinionated side lives on the shelf: the retired composing setup is
now the [chiefs_setup](lib/workbench_igniter/features/chiefs_setup/)
*collection* — a cartridge whose installer inserts the workbench's
picks. `mix workbench.expand` turns a cartridge into the inserts
`wb.sh add` runs (a collection: its missing members; a plain cartridge:
itself), so every inserted cartridge is one commit and `eject` reverts
one alone. chiefs_setup is archived with the line it collected
(2026-09-20), and is for now the only collection the shelf has had.

## Adding a feature (checklist)

- [ ] Create the cartridge directory under
      `lib/workbench_igniter/features/<feature>/`: feature module with
      `use WorkbenchIgniter.Feature` (manifest + `info/2` + `install/1`)
      in `<feature>.ex` and the `Mix.Tasks.Workbench.Install.<Feature>`
      shell in `task.ex`.
- [ ] Register it in the `WorkbenchIgniter.Features` list, in shelf
      order; declare `requires` when it builds on other cartridges, and
      name it in a collection's `members/1` if the collection should
      pick it.
- [ ] `installed?/1`, off one mark; and the idempotency guard reads
      that same function if it touches the router or any other
      non-idempotent edit (`installed?` + `add_notice`; see
      health_probe).
- [ ] Everything that is not code under `priv/features/<feature>/`:
      templates as EEx module *bodies* in `templates/`
      (`embed_templates()`), verbatim files in `assets/`
      (`embed_assets()`), the services' fragments in `compose/`,
      binaries beside them.
- [ ] Register `dont_move_file_pattern` for files outside the
      module-name → path convention (e.g. `controllers/`,
      `test/support/fixtures/`).
- [ ] Tests with `Igniter.Test.phx_test_project()`: creation, patches,
      idempotency (apply twice ⇒ `assert_unchanged`).
- [ ] The four papers beside the code, as the anatomy has them
      (`features/README.md`): `README.md`, `NEED.md` (the catalog test
      refuses a cartridge without one), `CHANGELOG.md` and `DESIGN.md`.
      The README's **Contents** is a table drawn as a *tree* of the
      cartridge's own files — its directory, its `priv/`, its test,
      each a root after an empty row, the branch in code in the first
      column with 📁 and 📄 and no-break spaces (U+00A0) for the
      indentation, the role on one line beside it. Copy the shape from
      [ecto](lib/workbench_igniter/features/ecto/README.md#contents);
      a flat two-column list of files is the pre-2026-09-19 shape and
      is not it.
- [ ] Manual validation: `./wb.sh new --name "…"`, then `./wb.sh add <feature>` on
      the created project.

Possible future step: moving the package to its own git repo. Today a
shelf of your own is a fork of the workbench; as a package of its own,
a project away from the workbench could keep installing cartridges via
`{:workbench_igniter, git: "..."}`.

## Usage

With `wb.sh` there is nothing to configure: the `new` command injects into
the generated `mix.exs` a conditional dep pointing at the workbench
mounted at `/app/workbench` (the `workbench_dep/0` function; it adds
nothing when the directory is not there). To use the package by hand in
any project:

```elixir
{:workbench_igniter, path: "path/to/workbench/igniter", only: [:dev, :test], runtime: false}
```

and then, to make a freshly generated vanilla project run inside the
workspace:

```sh
mix workbench.setup --yes
```

then the installers, one cartridge each:

```sh
mix workbench.install.health_probe            # shows the diff and asks for confirmation
mix workbench.install.health_probe --yes      # applies directly (for Docker/CI use)
mix workbench.install.health_probe --path /status   # configurable route prefix
```

The task performs, in a single atomic patch set:

| Change | Igniter API |
| --- | --- |
| Creates `MyAppWeb.Plugs.Health` | `Igniter.Project.Module.create_module/4` |
| Creates its test | `Igniter.Project.Module.create_module/4` |
| `plug MyAppWeb.Plugs.Health`, first in the endpoint | `Igniter.Project.Module.find_and_update_module!/3` + `Igniter.Code.Common.add_code/3` |

The module name, web module and app name are **derived from the target
project** (`app_name/1`, `web_module/1`, `module_name_prefix/1`): there
are no `%{elixir_module}` placeholders injected from outside.

## Idempotency

Running a task twice is a no-op: if `MyAppWeb.Plugs.Health` already
exists, the task emits a notice and touches nothing. The guard reads
`installed?/1`, the same function `mix workbench.status` asks, so the
two never disagree. This allows installing features on existing
projects, not just freshly generated ones.

## Tests

```sh
mix test
mix test --only exhaustive       # every order the base cartridges can go in: about an hour
mix test --only network:ash_hq   # the ash cartridge against ash-hq.org, live
```

Each cartridge's test uses `Igniter.Test`: every case runs against a
simulated **in-memory** Phoenix project (`phx_test_project/0`, requires
the `:phx_new` test dep) — no disk writes, no database, no real project
generation. They verify file creation at Phoenix's conventional paths,
the patches on router/config/mix.exs, and idempotency (applying twice ⇒
no changes + a notice).

Three suites stand over all of them. `catalog_test.exs` holds every
cartridge to its manifest: a need, a mark `installed?/1` reads, options
that are documented. `grown_vs_born_test.exs` grows a project born bare
one base cartridge at a time and compares it, file by file, with the
project born whole. The compose files are held, byte for byte, to a
golden corpus under `test/fixtures/compose/` (written by
`test/support/compose_golden.sh`), and
`services_conformance_test.exs` checks what each cartridge promises
about its own services.

## Lessons learned (for future features)

- **Igniter relocates new modules** to the path derived from their name
  (`module_location: :outside_matching_folder`), which breaks Phoenix's
  `controllers/` convention. The fix is registering the pattern in the
  target project's `.igniter.exs` with
  `Igniter.Project.IgniterConfig.dont_move_file_pattern/2` (the task
  already does; the generated `.igniter.exs` must be committed).
- **`add_scope` is not idempotent** (it always appends). Any installer
  touching the router needs its own guard: `installed?/1`, a notice,
  and nothing touched.
- **`Igniter.create_new_file(on_exists: :skip)` does not skip.** The
  same guard is the answer.
- EEx templates are the module *body*: `create_module/4` adds the outer
  `defmodule` and the target project's formatter normalizes indentation.

## Validated with

Elixir 1.19.5 / OTP 27, Phoenix 1.8.9, Igniter 0.8.3. Besides the test
suite, it was validated end-to-end against a real project generated with
`mix phx.new demo --no-assets --no-mailer --no-dashboard`: install
applied, re-run no-op, clean `mix compile` and the 5 generated tests
green.
