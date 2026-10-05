# The console

A Phoenix LiveView page that shows the configured workspace and drives
the workbench: the band across the top (what is running, the ground,
the workbench's own drawer), the rail on the left (workspace,
deployments, containers, services and doors, what is inserted, git),
the seven screens on the right (Deploy, Jobs, Logs, Terminal, Project,
Cartridges — the shelf of boxes — and Docker), and the jobs tray at
the bottom, where every command lands with its output and exit code.
The root [README](../README.md#the-console) walks them one by one,
with a capture of each.

```sh
./wb.sh console          # builds its image if missing (minutes), starts it: http://localhost:4100 (first free port from 4100)
./wb.sh console up       # the same, left running
./wb.sh console dev      # mix phx.server on the mounted sources, reloading on change (the first run compiles it)
./wb.sh console logs     # follows its output
./wb.sh console down
./wb.sh console build    # the workbench image again, from the seed as it is now, and the console's on top of it
```

## How it runs

As a container on the workbench's image (`scripts/Dockerfile.workbench`:
the Elixir toolchain, the Phoenix installer, and the Docker CLI with its
buildx and compose plugins), with two mounts: Docker's
socket, and the workbench itself **at the same absolute path as on the
host** — the relative paths of `config.conf` and the composes' bind
mounts then mean the same thing to the daemon whichever side asks. It
runs as the host user, in the socket's group.

Two ways. Bare and `up` run it as a **release**, on the console's own
image (`console/Dockerfile`): the workbench's image with the
console compiled into it, built once for the sources as they are — the
tag carries the workbench's version and a hash of `console/`,
`igniter/` and the workbench's path (`.dockerignore` says what counts;
a cartridge's papers do not, the console reads them off the mount) —
so it starts in seconds,
fetches and compiles nothing, and nothing is compiled through the bind
mount. A source that changed is another image, built on the next
start, and the old one goes. The image stays the workbench's because
the console runs `wb.sh` inside its own container, mix and git
included. `dev` runs `mix phx.server` on the mounted sources instead,
reloading on change, its build and deps in two volumes of its own: for
whoever works on the console or on the package, whose catalog is read
in this BEAM — under the release, a manifest edited keeps what the image
was built with until the next start.

## What it is made of

The console does not reimplement the workbench. It carries the
workbench's own package (`workbench_igniter`, a path dependency), so
the catalog is read in its own BEAM, off the cartridges' manifests;
what only the *project* can answer — what it carries, what a box would
insert — is asked of a **resident**: one BEAM with the project loaded,
`mix workbench.serve`, kept as a Port for as long as the console runs
and answering in milliseconds (`Console.Resident`). Then the contracts
and the verb:

* `./wb.sh status --json --fast` — the board: containers, ports,
  which deployment is up, git, each insert's argv; tenths of a second,
  no container. It answers on an empty workspace too (`exists` false).
  What the project carries comes from the resident and is merged in
  (`Console.Bench`), after the jobs that change it.
* `mix workbench.serve` — the resident's line: `{"ask": "status"}`,
  `{"ask": "expand", …}`. (`wb.sh catalog`, `status` and `expand
  --json` stay for the command line and answer the same, one container
  each.)
* `./wb.sh config set KEY=VALUE …` — the one writer of `config.conf`;
  the drawer's form saves through it, as a job.
* `./wb.sh --yes …` as a **job** (`Console.Jobs`): one at a time, its
  output streamed line by line over PubSub to the tray. A job starts
  with a verb the console knows (`Console.Verbs`), never a free-form
  line, and carries its *kind* — the verb and the deployment or
  cartridge it is about. `delete`, and `new` over a project, wait as
  *pending* until confirmed: `wb.sh` runs under `--yes` and asks
  nothing, so the gate is here, on the server.

| Module | Role |
| --- | --- |
| `Console.Workbench` | the workbench's directory, `wb.sh`, the JSON contracts |
| `Console.Bench` | what the console knows, held once for every page: the status, the catalog, the recipes; a page mounting reads memory and starts no container, and a reading in flight is the one everybody waits for |
| `Console.Resident` | the one BEAM with the project loaded, on a Port: `mix workbench.serve` beside the console in its container, or in one long-lived toolchain container on a host |
| `Console.Catalog` | the catalog read in this BEAM, off the package |
| `Console.Verbs` | the verbs a job may start with, their kind, what to confirm, what to read again |
| `Console.Jobs` | the job queue: a `Port` per command, pending until confirmed where it must, broadcast on `"jobs"` |
| `Console.Logs` | `docker compose logs --follow` on the compose project, parsed, buffered, broadcast on `"logs"` |
| `Console.Config` | `config.conf` read as the form it is: sections, fields, help, alternatives |
| `Console.Diffs` | what a cartridge wrote, off the workspace's git: the insert commit's files, a collection's range when its members are contiguous, both faces of every file cut into lines through `Console.Highlight` |
| `Console.Project` | the project's own papers, off the workspace: Birth, Mix, `.env` (its secrets masked before it leaves the module), README.md, CHANGELOG.md, and its git as Changes and History |
| `Console.Papers` | a box's README, DESIGN and CHANGELOG off the mount, rendered by MDEx with the HTML in them left out, links rewritten to what the console opens; and the workbench's own README and CHANGELOG, for the drawer's Manual, with its two tags written again (*Foreign content*) |
| `Console.Git` | the workspace's git, read: what a commit would take, the log with the cartridge inserts marked |
| `Console.Docker`, `Console.Events` | what the daemon holds, for the Docker screen, and what it does on its own, as it happens (`docker events` on a Port) |
| `Console.Terminals` | the terminal's sessions, each its own process: one per container and shell |
| `Console.Installers`, `Console.Nodes` | what `PHX_NEW_VERSION` and `NODE_VERSION` can name, asked of hex and of Node's release schedule and NodeSource, for the Config form (the stack's list is `wb.sh stacks`) |
| `Console.Hex`, `Console.GitHub` | what hex.pm and GitHub say of a package: latest release, when, how much it is downloaded |
| `Console.Themes` | the themes on the shelf, `console/themes/`, read when the page mounts |
| `Console.Shields` | a shields.io static badge drawn here, with no request to anyone |
| `Console.ANSI` | a line of `wb.sh` output as safe HTML, its colours kept as spans |
| `ConsoleWeb.Plugs.CSP` | the content security policy, with a nonce per response |
| `ConsoleWeb.ConsoleLive` | the page: the screen in the URL (`/deploy`, `/jobs`…), what arrives, what the reader does |
| `ConsoleWeb.Band`, `Board`, `Deploy`, `JobsScreen`, `LogsScreen`, `Terminal`, `ProjectScreen`, `Shelf`, `Box`, `DockerScreen`, `WorkbenchDrawer` | the band, the rail, the seven screens, the box in hand and the workbench's drawer, one module each |
| `ConsoleWeb.Refs` | the house's notation as components: the mention, the door, the probe, the chip |
| `ConsoleWeb.Cartridges` | what the page works out of the status and the catalog about a cartridge; and, off its papers, whether a box that is not done is designed or only identified |
| `ConsoleWeb.Services` | what a compose service is, for whoever draws one: its role, its colour, its shells, asked of the cartridge and never known by name |
| `ConsoleWeb.Doors` | the console calling the project's doors, every open route once, and what each answered |
| `ConsoleWeb.Reports` | the pages a project's tools write (`doc/`, `cover/`), served on a listener of their own |
| `ConsoleWeb.CoversController` | serves the box covers from `assets/covers` |
| `ConsoleWeb.FiguresController` | serves what a paper shows — the diagrams — as images, never inline |
| `ConsoleWeb.BlobController` | a file as a commit of the workspace has it, for the images on the Files screen |

The client keeps the reader's arrangement — the rail's width, the
ground, the clock, the wb.sh line's history and Tab completion — in
`assets/js/hooks.js` and this browser's `localStorage`.

Styles: one stylesheet, `priv/static/assets/css/console.css`, written by
hand, beside `tokens.css` and `components.css`, which
`assets/design/build.py` projects there from the house tokens. A visual
question is settled on a standalone page, then retired.

The console is published on `127.0.0.1` only and keeps the origin check
on in dev: it drives Docker and wipes workspaces, and no page the reader
visits while it is up may open its socket.

## The architecture, as settled

Settled in the console's port plan (`console/PLAN.md`, 2026-09-02 to
2026-09-27, closed on 2026-09-29 and kept in git history) and kept here
as what the code cites.

| Piece | Where | What |
| --- | --- | --- |
| `wb.sh` | the host, bash and Docker only | the one implementation of the verbs |
| the console | a container on the workbench's image, as a release | the LiveView; carries the igniter package; mounts the workbench and the socket; runs `wb.sh` in its own container, mix and git in-process |
| the resident | a process beside the console, `mix workbench.serve` on a Port | the one BEAM with the project loaded; answers `status` and `expand`, with the app up or down |
| the dev `app` | the workspace's compose | the project compiled and running |
| volumes | inside the engine | `_build` and `deps` of the workspace and of the console, and `<project>_workbench_build` for what the workbench compiles; the bind mount carries source only |

Four rules that stay fixed: nothing compiles through the bind mount; no
question starts a BEAM; the host needs Docker and nothing else; `wb.sh`
alone writes the workspace and `config.conf`.

The decisions the code leans on, each dated in the plan:

- **The resident, not `:erpc`** (2026-09-06). Asking the dev node by
  distribution would cost a named, cookied dev node, the console on the
  workspace's network, the OTP pinned once the console is a release —
  and, with the app down, nobody could say what the project carries.
  The resident answers with the app down. What was wrong, two BEAMs
  compiling into one `_build`, is fixed by the workbench compiling into
  a volume of its own.
- **The console is the toolchain** (2026-09-04). `wb.sh` run inside the
  console runs mix and git in this process at `/app/src`, where the
  workspace is mounted a second time under the app's volumes;
  `toolchain_here` checks the mount against `config.conf` and goes back
  to containers when the console was started for another workspace,
  which the band then says, with *Start again*.
- **The project's pages are served by the console** (2026-09-20).
  `mix docs`' `doc/` and coveralls' `cover/` are read off the workspace
  and served by `ConsoleWeb.Reports`, a second listener on a port of its
  own — another origin, so the project's JavaScript never runs on the
  page that runs `wb.sh --yes` — read-only, loopback names only. The
  project carries no route for them: a door of kind `:output`, unlit
  with the reason until built, `build:` as the button. `check_origin`
  names the port the browser sees.
- **The probes reach the app through `host.docker.internal`**
  (2026-09-02); the doors stay `localhost`, for the browser.
- **The console is a release** (2026-09-27), compiled at the workbench's
  host path so the package reads a cartridge's papers where it was
  compiled; `Console.Application` scrubs the release's runtime from the
  environment every job inherits.
- **What belongs where.** The client owns the reader's arrangement
  (`localStorage`); the URL owns where the reader is (`handle_params`);
  the server owns the workbench's facts. Logs and the terminal are lines
  pushed to a hook that keeps and filters them.
- **No cluster screen** (2026-09-26). The console reads no cluster: the
  addresses are on Docker and the Deploy sheet, `Node.list()` two
  keystrokes into an `rpc` session.

## The terminal

Line-oriented: `docker exec -i` (or `docker run
-i` on a one-off toolchain container with the source, when nothing
runs) on a `Port` owned by the page, no tty. bash and iex both read
lines that way — verified: `iex` on a piped stdin answers with its
prompt and the value. On the app container iex is `iex --remsh <app>`,
attached to the named node the dev image boots (`--sname <app>` in its
CMD), so what is evaluated there — a `deliver`, a query — happens on
the VM that serves the port; the one-off, where nothing runs, gets
`iex -S mix`. A release replica gets bash and `rpc`, one `bin/<app>
rpc` per line, because its remote shell stops the node when its input
ends; so does the remsh, which is why closing an iex session sends it
SIGTERM and waits for it before the port, its stdin, is closed.
History and Ctrl+L live in the client.

## Foreign content

Two rules about rendering, in a page, content the console did not write
— a cartridge's papers and the files its installer produced. Both were
decided before the papers were ported, and the reasons stay here.

**Markdown must escape the HTML in it.** The mock (the static maquette
the console grew from, retired on 2026-09-05) rendered a cartridge's
README with `marked`, which dropped its sanitiser years ago and passes
raw HTML straight through: a README carrying `<svg onload="…">` or
`<img onerror="…">` runs it. In the mock that was nobody, since the
cartridges are the ones in this repository — but the console proper is
meant to serve catalogues the user adds, and then it is somebody. Pick a
renderer that escapes by default rather than inherit the hole; both of
the usual Elixir ones do, so the risk is not choosing wrong but turning
it off to make a table look right.

A `<script>` element is not the vector and looking for one is how this
gets missed: neither `innerHTML` nor `insertAdjacentHTML` runs a script
element, by specification, and an SVG inside an `<img>` does not either.
What runs is an event-handler attribute — an `onload`, an `onerror` on a
source that fails — the moment the node is inserted.

**The workbench's own README keeps two tags, written again.** The
root README is Markdown with two exceptions, each for what Markdown
cannot say: an `<img>`, for a width or a side, and a `<br>`, the one way
to a second line inside a table's cell (2026-10-04). The renderer still
leaves raw HTML out, for that document too. `Console.Papers.house_tags/1`
takes those two tags out before the page is rendered and writes them
back afterwards, and what it writes is not what it read: the source
when it is a picture under `assets/`, a width in digits, a side, the
`alt` escaped. An `onerror`, a `style`, a source anywhere else are not
copied, and a tag that does not read that way is left for the renderer
to leave out. It is for the workbench's README alone: a cartridge's
papers are foreign content and never pass through it.

**The manifest's option docs go the same way.** Not only the papers: the
mock rendered each option's `doc` through `marked.parseInline` as well. It
is a field nobody reads with these eyes, and it arrives from the same
place the papers do.

**A content security policy is what actually holds.** With `script-src
'self'` and no `unsafe-inline`, an injected `onload=` does not run even
if one gets through. It covers the places a future reader forgets to
sanitise, which sanitising one call site at a time never will. Worth a
plug whatever the renderer does.

**A drawing goes in an `<img>`, never inline.** An inline SVG is part of
the document: its scripts run, its stylesheet is global — the exported
ones carry bare `text`, `path` and `circle` selectors, which restyled
every diagram on the page and the mark in the band — and its ids collide
with the page's. Inside an `<img>` it is its own document: no script, no
outside fetches, no reach into the parent. `insertAdjacentHTML` is not a
defence: it declines to run a `<script>` element, but an `onload`
attribute fires all the same. GitHub arrives at the same place from the
other side — it renders SVGs and disables their scripting and animation.

One consequence worth knowing, since the mock showed it as a limit rather
than a choice: its Files sheet could draw a file the cartridge *created*,
because the patch of a new file is the whole file, and not one it
*edited*, because a patch is only what changed. The console has git,
so it has both blobs: its Files screen draws either face through
`/blob/REV/PATH`, and the gap is closed there.
