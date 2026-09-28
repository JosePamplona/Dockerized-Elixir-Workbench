<!-- markdownlint-disable MD033 -->
# Configuration File

The configuration file `config.conf` configures the projects `./wb.sh new` creates, who signs the workbench's commits, and the service images baked into each workspace. There is no feature configuration here: features are cartridges, inserted on the created project one commit each (`./wb.sh add NAME`) and listed by `./wb.sh catalog`.

## Project creation configuration

Read by the creation command (`new`): the workspace, the name and the stack the images are built from. Updating them has no impact on an already created project.

The three stack versions are the parts of one `hexpm/elixir` image tag (`ELIXIR-erlang-ERLANG-debian-DEBIAN`). The usable list lives on Docker Hub, not in the file: `./wb.sh stacks` shows the recent ones (`--json` for tools) and `./wb.sh stacks use TAG` checks the image exists and writes the three below. `NODE_VERSION` is the fourth part of the stack and the one that is not hexpm's: the Node major both images install from NodeSource, for the `npm install` a project's `mix setup` runs when the project takes packages from the npm registry (today, ash's `--api typescript`). The workbench itself never runs node.

`PHX_NEW_VERSION` is the Phoenix installer `new` generates with, and it is a choice, not a record. Empty — the ordinary case — and hex decides: the newest `phx_new` release that runs on the stack above (see below), which `new` prints, saying so when that is not hex's very newest. Set it for a standing choice, and `./wb.sh new --phx-new VERSION` overrides it for one run.

What it resolves to is stamped into the workspace's own `Dockerfile.local` (`ARG PHX_NEW`) and read back from there ever after, and the workbench image is named `dew-ex<elixir>-erl<otp>-node<major>-phx<version>:<workbench version>` accordingly. That stamp — not this file — is the source of truth for *which generator made this project*, because it is the generator the base cartridges take their delta with. `new` never writes back here: this line says what the next project gets, never what an existing one got, so two workspaces created months apart keep their own and neither moves under the other's feet.

The installer and the stack have to hold each other, and that pair decides the resolution as well as the check. Every `phx_new` release declares on hex the Elixir it runs on (`~> 1.17` for 1.8.13, `~> 1.14` for the 1.7 line) — a floor, never a ceiling, so nothing about a Phoenix version *derives* an Elixir one. With no version named, `new` walks hex's releases newest first and takes the first this stack satisfies: normally that is hex's newest, at the cost of the one call the check would have made anyway, and it only walks further when the stack is behind. This is a deliberate parting from `mix archive.install`, which takes the newest and nothing else. A version that *was* named is taken as named: `new` refuses it outright if hex does not have that release — a typo has no requirement to weigh against anything, and would otherwise surface three layers into the image build — and refuses a stack below its requirement before the first layer is built. Only a 404 refuses; an unreachable hex judges neither question. `mix archive.install` refuses the same pair, but only inside the image and in its own words; the remedy is here, where the stack and the installer are chosen. Only hex's `~> MAJOR.MINOR` form is read: any other shape, or an unreachable hex, leaves the verdict to mix. Erlang/OTP never enters into it — Phoenix says nothing about OTP, and the Elixir/OTP pairing is already settled by the `hexpm/elixir` tag existing at all.

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `WORKSPACE_PATH` | string | `"./_workspace"` | (`wb.sh` only) Directory where the project is generated, used as the container volume mount point. Relative paths resolve from the workbench directory; any absolute path works. The workbench itself stays permanently in its own directory. |
| `PROJECT_NAME` | string | `"Lorem Ipsum"` | The name the next project gets: the app and module derive from it, and so do the workspace's images and its compose project. Capitalized, words separated by spaces. A setting, not a record — a workspace that has a project is named by that project, and every command but the creating ones reads it from there. `./wb.sh new --name "My App"` names one project without touching this. The console needs it before there is a project: it mounts `<project>_build` and `<project>_deps`, the volumes the compose will own, to run mix and git in its own process. |
| `PHX_NEW_VERSION` | string | `""` | The Phoenix installer to generate with. Empty resolves to the newest `phx_new` on hex that runs on the stack below; a version pins it. Never written back: the workspace's `Dockerfile.local` records what a creation actually used. |
| `ELIXIR_VERSION` | string | `"1.18.4"` | Elixir version component from app Docker image to use, `1.18` or newer: since 1.18 Mix locks the build and deps directories, which the workbench relies on to compile the workspace from two sides (`stacks use` and `new` refuse an older one).<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `ERLANG_VERSION` | string | `"27.1.1"` | Erlang version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `DEBIAN_VERSION` | string | `"buster-20240612-slim"` | Debian version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `NODE_VERSION` | string | `"24"` | The Node major the workbench image and the project's dev image install, from NodeSource, as one package with npm inside (Debian's `npm` is 640 packages and six minutes on the shared layer). Used only by a project that takes packages from the npm registry, which is what ash's `--api typescript` hooks into `assets.setup`. A major, because NodeSource names its repositories by major.<br/>Available majors: <https://github.com/nodesource/distributions#readme> |

## Git

The workbench commits what it does to the workspace: the first commit after `new` (the baseline), one commit per inserted cartridge (`Insert FEATURE …`, so `eject FEATURE` can revert that one alone — a collection leaves one commit per member, none of its own) and the revert itself. The commits run inside the toolchain container — where the project's git hooks can run `mix` — and are signed as this says:

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `GIT_IDENTITY` | string | `"user"` | Who signs. `"user"`: the host's git identity (`git config user.name` / `user.email`) when git is installed and has one, falling back to the workbench's own otherwise. `"workbench"`: always `Dockerized Elixir Workbench <wb.sh@localhost>`. |

## Docker containers specs

There is no host ports configuration: each workspace gets the first available ports at creation (application from `4000`, pgAdmin from `5050`, Grafana from `3000`), baked into its own `docker-compose.yml` (`up --deploy scaled` picks its own free ports, one per replica plus the balancer's, when it bakes `docker-compose.scaled.yml`) — that file is the source of truth of the workspace orchestration; edit it to change ports or images. The database is not published to the host: it is only reachable from inside its workspace (the `app` service shares its network namespace). Several workspaces can run simultaneously without conflicts.

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `POSTGRES_IMAGE_VERSION` | string | `"latest"` | _Postgres_ docker image baked into new workspaces.<br/>Available versions: <https://hub.docker.com/_/postgres/tags> |
| `MYSQL_IMAGE_VERSION` | string | `"8"` | _MySQL_ docker image the compose runs for a project on `--database mysql`.<br/>Available versions: <https://hub.docker.com/_/mysql/tags> |
| `MSSQL_IMAGE_VERSION` | string | `"2022-latest"` | _SQL Server_ docker image the compose runs for a project on `--database mssql` (amd64 only; the compose sets `ACCEPT_EULA`, so running it accepts Microsoft's licence).<br/>Available versions: <https://mcr.microsoft.com/en-us/artifact/mar/mssql/server/tags> |
| `PGADMIN_IMAGE_VERSION` | string | `"latest"` | _pgAdmin_ docker image `db_admin --admin pgadmin` puts in the compose, published on its own port (the first free one from `5050`).<br/>Available versions: <https://hub.docker.com/r/dpage/pgadmin4/tags> |
| `PHPMYADMIN_IMAGE_VERSION` | string | `"5"` | _phpMyAdmin_ docker image `db_admin --admin phpmyadmin` puts in the compose (from `8081`); the major its config file is written for.<br/>Available versions: <https://hub.docker.com/_/phpmyadmin/tags> |
| `ADMINER_IMAGE_VERSION` | string | `"6"` | _Adminer_ docker image `db_admin --admin adminer` puts in the compose (from `8080`); the major its login file is written for.<br/>Available versions: <https://hub.docker.com/_/adminer/tags> |
| `CLOUDBEAVER_IMAGE_VERSION` | string | `"latest"` | _CloudBeaver_ docker image `db_admin --admin cloudbeaver` puts in the compose (from `8978`). The image has no major tag: `latest`, or a full version to hold one.<br/>Available versions: <https://hub.docker.com/r/dbeaver/cloudbeaver/tags> |
| `NGINX_IMAGE_VERSION` | string | `"alpine"` | _nginx_ docker image used as the load balancer of the scaled deployment (`up --deploy scaled`).<br/>Available versions: <https://hub.docker.com/_/nginx/tags> |
| `K6_IMAGE_VERSION` | string | `"latest"` | _k6_ docker image the `k6` cartridge puts in the compose, run by `./wb.sh k6`.<br/>Available versions: <https://hub.docker.com/r/grafana/k6/tags> |
| `PROMETHEUS_IMAGE_VERSION` | string | `"latest"` | _Prometheus_ docker image the `monitoring` cartridge puts in the compose, scraping the app's `/metrics`.<br/>Available versions: <https://hub.docker.com/r/prom/prometheus/tags> |
| `GRAFANA_IMAGE_VERSION` | string | `"latest"` | _Grafana_ docker image the `monitoring` cartridge puts in the compose, published on its own port (the first free one from `3000`).<br/>Available versions: <https://hub.docker.com/r/grafana/grafana/tags> |

There is nothing else: the retired feature flags (`ENHANCE`, `EXDOC`, `COVERALLS`, `HEALTH`, …) died with the opinionated `workbench.setup` composition. Their features live on as cartridges, inserted one at a time, and each cartridge's options are set on its own installer (`./wb.sh add coverage --theme custom`), not here.

The settings that were not features went the same way: `INIT_VERSION` is `changelog`'s `--init-version`, the stack a project pins for its host is `version_manager` (read off the toolchain that installs it, not from these variables), `ID_TYPE` and `TIMESTAMPS` are `enhancements`' options, `COVERAGE_THEME` is `coverage`' `--theme`, and `CODING_GUIDELINES_URL` is `guidelines`' `--url`.
