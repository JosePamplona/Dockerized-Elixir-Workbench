<!-- markdownlint-disable MD033 -->
# Configuration File

The configuration file `config.conf` is used to setup new projects to be created with the `./wb.sh new` command and configure the ports to used by Docker.

## Project creation configuration

If the following specs are updated they will have no impact in a current created project, this configuration is meant to set up new projects.

The `./wb.sh new2` command (vanilla project) reads only `WORKSPACE_PATH`, `PROJECT_NAME`, the three stack versions and `PHX_NEW_VERSION`: they shape the workspace, the project generation and the Docker images. Everything else in this table configures the Elixir project, which `new2` deliberately leaves stock — those features are installed afterwards with `./wb.sh add`.

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `WORKSPACE_PATH` | string | `"./_workspace"` | (`wb.sh` only) Directory where the project is generated, used as the container volume mount point. Relative paths resolve from the workbench directory; any absolute path works. The workbench itself stays permanently in its own directory. |
| `PROJECT_NAME` | string | `"Lorem Ipsum"` | This is the full & main name of the project. It will be used by Phoenix in order to create a new project. It must be capitalized and separated by spaces. |
| `INIT_VERSION` | string | `"0.0.0"` | Initial version of the project upon creation. Semantic Versioning format. |
| `ELIXIR_VERSION` | string | `"1.17.3"` | Elixir version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `ERLANG_VERSION` | string | `"27.1.1"` | Erlang version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `DEBIAN_VERSION` | string | `"buster-20240612-slim"` | Debian version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `PHX_NEW_VERSION` | string | `"1.8.12"` | Phoenix installer (`phx_new` archive) baked into the toolchain image. It generates the project, and the base cartridges (mailer, gettext, ecto, esbuild, tailwind, html, live, dashboard) take their delta with it — and refuse another version than the one that generated the project, read off `{:phoenix, "~> x.y.z"}` in `mix.exs`. Changing it takes a `./wb.sh build` and applies to projects created from then on; projects already created keep asking for theirs.<br/>Available Versions: <https://hex.pm/packages/phx_new> |
| `INTERFACE` | string | `"rest"` | Configures the API interface standard to implement.<br/>Values: `"rest"`, `"graphql"` |
| `ID_TYPE` | string | `"uuid"` | Id type for Ecto database schemas.<br/>Values: `"id"`, `"uuid"`, `"bigserial"`, `"binary_id"`, `"identity"`. |
| `TIMESTAMPS` | string | `"naive_datetime_usec"` | Timestamps type for Ecto database schemas.<br/>Values: `"naive_datetime"`, `"naive_datetime_usec"`, `"utc_datetime"`, `"utc_datetime_usec"`. |
| `ENHANCE` | boolean | `"true"` | Configure enhancements implementation. |
| `EXDOC` | boolean | `"true"` | Configure exdocs implementation. |
| `COVERALLS` | boolean | `"true"` | Configure coveralls implementation. |
| `HEALTH` | boolean | `"true"` | Generate a healthcheck endpoint. |
| `AUTH0` | boolean | `"true"` | Configure Auth0 implementation. |
| `OPENAI` | boolean | `"true"` | Configure Open AI implementation. |
| `STRIPE` | boolean | `"true"` | Configure Stripe implementation. |
| `CODING_GUIDELINES_URL` | string | `"https://repo.com/GUIDE.md"` | URL used to download the elixir coding guidelines markdown file for _ExDoc_ documentation. Valid URL path with protocol included. |

## Git

The workbench commits what it does to the workspace: the first commit after `new`/`new2` (the baseline), one commit per `add` (`Insert FEATURE …`, so `eject FEATURE` can revert that one alone) and the revert itself. The commits run inside the toolchain container — where the project's git hooks can run `mix` — and are signed as this says:

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
