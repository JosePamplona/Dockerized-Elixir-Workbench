# Cartridge: mishka_chelekom

Ready-made components for Phoenix that are the project's own code:
cards, timelines, carousels, navbars, forms — function components
generated into the project, to use and to edit.

* **Task**: `mix workbench.install.mishka_chelekom`
* **Inserted by**: `wb.sh add mishka_chelekom`
* **Requires**: `html` with live, `tailwind`, `esbuild`.

## Description

[Mishka Chelekom](https://mishka.tools/chelekom) is a component
library that is not there at runtime. It is a development dependency
with a generator: it writes each component — HEEx, Tailwind utility
classes, a JavaScript hook where one is needed — into
`lib/<app>_web/components/`, and from then on the file is the
project's. Nothing of it runs in production but what it wrote.

It is an alternative to daisyUI, not a layer over it. daisyUI is a
Tailwind plugin of class names (`btn`, `card`), whose markup and
behaviour stay yours to write; Mishka's are components with attributes
(`<.button color="primary" variant="outline">`). Both stand on
Tailwind, and they can live in one project — with the one collision
*daisyUI beside it* names below.

Its functions take the names of Phoenix's own: `<.button>`, `<.input>`,
`<.table>` with `rows` and `:col`, `<.header>`, `<.list>`, `<.icon>`,
`<.flash>`. The library swaps its import for `CoreComponents`' in the
web module, so `Layouts` and what `phx.gen.live` writes draw Mishka's.

## What it installs

The cartridge adds `{:mishka_chelekom, "~> 0.0.9", only: :dev}` and
queues the library's own task, the one its installer composes:

```
mix mishka.ui.gen.components --import --helpers --global --yes
```

What that task writes, read off a Phoenix 1.8.15 project:

| Where | What |
| --- | --- |
| `lib/<app>_web/components/<name>.ex` | One module per component: 74 of them, 52,016 lines, or the ones chosen |
| `lib/<app>_web/components/mishka_components.ex` | The macro that imports them |
| `lib/<app>_web.ex` | `use <App>Web.Components.MishkaComponents` in `html_helpers`, where `import <App>Web.CoreComponents` was |
| `assets/vendor/mishka_chelekom.css` | Its colours, as CSS variables |
| `assets/css/app.css` | The `@import` of that file and a `@theme` block of 319 lines |
| `assets/vendor/*.js`, `assets/js/app.js` | The hooks of the components that have one, spread into the `LiveSocket`'s |
| `priv/mishka_chelekom/config.exs` | The library's settings: colours, variants and sizes to generate, prefixes, CSS overrides |

With `--mcp`, the cartridge itself writes three things more: the
route at the end of `lib/<app>_web/router.ex`,
`lib/mix/tasks/mcp.json.ex`, and `/.mcp.json` in `.gitignore`.

`core_components.ex` stays, imported by nothing.

## Options

* `--components card,badge,timeline` — the components to generate, by
  the library's names. Two things come along: what each one declares
  it needs (`carousel` brings `image` and `icon`), and the eight whose
  functions stand in for `CoreComponents` — `alert` (its `flash`),
  `button`, `icon`, `input_field` (its `input`), `list`, `modal` (its
  `show` and `hide`), `navbar` (its `header`), `table`. Left out, all
  74.
* `--no-daisy` — daisyUI out of the project. Default: it stays.
* `--no-format` — leaves the generated components as the library wrote
  them. Default: they are run through `mix format`, because the library
  leaves `button.ex` one line short of it, and a `mix format
  --check-formatted` in a pre-commit hook would refuse the next commit.
* `--mcp` — the library's MCP server for AI tools, on the project's own
  port. Default: off.

Every component is drawn, with its variants, at
<https://mishka.tools/chelekom>, and each one has a page of its own
there (`…/docs/navbar`, `…/docs/forms/text-field`): the console's form
puts that page beside each name.

What the choice weighs, `mix tailwind <app> --minify`:

| Components | CSS | gzipped |
| --- | --- | --- |
| a `phx.new` project, none | 75 KB (not minified) | |
| ten (`card`, `badge` and the core eight) | 263 KB | 31 KB |
| all 74 | 1.46 MB | 107 KB |

## daisyUI beside it

Both libraries style class names of their own, and five are the same:
`indicator`, `collapse-content`, `dropdown-content`, `stat-title`,
`stat-value`. Measured over the 146 elements of a page of Mishka's
components, with daisyUI's plugin in and out:

| Component | With daisyUI in |
| --- | --- |
| `collapse` | Open, its panel is 0 px high: daisyUI's `.collapse-content` hides it. **It does not show its content.** |
| `stat` | Titles at 60% of the ink, `white-space: nowrap`, daisyUI's grid columns |
| `indicator`, in `button` and `badge` | `position: relative` where Mishka leaves it static |
| `dropdown` | Nothing, closed |
| the rest | Nothing but the inherited ink |

`--no-daisy` is for the project that takes Mishka's as its one set:

* `assets/css/app.css` loses daisyUI's three `@plugin` blocks and
  gains the page's ground, which the themes painted: white and
  `zinc-950`, `zinc-900` and `zinc-50` in the dark.
* `mix.exs` loses the `:daisyui` dependency, and `mix.lock` its entry.
* The daisyUI classes of the two pages `phx.new` wrote, `Layouts` and
  the home page, become the Tailwind utilities they stood for —
  `bg-base-200` is `bg-zinc-100 dark:bg-zinc-800`, under whatever
  variant it had — and the *Get Started* button takes Mishka's own
  primary. A page the project already rewrote has none and is left
  alone.

It is refused while `cinder` or `ash_authentication_phoenix` is in the
project: their pages are dressed in daisyUI.

## MCP

Mishka Chelekom ships an MCP server: an AI tool connected to it can
list the components, read each one's attributes and examples, and get
the `mix` command that generates one. The library serves it three
ways — a standalone server on port 4003, a stdio process the client
spawns, and a route in the project's own router. The first two have
the client run `mix`, which a host with Docker alone does not have.
`--mcp` is the third:

```elixir
# MCP Server for AI tools (development only)
if Application.compile_env(:my_app, :dev_routes) do
  forward "/mcp", Anubis.Server.Transport.StreamableHTTP.Plug, server: MishkaChelekom.MCP.Server
end
```

With the app up, the server answers on the app's port:

```
claude mcp add --transport http mishka-chelekom http://localhost:<port>/mcp
```

How a client reaches the route — which port, on which machine — is a
fact of where the project runs, not of the project, so the installer
writes no address anywhere. It plants a task instead, the project's
own, which reads the address when it is run:

```
mix mcp.json        # ./wb.sh mix mcp.json on the workbench
```

It writes `.mcp.json` at the project's root, the file Claude Code,
Cursor and VS Code read:

| The project has | The address |
| --- | --- |
| a `docker-compose.yml` publishing the endpoint's port (`4011:4000`) | `http://localhost:4011/mcp` |
| no `docker-compose.yml`, or one that publishes no such port | the endpoint's own port, `http://localhost:4000/mcp` |

An existing `.mcp.json` keeps its other servers; one that is not a
JSON object is left alone, with the address printed. The file is this
machine's, as `.env` is: `.gitignore` lists it, and the task is run
again when the published port changes.

In the console the route is a door, **mcp**, of the kind that is for a
client and not a page: its address is shown and not linked, the bell
reads any answer as *answers* (a `GET` gets the server's own 406), and
the plate has a button that runs `mix mcp.json`. The box's *Opens*
also gives the line above, and the JSON entry, with the published port
already in them and a button to copy each — for registering the
server in a client's own configuration instead of a file.

The route is the one `mix mishka.mcp.setup` writes, and the cartridge
writes it itself, at the end of the router. That is a **workaround**
for the library's task, which on the router `phx.new` generates puts
the `forward` inside `pipeline :browser`; it goes when the task
appends to the router module instead (DESIGN §3.6).

The route names a development dependency. An environment that turns
`dev_routes` on without it — `test`, on a project that set it there —
compiles with a warning that the plug is not available.

## Idempotency

A second run generates nothing: the mark is the dependency, the same
one the ash cartridge's `--components mishka_chelekom` leaves. With
`--mcp` it adds the route where the router lacks it, on a project
either road brought the library to. A component is added afterwards
with the library's own task and a line in the macro:

```
mix mishka.ui.gen.component carousel
```

## What the library leaves, as it is

Facts of Mishka Chelekom 0.0.9, which the cartridge does not correct:

* `assets/js/app.js` comes back reformatted whole — semicolons, one
  property a line — not only with its two new lines.
* `button.ex` is one line short of `mix format`; the other 73 pass.
  The cartridge formats the components unless told `--no-format`.
* `mix mishka.mcp.setup` puts its route inside `pipeline :browser` on
  an untouched router (*MCP*, above).
* `<.header>` has no dark variant: its title is `text-zinc-800` on any
  ground.
* The usage example in `dropdown.ex`'s documentation passes attributes
  the component no longer declares.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/mishka_chelekom/` | The cartridge: its code and its papers |
| `├── 📄 mishka_chelekom.ex` | The dependency, the queued task, daisyUI out, and the MCP route |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why queued, why a core set, and what was measured |
|  |  |
| `📁 priv/features/mishka_chelekom/assets/` |  |
| `└── 📄 mcp.json.ex` | `mix mcp.json`, planted in the project by `--mcp` |
|  |  |
| `📁 lib/mix/tasks/` |  |
| `└── 📄 workbench.mishka_components.ex` | The queued command: the list completed, the library's task watched, the components formatted |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 mishka_chelekom_test.exs` | The queue, the list, and a project without daisyUI |
