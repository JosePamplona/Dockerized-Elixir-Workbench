# Feature cartridges

Each workbench feature is a *cartridge*: everything that defines it lives
in this folder. `workbench.setup` doesn't know features by name — it walks
the registry (`../features.ex`), which fixes the **composition order**:

1. Trivial dep group (`--enhance`): [osmon](osmon/) → [psql_extras](psql_extras/) → [credo](credo/) → [mock](mock/) → [exdebug](exdebug/)
2. Interface (`--interface`): [rest](rest/) | [graphql](graphql/)
3. [coveralls](coveralls/) (`--coveralls`)
4. [exdoc](exdoc/) (`--exdoc`)
5. [enhancements](enhancements/) (`--enhance`)
6. [auth0](auth0/) (`--auth0`, implied by openai/stripe)
7. [openai](openai/) (`--openai`)
8. [healthcheck](healthcheck/) (`--health`)
9. [stripe](stripe/) (`--stripe`) — *pending*: manifest only, setup emits a notice

## Anatomy

Every cartridge is a directory `features/<feature>/` holding:

* `<feature>.ex` — manifest (`WorkbenchIgniter.Feature`) + install logic.
* `task.ex` — the `Mix.Tasks.Workbench.Install.<Feature>` shell.
* `README.md` — what it installs, options, contents.
The cartridge directory holds only code. Everything that is not code
lives under `priv/features/<feature>/` (never compiled, so files keep
their final names — `cover.ex`, not `cover.ex.asset`):

* `priv/features/<feature>/templates/` — EEx templates, embedded at
  compile time (`embed_templates`).
* `priv/features/<feature>/assets/` — text files copied verbatim,
  embedded at compile time (`embed_assets`).
* Binaries (e.g. `images/`) — read at runtime with `priv_asset/1`
  (`WorkbenchIgniter.feature_asset/2`) or planted byte-for-byte with
  `plant_binary_asset/3`.

Cartridge test: `test/workbench_igniter/features/<feature>_test.exs` —
one per cartridge, mirroring the directory.

Dep-only cartridges have no `priv/features/<feature>/` directory:

| Cartridge | Installs | Enabled by |
| --- | --- | --- |
| [credo](credo/) | `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` | `--enhance` |
| [mock](mock/) | `{:mock, "~> 0.3", only: :test}` | `--enhance` (also composed by healthcheck, coveralls and enhancements) |
| [exdebug](exdebug/) | `{:ex_debug, "~> 1.0"}` | `--enhance` |
| [psql_extras](psql_extras/) | `{:ecto_psql_extras, "~> 0.8", only: :dev}` | `--enhance` |
| [osmon](osmon/) | `:os_mon` in `extra_applications` (no dep) | `--enhance` |
| [githooks](githooks/) | `{:git_hooks, "~> 0.7", only: :dev, runtime: false}` | manual (`wb.sh add githooks`) |
| [exmachina](exmachina/) | `{:ex_machina, "~> 2.8", only: :test}` | manual (`wb.sh add exmachina`) |
| [stripe](stripe/) | — (pending; implies `--auth0`) | `--stripe` |

Each cartridge README explains what it brings (mock's carries the pending
migration to Mox).

[clustering](clustering/) is standalone too, and adds no dependency: it
writes the `rel/*.eex` release templates with the distributed-node
exports DNSCluster needs, plus `DNS_CLUSTER_QUERY` in the environment
files. Installed by hand with `wb.sh add clustering`.

Box cover art for the cartridges — the fixed elements, the per-cartridge
slots and the prompt template — is in [COVERS.md](COVERS.md).

## The manifest (`WorkbenchIgniter.Feature` behaviour)

* `task/0` - installer mix task name (public interface).
* `flag/0` / `enabled?/1` - when the setup options turn it on.
* `implies/0` - flags it forces on when enabled.
* `argv/1` - arguments setup forwards when composing the task.
* `pending?/0` - documented but not ported yet.

Adding a feature = creating its cartridge here and adding it to the
`WorkbenchIgniter.Features` list at the right position in the order.
