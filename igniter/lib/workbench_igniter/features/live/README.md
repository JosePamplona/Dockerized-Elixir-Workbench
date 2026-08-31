# live

Phoenix's live for a project generated with `--no-live`.

LiveView is "included by default in Phoenix applications"
([installation](https://hexdocs.pm/phoenix_live_view/welcome.html)),
and `--no-live` is the one `phx.new` flag that removes no dependency:
`mix help phx.new` says it will "comment out LiveView socket setup in
your Endpoint and assets/js/app.js" — the `LiveSocket` lines are
written with `// ` in front — and drop LiveView's own configuration
and the `JS` commands of the core components. The dependency and its
compiler stay, because html brings them. LiveView's docs carry no
recipe for adding it to an existing project any more; this cartridge
is that recipe, at the project's Phoenix.

Base cartridge. Install it on demand with

```sh
./wb.sh add live
mix workbench.install.live
```

## What it installs

Whatever `phx.new` generates for it at the installer's version in the
toolchain — asked of `phx.new` itself (`WorkbenchIgniter.PhxDelta`, see
[mailer](../mailer/) for the mechanism). With Phoenix 1.8.12: `config :phoenix_live_view` (the root tag
attribute, for colocated CSS), the `LiveSocket` lines of
`assets/js/app.js` (the socket, topbar on navigation, the colocated
hooks — with `--no-live` phx.new writes them commented out), `alias
Phoenix.LiveView.JS` and the JS commands (`show`/`hide`) of the core
components, `phx-click` on the layouts' theme toggle, and the LiveView
section of `AGENTS.md`. The `phoenix_live_view` dependency is there
either way, and the endpoint's `/live` socket is on with the dashboard
too: what only live brings is its configuration, and that is the
cartridge's mark.

It builds on [html](../html/): `phx.new` generates live only with html,
and the cartridge refuses on a `--no-html` project, naming it (`./wb.sh
add html` first). The catalog carries it as `requires`.

The client side needs [esbuild](../esbuild/): the `LiveSocket` lives
in `assets/js/app.js`, which exists only with a bundler, and
`phx.new`'s static placeholder for a project without one is a
comment. On such a project live configures and serves LiveView and
nothing in the browser connects to it until esbuild is in — the same
as `phx.new --no-esbuild` with live; the insert says so in a notice.

Files the project already changed are merged three ways; a conflict is
reported with `phx.new`'s version of the file beside it.

## Options

None. `phx.new` has none for it.

## Idempotency

Re-running is a no-op: when `config :phoenix_live_view` in `config/config.exs` is there — a default project carries
it — nothing is touched and a notice says so.

## Contents

| File | Role |
| --- | --- |
| `live.ex` | Manifest + logic: the flag, the mark, what it builds on |
| `task.ex` | `Mix.Tasks.Workbench.Install.Live` shell |
| `CHANGELOG.md` | The cartridge's own version history |
| `DESIGN.md` | Why the mark is a config line and why it requires html, with sources; the engine is in [mailer's](../mailer/DESIGN.md) |

Cartridge test: `test/workbench_igniter/features/base_cartridges_test.exs`.
