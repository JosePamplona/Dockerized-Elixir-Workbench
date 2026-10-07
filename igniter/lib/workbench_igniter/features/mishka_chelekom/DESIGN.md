# mishka_chelekom — Design

*Revision: cartridge v0.1.0 (2026-10-06). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md).*

## Abstract

Mishka Chelekom generates Phoenix components into a project, and the
shelf reached it only through the ash cartridge's `--components`. This
cartridge is the road without Ash. It adds the dependency and queues
the library's own batch task, the one its installer composes, so
nothing of the library is reimplemented. It owns the decisions the
library leaves open. Which components: the batch task generates exactly
the names it is given, so a chosen list is completed with what each
component needs and with the eight that stand in for `CoreComponents`.
And daisyUI: both libraries style five of the same class names, and
measured on a real project one of Mishka's components stops working
beside it, so `--no-daisy` takes it out and rewrites what `phx.new`
dressed in it. Two more are smaller: the components are formatted,
because the library leaves one short of `mix format`, and `--mcp`
forwards the library's MCP server in the router — written by the
cartridge, a workaround for a task that puts the route in the wrong
block.

## 1. Problem

A developer who wants Mishka's components on a `phx.new` 1.8 project
meets three things its documentation does not say.

* **daisyUI is already there.** Since 1.8 `phx.new` ships daisyUI, and
  `CoreComponents`, `Layouts` and the home page wear its classes. The
  library's documentation does not mention daisyUI [1], and neither
  does its source, outside one comment (§2.3).
* **All or a list by hand.** The installer generates all 74 components.
  A shorter list is one task away, but that task does not resolve what
  each component needs (§2.2).
* **The swap is global.** The installer replaces `CoreComponents`'
  import in the web module, so a short list has to carry whatever the
  project's templates already call.

## 2. Background

### 2.1 What the installer is

`mishka_chelekom` 0.0.9 is installed as
`{:mishka_chelekom, "~> 0.0.9", only: :dev}` [1][2]. Its Igniter
installer declares no `adds_deps`, `installs` or `composes`, and its
body is one line [3]:

> `Igniter.compose_task("mishka.ui.gen.components", ["--import", "--helpers", "--global", "--sub"])`

That task, for every component of the catalog, composes
`mishka.ui.gen.component NAME --no-deps --sub --yes`, then writes the
`MishkaComponents` macro (`--import`, with the `show`/`hide` helpers
under `--helpers`), swaps it for `import <App>Web.CoreComponents` in
`html_helpers/0` (`--global`), and installs the stylesheet and the
`@theme` [4][5][6]. It requires Elixir `~> 1.18` and, optionally,
`phoenix_live_view ~> 1.2` [2]; its documentation names Tailwind 4,
Phoenix 1.8 and LiveView 1.1 [1].

### 2.2 The batch task and `--no-deps`

A component's catalog entry (`priv/components/<name>.exs`) declares
`necessary: [...]`, the components it calls: `carousel` needs `image`
and `icon`, `file_field` needs `spinner`, `progress` and `icon` [7].
`mishka.ui.gen.component` alone generates them along. The batch task
hands every child `--no-deps` [4], which is right for all 74 and leaves
a list of some short of what it calls. The names are taken as one
comma-separated positional, and `Core.resolve_components/5` only
removes the excluded ones [8].

### 2.3 Where the two libraries meet

daisyUI is a Tailwind plugin: a rule of it reaches the stylesheet when
its class name appears in the scanned sources. Mishka's components are
under `lib/<app>_web`, which `phx.new`'s `app.css` scans. Of the 3,774
class tokens in the generated components' `class` attributes, five are
daisyUI's too: `indicator` (in `badge`, `button`, `indicator`),
`collapse-content`, `dropdown-content`, `stat-title`, `stat-value`.
The library knows of the neighbour in one place, `shape.eex` [9]:

> "Inspired by daisyUI's mask component but renamed to avoid colliding
> with Tailwind v4's mask-* utilities."

Their theme variables do not meet: Mishka's are `--primary-light` and
`--color-primary-light`, daisyUI's `--color-primary` and
`--color-base-100`. Both follow `phx.new`'s `dark` variant, which reads
`data-theme` off `<html>`.

### 2.4 What stands in for `CoreComponents`

Phoenix 1.8's `CoreComponents` exports `flash`, `button`, `input`,
`header`, `table`, `list`, `icon`, `show`, `hide`, `translate_error`
and `translate_errors`. In the generated macro they come from: `flash`
`Alert`, `button` `Button`, `input` `InputField`, `header` `Navbar`,
`table` `Table`, `list` `List`, `icon` `Icon`, and `show` and `hide`
`Modal`. `translate_error/1` and `translate_errors/2` have no
counterpart, and nothing `phx.new` writes calls them from a template.

### 2.5 The library's MCP server

0.0.9 brought a server of the Model Context Protocol: "Connect your
favorite AI tools directly to the component library" [12]. It is a
process of the library's own application
(`MishkaChelekom.Application` starts `MishkaChelekom.MCP.Server`), so
it is there wherever the dependency is loaded, which is `:dev`. The
library documents three ways to reach it [12]:

* *standalone*, `mix mishka.mcp.server`, on port 4003;
* *stdio*, the same task with `--transport stdio`, spawned by the
  client from a `.mcp.json` whose command is `mix`;
* *in the project's router*, `mix mishka.mcp.setup`: a `forward` to
  `Anubis.Server.Transport.StreamableHTTP.Plug` under `dev_routes`,
  answering on the app's own port [13].

Asked for what it has (`tools/list`, `resources/list`, on the author's
project, §4.2), the server names eleven tools — `search_components`,
`get_component_info`, `get_example`, `get_js_hook_info`,
`get_mix_task_info`, `get_docs`, `generate_component`,
`generate_components`, `uninstall_component`, `update_config`,
`validate_config` — and ten resources: `config`, `colors`,
`components`, `css-variables`, `dependencies`, `headless`, `scripts`,
`sizes`, `spaces`, `variants`. The three generating tools each say
they return "the mix command", and `update_config` the Elixir "to add
to the config": none of them writes to the project.

The route speaks the protocol's streamable HTTP: `POST` with
`initialize` opens a session and answers its id in `mcp-session-id`;
every other request needs that header, `ping` among them; `DELETE`
closes it. A `GET` that accepts no event stream is refused with 406
(§4.2).

## 3. Design

### 3.1 Queue the library's task

The dependency is this patch set's to add, so its task is not loaded
while the patch set is built. A task queued with `Igniter.add_task/3`
runs as its own `mix` process after the files are written, and Igniter
runs `mix deps.get` before the first one. The ash cartridge queues
`mix igniter.install` for the same reason; here the queued command is
the library's batch task, not its installer, because the installer
takes no list.

It runs through `mix workbench.mishka_components`, plumbing of the
package and not of the project, for two reasons. It completes the list
where the catalog is — in the fetched package — and it runs the
library's task under the shell `workbench.igniter_install` listens
with, now `watched/2` there: an Igniter task that reports issues
writes nothing and exits with zero, and the library's spinner needs a
screen when colour is on over a pipe.

*Beaten:* running `mix igniter.install mishka_chelekom`, as ash does —
it cannot take a list. Writing `exclude_components` into the library's
`priv/mishka_chelekom/config.exs` — the library's own switch, and the
inverse of the list, but it needs the catalog before the package is
fetched, and it would leave the project a settings file that says the
opposite of what was asked.

### 3.2 `--components`, completed

The list handed to the library is the names given, the transitive
closure of their `necessary`, and the core set of §2.4: `alert`,
`button`, `icon`, `input_field`, `list`, `modal`, `navbar`, `table`.
Without the closure a chosen `carousel` does not compile. Without the
core set `--global` leaves `Layouts` calling a `<.flash>` nobody
defines, and the next `phx.gen.live` a `<.table>`.

The option's values are a closed list: the 74 names of 0.0.9 under the
library's own six categories. A name outside it is refused by the
installer, before anything is fetched; the queued task checks again
against the fetched catalog, which is the one that counts. The first
cut left the list open, with a field for other names, and the field
had nothing to take: 0.0.10-alpha.8 carries the same 74 [10], and the
other names the library's task accepts — `component_*`, `preset_*`,
`template_*` — are templates in the project's own
`priv/mishka_chelekom/`, which a project being given the library does
not have yet. The 35 headless components are another task's
(`mishka.ui.gen.headless.components`), with no import macro and no
swap, and are not this option's.

*Beaten:* a list without `--global`, leaving `CoreComponents` imported.
Both export `button/1`: importing the two is a compile error at the
first call, and the library's answer to that is a prefix on every
function, which is a different product.

### 3.3 `--no-daisy`

daisyUI stays by default: it is what the project has, and the
cartridge installs the library as its author wrote it. The option is
for the project that takes Mishka's components as its one set, and it
does four things, all in this patch set, before the queued task:

1. `app.css` without daisyUI's three `@plugin` blocks.
2. `mix.exs` without `:daisyui`, and `mix deps.unlock daisyui` queued.
3. The page's ground as a rule of its own. daisyUI's themes painted
   `<body>`; without them a dark theme has dark components on a white
   page.
4. The daisyUI classes of `Layouts` and the home page as Tailwind
   utilities. A base colour is translated wherever it stands — any
   utility (`bg`, `border`, `text`, `fill`), any variant, any opacity —
   to a light and a dark grey of Tailwind's zinc, the scale Mishka's
   own base colours sit on. The six component classes those two pages
   use (`navbar`, `btn btn-ghost`, `btn btn-primary`, the badge,
   `card`, `rounded-box`) become the utilities they stood for there.
   `mix format` is queued over the two files, since the lines grow.

It is refused while `cinder` or `ash_authentication_phoenix` is in:
the first imports `cinder/priv/themes/daisy_ui.css` and the second
writes daisyUI overrides for its sign-in pages.

*Beaten:* rewriting `Layouts` with Mishka's `<.navbar>` and
`<.button_link>`. It changes tags and closing tags, where a class is a
token: the translation holds on a file the project already edited, and
a page without daisyUI classes is simply left alone. Defining
`btn`, `navbar` and the base colours in `app.css` under their old
names — daisyUI rebuilt by hand, to keep two pages every project
replaces.

### 3.4 Formatted, unless told not to

Of the 74 generated modules, `button.ex` does not pass the project's
`mix format --check-formatted` (§4.2): one `do:` on the line of the
bracket that closes its list. A project with a pre-commit hook that
checks the format — the precommit cartridge's — refuses its next
commit for a file nobody wrote. So the queued task runs `mix format`
over `lib/<app>_web/components/` when the library's task is done, and
`--no-format` leaves the files as generated.

It is the one place the cartridge touches what the library writes, and
it changes no behaviour: the formatter is the project's own, with its
own configuration. It runs inside the plumbing task rather than as a
queued `mix format`: Igniter joins a queued task's arguments into a
shell command, where the glob over the components would be expanded
by `sh`, which has no `**`.

*Beaten:* leaving it and documenting it, as the first cut of this box
did — the author asked for a project ready for its next commit.

### 3.5 What the form shows

A component's name says little; its page shows it drawn. The catalog
gives each value its page in the library's documentation as its doc —
`docs/<name>` in dashes, `docs/forms/<name>` for the forms, two
exceptions, and none for `icon`, which has no page; each is the
`doc_url` of the library's own catalog entry [7] — and the option's
note names <https://mishka.tools/chelekom>, where they are all drawn.

Seventy-four values with a link under each were 148 lines of form. The
console now draws a value whose doc is an address alone with a mark
beside its name, and sets a list of more than a dozen such values in
columns, each section its own; a section's name ticks or clears its
values at one press. All three are the console's rules, for any
cartridge; a value with a sentence under it keeps its line.

### 3.6 `--mcp`: the library's route, written here

The library serves its MCP server three ways [12]: standalone
(`mix mishka.mcp.server`, port 4003), stdio (`.mcp.json` with `mix` as
the command), and forwarded in the project's router
(`mix mishka.mcp.setup`). On the workbench the host has Docker and no
`mix`, and the app's port is the one thing a project publishes: the
route is the way that works, and it answers on that port while the app
is up.

`mix mishka.mcp.setup --yes` writes [13]:

```elixir
# MCP Server for AI tools (development only)
if Application.compile_env(:my_app, :dev_routes) do
  forward "/mcp", Anubis.Server.Transport.StreamableHTTP.Plug,
    server: MishkaChelekom.MCP.Server
end
```

**WORKAROUND.** On the router `phx.new` 1.8.15 generates, untouched,
the task writes those lines inside `pipeline :browser`, after its last
plug (§4.2). `find_insertion_point/1` calls
`Igniter.Code.Common.move_to_do_block/1` on the zipper it is given and
takes the last sibling of that block; the block it gets is the first
one in the module, the pipeline's [13]. The route answers all the same
— `forward` defines its clause wherever it is expanded — which is why
it goes unnoticed, but it reads as a plug of the browser pipeline and
moves with it. 0.0.10-alpha.8 carries the same code [14].

So the cartridge writes the task's own lines at the end of the router
module, where the task means them, and does not queue it. It is a
compensation, not a decision: remove it, and queue `mishka.mcp.setup
--yes` through `watched/2`, when the task appends to the router
module's block. Issue: TODO — not filed yet; no issue of the
repository names it (searched 2026-10-06), and the draft is
`ISSUE-mishka_chelekom-mcp-route.md` in the workbench's `_local/`.

The option is off by default: a route in the router is a decision, and
a project without an AI tool has no use for it. It is the one piece a
second run adds (`adds: [:mcp]`).

*Beaten:* running the task and moving its route afterwards — two
writes to say one thing.

**The path: the library's own, not `/mcp`.** The library's setup
forwards at `/mcp` unless given `--path` [13]. The protocol's
streamable HTTP transport says "The server MUST provide a single HTTP
endpoint path (hereafter referred to as the MCP endpoint) that supports
both POST and GET methods. For example, this could be a URL like
`https://example.com/mcp`" [16]: one endpoint, one server, one
handshake and one list of tools, and nothing for two servers to share
a path. A client is told of each by its own name and address. So a
second cartridge with an MCP server needs a second path, and `/mcp`,
the specification's example, is the one each of them would take by
default. The cartridge forwards at `--mcp-path`, `/mishka-chelekom/mcp`
unless told otherwise — the author's default. The name goes before
`mcp`: the transport does not say, and two things do. A Phoenix
`forward "/mcp"` takes every path under `/mcp/`, so `/mcp/<name>`
beside a server at `/mcp` would answer by the router's order. And it
is where the other MCP server a workbench project may carry already
is: ash's `--ai tidewave` mounts `plug Tidewave` in the endpoint, on a
path of its own.

The path is a detail of the switch, and is declared as one
(`details/0`, `[mcp_path: :mcp]`): it says where `--mcp` forwards and
nothing without it. So the installer refuses `--mcp-path` given alone,
where the first cut ignored it in silence; the console's form shows
the field unlit, *only with --mcp*, until the switch is on, and leaves
it off the command; and on a project that has the library, where the
switch is the one piece a second run adds, the field follows the
switch — open while it is being added, shut with *went in with --mcp*
once it is in.

Nothing but the installer holds the path: `state/1`, the door of the
console (`{mcp_path}`) and the planted task all read it off the
router's `forward` to `MishkaChelekom.MCP.Server`. A project inserted
while the path was `/mcp`, or one the library's setup wrote the route
of, is read where it is.

**The client's side: a task of the project's, not a file of the
installer's.** A client needs the address, and the address has a port
the project's code does not know: the one its compose publishes the
app on, decided at each bake, another on another machine. Three ways
to give it were weighed.

* *A `.mcp.json` written by the installer.* It carries a number that
  stops being true at the next bake. Out.
* *A port-free stdio entry*, `docker compose exec app mix
  mishka.mcp.server --transport stdio`. It makes Docker a requirement
  of a file in a project that, without the workbench, is a Phoenix
  project run with `mix`. The author turned it down for that.
* *A task that reads the port when it is run.* The author's: the
  number is in a file of the project's own, `docker-compose.yml`
  (`- 4011:4000`), and where there is no such file the project runs
  on the host and the address is the endpoint's own port. Neither the
  workbench nor Docker is needed to run it, and nothing it reads is
  the workbench's.

So `--mcp` plants `lib/mix/tasks/mcp.json.ex`, verbatim. `mix
mcp.json` reads the path off the router, loads the app's
configuration (`app.config`), takes the
endpoint's port from the one entry that has `http: [port: …]`, 4000
when none does; looks in `docker-compose.yml` for the line that
publishes that port (`HOST:PORT`, with the address, `/tcp` and quotes
Compose allows); and adds or replaces the `mishka-chelekom` entry of
`.mcp.json`, leaving its other servers, and leaving alone a file that
is not a JSON object — where the library's own `--stdio` setup writes
a fresh one over it [13]. The compose is read with one expression, not
a YAML parser: the project has no YAML dependency and the task brings
none, and a compose it cannot read is the case of no compose, said in
the task's line. What it writes is the machine's, as `.env` is, so
`.gitignore` lists it.

On the workbench the console knows the port too, and offers both: the
route is declared as a door for a client (`console/0`, `client:`),
with the task as its `build:` — a button on its plate — and the lines
a client is given, `{url}` filled with the published port, for
registering the server in the client's own configuration instead.

**The bell and the 406.** The console calls a door with a `GET`, and
the MCP plug answers one that accepts no stream with 406. As a page
that is a warning; for a client's door any answer is the door
answering, so the chip says *answers*. The protocol's own check was
tried and left out of the bell: `ping` needs a session (404 without
one), and `initialize` followed by `DELETE` of the session it opens
took 1.0 to 2.3 s on the author's project in dev, once over 8 s, where
the bell gives a door 2.5 s — and it would have the console speak a
protocol, which today it does of none (§4.2).

### 3.7 The mark, and a second run

The mark is the dependency in `mix.exs`, which is also what
`ash --components mishka_chelekom` leaves, so the two roads light the
same box. A second run generates nothing and says how a component is
added: the library's own `mix mishka.ui.gen.component NAME`. Running
the batch task again would overwrite the macro with the new list alone
and regenerate components the project may have edited.

The mark of `--mcp` is both of its pieces: the route in the router and
`lib/mix/tasks/mcp.json.ex`. A project with the route alone — written
by the library's own setup, or by this box before it planted the task
— answers that the option is not in, so the console keeps offering it
and a second run adds what is missing; with both, the console counts
the box as full and offers nothing.

`state/1` reads the components off the macro the library wrote,
daisyUI off `app.css` and the MCP route and task off the project: the project as
it is, whichever road it took. `format` answers `nil`: a formatted
file keeps no mark of who formatted it.

## 4. Evaluation

### 4.1 Unit tests

`mishka_chelekom_test.exs`, on `phx.new`'s project in memory: the
dependency and the queued task; the three requirements; the list
handed over and what completes it, on a catalog of fourteen entries;
`--no-daisy` file by file, the order of the queued tasks, the
refusal, a page left alone; the translation of a class; the read of
the state.

### 4.2 Real project

2026-10-06, Phoenix 1.8.15, LiveView 1.2.12, Tailwind 4, daisyUI
5.5.20, Elixir 1.19.5 on OTP 27, `mishka_chelekom` 0.0.9, a `phx.new
--no-ecto` project on the host.

* The library's installer alone: 58 s, exit 0, 91 files, and the
  project compiles with no warning. `<.header>` with `:subtitle` and
  `:actions`, `<.table rows>` with `:col` and `:action`, `<.input>`
  with `field`, `select` and `checkbox` compile and render.
* The collision of §2.3: every computed style of the 146 elements of
  a page of the suspect components, with daisyUI's plugin in and out.
  47 elements differ; all but the ones in the README's table differ
  only by the inherited ink.
* The cartridge, `--components card,badge,timeline,stat,collapse
  --no-daisy`: exit 0; thirteen components generated — the five, the
  core eight, `icon` already among them; `collapsible.js` alone in
  `assets/vendor`; the project compiles with no warning; the home page
  and a page under `Layouts.app` drawn in light and dark, the open
  `collapse` 56 px high, no error in the browser's console.
* The stylesheet, `mix tailwind <app> --minify`: 1,459,454 bytes
  (106,759 gzipped) for all 74 without daisyUI, 1,543,527 (119,740)
  with it, 263,481 (30,593) for ten components with it.

* The cartridge again, `--components card,timeline --mcp`, with the
  default formatting: exit 0; `mix format --check-formatted` passes;
  the router gains the route's four lines at its end and nothing else;
  the project compiles with no warning; `POST /mcp` with an
  `initialize` answers 200 and `"serverInfo":{"name":"Mishka
  Chelekom","version":"0.0.9"}`. `GET /mcp` answers 406.
* The library's own `mix mishka.mcp.setup --yes` on the same router:
  the route inside `pipeline :browser` (§3.6). With `dev_routes` on in
  `test`, `MIX_ENV=test mix compile` warns that
  `Anubis.Server.Transport.StreamableHTTP.Plug.init/1` is undefined.
* The door, on the console from the working tree against a project
  up in dev with the route: the rail's row `mcp :4011/mcp`, no link,
  *answers* after the bell; the box's *Opens* with the two lines,
  `http://localhost:4011/mcp` in each, and *copy* answering *copied*.
* `mix mcp.json`, on the host project: with no compose,
  `http://localhost:4000/mcp`; with one publishing `4011:4000`,
  `…:4011/mcp`; over a file with another server, both kept; over a
  file that is not JSON, the file untouched and the task's error with
  the address. `git status` does not show `.mcp.json`, `mix format
  --check-formatted` passes with the task planted. Inside the
  container of a workbench project up in dev: `docker-compose.yml` is
  in the task's directory, the endpoint's port is 4000 and the line
  found is `4011:4000`.
* The server driven by hand, against that project: `initialize`,
  then `tools/list` (the eleven of §2.5) and `resources/list` (the
  ten); `search_components` for "timeline" answers the component with
  its page and `mix mishka.ui.gen.component timeline`;
  `get_component_info` its two functions, thirteen colours, eight
  sizes and that it needs `icon`; `get_example` its documentation with
  the attributes of each function. Read-only calls: nothing of the
  project was written.
* With the path the library's own (2026-10-07, a project generated
  anew): `--components card --mcp` writes the route at
  `/mishka-chelekom/mcp`; `mix format --check-formatted` passes and the
  project compiles with no warning; `POST` of an `initialize` there
  answers 200 with the server's name, and the same at `/mcp` 404;
  `mix mcp.json` writes `http://localhost:4000/mishka-chelekom/mcp`
  with no compose and `…:4011/…` with one publishing `4011:4000`. The
  measurements above this one were taken while the path was `/mcp`.
* The protocol as a health check, against that project: `ping` with no
  session 404; `initialize` 200 with a session id; `ping` on it 200;
  `DELETE` of the session 200; `ping` afterwards 404. Four
  `initialize` calls: no answer in 8 s, 2.3 s, 1.2 s, 1.0 s — every
  request to that app took 0.6 to 1.1 s then, a plain `GET /` among
  them.
* The console's form, from the working tree: `--components` in six
  sections of five columns, 73 page marks, the three switches under
  it.

### 4.3 Through `wb.sh`

Same day, a copy of a workbench project with seven cartridges in,
precommit among them: `./wb.sh -y add mishka_chelekom --components
card,badge,timeline --no-daisy` in the workbench's container. One
commit, *Insert mishka_chelekom …*, 20 files, a clean tree; eleven
components. `status --json` answers `installed` with those eleven and
daisyUI out; `mix compile --warnings-as-errors` passes; `mix
format --check-formatted` names `button.ex` alone. `./wb.sh eject
mishka_chelekom` reverts it: daisyUI back in `mix.exs` and `app.css`,
the components gone.

### 4.4 Not measured

`--mcp` and the formatting through `wb.sh`: both ran on the host, and
the planted `mix mcp.json` was run there too, never as `./wb.sh mix
mcp.json`. A client — Claude Code, Cursor — reading the `.mcp.json`
the task writes: the server was driven with `curl` alone. The console
with a box full by its switch, in a browser: its tests cover it. An
opened `dropdown` beside daisyUI. A project that had edited
`Layouts`.

## 5. Limitations and open questions

* **The list of names is 0.0.9's**, and closed. `~> 0.0.9` resolves
  0.0.10 when it is released; a component it adds is not offered until
  the manifest is updated, and is generated meanwhile with the
  library's own `mix mishka.ui.gen.component NAME`.
* **The headless set and the Kit are out.** 0.0.9 also generates 35
  unstyled components (`mishka.ui.gen.headless.components`) and a
  restyling kit (`mishka.ui.gen.kit`). Neither is offered here: each
  is run by hand on a project that has the library.
* **0.0.9 reads `app.css` off the disk** and writes it back whole
  (`Generators.Assets.import_and_setup_theme/2`). Here that is
  harmless: the task runs in its own process, after this patch set is
  on disk. 0.0.10-alpha.8 patches the source instead.
* **`core_components.ex` stays**, with its daisyUI classes, imported
  by nothing. Deleting it is the project's call.
* **A system theme.** The ground follows `data-theme`, as `phx.new`'s
  `dark` variant does; a root layout that sets no `data-theme` gets
  the light ground.
* **The MCP route is a workaround** (§3.6), with its removal
  condition and no issue filed yet.
* **The task reads the dev compose.** `docker-compose.yml` is the dev
  deployment's, which is where `dev_routes` and the route are. A
  compose rewritten by hand in a form the expression does not read
  falls back to the endpoint's port, and the task says which it used.
* **`dev_routes` outside `dev`.** The route names a `:dev` dependency;
  an environment that turns `dev_routes` on without it compiles with a
  warning, and with `--warnings-as-errors` does not compile.
* **What the library leaves as it is** is in the README: `app.js`
  reformatted, `<.header>` with no dark variant.

## References

1. Mishka Chelekom, *Get Started* — <https://mishka.tools/chelekom/docs>.
   Read through a summarizer: quoted for the versions it names and the
   install line only.
2. `mishka_chelekom` 0.0.9, `mix.exs` — the Hex tarball,
   <https://repo.hex.pm/tarballs/mishka_chelekom-0.0.9.tar>.
3. Same, `lib/mix/tasks/mishka_chelekom.install.ex`. Read whole.
4. Same, `lib/mix/tasks/mishka.ui.gen.components.ex`. Read from
   `igniter/1` on.
5. Same, `lib/mishka_chelekom/generators/import_macro.ex`. Read whole.
6. Same, `lib/mishka_chelekom/generators/assets.ex`. Read whole.
7. Same, `priv/components/*.exs`. **Searched, not read**: for
   `necessary:`, `optional:` and `category:`.
8. Same, `lib/mishka_chelekom/generators/core.ex`. Read for
   `resolve_components/5`, `fan_out/4`, `fetch_catalog/3` and
   `ensure_user_config/1`.
9. Same, `priv/components/shape.eex`, line 7. The package was searched
   for "daisy": this file and its demo are the only two hits.
10. `mishka_chelekom` 0.0.10-alpha.8, `lib/mishka_chelekom/generators/assets.ex`
    — the Hex tarball. Read for `import_and_setup_theme/2` only.
11. Hex package metadata — <https://hex.pm/api/packages/mishka_chelekom>.
12. `mishka_chelekom` 0.0.9, `MCP.md` — the Hex tarball. Read to *Connect
    Your AI Tools*; the tools' reference skimmed.
13. Same, `lib/mix/tasks/mishka.mcp.setup.ex`. Read whole.
14. `mishka_chelekom` 0.0.10-alpha.8, `lib/mix/tasks/mishka.mcp.setup.ex`
    — compared with 0.0.9's from `add_mcp_route/5` on: identical.
15. Mishka, *Introducing Mishka Chelekom v0.0.9* —
    <https://mishka.tools/blog/introducing-mishka-chelekom-v0.0.9-ai-native-phoenix-components-with-mcp-headless-ui-and-the-kit>.
    Read through a summarizer, for what it says of the MCP server.
16. Model Context Protocol, *Transports*, revision 2025-03-26 —
    <https://modelcontextprotocol.io/specification/2025-03-26/basic/transports>.
    Read whole; quoted for the endpoint a server provides.
