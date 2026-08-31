<!-- markdownlint-disable MD033 -->
# Configuration File

The configuration file `config.conf` configures the projects `./wb.sh new` creates, who signs the workbench's commits, and the service images baked into each workspace. There is no feature configuration here: features are cartridges, inserted on the created project one commit each (`./wb.sh add NAME`; `./wb.sh add chiefs_setup` inserts the workbench's own picks) and listed by `./wb.sh catalog`.

## Project creation configuration

Read by the creation command (`new`): the workspace, the name, the stack the images are built from, and the Phoenix installer. Updating them has no impact on an already created project.

The three stack versions are the parts of one `hexpm/elixir` image tag (`ELIXIR-erlang-ERLANG-debian-DEBIAN`). The usable list lives on Docker Hub, not in the file: `./wb.sh stacks` shows the recent ones (`--json` for tools) and `./wb.sh stacks use TAG` checks the image exists and writes the three below.

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `WORKSPACE_PATH` | string | `"./_workspace"` | (`wb.sh` only) Directory where the project is generated, used as the container volume mount point. Relative paths resolve from the workbench directory; any absolute path works. The workbench itself stays permanently in its own directory. |
| `PROJECT_NAME` | string | `"Lorem Ipsum"` | This is the full & main name of the project. It will be used by Phoenix in order to create a new project. It must be capitalized and separated by spaces. |
| `ELIXIR_VERSION` | string | `"1.17.3"` | Elixir version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `ERLANG_VERSION` | string | `"27.1.1"` | Erlang version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `DEBIAN_VERSION` | string | `"buster-20240612-slim"` | Debian version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `PHX_NEW_VERSION` | string | `"1.8.12"` | Phoenix installer (`phx_new` archive) baked into the toolchain image. It generates the project, and the base cartridges (mailer, gettext, ecto, esbuild, tailwind, html, live, dashboard) take their delta with it — and refuse another version than the one that generated the project, read off `{:phoenix, "~> x.y.z"}` in `mix.exs`. Changing it takes a `./wb.sh build` and applies to projects created from then on; projects already created keep asking for theirs.<br/>Available Versions: <https://hex.pm/packages/phx_new> |

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
