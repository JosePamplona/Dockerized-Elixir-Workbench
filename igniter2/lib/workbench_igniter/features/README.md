# Feature cartridges

Each workbench feature is a *cartridge*: everything that defines it lives
in this folder. `workbench.setup` doesn't know features by name — it walks
the registry (`../features.ex`), which fixes the **composition order**:

1. Trivial dep group (`--enhance`): osmon → psql_extras → credo → mock → exdebug
2. Interface (`--interface`): [rest](rest/) | [graphql](graphql/)
3. [coveralls](coveralls/) (`--coveralls`)
4. [exdoc](exdoc/) (`--exdoc`)
5. [enhancements](enhancements/) (`--enhance`)
6. [auth0](auth0/) (`--auth0`, implied by openai/stripe)
7. [openai](openai/) (`--openai`)
8. [healthcheck](healthcheck/) (`--health`)
9. stripe (`--stripe`) — *pending*: manifest only, setup emits a notice

## Formats

**Directory cartridge** — features with templates or assets. Holds
`<feature>.ex` (manifest + logic), `task.ex` (mix task shell),
`templates/` (compile-time embedded), an optional `assets/` (verbatim,
embedded; `*.ex` files carry an `.asset` suffix so mix doesn't compile
them) and its own `README.md`. Its test:
`test/workbench_igniter/features/<feature>_test.exs`.

**Single-file cartridge** — features with no resources (dep-only):
manifest + logic + task shell in one `<feature>.ex`.

| File | Installs | Enabled by |
|---|---|---|
| `credo.ex` | `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` | `--enhance` |
| `mock.ex` | `{:mock, "~> 0.3", only: :test}` | `--enhance` (also composed by healthcheck, coveralls and enhancements) |
| `exdebug.ex` | `{:ex_debug, "~> 1.0"}` | `--enhance` |
| `psql_extras.ex` | `{:ecto_psql_extras, "~> 0.8", only: :dev}` | `--enhance` |
| `osmon.ex` | `:os_mon` in `extra_applications` (no dep) | `--enhance` |
| `githooks.ex` | `{:git_hooks, "~> 0.7", only: :dev, runtime: false}` | manual (`wb.sh add githooks`) |
| `exmachina.ex` | `{:ex_machina, "~> 2.8", only: :test}` | manual (`wb.sh add exmachina`) |
| `stripe.ex` | — (pending; implies `--auth0`) | `--stripe` |

What each one brings, in short:

* **credo** — an automated reviewer that flags style and code-quality
  issues before they reach production.
* **mock** — lets tests simulate external pieces (APIs, services) without
  depending on the real thing.
* **exdebug** — utilities to inspect values comfortably while developing.
* **psql_extras** — ready-made queries to diagnose database health
  (unused indexes, slow queries, locks).
* **osmon** — machine resource monitoring (CPU, memory, disk) visible from
  the dashboard.
* **githooks** — automates checks before each commit, so problematic code
  doesn't even reach the repository.
* **exmachina** — test data factories: realistic sample records in one
  line.
* **stripe** — payments and subscriptions with Stripe (not ported yet).

The trivial group's tests are the parameterized suite
`test/workbench_igniter/features/deps_test.exs` (plus `osmon_test.exs`).

## The manifest (`WorkbenchIgniter.Feature` behaviour)

* `task/0` - installer mix task name (public interface).
* `flag/0` / `enabled?/1` - when the setup options turn it on.
* `implies/0` - flags it forces on when enabled.
* `argv/1` - arguments setup forwards when composing the task.
* `pending?/0` - documented but not ported yet.

Adding a feature = creating its cartridge here and adding it to the
`WorkbenchIgniter.Features` list at the right position in the order.
