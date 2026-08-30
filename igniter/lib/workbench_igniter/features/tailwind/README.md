# tailwind

Phoenix's tailwind for a project generated with `--no-tailwind`.

Phoenix styles its generated markup with Tailwind CSS: the
[tailwind](https://hexdocs.pm/tailwind/) package downloads the
stand-alone CLI and runs it from a profile in `config.exs`
(`assets/css/app.css` in, `priv/static/assets/css/app.css` out), a
watcher rebuilds it in development, and the `assets.*` aliases drive
it. Heroicons come "embedded as CSS classes, ensuring only used icons
reach clients via Tailwind's tree-shaking", and daisyUI as a plugin
([asset management](https://hexdocs.pm/phoenix/asset_management.html)).
`mix help phx.new` on the flag: "The generated markup will still
include Tailwind CSS classes, those are left-in as reference" — so a
`--no-tailwind` project has a layout written for Tailwind, styled by a
static `default.css` snapshot.

Standalone, base cartridge. Install it on demand with

```sh
./wb.sh add tailwind
mix workbench.install.tailwind
```

## What it installs

Whatever `phx.new` generates for it at the installer's version in the
toolchain — asked of `phx.new` itself (`WorkbenchIgniter.PhxDelta`, see
[mailer](../mailer/) for the mechanism). With Phoenix 1.8.12: `{:tailwind, "~> 0.5"}` with the `heroicons` and
`daisyui` git dependencies, `config :tailwind` (the version and the
`test` profile: `css/app.css` to `priv/static/assets/css/app.css`), the
tailwind watcher in `dev.exs`, `tailwind test` in the
`assets.setup`/`assets.build`/`assets.deploy` aliases,
`assets/css/app.css` and `assets/vendor/heroicons.js`, and the
Tailwind classes of the root layout and the home page (without it
phx.new ships a plain stylesheet).

Files the project already changed are merged three ways; a conflict is
reported with `phx.new`'s version of the file beside it.

What the build needs: `phx.new`'s `app.css` imports
`phoenix-colocated/<app>/colocated.css`, a directory LiveView's
compiler writes — and that compiler comes with [html](../html/). The
insert succeeds on any project and says so in a notice when html is
out; `mix assets.build` fails with "Can't resolve
'phoenix-colocated/…'" until html is in. What goes: `--no-tailwind`
put `priv/static/assets/css/app.css` and the 80 kB
`priv/static/assets/default.css` in the project; the insert takes
them away when they are still `phx.new`'s, and keeps a file the
project rewrote (the root layout no longer links `default.css` either
way).

## Options

None. `phx.new` has none for it.

## Idempotency

Re-running is a no-op: when the `tailwind` dependency is there — a default project carries
it — nothing is touched and a notice says so.

## Contents

| File | Role |
| --- | --- |
| `tailwind.ex` | Manifest + logic: the flag, the mark |
| `task.ex` | `Mix.Tasks.Workbench.Install.Tailwind` shell |
| `CHANGELOG.md` | The cartridge's own version history |
| `DESIGN.md` | Why it is shaped like this, with sources; the engine is in [mailer's](../mailer/DESIGN.md) |

Cartridge test: `test/workbench_igniter/features/base_cartridges_test.exs`.
