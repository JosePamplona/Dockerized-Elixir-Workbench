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

**What hex says of a package, asked for.** The Box screen's third
panel, under Specs — beside what the box opens and what it raises —
reads the project — what the box brings, what `mix.exs`
pins, what `mix.lock` resolved — off `mix workbench.status`, offline.
Beside it, on a press, what hex.pm says of each package: its latest
stable release, how long since that was published, how much it is
downloaded (`Console.Hex`, `:httpc`, the client `Console.Installers`
already uses for the same host). It is held in `Console.Bench` by
package name, under the rule the stacks and the installers already
follow — no clock, no read at mount, only a reader pressing — so a
package another box already brought is answered from memory. The panel
is a table with a header — package, brings, pins, locked, latest,
released, downloads — because each column is read off a different place
and a reader compares down a column, where a tooltip can only be read
one at a time. The three hex columns are unlit until somebody asks, say
*not read* with the reason when hex does not answer, and the latest is
marked when it is the version the project runs. The name carries hex's
own mark — vendored under `priv/static/images/vendor/` with its note,
not hot-linked from a hashed asset that changes under us — and opens
the package's page; the locked version opens that version's
documentation. The reading is asked for with the square the
configuration already carries for the Docker tags and the phx_new
releases. The date is the reading that matters: it is what
says whether a dependency is alive, and it is the fact a paper
otherwise carries by hand.

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
card reads `PROJECT_NAME`, `WORKSPACE_PATH` and the stack from there —
the name is a field on the card since 2026-09-26, `./wb.sh new --name`,
and opens with the file's — and
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

**The cluster has no data.** Replica addresses, node names, the
host port of each replica, who is connected to whom — every value on
that table is invented in the mock, and the status's containers carry
only Service, State, Health and Image. Either the fast status carries
the published ports (`compose ps` has them) and the address (`inspect`
has it), or the reading is built on its two probes and nothing else.
Decide which before drawing the table. *Settled by dropping the
question (2026-09-26): the console does not read the cluster at all.
It was a screen on the rail, a box under the `scaled` row for a day,
and then gone. Four of the five things it showed are elsewhere — the
addresses and the published ports on Docker and on the Deploy sheet,
the rpc shell on Terminal, `Node.list()` two keystrokes into an
`app1 · rpc` session — and the fifth, four requests through the
balancer reading `X-Served-By`, is a demonstration and not a reading:
it needs a scaled deployment up, which is what the reader it was for
does not have. Its cost was the console running commands of its own,
outside the jobs it hands to `wb.sh` — the one place it did.*

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

## The covers weigh 58 MiB

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
anything that counts replicas — must not see a node that is not a
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

## The console is the toolchain, settled on 2026-09-04

The console began as a page over `wb.sh` and became a container of its
own — on the toolchain image, since it drives Docker and reads the
package. Which left a waste in plain sight: `wb.sh`, run *inside* that
container, went on starting a sibling container on the same image, with
the same mounts, to run `mix` and `git` it had at hand. Every `add` of
a collection of N members cost about 4N container starts (one compose
one-off per insert, which also waited for the database, and three
`docker run` of git per commit); `new` cost two runs and three of git.
And a second waste under it: the resident compiled the workspace from
its host path while the app compiled it from `/app/src`, and Mix keys
its manifests on the source path — one `_build` volume, two builds.

Four alternatives were weighed. Reimplementing the verbs in the console
duplicates the logic and was refused. Running `wb.sh` always inside
the console image, with a launcher on the host, is the cleanest end
state but a restructuring (the image is built by `new`; the CLI would
pay a container start per command instead of several) — the horizon,
not the step. `docker exec` into the console from the host's `wb.sh`
makes the console being up change where host commands run, and was
set aside. What was done: **one runner that decides where it runs**,
the shape `git_read` already had.

| Runner in `wb.sh` | In a container (the host, as before) | Here, in the console |
| --- | --- | --- |
| `workspace_igniter` — mix of the package on the project | `docker run` on the dev image, workspace at `/app/src` | `mix` in this process, in `/app/src` |
| `workspace_git` — git that writes | `docker run` on the dev image | `git -C /app/src`, same identity through the environment |
| `entrypoint_run` — `new`, `workbench_setup` | `docker run` on the toolchain image | `bash scripts/entrypoint.sh` in this process, from `/app` |
| `entrypoint_run` — `add`, `expand` | `compose run app` (waits for the database, reads `.env`) | the same entrypoint in this process, no compose |
| `package_igniter` — the package alone | `docker run` on the toolchain image | **unchanged**: here it would compile the package through the workbench's bind mount |

Per verb, from the console: `new`, `add`, `eject`, `commit` and `bake`
start no container for mix or git any more (`bake` and `new` still
`docker build`, which goes to the daemon). `expand` and the full
`status` were already the resident's; their `wb.sh` branches serve the
CLI. `setup` and the cold `mix` stay compose one-offs: they need the
pod's network. `up`, `build`, `stop`, `down`, `logs`, `delete`, `ps`,
`iex` and `bash` go to the daemon and were never the question.
`catalog`, `stacks`, `config`, `engine`, `help` and `status --fast`
never started a toolchain container.

What the mapping brought out, each now in the code:

- **The detector is not `command -v mix`.** A host with Elixir under
  asdf would take the in-process branch and compile the workspace in
  place, on the host — the very thing the volumes exist to prevent,
  and a break of "the host needs Docker and nothing else". `git_read`
  may test for git because git only reads. So `./wb.sh console` says it
  explicitly: `WORKSPACE_MOUNT=/app/src`, and with it the host path it
  mounted there and the volume prefix (`WORKSPACE_MOUNT_PATH`,
  `WORKSPACE_MOUNT_PROJECT`). `toolchain_here` checks all three against
  what config.conf names *now*: the container is bound to the workspace
  named when it started, and named another, the runs go back to
  containers, which work for any workspace, instead of into the wrong
  mounts.
- **The console mounts the workspace a second time, at `/app/src`**,
  with the two volumes over it — the app service's own arrangement —
  instead of over the host path. The resident and the in-process runs
  work there, so the app's build is the one they find and add to. The
  console's reads (git, diffs, papers) stay on the host path, which the
  workbench's mount already covers. The workbench itself stays at its
  host path, because what `wb.sh` hands `docker run -v` must be a host
  path.
- **`entrypoint.sh` did not change.** It works from `/app` and enters
  `src`; with the workspace at `/app/src` that is the same path inside
  the console. `mix.exs` resolves the package by `WORKBENCH_PATH`,
  which `toolchain_env` names (and drops the console's own
  `MIX_BUILD_ROOT` / `MIX_DEPS_PATH`, as the resident already did).
- **Colour and identity as `NAME=VALUE` pairs.** `COLOR_ENV`,
  `GIT_COLOR_ENV` and the new `GIT_IDENTITY_ENV` are defined once; a
  container gets them as `--env` (`"${ARRAY[@]/#/--env=}"`), a run
  here through `env`.
- A side effect worth having: when the console kills a job, the signal
  reaches `mix` and `git` directly. A sibling `docker run` could outlive
  the `wb.sh` that started it.

Measured from inside the console, the container branch forced against
the process branch: a container start is 1–2 s here (`status`: 6.1 s →
5.1 s, the Mix boot is the rest); `expand` through compose is 45 s with
the database down and 6.5 s with it up, against 3.4 s in process; one
git call 2.2–3.8 s against 0.06 s. Then the whole thing, on a scratch
workspace (`test_81`, "Scratch Chiefs") with the console bound to it,
2026-09-04: `new` from the page in 70 s, `add chiefs_setup` — 13
cartridges, 13 commits — in **141 s against the 330 s** the same
collection took through containers; **no container created** by either
(the daemon's `docker events` watched throughout), no installer missed
`.env` or the database, the board went to *22 cartridges · 13 the
workbench can eject* on its own once the job ended, and the console's
container peaked at 661 MiB during `new` and 900 MiB during the add —
the project's compile, now in here, with no memory limit set on the
container. The scratch workspace is left for the user to delete.

**The first run found the binding biting.** The console had been
started for one workspace (`test_75`), config.conf was then pointed at
another (`test_80`, another project name), `new` and `add chiefs_setup`
ran from the console — and three things showed at once: the database
and the network came up during the add, the board reported `ansi` and
`clustering` inserted on a project just born, and nothing changed on
it after the collection landed. One cause. `wb.sh` saw the mounts were
not this workspace's (`toolchain_here`) and went back to containers,
as designed — the compose one-offs brought the database up. The
resident did not look: it entered `/app/src` unconditionally, which
was `test_75`, whose `ansi` and `clustering` it reported, and it kept
reporting them since it answers for the project it was started on.
Now `Console.Resident` makes the same three checks (`mounted_here?`)
and, failing them, runs as one container on the workspace's dev image
with its volumes — `Console.Workbench.project/1` reads the name and
the image off the workspace's compose, as `wb.sh` does — and it drops
a resident whose workspace is no longer the one config.conf names
(`follow_workspace`). Verified: bound to `test_75` with config on
`test_80`, the resident came up as `awesome_virtus_workbench_serve_*`
and the board turned to the 22 cartridges of the right project;
`./wb.sh console` again, now bound to `test_80`, and the resident is
back in process at `/app/src`, `wb.sh` in process, no container.

**And the console now says it, with the way out.** Four alternatives
were weighed for the binding itself. Mounting the workspaces' parent
directory solves the path and not the project: the volumes are named
per project and mounted at creation. A long-lived toolchain container
per workspace, used by `docker exec` from the console and the host
alike, removes the binding for good and speeds the host's CLI too (an
exec is a tenth of a second, a run one to two seconds) — the horizon,
at the cost of a container per workspace to keep and to end. An
automatic restart on every change is comfortable and opaque. What was
done: the notice and a button. `Console.Workbench.rebind/0` makes the
three checks on every status; the board's workspace section says
*This console was started for X at Y* and offers *Start again*, which
runs `console` as a job (`Console.Verbs` admits it now). `wb.sh
console`, run from inside the console, cannot replace the container
it runs in — removing it would end the job that asked — so it starts
a helper container on the console's own image, socket and workbench
mounted, that runs `./wb.sh console` from outside two seconds later
and is gone. And `wb.sh console` keeps the port of the console it
replaces (`docker port`), so the address survives and the page
reconnects on its own — a container cannot look for a free port on
the host anyway. Verified both ways with playwright, 2026-09-04:
config pointed at `test_75` from the host, a job run, the notice up,
the button pressed, the new console on 4100 in 15 s bound to
`test_75` and the board on `dolor_sit_amet_gold`; then back to
`test_80`, 10 s, `awesome_virtus` and its 22 cartridges.

## The resident stays, settled on 2026-09-06

The section of 2026-09-02 retires the resident for `:erpc` on the dev
node. It is not going to happen, and the reason it was written for is
gone: the resident compiled the workspace from another source path
through the bind mount, and the revision of 2026-09-04 put it in the
console's container, at `/app/src`, on volumes. What `:erpc` would
still buy — one BEAM less, `iex` on the app's node — costs a
distributed dev node with a name and a cookie in the compose and the
entrypoint, the console joining the workspace's network, the cookie
shared, the OTP pinned once the console is a release, and a regression:
with the app down, nothing could say what the project carries. The
resident answers with the app down. Distributing dev to ask it a
question is the wrong shape; the right one passes through the prod
Dockerfile, and dirties the project with the workbench's environment.

What was wrong, and is fixed, is narrower: two BEAMs compiling into one
`_build` — the app service and the resident, and with it every `mix`
the console runs in-process on the workspace. Since 2026-09-06 the
workbench compiles into a volume of its own, `<project>_workbench_build`,
mounted over `_build` in the console's container and in every one-off
run of the workbench (`add` no longer runs as the compose's `app`); the
app's `build` volume is the app's alone. Both sides share `deps/`:
sources only, and Mix locks the deps directory since 1.18, which
`stacks use` and `new` now require. The price is a second incremental
compile of what an insert changed, a build's worth of disk per
workspace, and the first `up` after `new` compiling the project once
more. `:erpc` stays on the shelf for the terminal's `iex`, if ever, on
its own merits.

## The project's pages are served by the console, settled on 2026-09-20

ExDoc's site and ExCoveralls' HTML report were served by the project:
exdoc planted a pipeline, a `Plug.Static`, an `ExDocController` and the
`/dev/docs` routes in the project's router, and `coverage --exdoc` a
`/docs/cover` action on that controller — the workbench's reading
carried by the project, for the workbench's reader, and only in dev,
only with the app up. It is the contract [no contract back] refuses.
**Decided:** the console serves them off the workspace, where they
already are, and the project serves nothing for it.

**What the project owes: nothing.** `mix docs` writes `doc/`,
`mix coveralls.html` writes `cover/` — the tools' own output, gitignored,
on the disk the console has mounted at `/app/src`. The console reads
the files as they are. The docs can be read with the app down, with
prod or scaled up, with no `dev_routes`.

**On an origin of its own.** Those pages carry the project's
JavaScript. On the console's origin that script could read the page
that runs `wb.sh --yes`. `ConsoleWeb.Reports` is a second Bandit
listener on the port beside the console's (4001 in the container;
`wb.sh console` publishes it on `127.0.0.1`, the next free port after
the console's, kept across a start-again), read-only (GET, HEAD), the
loopback names only (a rebound DNS name gets 421), never framed.
Another port is another origin, and ExDoc keeps a real one: its search,
its `localStorage`, its theme work as on HexDocs — verified on
2026-09-20 against tunez's site, 131 hits for a search, the theme kept
across a reload, no console errors. A `sandbox` CSP on the console's
own port was the alternative, and it gives the page an opaque origin,
where `localStorage` throws.

**What the prototype found in the console.** `check_origin:
["//localhost", "//127.0.0.1"]` compares the host and not the port: a
page on `localhost:4132` opened the console's socket. It could mount
nothing — the signed session is in the console's page, unreadable
across origins — but the first fence was open. The check names the
port now, the one the browser sees (`CONSOLE_PUBLIC_PORT`, which
`wb.sh console` passes, since Docker publishes 4000 on another).

**A door of a third kind: the output.** A cartridge declares
`{label, {:output, dir, index}}` — `{"docs", {:output, "doc",
"index.html"}}`, `{"coverage", {:output, "cover", "excoveralls.html"}}` —
beside the routes (violet, on the app's port) and the ports (blue, the
compose's). It is green (`addr-output`): a page on disk, which answers
whether the app runs or not. It is not knocked: what it has to say is
when it was built — the day and the time and nothing more,
`2026-09-22 18:18`, read off the index's mtime on the machine's own
clock and attached where a route has its HTTP code: a page on disk is
read against the project of that moment, and the hour alone left the
day to be guessed. It carried the offset too until 2026-09-25 (the same
mtime read local and UTC, their difference), which said nothing the
reader did not know: the clock is theirs. Unlit, with the reason, while nothing is
built — and after the reading, the one thing to do: **build**
(the word *built* beside the stamp was the same fact said twice: the
stamp is there or it is not), which runs the command the cartridge
names (`build:` in its door, `./wb.sh mix docs`) as a job. Built, the
button stays beside the stamp as the rebuild (2026-09-25): a page is
written again as often as the project moves. The
listener serves `/<label>/` from the dirs the inserted cartridges
declare, and nothing else of the workspace — `.env` is in it.

**Open.**

* **Where the project moved the output.** tunez writes its docs to
  `priv/static/doc` (`docs: [output: …]`); a `coveralls.json` may name
  another `output_dir`. The door says the tool's default, and a project
  that moved it reads *nothing built*. The fix is the cartridge's
  `state/1` reporting where the output lands — exdoc reads `mix.exs`,
  coverage reads its json — as a fact and not an option, which the
  Record's parameters column has to learn to tell apart.
* ~~**Building it from the door.**~~ *Done on 2026-09-22:* a door on
  disk carries `build:`, the Mix task of the project that writes it —
  exdoc `docs`, coverage `cover` where the docs site takes the report
  and `coveralls.html` otherwise, the first whose condition holds. The
  unlit door shows it as a button and runs `./wb.sh mix <task>`; the
  workbench never invents a command, and no cartridge learns one for
  the console's sake.
* ~~**The boxes.**~~ *Done on 2026-09-21:* exdoc v0.2.0 plants no
  router, controller or `doc/` dummies, and dropped `--version` and
  `--auth0` (the token page needs the app's origin; auth0 is archived);
  coverage v0.4.0 links the report and the report page by relative
  paths, which hold under the console and under a v0.1.0 project's
  `/dev/docs` alike. No `exdoc_tied` copy: git keeps v0.1.0.
* **Symlinks** under an output dir are followed.

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
   for a release, which is where `Node.list()` is asked since the
   console stopped reading the cluster itself); the cluster off the
   status's addresses and its two probes run by the console — retired
   whole on 2026-09-26, see *The cluster has no data* above; the figure
   viewer in the client, one shape, since a drawing is an `<img>`.

What is not built yet stays on the screen as `.unlit`, with the reason —
as the mock already does with Project and Cluster. A tab that is missing
teaches nothing; a tab that says why it is dark teaches what the console
is going to be.
