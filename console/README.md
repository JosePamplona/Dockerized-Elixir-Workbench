# The console

A Phoenix LiveView page that shows the configured workspace and drives
the workbench: the board on the left (workspace, containers,
deployments, git, what is inserted), the screens on the right (Deploy,
Logs, Project, Cartridges — the shelf of boxes), and the jobs tray at
the bottom, where every command lands with its output and exit code.

```sh
./wb.sh console          # builds its image if missing, starts it: http://localhost:4100 (first free port from 4100)
./wb.sh console logs     # follows its output (the first run compiles it)
./wb.sh console down
./wb.sh console build    # the image again — the Docker CLI in it follows the host's
```

## How it runs

As a container (`console/Dockerfile`: the workbench's toolchain image
plus the Docker CLI and the compose plugin), with two mounts: Docker's
socket, and the workbench itself **at the same absolute path as on the
host** — the relative paths of `config.conf` and the composes' bind
mounts then mean the same thing to the daemon whichever side asks. It
runs as the host user, in the socket's group, with the source mounted
and `mix phx.server` reloading on change.

## What it is made of

The console does not reimplement the workbench. Two contracts and one
verb:

* `./wb.sh status --json` — the board; read again after every job.
* `./wb.sh catalog --json` — the shelf, each box's options, what it
  builds on, what follows.
* `./wb.sh --yes …` as a **job** (`Console.Jobs`): one at a time, its
  output streamed line by line over PubSub to the tray.

| Module | Role |
| --- | --- |
| `Console.Workbench` | the workbench's directory, `wb.sh`, the JSON contracts |
| `Console.Jobs` | the job queue: a `Port` per command, broadcast on `"jobs"` |
| `ConsoleWeb.ConsoleLive` | the page: board, tabs, box modal, tray |
| `ConsoleWeb.CoversController` | serves the box covers from `assets/covers` |

Styles: the mock's (`mock/console.template.html`) with the house tokens
(`assets/design`), in `priv/static/assets/css/app.css`. The mock stays
the place to try an interaction before it is built here.

## Not yet

Live logs, the Project tab (README, CHANGELOG, `.env`), the workbench
modal (manual, changelog, config), the New project card, the box's
Manual screen (README, DESIGN, CHANGELOG) and the figure viewer — all
in the mock, ported one at a time.

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
*edited*, because a patch is only what changed. GitHub renders both,
having the two complete blobs. Closing that gap is a change to the
capture — `--diffs` would have to store the contents, not only the patch
— not to the page.
