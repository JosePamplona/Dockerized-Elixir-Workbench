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
Manual/Design/Changelog tabs and the figure viewer — all in the mock,
ported one at a time.
