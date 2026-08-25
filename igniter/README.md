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
│   │   ├── 📄 features.ex                           # registry (composition order)
│   │   └── 📁 features/                             # one directory per cartridge, each with its README:
│   │       ├── 📦 healthcheck/                      #   the reference cartridge
│   │       │   ├── 📄 README.md                     #   what it installs, options, contents
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
│   │       └── 📦 stripe/                           # pending manifest (installer not ported)
│   └── 📁 mix/tasks/
│       ├── 📄 workbench.setup.ex                    # umbrella task: configure_files + Features.compose/2
│       ├── 📄 workbench.setup2.ex                   # vanilla setup: only what the workspace needs to boot
│       └── 📄 workbench.plant_asset.ex              # after-apply byte-for-byte copy of binary assets
├── 📁 priv/
│   ├── 📁 setup/templates/                          # setup tasks templates (README, .env, …)
│   └── 📁 features/<feature>/                       # mirror of lib/…/features/<feature>/ for binary
│       └── 📁 exdoc/images/                         #   assets (priv_asset/1, plant_binary_asset/3)
└── 📁 test/
    └── 📁 workbench_igniter/
        ├── 📄 setup_test.exs
        ├── 📄 setup2_test.exs
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
  - `install/1` — the installer's `igniter/1` body.
  - Ordering constraints are documented in the `@moduledoc`; the actual
    order is the `WorkbenchIgniter.Features` registry list.
- **`task.ex`** — a `Mix.Tasks.Workbench.Install.<Feature>` shell (~15
  lines) delegating `info/2` and `igniter/1` to the feature module. Elixir
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

Dep-only cartridges (credo, mock, …) keep the same shape minus
`templates/` and `assets/`: README, `<feature>.ex` and `task.ex`.

Every feature is in cartridge form; `lib/mix/tasks/` only keeps the two
setup tasks and the `workbench.plant_asset` plumbing.

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
      composition position; declare `flag`/`enabled?`, `implies` and
      `argv` as needed.
- [ ] Idempotency guard if it touches the router or any other
      non-idempotent edit (`module_exists` + `add_notice`; see
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
