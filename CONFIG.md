<!-- markdownlint-disable MD033 -->
# Configuration File

The configuration file `config.conf` is used to setup new projects to be created with the `./app new` command and configure the ports to used by Docker.

## Project creation configuration

If the following specs are updated they will have no impact in a current created project, this configuration is meant to set up new projects.

| Variable | Description | Type | Example |
| --: | :-- | :-- | :-- |
| `PROJECT_NAME` | This is the full & main name of the project. It will be used by Phoenix in order to create a new project. It must be capitalized and separated by spaces. | **String** | `"Lorem Ipsum"` |
| `INIT_VERSION` | Initial version of the project upon creation. Semantic Versioning format. | **String** | `"0.0.0"` |
| `ELIXIR_VERSION` | Elixir version component from app Docker image to use.&#13;Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> | **String** | `"1.17.3"` |
| `ERLANG_VERSION` | Erlang version component from app Docker image to use.&#13;Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> | **String** | `"27.1.1"` |
| `DEBIAN_VERSION` | Debian version component from app Docker image to use.&#13;Available Versions: <https://hub.docker.com/r/hexpm/elixir/tags> | **String** | `"buster-20240612-slim"` |
| `INTERFACE` | Configures the API interface standard to implement.&#13;Values: `"rest"`, `"graphql"` | **String** | `"rest"` |
| `ID_TYPE` | Id type for Ecto database schemas.&#13;Values: `"id"`, `"uuid"`, `"bigserial"`, `"binary_id"`, `"identity"`. | **String** | `"uuid"` |
| `TIMESTAMPS` | Timestamps type for Ecto database schemas.&#13;Values: `"naive_datetime"`, `"naive_datetime_usec"`, `"utc_datetime"`, `"utc_datetime_usec"`. | **String** | `"naive_datetime_usec"` |
| `ENHANCE` | Configure enhancements implementation. | **Boolean** | `"true"` |
| `EXDOC` | Configure exdocs implementation. | **Boolean** | `"true"` |
| `COVERALLS` | Configure coveralls implementation. | **Boolean** | `"true"` |
| `HEALTH` | Generate a healthcheck endpoint. | **Boolean** | `"true"` |
| `AUTH0`  | Configure Auth0 implementation. | **Boolean** | `"true"` |
| `OPENAI` | Configure Open AI implementation. | **Boolean** | `"true"` |
| `STRIPE` | Configure Stripe implementation. | **Boolean** | `"true"` |
| `CUSTOM_SCHEMAS` | If set to `"true"` it run a custom schemas script in order to generate migration files. Its required to configure the `scripts/contexts/schemas.sh` file in order to set up those schemas. | **Boolean** | `"false"` |
| `CODING_GUIDELINES_URL` | URL used to download the elixir coding guidelines markdown file for _ExDoc_ documentation. Valid URL path with protocol included. | **String** | `"https://repo.com/GUIDE.md"` |

## Docker containers specs

Modifying the following specs has effect when any command is executed.

### Application container

| Variable | Description  | Type | Example |
| --: | :-- | :-- | :-- |
| `APP_CONTAINER_NAME` | Docker container name used for the application service. | **String** | `"back-end"` |
| `APP_PORT` | Port number used to mount the application service. | **Integer** | `4000` |
| `DB_CONTAINER_NAME` | Docker container name used for the application service. | **String** | `"database"` |
| `POSTGRES_IMAGE_VERSION` | _Postgres_ docker image to use.&#13;Available versions: <https://hub.docker.com/_/postgres/tags> | **String** | `"latest"` |
| `DB_PORT` | Port number used to mount the _Postgres_ database service. | **Integer** | `5432` |
| `PGADMIN_CONTAINER_NAME` | Docker container name used for the application service. | **String** | `"pgadmin"` |
| `PGADMIN_IMAGE_VERSION` | _PgAdmin_ docker image to use.&#13;Available versions: <https://hub.docker.com/r/dpage/pgadmin4/tags> | **String** | `"latest"` |
| `PGADMIN_PORT` | Port number used to mount the _PgAdmin_ service. | **Integer** | `5050` |
