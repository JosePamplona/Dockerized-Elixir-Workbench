# The console

A Phoenix LiveView page that shows the configured workspace and drives
the workbench: the board on the left (workspace, containers,
deployments, git, what is inserted), the screens on the right (Deploy,
Logs, Project, Cartridges — the shelf of boxes), and the jobs tray at
the bottom, where every command lands with its output and exit code.

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
| `Console.Project` | the project's own README, CHANGELOG and `.env`, the last with its secrets masked before it leaves the module |
| `Console.Cluster` | the two probes of the Cluster screen, run by the console: four requests to the balancer, `Node.list()` through the release's rpc |
| `Console.Papers` | a box's README, DESIGN and CHANGELOG off the mount, rendered by MDEx with the HTML in them left out, links rewritten to what the console opens |
| `Console.ANSI` | a line of `wb.sh` output as safe HTML, its colours kept as spans |
| `ConsoleWeb.Plugs.CSP` | the content security policy, with a nonce per response |
| `ConsoleWeb.ConsoleLive` | the page: the screen in the URL (`/deploy`, `/jobs`…), what arrives, what the reader does |
| `ConsoleWeb.Board`, `Deploy`, `JobsScreen`, `Shelf`, `Box`, `ProjectScreen`, `Cluster`, `Terminal`, `WorkbenchDrawer` | the rail, the screens, the box in hand and the workbench's drawer, one module each |
| `ConsoleWeb.Refs` | the house's notation as components: the mention, the door, the probe, the chip |
| `ConsoleWeb.Cartridges` | what the page works out of the status and the catalog about a cartridge |
| `ConsoleWeb.CoversController` | serves the box covers from `assets/covers` |
| `ConsoleWeb.FiguresController` | serves what a paper shows — the diagrams — as images, never inline |
| `ConsoleWeb.BlobController` | a file as a commit of the workspace has it, for the images on the Files screen |

The client keeps the reader's arrangement — the rail's width, the
ground, the clock, the wb.sh line's history and Tab completion — in
`assets/js/hooks.js` and this browser's `localStorage`.

Styles: one stylesheet, `priv/static/assets/css/console.css`, written by
hand and shared with the mock — `mock/build.py` inlines it, the console
serves it as it is — beside `tokens.css` and `components.css`, which
`assets/design/build.py` projects there from the house tokens. The mock
stays the place to try an interaction before it is built here.

The console is published on `127.0.0.1` only and keeps the origin check
on in dev: it drives Docker and wipes workspaces, and no page the reader
visits while it is up may open its socket.

## The terminal

Line-oriented, as the mock drew it: `docker exec -i` (or `docker run
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

## Not verified yet

The Cluster screen — the table off the status's addresses and
publishers, the two probes — is built but was not seen against a
scaled deployment with clustering inserted; the workspace at hand has
neither.

What to settle before that porting starts — the contracts `wb.sh` still
owes the console, what belongs to the client, and the order to build in
— is in [`PLAN.md`](PLAN.md).

### What to settle when the documents are ported

Both are about rendering, in a page, content the console did not write —
a cartridge's papers and the files its installer produced. Neither costs
anything if it is decided up front, and both are expensive later.

**Markdown must escape the HTML in it.** The mock renders a cartridge's
README with `marked`, which dropped its sanitiser years ago and passes
raw HTML straight through: a README carrying `<svg onload="…">` or
`<img onerror="…">` runs it. In the mock that is nobody, since the
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

**The manifest's option docs go the same way.** Not only the papers: the
mock renders each option's `doc` through `marked.parseInline` as well. It
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

One consequence worth knowing, since the mock shows it as a limit rather
than a choice: its Files sheet can draw a file the cartridge *created*,
because the patch of a new file is the whole file, and not one it
*edited*, because a patch is only what changed. The console has git,
so it has both blobs: its Files screen draws either face through
`/blob/REV/PATH`, and the gap is closed there.
