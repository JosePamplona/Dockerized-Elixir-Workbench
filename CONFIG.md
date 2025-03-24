<!-- markdownlint-disable MD033 -->
# Configuration File

The configuration file `config.conf` is used to setup new projects to be created with the `./app new` command and configure the ports to used by Docker.

## Project creation configuration

If the following specs are updated they will have no impact in a current created project, this configuration is meant to set up new projects.

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `PROJECT_NAME` | string | `"Lorem Ipsum"` | This is the full & main name of the project. It will be used by Phoenix in order to create a new project. It must be capitalized and separated by spaces. |
| `INIT_VERSION` | string | `"0.0.0"` | Initial version of the project upon creation. Semantic Versioning format. |
| `ELIXIR_VERSION` | string | `"1.17.3"` | Elixir version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `ERLANG_VERSION` | string | `"27.1.1"` | Erlang version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `DEBIAN_VERSION` | string | `"buster-20240612-slim"` | Debian version component from app Docker image to use.<br/>Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> |
| `INTERFACE` | string | `"rest"` | Configures the API interface standard to implement.<br/>Values: `"rest"`, `"graphql"` |
| `ID_TYPE` | string | `"uuid"` | Id type for Ecto database schemas.<br/>Values: `"id"`, `"uuid"`, `"bigserial"`, `"binary_id"`, `"identity"`. |
| `TIMESTAMPS` | string | `"naive_datetime_usec"` | Timestamps type for Ecto database schemas.<br/>Values: `"naive_datetime"`, `"naive_datetime_usec"`, `"utc_datetime"`, `"utc_datetime_usec"`. |
| `ENHANCE` | boolean | `"true"` | Configure enhancements implementation. |
| `EXDOC` | boolean | `"true"` | Configure exdocs implementation. |
| `COVERALLS` | boolean | `"true"` | Configure coveralls implementation. |
| `HEALTH` | boolean | `"true"` | Generate a healthcheck endpoint. |
| `AUTH0`  | boolean | `"true"` | Configure Auth0 implementation. |
| `OPENAI` | boolean | `"true"` | Configure Open AI implementation. |
| `STRIPE` | boolean | `"true"` | Configure Stripe implementation. |
| `CUSTOM_SCHEMAS` | boolean | `"false"` | If set to `"true"` it run a custom schemas script in order to generate migration files. Its required to configure the `scripts/contexts/schemas.sh` file in order to set up those schemas. |
| `CODING_GUIDELINES_URL` | string | `"https://repo.com/GUIDE.md"` | URL used to download the elixir coding guidelines markdown file for _ExDoc_ documentation. Valid URL path with protocol included. |

## Docker containers specs

Modifying the following specs has effect when any command is executed.

### Application container

#### Back-end

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `APP_CONTAINER_NAME` | string | `"back-end"` | Docker container name used for the application service. |
| `APP_PORT` | Integer | `4000` | Port number used to mount the application service. |

#### Database

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `DB_CONTAINER_NAME` | string | `"database"` | Docker container name used for the application service. |
| `POSTGRES_IMAGE_VERSION` | string | `"latest"` | _Postgres_ docker image to use.<br/>Available versions: <https://hub.docker.com/_/postgres/tags> |
| `DB_PORT` | Integer | `5432` | Port number used to mount the _Postgres_ database service. |

#### PgAdmin

| Variable | Type | Example | Description |
| --: | :-- | :-- | :-- |
| `PGADMIN_CONTAINER_NAME` | string | `"pgadmin"` | Docker container name used for the application service. |
| `PGADMIN_IMAGE_VERSION` | string | `"latest"` | _PgAdmin_ docker image to use.<br/>Available versions: <https://hub.docker.com/r/dpage/pgadmin4/tags> |
| `PGADMIN_PORT` | Integer | `5050` | Port number used to mount the _PgAdmin_ service. |
