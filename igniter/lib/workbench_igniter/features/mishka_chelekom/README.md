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
`lib/mix/tasks/chelekom.mcp.json.ex`, and `/.mcp.json` in `.gitignore`.

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
* `--solve-warnings` — writes the fence three of the library's code
  blocks lack, in the documentation of `combobox` and of `layout`'s
  `flex` and `grid`: ExDoc warns of each on every `mix docs`. Default:
  off, the components stay as the library wrote them. It works as the
  components are generated, not on the ones a project already has.
* `--mcp` — the library's MCP server for AI tools, on the project's own
  port. Default: off.
* `--mcp-path /ai/components` — where `--mcp` forwards it, and only
  with `--mcp`: given alone it is refused, and the console's form
  offers the field while the switch is on. Default:
  `/mishka-chelekom/mcp`.

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

Mishka Chelekom ships an MCP server: an AI tool connected to it reads
the library instead of guessing it. Asked for a timeline, it looks up
which attributes `<.timeline>` takes and writes those.

What the server of 0.0.9 offers, as it lists them itself:

| Tools | |
| --- | --- |
| `search_components`, `get_component_info`, `get_example` | Find a component; its types, colours, sizes and what it needs; its documentation with the attributes of each function |
| `get_js_hook_info`, `get_mix_task_info`, `get_docs` | A hook's, a Mix task's, or a page of the library's site |
| `generate_component`, `generate_components`, `uninstall_component` | The `mix` command that does it — the tool hands the command over, and running it is yours: `./wb.sh mix …` on the workbench |
| `update_config`, `validate_config` | The lines to add to the library's `priv/mishka_chelekom/config.exs`, handed over the same way, and a check of that file |

And ten resources to read: the components, colours, variants, sizes,
spaces, CSS variables, dependencies between components, scripts, the
headless set, and the project's configuration.

### What `--mcp` puts in

The library serves it three ways — a standalone server on port 4003,
a stdio process the client spawns, and a route in the project's own
router. The first two have the client run `mix`, which a host with
Docker alone does not have. `--mcp` is the third, and two more things
with it:

* the route, at the end of `lib/<app>_web/router.ex`:

  ```elixir
  # MCP Server for AI tools (development only)
  if Application.compile_env(:my_app, :dev_routes) do
    forward "/mishka-chelekom/mcp", Anubis.Server.Transport.StreamableHTTP.Plug,
      server: MishkaChelekom.MCP.Server
  end
  ```

* `lib/mix/tasks/chelekom.mcp.json.ex`, the project's own `mix chelekom.mcp.json`;
* `/.mcp.json` in `.gitignore`.

### Connecting a client

The server is the app's: it answers while the app is up in dev, on
the app's port.

1. `./wb.sh add mishka_chelekom --mcp` — on a project that already has
   the library, this adds the three things above and nothing else.
2. `./wb.sh up`, the dev deployment.
3. `./wb.sh mix chelekom.mcp.json` — `mix chelekom.mcp.json` off the workbench. It
   writes `.mcp.json` at the project's root, the file Claude Code,
   Cursor and VS Code read, with the address the app answers on here.
4. Open the client **from the project's folder**. Claude Code asks
   once whether to trust the servers of that `.mcp.json`; `/mcp` in
   the session then shows `mishka-chelekom` connected, with its tools.

Afterwards: with the app down the client shows the server
disconnected, and finds it again when the app is back (`/mcp`, or a
new session). When the published port changes — another bake — run
`mix chelekom.mcp.json` again. A session opened from another folder does not
see the server.

### The address

How a client reaches the route — which port, on which machine — is a
fact of where the project runs, not of the project, so the installer
writes no address anywhere. The task reads it when it is run:

![The MCP address, and where each part of it comes from: the router forwards a path to the library's MCP server under dev_routes; the project's own task, mix chelekom.mcp.json, reads that path off the router, the endpoint's port off the app's configuration and the port docker-compose.yml publishes it as, and writes the address into .mcp.json, a file of the machine's that git ignores; an AI tool reads that file and calls the route over HTTP on the published port](../../../../../assets/diagrams/mishka_chelekom/mcp-address.svg)

*Three facts make the address, and each has one owner: the path is the
router's, the port the endpoint's, and the number a client dials the
compose's. The task reads all three when it is run, so none of them is
written twice.*

| The project has | The address |
| --- | --- |
| a `docker-compose.yml` publishing the endpoint's port (`4011:4000`) | `http://localhost:4011/mishka-chelekom/mcp` |
| no `docker-compose.yml`, or one that publishes no such port | the endpoint's own port, `http://localhost:4000/mishka-chelekom/mcp` |

The path is the one the project's router forwards on, read off
`lib/<app>_web/router.ex`, so a project that moved the route is still
found. The endpoint's port is the one its configuration says (`http:
[port: …]`), 4000 when it says none. An existing `.mcp.json` keeps its other
servers; one that is not a JSON object is left alone, with the address
printed. The file is this machine's, as `.env` is: `.gitignore` lists
it.

Without the file, the same server is registered in the client's own
configuration, which is kept per folder and outside the project:

```
claude mcp add --transport http mishka-chelekom http://localhost:<port>/mishka-chelekom/mcp
```

### The path

The library's documentation forwards its server at `/mcp`. The
cartridge's default is `/mishka-chelekom/mcp`, and `--mcp-path` moves
it. An MCP endpoint is one server's: the protocol gives each server "a
single HTTP endpoint path", with no way for two to share one, and a
client lists them one by one, each by its name and address. `/mcp` is
the specification's own example of such a path, and the one any other
server in the project would want too. The name goes before `mcp`, as
Tidewave's does, and not after: `forward "/mcp"` takes every path under
`/mcp/`, so two servers at `/mcp` and `/mcp/<name>` would depend on the
order of the router.

A project that already forwards the server elsewhere — at the
library's `/mcp`, by an earlier insert or by `mix mishka.mcp.setup` —
keeps it there: the cartridge, the task and the console read the path
off the router.

### In the console

The route is a door, **mcp**, of the kind that is for a client and not
a page: its address is shown and not linked, the bell reads any answer
as *answers* (a `GET` gets the server's own 406), and under it, in the
same plate, is its file: a mark and when `.mcp.json` was written —
hollow while there is none, full and green while it carries the
address of today, half and amber once the port moved — and the button
that runs `mix chelekom.mcp.json`. The box's *Opens* shows the same
plate and no line to copy: the task writes what a client reads.

### What to know of it

* The route is the one `mix mishka.mcp.setup` writes, and the cartridge
  writes it itself. That is a **workaround** for the library's task,
  which on the router `phx.new` generates puts the `forward` inside
  `pipeline :browser`; it goes when the task appends to the router
  module instead (DESIGN §3.6).
* The route names a development dependency. An environment that turns
  `dev_routes` on without it — `test`, on a project that set it there —
  compiles with a warning that the plug is not available.
* It is the dev deployment's: `dev_routes` is off in prod, and the
  task reads `docker-compose.yml`, not the prod or scaled compose.

## Idempotency

A second run generates nothing: the mark is the dependency, the same
one the ash cartridge's `--components mishka_chelekom` leaves. A
component is added afterwards with the library's own task and a line
in the macro:

```
mix mishka.ui.gen.component carousel
```

`--mcp` is the one piece a second run adds, and it counts as in when
both of its pieces are: the route and the project's `mix chelekom.mcp.json`. A
project with the route alone — written by the library's own setup, or
by this box before it planted the task — is offered the option again
and gets what it lacks; the route is not written twice. With both in,
the console shows the switch shut on and the box with nothing left to
add.

## What the library leaves, as it is

Facts of Mishka Chelekom 0.0.9, which the cartridge does not correct:

* `assets/js/app.js` comes back reformatted whole — semicolons, one
  property a line — not only with its two new lines.
* `button.ex` is one line short of `mix format`; the other 73 pass.
  The cartridge formats the components unless told `--no-format`.
* Three code blocks in the components' documentation have one fence
  of the two — `combobox.ex` lacks the one that opens, `layout.ex` the
  one that closes, twice — and `mix docs` warns *Fenced Code Block
  opened with ``` not closed at end of input* for each. They render
  and compile all the same. `--solve-warnings` writes the three
  fences.
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
| `└── 📄 chelekom.mcp.json.ex` | `mix chelekom.mcp.json`, planted in the project by `--mcp` |
|  |  |
| `📁 lib/mix/tasks/` |  |
| `└── 📄 workbench.mishka_components.ex` | The queued command: the list completed, the library's task watched, the fences written, the components formatted |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 mishka_chelekom_test.exs` | The queue, the list, and a project without daisyUI |
