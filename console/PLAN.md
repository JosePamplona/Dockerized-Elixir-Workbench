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
the workbench drawer edits it as a form. **Open:** whether the console
writes the file directly (it is the workbench's own file, on the mount)
or goes through `wb.sh config --set`. Direct is simpler and honest —
nothing about `config.conf` is workspace state — but then the console
owns a writer for a file `wb.sh` parses, and the two have to agree about
quoting.

**Logs.** `wb.sh logs` exists but not in a shape the console can follow
per service. **Open:** whether the console runs `docker compose logs
--follow` itself through the socket it already has, or whether `wb.sh`
grows a mode for it. Running it directly is the smaller change and the
console already holds the socket; the cost is one more place that knows
how the composes are named.

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

## What belongs to the client

The mock is all client, and some of it must stay there. The rule, written
once so it is not decided again per screen:

* **The client owns the reader's arrangement**, in a hook and
  `localStorage`: the rail's width, the band's position, the ground, the
  open tab, the face of the box in hand, the viewer's zoom and pan, the
  logs' follow / level / search, whether a job is unfolded.
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

It comes last in the order, but it is a real module, not glue.

## The order

1. **The contracts, the policy, the origin, the single stylesheet.**
   Nothing visible; everything else stands on it.
2. **Board, Deploy, Jobs** to parity with the mock: the New project card,
   the Deployment card with its replicas and its balancer, the
   confirmations.
3. **Logs**: the stream and the hook.
4. **Cartridges**: the box, the papers, Installation with `expand`.
5. **Files**: `Console.Diffs`, through the highlighter that exists.
6. **Project, the workbench drawer** (config as a form), **the terminal,
   the cluster.**

What is not built yet stays on the screen as `.unlit`, with the reason —
as the mock already does with Project and Cluster. A tab that is missing
teaches nothing; a tab that says why it is dark teaches what the console
is going to be.
