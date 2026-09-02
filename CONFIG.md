<!-- markdownlint-disable MD033 -->
# Configuration File

The configuration file `config.conf` configures the projects `./wb.sh new` creates, who signs the workbench's commits, and the service images baked into each workspace. There is no feature configuration here: features are cartridges, inserted on the created project one commit each (`./wb.sh add NAME`; `./wb.sh add chiefs_setup` inserts the workbench's own picks) and listed by `./wb.sh catalog`.

## Project creation configuration

Read by the creation command (`new`): the workspace, the name and the stack the images are built from. Updating them has no impact on an already created project.

The three stack versions are the parts of one `hexpm/elixir` image tag (`ELIXIR-erlang-ERLANG-debian-DEBIAN`). The usable list lives on Docker Hub, not in the file: `./wb.sh stacks` shows the recent ones (`--json` for tools) and `./wb.sh stacks use TAG` checks the image exists and writes the three below.

`PHX_NEW_VERSION` is the Phoenix installer `new` generates with, and it is a choice, not a record. Empty — the ordinary case — and hex decides: the newest `phx_new` release that runs on the stack above (see below), which `new` prints, saying so when that is not hex's very newest. Set it for a standing choice, and `./wb.sh new --phx-new VERSION` overrides it for one run.

What it resolves to is stamped into the workspace's own `Dockerfile.local` (`ARG PHX_NEW`) and read back from there ever after, and the toolchain image is tagged `workbench:<elixir>-<otp>-phx<version>` accordingly. That stamp — not this file — is the source of truth for *which generator made this project*, because it is the generator the base cartridges take their delta with. `new` never writes back here: this line says what the next project gets, never what an existing one got, so two workspaces created months apart keep their own and neither moves under the other's feet.

The installer and the stack have to hold each other, and that pair decides the resolution as well as the check. Every `phx_new` release declares on hex the Elixir it runs on (`~> 1.17` for 1.8.13, `~> 1.14` for the 1.7 line) — a floor, never a ceiling, so nothing about a Phoenix version *derives* an Elixir one. With no version named, `new` walks hex's releases newest first and takes the first this stack satisfies: normally that is hex's newest, at the cost of the one call the check would have made anyway, and it only walks further when the stack is behind. This is a deliberate parting from `mix archive.install`, which takes the newest and nothing else. A version that *was* named is taken as named: `new` refuses it outright if hex does not have that release — a typo has no requirement to weigh against anything, and would otherwise surface three layers into the image build — and refuses a stack below its requirement before the first layer is built. Only a 404 refuses; an unreachable hex judges neither question. `mix archive.install` refuses the same pair, but only inside the image and in its own words; the remedy is here, where the stack and the installer are chosen. Only hex's `~> MAJOR.MINOR` form is read: any other shape, or an unreachable hex, leaves the verdict to mix. Erlang/OTP never enters into it — Phoenix says nothing about OTP, and the Elixir/OTP pairing is already settled by the `hexpm/elixir` tag existing at all.

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `WORKSPACE_PATH` | string | `"./_workspace"` | (`wb.sh` only) Directory where the project is generated, used as the container volume mount point. Relative paths resolve from the workbench directory; any absolute path works. The workbench itself stays permanently in its own directory. |
| `PROJECT_NAME` | string | `"Lorem Ipsum"` | This is the full & main name of the project. It will be used by Phoenix in order to create a new project. It must be capitalized and separated by spaces. |
| `PHX_NEW_VERSION` | string | `""` | The Phoenix installer to generate with. Empty resolves to the newest `phx_new` on hex that runs on the stack below; a version pins it. Never written back: the workspace's `Dockerfile.local` records what a creation actually used. |
| `ELIXIR_VERSION` | string | `"1.17.3"` | Elixir version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `ERLANG_VERSION` | string | `"27.1.1"` | Erlang version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `DEBIAN_VERSION` | string | `"buster-20240612-slim"` | Debian version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |

## Git

The workbench commits what it does to the workspace: the first commit after `new` (the baseline), one commit per inserted cartridge (`Insert FEATURE …`, so `eject FEATURE` can revert that one alone — a collection like `chiefs_setup` leaves one commit per member, none of its own) and the revert itself. The commits run inside the toolchain container — where the project's git hooks can run `mix` — and are signed as this says:

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `GIT_IDENTITY` | string | `"user"` | Who signs. `"user"`: the host's git identity (`git config user.name` / `user.email`) when git is installed and has one, falling back to the workbench's own otherwise. `"workbench"`: always `Dockerized Elixir Workbench <wb.sh@localhost>`. |

## Docker containers specs

There is no host ports configuration: each workspace gets the first available ports at creation (application from `4000`, pgAdmin from `5050`), baked into its own `docker-compose.yml` (`up --deploy scaled` picks its own free ports, one per replica plus the balancer's, when it bakes `docker-compose.scaled.yml`) — that file is the source of truth of the workspace orchestration; edit it to change ports or images. The database is not published to the host: it is only reachable from inside its workspace (the `app` service shares its network namespace). Several workspaces can run simultaneously without conflicts.

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `POSTGRES_IMAGE_VERSION` | string | `"latest"` | _Postgres_ docker image baked into new workspaces.<br/>Available versions: <https://hub.docker.com/_/postgres/tags> |
| `PGADMIN_IMAGE_VERSION` | string | `"latest"` | _PgAdmin_ docker image baked into new workspaces.<br/>Available versions: <https://hub.docker.com/r/dpage/pgadmin4/tags> |
| `NGINX_IMAGE_VERSION` | string | `"alpine"` | _nginx_ docker image used as the load balancer of the scaled deployment (`up --deploy scaled`).<br/>Available versions: <https://hub.docker.com/_/nginx/tags> |

There is nothing else: the retired feature flags (`ENHANCE`, `EXDOC`, `COVERALLS`, `HEALTH`, …) died with the opinionated `workbench.setup` composition. Their features live on as cartridges — the ones the chief still picks, in the `chiefs_setup` collection — and each cartridge's options are set on its own installer (`./wb.sh add coveralls --theme custom`), not here.

The settings that were not features went the same way: `INIT_VERSION` is `versioning`'s `--version`, the stack a project pins for its host is `toolchain` (read off the toolchain that installs it, not from these variables), `ID_TYPE` and `TIMESTAMPS` are `enhancements`' options, `COVERAGE_THEME` is `coveralls`' `--theme`, and `CODING_GUIDELINES_URL` is `guidelines`' `--url`.
