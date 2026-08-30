# WorkbenchIgniter

Port of the `app.sh` script features to
[Igniter](https://hexdocs.pm/igniter) tasks, which patch the target
project semantically (AST-based) instead of with `sed`. The only feature
documented but not ported yet is stripe (see
`lib/workbench_igniter/features/stripe/`); the migration history from
the legacy `app.sh` and the earlier package editions lives in the git log.

## Structure

```text
📁 igniter/
├── 📄 mix.exs                                       # :workbench_igniter package
├── 📁 lib/
│   ├── 📄 workbench_igniter.ex                      # priv/ template/asset helpers
│   ├── 📁 workbench_igniter/
│   │   ├── 📄 feature.ex                            # Feature behaviour + embed_templates/embed_assets
│   │   ├── 📄 phx_delta.ex                          # a phx.new capability added after the fact, as the difference between two generations
│   │   ├── 📄 features.ex                           # registry: composition order, the standalone ones, the catalog
│   │   └── 📁 features/                             # one directory per cartridge, each with its README:
│   │       ├── 📦 healthcheck/                      #   the reference cartridge
│   │       │   ├── 📄 README.md                     #   what it installs, options, contents
│   │       │   ├── 📄 CHANGELOG.md                  #   the cartridge's own version history
│   │       │   ├── 📄 DESIGN.md                     #   why it is shaped like this, with sources
│   │       │   ├── 📄 healthcheck.ex                #   manifest + install logic
│   │       │   ├── 📄 task.ex                       #   Mix.Tasks.Workbench.Install.Healthcheck shell
│   │       │   └── 📄 templates/*.eex               #   compile-time embedded templates
│   │       ├── 📦 rest/                             # same (6 templates)
│   │       ├── 📦 graphql/                          # same (2 templates)
│   │       ├── 📦 auth0/                            # same (14 templates)
│   │       ├── 📦 openai/                           # same (13 templates)
│   │       ├── 📦 enhancements/                     # same (16 templates), + verbatim assets/
│   │       │   └── 📁 assets/{db_schema, postman}/  #   DbSchema diagrams and Postman collections
│   │       ├── 📦 coveralls/                        # same, + embedded verbatim assets/
│   │       │   └── 📁 assets/{cover.ex.asset, ...}  #   .asset suffix: mix won't compile them
│   │       ├── 📦 exdoc/                            # same, + text assets/; the binary PNG logo
│   │       │                                        #   lives in priv/features/exdoc/
│   │       ├── 📦 credo/, mock/, osmon/, ...        # dep-only cartridges: README + <f>.ex + task.ex
│   │       ├── 📦 githooks/, exmachina/             # standalone cartridges (setup never composes them)
│   │       ├── 📦 clustering/                       #   standalone too: rel/*.eex + distributed exports
│   │       ├── 📦 healthcheck2/                     #   standalone too: liveness/readiness plug, mounted first
│   │       ├── 📦 mailer/                           #   a base cartridge: phx.new's --no-mailer, undone through phx_delta
│   │       ├── 📦 ash/                              #   standalone too: queues the mix igniter.install of ash-hq.org
│   │       └── 📦 stripe/                           # pending manifest (installer not ported)
│   └── 📁 mix/tasks/
│       ├── 📄 workbench.setup.ex                    # umbrella task: configure_files + Features.compose/2
│       ├── 📄 workbench.setup2.ex                   # vanilla setup: only what the workspace needs to boot
│       ├── 📄 workbench.catalog.ex                  # every cartridge's manifest, as a table or JSON
│       ├── 📄 workbench.status.ex                   # the catalog plus what this project carries
│       └── 📄 workbench.plant_asset.ex              # after-apply byte-for-byte copy of binary assets
├── 📁 priv/
│   ├── 📁 setup/templates/                          # setup tasks templates (README, .env, …)
│   └── 📁 features/<feature>/                       # mirror of lib/…/features/<feature>/ for binary
│       └── 📁 exdoc/images/                         #   assets (priv_asset/1, plant_binary_asset/3)
└── 📁 test/
    └── 📁 workbench_igniter/
        ├── 📄 setup_test.exs
        ├── 📄 setup2_test.exs
        ├── 📄 catalog_test.exs                      # the registry, the catalog, installed?/1 of every cartridge
        └── 📄 features/<feature>_test.exs           # one test per cartridge
```

Package modules use the `WorkbenchIgniter` prefix; the Mix tasks keep the
short `workbench.*` namespace as the command-line interface.

## Anatomy of a cartridge

Each feature is a *cartridge*: a folder under
`lib/workbench_igniter/features/<feature>/` that self-contains everything
defining it, so reviewing the folder equals knowing its full
functionality. Every cartridge — dep-only ones included — is a directory
with its own `README.md` explaining what it installs, how it is enabled
and the role of each file; the general index is
[`lib/workbench_igniter/features/README.md`](lib/workbench_igniter/features/README.md).
`healthcheck/` is the reference:

- **`<feature>.ex`** — a `WorkbenchIgniter.Features.<Feature>` module with
  `use WorkbenchIgniter.Feature`. It gathers the *manifest* (what used to
  be spread across `workbench.setup.ex`) and the install logic:
  - `task/0` — installer mix task name (public interface, never changes).
  - `flag/0` / `enabled?/1` — when the setup options turn it on.
  - `implies/0` — flags it forces (e.g. `openai` ⇒ `auth0`).
  - `argv/1` — arguments setup forwards when composing it.
  - `pending?/0` — documented but not ported yet (setup emits a notice).
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
  - `enabled_by/0` — what turns the feature on under setup, when it is
    not its own flag: `:enhance` for the trivial group, `{:interface,
    "rest"}` for the interfaces. Defaults to `flag/0`.
  - `rerun/0` and `state/1` — what a second run does (`:noop`, or
    `:adds` for a cartridge whose options are independent pieces, like
    ash's packages) and, for the latter, what the project already
    carries of them, read off the project.
  - `name/0`, `version/0`, `summary/0` — derived, not declared: the
    cartridge directory, the first entry of its `CHANGELOG.md`, and its
    task's `@shortdoc`. They are what the catalog prints.
  - `install/1` — the installer's `igniter/1` body.
  - Ordering constraints are documented in the `@moduledoc`; the actual
    order is the `WorkbenchIgniter.Features` registry list.
- **`task.ex`** — a `Mix.Tasks.Workbench.Install.<Feature>` shell (~15
  lines) delegating `info/2` and `igniter/1` to the feature module, and
  rendering its "## Options" from the module's `option_docs/0`. Elixir
  doesn't require Mix tasks to live in `lib/mix/tasks/`: only the module
  name matters, so the task lives inside the cartridge.
- **`templates/*.eex`** — templates embedded at compile time by
  `embed_templates()` (each one is an `@external_resource`: editing it
  recompiles). Rendered through the module's local `template/2`, with the
  same semantics as `WorkbenchIgniter.template/2`.
- **`assets/`** — files the feature copies verbatim (no rendering):
  `embed_assets()` embeds them as a local `asset/1` (see coveralls).
  Careful: a `*.ex` asset would be compiled by mix along with the package
  — it is stored with an extra `.asset` suffix (`cover.ex.asset`) and the
  macro strips it from the key.
- **`priv/features/<feature>/`** — the cartridge's mirror under `priv/`
  for binary assets that must stay out of the compiled module (the exdoc
  logo). Read at runtime
  with the local `priv_asset/1`, or planted byte-for-byte after the patch
  set is applied with `plant_binary_asset/3` (binaries must never go
  through the igniter rewrite pipeline, which normalizes trailing bytes).
  Both helpers derive the feature name from the cartridge directory.
- **test** — at `test/workbench_igniter/features/<feature>_test.exs`,
  exercising the task by name with `Igniter.Test`.
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
  backfill rule as the changelog; `healthcheck2/DESIGN.md` is the
  reference, and the criteria for writing one are in the features
  index, under *Writing a DESIGN.md*.

Dep-only cartridges (credo, mock, …) keep the same shape minus
`templates/` and `assets/`: README, `<feature>.ex` and `task.ex`.

Every feature is in cartridge form; `lib/mix/tasks/` only keeps the two
setup tasks, the two query tasks (`workbench.catalog`, `workbench.status`)
and the `workbench.plant_asset` plumbing.

## The catalog

The registry knows every cartridge: `WorkbenchIgniter.Features.all/0`
is the composition list, `standalone/0` the ones no setup composes
(githooks, exmachina, clustering, healthcheck2, ash), `catalog/0` both. Two
tasks read it, for tools as much as for people — `wb.sh catalog` and
`wb.sh status` are their front:

```sh
mix workbench.catalog [--json] [--covers DIR]  # every cartridge's manifest: name, version,
                                               # summary, flag, implies, installer options
mix workbench.status  [--json]                 # the same, plus 'installed' for this project
```

`status` asks each cartridge (`installed?/1`); nothing is compiled or
written. With `--covers`, the catalog also says which sealed box covers
exist under that directory, so whatever draws a shelf of cartridges
reads one JSON and not two trees.

## The two setups

| | `workbench.setup` | `workbench.setup2` |
| --- | --- | --- |
| Driven by | all of `config.conf` | nothing |
| Options | 27 | 6 |
| `composes:` | the 13 ported cartridges | `[]` |
| `config/dev.exs` `ip: {0,0,0,0}` | ✅ | ✅ |
| `.env` / `.env.sample` | ✅ | ✅ |
| `.gitignore` `.env` | ✅ | ✅ |
| `.gitignore` `/.elixir_ls/` | ✅ | ❌ |
| `mix.exs` initial version | ✅ | ❌ |
| ANSI colors, `:utc_datetime_usec`, migration types | ✅ | ❌ |
| `dev_routes: true` in test | ✅ | ❌ |
| `README.md`, `CHANGELOG.md`, `.tool-versions` | ✅ | ❌ |
| Feature installers | ✅ | ❌ |
| `mix release.init` (from the entrypoint) | ✅ | ❌ — see [clustering](lib/workbench_igniter/features/clustering/) |

`workbench.setup2` is the vanilla edition: a stock `phx.new` project plus
*only* what the dockerized workspace requires to boot it. The endpoint
must bind `0.0.0.0` because the compose pod pattern
(`network_mode: "service:network"`) delivers the published port on the
namespace interface and never on loopback; `.env` must exist because the
workspace compose declares `env_file: ./.env`. Everything else is a
workbench opinion, and is left to the `add` command.

`./wb.sh new2` is the command that drives it, and it is the base for the
ongoing restructuring of this package.

Note: `workbench.setup` declares `--db-port` and documents it as part of
`DATABASE_URL`, but never reads it — the `ecto://` URL it builds carries
no port. `workbench.setup2` does use it. With the default `5432` both
produce an equivalent URL, so this is a divergence to settle when the
restructuring reaches the setup options, not a bug to chase now.

## Adding a feature (checklist)

- [ ] Create the cartridge directory under
      `lib/workbench_igniter/features/<feature>/`: feature module with
      `use WorkbenchIgniter.Feature` (manifest + `info/2` + `install/1`)
      in `<feature>.ex` and the `Mix.Tasks.Workbench.Install.<Feature>`
      shell in `task.ex`.
- [ ] Register it in the `WorkbenchIgniter.Features` list at the right
      composition position — or in its `@standalone` list when no setup
      flag drives it; declare `flag`/`enabled?`, `implies` and
      `argv` as needed.
- [ ] `installed?/1`, off one mark; and the idempotency guard reads
      that same function if it touches the router or any other
      non-idempotent edit (`installed?` + `add_notice`; see
      healthcheck).
- [ ] Templates as EEx module *bodies* in `templates/`
      (`embed_templates()`); verbatim files in `assets/`
      (`embed_assets()`, `.asset` suffix for `*.ex` files); binary
      assets in the `priv/features/<feature>/` mirror.
- [ ] Register `dont_move_file_pattern` for files outside the
      module-name → path convention (e.g. `controllers/`,
      `test/support/fixtures/`).
- [ ] Tests with `Igniter.Test.phx_test_project()`: creation, patches,
      idempotency (apply twice ⇒ `assert_unchanged`). Add the cartridge's
      `README.md`.
- [ ] Manual validation: `./wb.sh new` with the feature enabled in
      `config.conf`.

Possible future step: moving the package to its own git repo, so projects
that already ran `remove-workbench` can keep installing features via
`{:workbench_igniter, git: "..."}`.

## Usage

With `wb.sh` there is nothing to configure: the `new` command injects into
the generated `mix.exs` a conditional dep pointing at the workbench
mounted at `/app/workbench` (the `workbench_dep/0` function). To use the
package by hand in any project:

```elixir
{:workbench_igniter, path: "path/to/workbench/igniter", only: [:dev, :test], runtime: false}
```

and then, to configure a freshly generated project (equivalent to app.sh's
`configure_files` + `config.conf`):

```sh
mix workbench.setup --project-name "Lorem Ipsum" \
  --enhance --health --id-type uuid --timestamps naive_datetime_usec --yes
```

or, for a vanilla project that only has to run inside the workspace:

```sh
mix workbench.setup2 --yes
```

or individual installers:

```sh
mix workbench.install.healthcheck          # shows the diff and asks for confirmation
mix workbench.install.healthcheck --yes    # applies directly (for Docker/CI use)
mix workbench.install.healthcheck --endpoint /status   # configurable route
```

The task performs, in a single atomic patch set:

| Change | Igniter API | app.sh equivalent |
| --- | --- | --- |
| Adds `{:mock, "~> 0.3", only: :test}` | `Igniter.Project.Deps.add_dep/3` | `mix_insert` |
| `dev_routes: true` in `config/test.exs` | `Igniter.Project.Config.configure/5` | `adjust_config_test` |
| Creates `MyAppWeb.HealthcheckController` | `Igniter.Project.Module.create_module/4` | `cp seed + sed placeholders` |
| Creates the controller test | `Igniter.Project.Module.create_module/4` | `unit_testing` |
| Router scope | `Igniter.Libs.Phoenix.add_scope/4` | `router_add_scope` |

The module name, web module and app name are **derived from the target
project** (`app_name/1`, `web_module/1`, `module_name_prefix/1`): there
are no `%{elixir_module}` placeholders injected from outside.

## Idempotency

Running a task twice is a no-op: if `MyAppWeb.HealthcheckController`
already exists, the task emits a notice and touches nothing. This allows
installing features on existing projects, not just freshly generated ones.

## Tests

```sh
mix test
```

Tests use `Igniter.Test`: each case runs against a simulated **in-memory**
Phoenix project (`phx_test_project/0`, requires the `:phx_new` test dep) —
no disk writes, no database, no real project generation. They verify file
creation at Phoenix's conventional paths, the patches on
router/config/mix.exs, and idempotency (applying twice ⇒ no changes + a
notice).

## Lessons learned (for future features)

- **Igniter relocates new modules** to the path derived from their name
  (`module_location: :outside_matching_folder`), which breaks Phoenix's
  `controllers/` convention. The fix is registering the pattern in the
  target project's `.igniter.exs` with
  `Igniter.Project.IgniterConfig.dont_move_file_pattern/2` (the task
  already does; the generated `.igniter.exs` must be committed).
- **`add_scope` is not idempotent** (it always appends). Any installer
  touching the router needs its own guard — here, the controller's
  existence via `Igniter.Project.Module.module_exists/2`.
- EEx templates are the module *body*: `create_module/4` adds the outer
  `defmodule` and the target project's formatter normalizes indentation.

## Validated with

Elixir 1.19.5 / OTP 27, Phoenix 1.8.9, Igniter 0.8.3. Besides the test
suite, it was validated end-to-end against a real project generated with
`mix phx.new demo --no-assets --no-mailer --no-dashboard`: install
applied, re-run no-op, clean `mix compile` and the 5 generated tests
green.
