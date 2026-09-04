# From the mock to the console

`mock/workbench-console.html` is not a maquette of how the console
should look. It is a specification of how it behaves: which gesture
belongs to which screen, what a job says while it runs, what the box in
hand shows and in what order, which of the workbench's facts the reader
is allowed to change from the page. Porting it is mostly transcription.

What follows is what to settle **before** transcribing — the decisions
that cost an afternoon now and a rewrite later — and the order to build
in. Where a decision is genuinely open it says **Open**; everything else
is a recommendation with its reason.

One correction to "mostly transcription". The mock's 2,500 lines of
script **mutate their own state optimistically**: every `onDone` writes
`e.installed = true`, invents a sha, moves `state.git.head`, marks the
containers healthy six seconds later. None of that is written in the
console. Everything the mock mutates by hand — installed, a cartridge's
state, the inserts, the head, what is baked, the containers — is
**re-read from the status** after the job, and the page is what the
status says. The port replaces "the client knows what happened" with
"the server asks again", and that is what decides how much status is
needed and when (below).

## What the mock is as a source, and where it lies

`mock/build.py` reaches into the repository for everything the two JSON
contracts do not carry: each cartridge's README, DESIGN and CHANGELOG;
the workbench's own README, CHANGELOG and `config.conf`; the workspace's
README, CHANGELOG and `.env`; the covers; the diffs, captured off a
workspace's git. In the mock that is free — it runs from the repository
root with the whole tree under it.

The console has the workbench mounted at the same absolute path, so it
*can* read those files too. But `console/README.md` says the console is
made of two contracts and one verb, and documents, config, diffs and
logs do not fit in that sentence. Either the sentence grows or the
contracts do.

**Open.** Which. The recommendation is: facts about the *workspace* go
through `wb.sh` (it already knows how to ask the igniter package on the
project, and the console must not grow a second opinion about what is
installed); files that belong to the *workbench itself* — the
cartridges' papers, `config.conf`, the covers — are read off the mount,
as `CoversController` already reads the covers. The line is between
"what is true of this project" and "what this workbench ships".

## The contracts that are missing

Four, and the first one blocks the first screen.

**The catalog and the status die without a project.** `wb.sh catalog`
terminates with *There is no project* (`wb.sh:1713`), and so does
`status` (`wb.sh:1725`). But the screen the mock draws for an empty
workspace — the New project card — reads the base cartridges off the
catalog (`BASE = CATALOG.filter(e => e.base)`), and it is the only
screen that means anything at that moment. The catalog belongs to the
workbench, not to the workspace: it should answer always. `status
--json` should return `{"project": null, …}` rather than terminate; it
already has the shape for it, and the mock already renders that state
(`state.project === false`).

**`mix workbench.expand` has no door in `wb.sh`.** A collection's box
must show the recipe as its own options fill it, minus what the project
already carries. The mock computes it in the page and says so in a
comment — *the console proper asks `workbench.expand`*. It needs `wb.sh
expand NAME [args] --json`.

**`config.conf` has no verb.** The mock stages the save. The New project
card reads `PROJECT_NAME`, `WORKSPACE_PATH` and the stack from there, and
the workbench drawer edits it as a form. **Decided (2026-09-02):** `wb.sh
config set KEY=VALUE`, on the writer `stacks use TAG` already has — one
writer for a file `wb.sh` parses, and the save lands in the tray as a job
like everything else. The console reads the file off the mount and never
writes it.

**Logs.** `wb.sh logs` exists but not in a shape the console can follow
per service. **Decided (2026-09-02):** the console runs `docker compose
logs --follow` itself, by the project name the status gives — the
three composes share it, so no compose file has to be named and no
deployment has to be baked. The smaller change, and the console
already holds the socket.

Three more, smaller, found by reading what the page works out for itself
that the contracts never told it.

**Which deployment is up.** The mock guesses it off the image tags
(`:local`, `-prod`, `app\d+` in `deploymentUp`). The status should say
it: `deployment: "dev" | "prod" | "scaled" | null`. In the same spirit,
`insertedArgs` reconstructs a cartridge's options by parsing the subject
of its insert commit; `git.inserts[].argv` costs the status nothing and
spares the console a parser of commit subjects.

**The Cluster screen has no data.** Replica addresses, node names, the
host port of each replica, who is connected to whom — every value on
that table is invented in the mock, and the status's containers carry
only Service, State, Health and Image. Either the fast status carries
the published ports (`compose ps` has them) and the address (`inspect`
has it), or the screen is built on its two probes and nothing else.
Decide which before drawing the table.

**NEED has two owners.** The catalog already carries `need` (`line`,
`body`), and the mock parses NEED.md itself into the four parts the Box
screen prints — the want, Before, After, Not for. The catalog should
carry the four; the console must not parse Markdown with regular
expressions to find them.

## `--yes`, and the two verbs that cannot be taken back

`Console.Jobs` passes `--yes` to every command. `new` over a workspace
that has a project overwrites it; `delete` wipes it. In the mock the
confirmation is a red button that appears before the click, which is
right — but a confirmation that lives only in the page is a confirmation
any page can skip (see Security). The server owns it: a destructive verb
is queued as *pending* and runs on a second, explicit event, or not at
all.

That asks for a `kind` on the job — `{:up, "scaled"}`, `{:insert,
"rest"}`, `:delete` — rather than the regular expression over `cmdline`
the mock uses to know whether a deploy is in flight. The kind is also
what routes a job's output back to where it was asked: the insert's log
lands in the box's own drawer because the job says which box it is.

## What is read again, after what

The split of the status into a fast one and a slow one (below) is only
half the rule; the other half is which one follows which job.

| After | Read again |
| --- | --- |
| `up`, `stop`, `down`, `build` | the fast status; the log stream restarts on the deployment that is up |
| `add`, `eject`, `commit` | the slow status (what the project carries), git |
| `new`, `delete` | everything: both statuses, the project's papers, the log buffer emptied, the catalog's installed marks |
| saving `config.conf` | the New project card (it reads the file) |

And one change that no job announces: a container going from `starting`
to `healthy`. The mock fakes it with a timer. The console needs either a
poll of the fast status while something is `starting`, or `docker events`
on the socket it already holds. The poll is a line; the events are the
right answer and can come later.

## What reading the bench costs, and why it shapes the LiveView

`status_json` starts a container and boots Mix to ask the igniter
package: seconds. And it mixes that with what is cheap — the ports, `docker
compose ps`, git — in a single call. `ConsoleLive` re-reads the status
after every job, so today every `up` leaves the board frozen for as long
as a Mix boot takes.

Split it before building: a fast status without the igniter (containers,
ports, git — tenths of a second) for what changes all the time, and the
expensive one only after an insert or an eject, which is the only thing
that changes what the project carries. And cache the catalog in a
process: it changes when the workbench changes, never when the workspace
does.

While the slow one is in flight the board keeps what it has and says it
is reading — which `ConsoleLive` already does with `reading:`. That part
is right; it just asks for too much, too often.

*Found on 2026-09-02, once the port was whole:* the page was still
asking the full status and the catalog on every mount — every reload,
every tab — and each reading was its own container. Measured on the
workspace at hand: the container start is 3 s of the 7 the full status
costs, Mix is the rest; running the task inside the app container by
`exec` would save the 3 s only while dev is up, and the package is not
mounted there. The fix is not to ask: `Console.Bench` holds the status,
the catalog and the recipes once for every page, a mount reads memory,
the full status runs only after the jobs that change what the project
carries, the catalog only after `new`, `delete` or a change in the
features directory, and a reading in flight is shared, never doubled.

*And then, the same day, the rest of it.* Docker's VM ran out of memory
twice even so: each question to the project was still a fresh BEAM
compiling it in a fresh container, and `expand` brought the database
up with it. Two decisions:

**The console carries the package.** `workbench_igniter` is a path
dependency of the console, so the catalog — the manifests, nothing of
a project — is a function call in the console's BEAM. One project for
the two was considered and refused: the package is a dependency of
every *generated* project, and merging would drag Phoenix, LiveView
and the rest of the console into each of them.

**The project gets a resident.** Igniter compiles and loads the
project it reads (`Igniter.new/0` runs `compile`; verified against a
foreign project: it fails on the project's own compilers, and would
load the project's Phoenix beside the console's if it did not). So the
project is read in its own BEAM — but one, kept: `mix workbench.serve`
answers `status` and `expand` on stdin/stdout, forgetting Mix's ran
tasks before each so what an insert wrote is compiled again,
incrementally. `Console.Resident` keeps it on a Port: inside the
console's container as a process beside it (the image is the
toolchain, the workspace's dev image is an alias of it, so they share
`_build`; `WORKBENCH_PATH` in the environment resolves the project's
path dependency), or, on a host running the console by hand, in one
long-lived toolchain container (128 MiB resident, measured). Dropped
on `new` and `delete`.

## What belongs to the client

The mock is all client, and some of it must stay there. The rule, written
once so it is not decided again per screen:

* **The client owns the reader's arrangement**, in a hook and
  `localStorage`: the rail's width, the band's position, the ground, the
  face of the box in hand, the viewer's zoom and pan, the logs' follow /
  level / search, whether a job is unfolded.
* **The URL owns where the reader is**: the open tab, the box in hand,
  the drawer's screen and the paper on it — through `handle_params`, so
  a refresh keeps the place and the back button means something. The
  mock keeps none of this and loses it on reload; that is the one habit
  of the mock not to port.
* **The server owns the workbench's facts**: the board, the catalog, the
  jobs and their output, the rendered papers.

The case that decides it is the log viewport: two thousand lines with a
search box. If the filter lives on the server, every keystroke
re-renders two thousand nodes across the socket. The server pushes
lines; the hook keeps them and filters them. The terminal is the same
shape.

## The terminal

`console/README.md` says xterm.js in the page and Docker's exec API over
the socket. The terminal the mock actually drew is **line-oriented**: an
input, a screen, `↑↓` history, Tab completion against a trie. That needs
no pty and no xterm.js — `docker exec -i` on a `Port` is enough. A real
TTY (Ctrl+C, colour, iex's own readline) needs the hijacked stream of
Docker's HTTP API, which is a project of its own.

Recommendation: keep the line-oriented one the mock already tried, and
correct that paragraph of the README when it is settled. Left as it
stands, it is an unplanned week.

Verified (2026-09-02): `iex` on a piped stdin works line by line, with
its prompt and its bindings. `bin/<app> remote` is not offered: it
stops the node when its input ends, and a page closing is an input
ending. A release replica gets bash and `rpc`, one expression per line.

## Security

Three of these are already written down in `console/README.md` and stay
right: a Markdown renderer that escapes by default, a drawing inside an
`<img>` and never inline, a content security policy. Two precisions and
one addition.

**The policy goes in on the first day.** With LiveView it needs a nonce
on the layout's script; retrofitting it means touching every template.

**The figure viewer follows from the `<img>` rule.** The mock's viewer
manipulates the SVG inline: it reads the `viewBox`, asks the element for
`createSVGPoint`, and rewrites every id in the copy so two figures on one
page do not resolve `url(#id)` to each other's markers. Inside an `<img>`
there is no viewBox to touch — and none is needed: an `<img>` of an SVG
is rasterised at its CSS size, so zooming by width and height stays
vector-crisp, and the id collisions go away because the document is
isolated. `uniqueIds` is not ported. It is a simplification, but only if
it is done that way from the start.

**And the one that is not written down yet.** The console runs in `dev`,
with `check_origin: false` (`config/dev.exs:14`), listening on
`0.0.0.0`. `handle_event("run", …)` splits a string from the client and
hands it to `wb.sh`. Any page the user visits while the console is up can
open the socket to `localhost:4100` and send `delete`. The console drives
Docker and wipes workspaces: it wants `check_origin` on, `127.0.0.1`, and
a named set of verbs rather than free-form argv.

**Name the Markdown renderer, and the test that keeps it honest.** "Both
of the usual Elixir ones escape" is not a decision. The plan names one
and the option that makes it escape, and the first test of the papers
is a README carrying `<img onerror=…>` that comes out as text. The
diagrams a paper references (`![…](x.svg)`) go in an `<img>`, so they
need a route of their own — `/features/:name/*path`, read off the mount
the way `CoversController` reads the covers.

## The console is in a container, and `localhost` is not the app

The doors are opened by the browser, on the host, where
`localhost:<port>` is the app: fine. The probes (`{path}/live`,
`{path}/ready`) are called by the **server**, and from inside the
console's container `localhost:4000` is the console's own network
namespace, where nothing answers. The mock never calls a probe, so it
never met this.

**Decided (2026-09-02):** `./wb.sh console` adds
`--add-host host.docker.internal:host-gateway`, and the console probes
`host.docker.internal:<port>` while the doors stay `localhost` for the
browser. The smallest change, and the same on Linux and Docker Desktop;
`network_mode: host` would have moved the loopback publish into the
endpoint, and joining the compose network changes with every workspace.

## What a job's output looks like

The mock colours its staged lines by a class it invents — `dim`, `ok`,
`add`, `upd`. The real output is text with ANSI in it, and `Console.Jobs`
strips it (`Workbench.strip`). Keep the ANSI and turn it into spans
instead: the workbench already colours its own output on purpose, the
conversion exists for the box-backs' screenshots, and stripping it is
throwing away the only classification there is.

And the lines never ride on the job. They did: every line the port
wrote put the whole job on the topic and every page rendered every
line of every job again — quadratic, and a `new` of two thousand lines
left the page deaf to the reader's clicks, queued behind the renders.
`Console.Jobs` holds the output and broadcasts it as `{:job_lines, id,
from, html}`, a batch every 50 ms; the `JobLines` hook writes it into a
`phx-update="ignore"` element, on the Jobs screen and in the box's
drawer alike, and asks for the backlog when it mounts. The same rule
the Logs screen already followed.

## The covers weigh 58 MB

The mock scales every cover to 560 px JPEG at build time. The console's
`CoversController` serves the originals — a cover is around a megabyte —
and the shelf shows thirty-two of them. The console has no image
library, and should not grow one for this: the covers pipeline
(`assets/covers/covers.py`) emits a web size beside each sealed face, and
the controller serves that.

## One stylesheet

`priv/static/assets/css/app.css` is 495 lines written by hand; the mock's
is about 845 plus the generated tokens. They have already drifted. Two
copies means the console trails the mock forever.

Lift the CSS out of `console.template.html` into a file of its own, have
`build.py` inline it into the mock and have the console serve it as it
is. The house tokens already arrive the same way in both.

## `Console.Diffs`

The two hundred lines of Python in `build.py --diffs` are not the mock's
scaffolding — they are the specification of a module that does not exist
yet: the walk over the insert commits with their reverts, a collection's
range and why it is only honest when its members are contiguous, both
faces of every file because a patch cannot be handed to a lexer, and
which lines of each face the patch actually asks for. `Console.Highlight`
is already on the other side waiting for it.

Two things not to port as they are. `split_lines` balances the open
spans by hand across Makeup's output because Python only had the HTML;
Elixir has the tokens, so the file is lexed once and emitted line by
line from them. And the raster thumbnails (WEBP, scaled with PIL) become
a route that serves the blob out of git as it is — a logo beside a diff
needs no resizing on the server, only a `max-width`.

It comes last in the order, but it is a real module, not glue.

## The architecture, settled on 2026-09-02

Docker Desktop's VM fell twice more with the resident in place, and its
logs said why: `virtiofsd exited with status -1` — the daemon that
serves the bind mounts, not a container out of memory (the host had
17 GB free). Compiling through a bind mount is the load VirtioFS bears
worst, and everything here compiled through one. The architecture was
read again against how Livebook, Tidewave and LiveDashboard do the same
job — none of them starts a runtime per question; they attach to, or
run inside, the application's own — and settled as follows.

| Piece | Where | What |
| --- | --- | --- |
| `wb.sh` | the host, bash and Docker only | the one implementation of the verbs |
| the console | a container on the toolchain image, as a **release** | the LiveView; carries the igniter package; mounts the workbench and the socket |
| the dev `app` | the workspace's compose | the project compiled and running, with a node name, a cookie and the package mounted: **the runtime the questions go to** |
| volumes | inside the VM | `_build`, `deps`, `node_modules` of the workspace and of the console; the bind mount carries source only |

How they talk. *Actions* (`new`, `add`, `up`, `delete`…): the console
runs `wb.sh --yes` as a job, `wb.sh` runs `docker` — short processes,
as today. *Questions to the project* (what it carries, what a box would
insert): the console connects to the app's node by distribution and
calls the package there with `:erpc` — no BEAM started, nothing
compiled, milliseconds; the resident goes. *Questions to the workspace*
that need no Mix (containers, ports, git, diffs, papers, `.env`):
`wb.sh status --fast` and file reads, as today. *Catalog*: a function in
the console's BEAM. *Logs*: `compose logs --follow`, as today.
*Terminal*: bash by `docker exec -i`; `iex` becomes remote evaluation
on the app's node, as Livebook's attached runtime. *Network*: the
console joins the workspace's compose network by name — distribution
asks for it, and the probes get their host with it.

**The console connects `-hidden`, and this is not optional.** Erlang
distribution is transitive: a visible node that dials one replica ends
up in the mesh of all of them. Measured with three nodes, 2026-09-03 —
a visible `probe` connected only to `app1`, and `app2`, which nobody
dialled, answered `Node.list() == [app1, probe]`. With `-hidden` the
same connection gives `Node.list() == [app2]` on `app1` (the console
only under `Node.list(:hidden)`), `app2` never hears of it, and
`:erpc.call/4` works exactly the same. It is what `iex --remsh`,
`observer` and Livebook's attached runtime do, and for this reason:
everything that iterates `Node.list()` — `pg` and Phoenix.PubSub with
it, `:global`, a quorum count, LiveDashboard's node picker, the
console's own Cluster screen — must not see a node that is not a
replica.

The clustering cartridge does not collide with this, and it is worth
writing down why, because the two look like they should. It is
DNSCluster, and it is `:prod` only: the block goes inside the `:prod`
of `runtime.exs`, `DNS_CLUSTER_QUERY` is written only into the scaled
compose, and `rel/env.sh.eex` is read only by the release. The
questions go to the **dev** node, and only one deployment is up at a
time — so where there is a cluster there is no dev node to ask, and
where there is a dev node there is no cluster. Discovery cannot cross
either: DNSCluster only calls `Node.connect/1` on the IPs its query
resolves to, and the console is in no DNS record. Two things this
leaves standing, both about the console and not about the cluster:
distribution means sharing the app's cookie, so the console asks the
dev node and no other — pointing it at `prod` or `scaled` would be
handing it the cluster's key; and once the console is a release with
an image of its own, the OTP on both ends stops being guaranteed by
the shared toolchain and has to be pinned.

When the app is down the console says so: the board, git, diffs and
papers as always; what depends on the project marked `.unlit` with the
reason — the app is down, bring it up to ask it. `Up` is the first act.

Four rules that stay fixed: nothing compiles through the bind mount;
no question starts a BEAM; the host needs Docker and nothing else
(running the console on a host with Elixir was considered and refused
for breaking that promise); `wb.sh` alone writes the workspace and
`config.conf`.

What changes: the dev compose gives `app` a name and a cookie, mounts
the package, and puts `_build` and `deps` in named volumes — as do the
one-off runs of `new`, `add` and the reads, on the same volume names;
`./wb.sh console` joins the console to the workspace's network and
runs the release, `console dev` keeps the reloading mode for whoever
works on the console; `Console.Resident` becomes `Console.Node`;
`mix workbench.serve` retires (`Status.read/0` and `Expand.plan/2`
are what `:erpc` calls). To verify first: `Igniter.new/0` inside the
running app without a full recompile; one node connection per console;
`new` and `add` with `_build` on a volume.

The order: the volumes first — they stop the crashes — then the
release, then the node.

*Volumes, written 2026-09-02, untested while Docker Desktop was down:*
the toolchain image points Mix at `/app/build` and `/app/deps`
(`MIX_BUILD_ROOT`, `MIX_DEPS_PATH`), born owned by the user so a fresh
named volume takes the ownership; the compose declares `build` and
`deps`; every one-off run (`new`, the reads, the package's catalog)
mounts the same volume names; the console's container gets its own
two. **Revised 2026-09-03:** the two variables are gone from the
toolchain. The volumes now cover `_build` and `deps` where Mix looks
for them, inside the source mount, and Mix is told nothing — because
Mix was never the only reader of that path. `phx.new` writes the
conventional `deps/` into `config.exs` (NODE_PATH) and into
`assets/vendor/heroicons.js` and asks Mix nothing, and since phx_new
1.8 daisyUI is a git dependency resolved through that NODE_PATH: a new
project could not build its assets, and the workbench had to patch the
generated lines back. Only the console keeps the variables, for its
own build, because its source has no fixed mount point. `bake` now bakes `Dockerfile.local` again when the seed moved —
keeping the project's stamped installer — and rebuilds the image, so
an existing workspace moves over with `./wb.sh bake && ./wb.sh up`.
Verified on 2026-09-02, late: on Docker Desktop, `test_50` compiled
into `lorem_ipsum_build` and `lorem_ipsum_deps` with the host's
`_build` untouched and the VM at 1.4 GB — and the console's container
took Desktop down again while compiling, the same `virtiofsd` death.
On the host's **native Docker Engine** (`docker context use default`;
the user must be in the `docker` group) the same sequence ran whole:
the workspace up in 90 s, the console's image built, its container
serving on 4100 in 50 s, the resident beside it answering the status,
five containers, 260 MiB for console and resident together, nothing
crashed. The verdict on Desktop for Linux stands: its VM is what
fails, and the README should say Docker Engine on Linux.

Three things learned on the way, each now in the code: the app
service never fetches the package's dependencies (it does not see the
package without the workbench mounted), so every igniter run and the
resident do `deps.get, deps.compile` first — a second once done; Mix
keys its manifests on the deps path, so the resident must see the
workspace's volumes at the *same* paths the app does (`/app/build`,
`/app/deps`) and the console's own build lives under `/app/console`
— **measured on 2026-09-03 and false in its first half**: moving
`_build` and `deps` to another absolute path costs nothing, moving the
*source* recompiles the project. The source path already differs
between the app service (`/app/src`) and the console (the host path),
so that recompile is there either way; the volumes are free to sit
where Mix looks for them;
and the bench remembers a failed first reading so a page mounting
after it asks again instead of waiting forever.

## Open — one word, two things: *installer*

`wb.sh installers` is the verb for the Phoenix generators: the stable
`phx_new` releases, each with the Elixir it declares and whether this
stack can run it. The name is the workbench's own word for that thing
already — the New project card's row is labelled `installer`, `wb.sh`
prints *Phoenix installer: phx_new 1.8.13*, and `Console.Project`
documents *the installer it was born with*. It is also the twin of
`stacks`, down to the second verb it wants: `installers use VERSION`
would write `PHX_NEW_VERSION` the way `stacks use TAG` writes the three.

But the console says *installer* about something else too. A cartridge
that is designed and whose igniter task is not written yet reads *the
box is designed; its installer is not done yet* (`box.ex:66` and the
`not done` chip beside it). Two meanings, and the verb takes the first.

**To settle: what a cartridge's installation is called.** The vocabulary
may already have it — a cartridge's `task.ex` is its *task* everywhere
else in `features/README.md`, so *its task is not written yet* might be
the whole fix. Whatever it comes to, it is two strings in `box.ex` and
whatever the cartridge documents call it, and it should be decided
before the word `installer` is spent on the verb in the help text.

## The order

1. **The contracts, the policy, the origin, the single stylesheet.**
   Nothing visible; everything else stands on it. The contracts are:
   catalog and status answering without a project; the fast status apart
   from the slow one, with `deployment`, the published ports and
   `inserts[].argv`; `expand --json`; the catalog's `need` in four parts.
   The policy is the CSP with its nonce, `check_origin`, `127.0.0.1`, the
   named verbs with their `kind`, and the pending state of the two
   destructive ones. The stylesheet is one file both pages read.
   *Landed on 2026-09-02*: all of it but the network question (the
   console reaching the app's port) and `config.conf`'s writer, which
   stay **Open** above; `catalog` reads off the package when the
   workspace is empty (`package_igniter`, its build under
   `igniter/_build/toolchain`).
2. **Board, Deploy, Jobs** to parity with the mock: the New project card,
   the Deployment card with its replicas and its balancer, the
   confirmations. *Landed on 2026-09-02*: the screen in the URL, the
   rail with the house's references, the three cards, the wb.sh line
   with history and completion, the pending state drawn where it was
   asked, the output coloured off its ANSI. Not yet: the install output
   landing in the box's drawer (it comes with the box, step 4).
3. **Logs**: the stream and the hook. *Landed on 2026-09-02*: the
   console runs `docker compose logs --follow` itself, by project name
   (`Console.Logs`), started again after the jobs that change the
   containers; the hook keeps and filters the lines, as the mock did.
4. **Cartridges**: the box, the papers, Installation with `expand`.
   *Landed on 2026-09-02*: the box and its screen in the URL
   (`?box=rest&screen=manual&paper=design`, so the browser's back is
   the trail back and `uniqueIds`, `trail` and `measureDrawer` are not
   ported); the shelf's planks by state and its list; Box with the
   need and the live specs; Installation with the form, the command,
   Insert and Eject, a collection asking `expand` when picked up and
   when a choice moves, the output landing in the drawer; Manual with
   MDEx (raw HTML left out, tested), the index, links to other boxes,
   diagrams through `/figures/`. Also found on the way: two readers
   of the igniter at once fought over one container name in `wb.sh`
   (fixed: the name carries the pid).
5. **Files**: `Console.Diffs`, through the highlighter that exists.
   *Landed on 2026-09-02*: the module as the Python specified it — the
   walk, the range and its contiguity, who touched what, both faces —
   with the two changes named above (lines cut from Makeup's tokens,
   images served out of git by `/blob/`). The fold of a file is a JS
   command on the client, never a round trip.
6. **Project, the workbench drawer** (config as a form), **the terminal,
   the cluster.** *Landed on 2026-09-02*: Project with the `.env`
   masked in `Console.Project`; the drawer with `config.conf` as a form
   saved through `wb.sh config set`, the stacks asked once, the manual
   and changelog, and Console with the frame in the client; the
   terminal line by line on a Port (`iex` verified without a tty; `rpc`
   for a release); the cluster off the status's addresses and its two
   probes run by the console (not yet seen against a scaled
   deployment); the figure viewer in the client, one shape, since a
   drawing is an `<img>`.

What is not built yet stays on the screen as `.unlit`, with the reason —
as the mock already does with Project and Cluster. A tab that is missing
teaches nothing; a tab that says why it is dark teaches what the console
is going to be.
