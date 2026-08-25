#!/bin/bash
# Dockerized workbench script (Igniter edition)
# v0.8.0
#
# Thin Docker wrapper: project creation and Elixir configuration are
# delegated to the :workbench_igniter package (igniter/) via
# `mix workbench.setup` and `mix workbench.install.*` tasks.
#
# The workbench lives permanently in this directory; projects are generated
# into WORKSPACE_PATH (config.conf). Each workspace owns its
# docker-compose.yml — baked with real values (name, ports, images) at
# creation — which is the source of truth for its orchestration: several
# workspaces can run simultaneously without port conflicts. The workbench
# is mounted read-only at /app/workbench so the igniter tasks are available
# inside the containers.

# CONFIGURATION ================================================================

  # The workbench is wherever this script lives; run everything from here.
  WORKBENCH_PATH="$( cd "$( dirname "$0" )" && pwd )"
  cd "$WORKBENCH_PATH"

  # Environment overrides survive config.conf (e.g. WORKSPACE_PATH=./x ./wb.sh).
  WORKSPACE_PATH_OVERRIDE="$WORKSPACE_PATH"

  SCRIPT_CONFIG_FILE="config.conf"
  source "./$SCRIPT_CONFIG_FILE"

  # Workbench configuration --------------------------------------------------

    # Feature dependencies
    if [ "$STRIPE" == true ]; then AUTH0="true"; fi
    if [ "$OPENAI" == true ]; then AUTH0="true"; fi

    WORKBENCH_VERSION=$( sed '3!d' $0 | sed -n 's/^.*v\(.*\).*/\1/p' )

    # Workspace: directory where the project is generated (volume mount
    # point). Relative paths are resolved from the workbench directory.
    WORKSPACE_PATH="${WORKSPACE_PATH_OVERRIDE:-$WORKSPACE_PATH}"
    WORKSPACE_PATH="${WORKSPACE_PATH:-./_workspace}"
    case "$WORKSPACE_PATH" in
      /*) ;;
      *) WORKSPACE_PATH="$WORKBENCH_PATH/${WORKSPACE_PATH#./}" ;;
    esac

    # Directories - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    SCRIPTS_DIR="scripts"

    # Script files - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Dev toolchain dockerfile: baked from the seed into scripts/ on each
    # `new`, then copied into the workspace under the same name.
    PROD_DOCKERFILE="Dockerfile"
    PROD_COMPOSE_FILE="docker-compose.prod.yml"
    CLUSTER_COMPOSE_FILE="docker-compose.cluster.yml"
    CLUSTER_COMPOSE_SEED="docker-compose.cluster.seed.yml"
    # Replicas the cluster deployment starts unless --replicas says
    # otherwise; the balancer sits in front of them.
    DEFAULT_CLUSTER_REPLICAS=4
    LOCAL_DOCKERFILE="Dockerfile.local"
    LOCAL_DOCKERFILE_SEED="Dockerfile.seed.local"
    COMPOSE_FILE="docker-compose.yml"
    COMPOSE_SEED="docker-compose.seed.yml"
    # The entrypoint script runs from the mounted workbench (workdir /app).
    CONTAINER_ENTRYPOINT="bash workbench/scripts/entrypoint.sh"
    # TTY flags only when running from an interactive terminal (CI-safe).
    if [ -t 0 ]
    then DOCKER_TTY_FLAGS="--tty --interactive"
    else DOCKER_TTY_FLAGS=""
    fi

    # Elixir project files - - - - - - - - - - - - - - - - - - - - - - - - - -
    LOWER_CASE=$( echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' )
    ELIXIR_PROJECT_NAME=$( echo $LOWER_CASE | tr ' ' '_' )
    MIX_FILE="mix.exs"
    EXISTING_PROJECT=$(
      [ -f "$WORKSPACE_PATH/$MIX_FILE" ] && echo true || echo false
    )

    # Git - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if [ -d "$WORKSPACE_PATH/.git" ]
    then REPO_URL=$(
      git -C "$WORKSPACE_PATH" config --get remote.origin.url | \
      sed 's/\.git$//'
    )
    else REPO_URL="https://github.com/user/repo"
    fi

  # Docker ---------------------------------------------------------------------

    APP_NAME=$( echo "$LOWER_CASE" | tr ' ' '-' )
    # Bare toolchain image, shared by every workspace of the same stack.
    TOOLCHAIN_IMAGE="workbench:${ELIXIR_VERSION}-${ERLANG_VERSION}"
    # The workspace's own dev image name. Standalone it is built from the
    # project's Dockerfile.local; with the workbench present, `new` seeds
    # it as an alias (docker tag) of the shared toolchain image.
    LOCAL_IMAGE="$APP_NAME:local"
    # Ports the services bind INSIDE the containers; the host ports are
    # chosen per workspace and mapped to these in its compose file.
    APP_INTERNAL_PORT="4000"
    PGADMIN_INTERNAL_PORT="5050"
    SOURCE_CODE_VOLUME="$WORKSPACE_PATH:/app/src"
    WORKBENCH_VOLUME="$WORKBENCH_PATH:/app/workbench:ro"

  # Format codes -------------------------------------------------------------

    # Colors
    C1="\x1B[38;5;1m" # Dark-red
    C2="\x1B[4;34m"   # Blue underline
    # Format
    B="\x1B[1m" # Bold
    R="\x1B[0m" # Reset

    Li=$C2 # Link color

# FUNCTIONS ====================================================================

  # If echo handles -e option, overrides the command
  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi

  # confirm <MESSAGE>
    # Prints MESSAGE and spects input prompt for continue or exit the script
  confirm() {
    echo "⚠️  ${B}Warning${R} $@"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then exit 0; fi
    echo
  }

  # args_error <ERROR>
    # Prints a default messages for argument errors.
  args_error() {
    if   [ "$1" == "missing" ];  then echo "Missing arguments."
    elif [ "$1" == "too_many" ]; then echo "Too many arguments."
    elif [ "$1" == "invalid" ];  then echo "Invalid argument."
    elif [ "$1" != "" ];         then echo "$@"
    else echo "Argument error."; fi
    exit 1
  }

  # warning <MESSAGE>
    # Prints a warning without interrupting: the command carries on.
  warning() { echo "⚠️  ${B}Warning${R} $@"; echo; }

  # terminate <MESSAGE>
    # Print error and terminate with sigerr 1
  terminate() { echo "${B}${C1}Error${R} $@"; echo; exit 1; }

  # first_free_port <BASE>
    # Prints the first host port available starting from BASE.
  first_free_port() {
    local port=$1
    while (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; do
      exec 3>&- 3<&-
      port=$((port + 1))
    done
    echo $port
  }

  # workspace_compose [COMMAND...]
    # Runs docker compose against the workspace's own compose file.
  workspace_compose() {
    docker compose --file "$WORKSPACE_PATH/$COMPOSE_FILE" "$@"
  }

  # compose_file_for <ENV>
    # Compose file each environment deploys with. dev is the workspace's
    # own docker-compose.yml; prod and cluster are baked on demand.
  compose_file_for() {
    case "$1" in
      cluster) echo "$CLUSTER_COMPOSE_FILE" ;;
      prod)    echo "$PROD_COMPOSE_FILE" ;;
      *)       echo "$COMPOSE_FILE" ;;
    esac
  }

  # resolve_compose_file <ENV>
    # Sets COMPOSE_TARGET to the environment's compose file, or
    # terminates when it has not been baked yet (no deployment of that
    # environment ever ran). It assigns instead of echoing on purpose:
    # called from a command substitution, 'terminate' would only exit the
    # subshell and its message would be captured as the file name.
  resolve_compose_file() {
    COMPOSE_TARGET="$WORKSPACE_PATH/$(compose_file_for "$1")"

    [ -f "$COMPOSE_TARGET" ] || terminate \
      "This workspace has no '$1' deployment ($(basename "$COMPOSE_TARGET")" \
      "does not exist). Create it with: ./$(basename $0) up --env $1"
  }

  # app_is_running [FILE] [SERVICE]
    # Succeeds when the given service of the given deployment is up (exec
    # target). Defaults to the dev compose and its 'app' service.
  app_is_running() {
    local file_path="${1:-$WORKSPACE_PATH/$COMPOSE_FILE}"
    local service="${2:-app}"

    [ -n "$(
      docker compose --file "$file_path" \
        ps --status running --quiet "$service" 2>/dev/null
    )" ]
  }

  # --------------------------------------------------------------------------

  # wipe_workspace
    # Deletes every file and directory inside the workspace (the workbench
    # itself is never touched: it lives outside the workspace).
  wipe_workspace() {
    [ -d "$WORKSPACE_PATH" ] && \
    find "$WORKSPACE_PATH" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  }

  # create_local_dockerfile
    # Bakes the local (dev toolchain) dockerfile from its seed.
  create_local_dockerfile() {
    local seed_path="$SCRIPTS_DIR/$LOCAL_DOCKERFILE_SEED"
    local file_path="$SCRIPTS_DIR/$LOCAL_DOCKERFILE"

    cp $seed_path $file_path

    sed -i "s/%{elixir_version}/$ELIXIR_VERSION/" $file_path
    sed -i "s/%{erlang_version}/$ERLANG_VERSION/" $file_path
    sed -i "s/%{debian_version}/$DEBIAN_VERSION/" $file_path
  }

  # prepare_workspace
    # Ensures an empty workspace directory (confirming first when a project
    # already exists there) and bakes the local dockerfile from seed.
  prepare_workspace() {
    if [ $EXISTING_PROJECT == true ]; then
      confirm \
        "A project already exists in $WORKSPACE_PATH. This action will" \
        "overwrite all its files." && \
      wipe_workspace
    else
      mkdir -p "$WORKSPACE_PATH"
    fi && \
    create_local_dockerfile
  }

  # register_igniter_package
    # Bootstrap: registers the workbench_igniter package in the generated
    # mix.exs. The dependency is conditional on the mounted workbench
    # (/app/workbench, overridable with WORKBENCH_PATH), so the project
    # stays self-contained whenever the workbench is absent.
  register_igniter_package() {
    local file_path="$WORKSPACE_PATH/$MIX_FILE"

    sed -i 's/deps: deps(),/deps: deps() ++ workbench_dep(),/' "$file_path" && \
    sed -i '/^  defp deps do/i\
\  # Workbench igniter tasks, available while the workbench is mounted.\
\  defp workbench_dep do\
\    path = "#{System.get_env("WORKBENCH_PATH", "/app/workbench")}/igniter"\
\
\    if File.exists?(path),\
\      do: [{:workbench_igniter, path: path, only: [:dev, :test], runtime: false}],\
\      else: []\
\  end\
' "$file_path"
  }

  # bake_compose <IMAGE> <DOCKERFILE> <TARGET_FILE>
    # Generates a compose file into the workspace from the seed, with the
    # real configuration values baked in. The workspace's compose is the
    # source of truth of its orchestration (name, ports, images); the
    # start command is each image's own CMD.
  bake_compose() {
    local image="$1"
    local dockerfile="$2"
    local file_path="$WORKSPACE_PATH/$3"

    cp "$SCRIPTS_DIR/$COMPOSE_SEED" "$file_path"

    sed -i "s/%{app_name}/$ELIXIR_PROJECT_NAME/"                 $file_path
    sed -i "s/%{compose_image}/$image/"                          $file_path
    sed -i "s/%{compose_dockerfile}/$dockerfile/"                $file_path
    sed -i "s/%{uid}/$(id -u)/"                                  $file_path
    sed -i "s/%{gid}/$(id -g)/"                                  $file_path
    sed -i "s/%{app_port}/$APP_PORT/"                            $file_path
    sed -i "s/%{internal_port}/$APP_INTERNAL_PORT/g"             $file_path
    sed -i "s/%{pgadmin_port}/$PGADMIN_PORT/"                    $file_path
    sed -i "s/%{pgadmin_internal_port}/$PGADMIN_INTERNAL_PORT/g" $file_path
    sed -i "s/%{postgres_image_version}/$POSTGRES_IMAGE_VERSION/" $file_path
    sed -i "s/%{pgadmin_image_version}/$PGADMIN_IMAGE_VERSION/"  $file_path

    # Remove the database & pgadmin services on projects without Ecto
    # (the network holder and the pod structure remain).
    if ! grep -q "ecto_repos" "$WORKSPACE_PATH/config/config.exs" 2>/dev/null
    then
      sed -i '/^  database:/,$d'            $file_path
      sed -i '/^    depends_on:/,+2d'       $file_path
      sed -i "/# pgAdmin port/,/:$PGADMIN_INTERNAL_PORT\$/d" $file_path
    fi
  }

  # workspace_app_port
    # Reads the application host port from the workspace's compose file.
  workspace_app_port() {
    sed -n "s/^ *- \([0-9]*\):$APP_INTERNAL_PORT\$/\1/p" \
      "$WORKSPACE_PATH/$COMPOSE_FILE" | \
    head -n 1
  }

  # bake_prod_compose
    # Generates the workspace's production compose file (used by the
    # 'up --env prod' and 'build --env prod' commands): same seed and
    # application port as the dev compose, versioned production image,
    # and — the production image being self-contained — no source code
    # volume nor build identity (its Dockerfile runs as nobody).
  bake_prod_compose() {
    APP_PORT=$(workspace_app_port)
    PGADMIN_PORT=$(first_free_port 5050)
    APP_VERSION=$(
      sed -n 's/^.*version: "\(.*\)".*/\1/p' "$WORKSPACE_PATH/$MIX_FILE" | \
      head -n 1
    )

    bake_compose \
      "$APP_NAME:$APP_VERSION-prod" \
      "$PROD_DOCKERFILE" \
      "$PROD_COMPOSE_FILE" && \
    sed -i '/^    volumes:/,+1d' "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" && \
    sed -i '/^      # These arguments/,/GID:/d' \
      "$WORKSPACE_PATH/$PROD_COMPOSE_FILE"
  }

  # parse_deploy_args [ARGS...]
    # Reads the options 'up' and 'build' share into ENV_ARG,
    # CLUSTER_REPLICAS and CLUSTER_BALANCER, leaving everything it did
    # not consume in DEPLOY_REST (passed through to docker compose).
    # --replicas and --balancer only shape how the cluster compose file
    # is baked, so 'logs', 'ps', 'stop' and 'down' never need them: the
    # file they act on is the same either way.
  parse_deploy_args() {
    ENV_ARG=dev
    CLUSTER_REPLICAS=$DEFAULT_CLUSTER_REPLICAS
    CLUSTER_BALANCER=true
    DEPLOY_REST=()

    while [ $# -gt 0 ]; do
      case "$1" in
        -e|--env)      ENV_ARG="$2";          shift 2 ;;
        --replicas)    CLUSTER_REPLICAS="$2"; shift 2 ;;
        --balancer)    CLUSTER_BALANCER=true;  shift ;;
        --no-balancer) CLUSTER_BALANCER=false; shift ;;
        *)             DEPLOY_REST+=( "$1" );  shift ;;
      esac
    done

    case "$CLUSTER_REPLICAS" in
      ''|*[!0-9]*|0) args_error "--replicas expects a positive integer." ;;
    esac
  }

  # bake_cluster_compose
    # Generates the workspace's cluster compose file from its seed: the
    # production image replicated CLUSTER_REPLICAS times on a bridge
    # network, each replica with its own host port. Leaves the chosen
    # ports in the CLUSTER_PORTS array.
  bake_cluster_compose() {
    local file_path="$WORKSPACE_PATH/$CLUSTER_COMPOSE_FILE"
    local services depends upstream
    local port=4000
    local i=1

    APP_VERSION=$(
      sed -n 's/^.*version: "\(.*\)".*/\1/p' "$WORKSPACE_PATH/$MIX_FILE" | \
      head -n 1
    )

    cp "$SCRIPTS_DIR/$CLUSTER_COMPOSE_SEED" "$file_path"

    # The balancer takes the first free port: it is the cluster's single
    # entry point. Every replica publishes its own too, so a specific
    # node can still be addressed — which is how the cross-node
    # behaviour is demonstrated.
    BALANCER_PORT=$(first_free_port $port)
    port=$((BALANCER_PORT + 1))

    services=$(mktemp)
    depends=$(mktemp)
    upstream=$(mktemp)
    CLUSTER_PORTS=()

    while [ $i -le $CLUSTER_REPLICAS ]; do
      port=$(first_free_port $port)
      CLUSTER_PORTS+=( $port )

      printf '  app%s:\n    <<: *app\n    ports:\n      - %s:%s\n\n' \
        "$i" "$port" "$APP_INTERNAL_PORT" >> "$services"
      printf '      app%s:\n        condition: service_started\n' \
        "$i" >> "$depends"
      printf '        server app%s:%s;\n' \
        "$i" "$APP_INTERNAL_PORT" >> "$upstream"

      port=$((port + 1))
      i=$((i + 1))
    done

    # 'r' queues the generated block after the marker line, 'd' drops the
    # marker: no escaping of newlines into a sed replacement.
    sed -i -e "/%{app_services}/r $services"     -e "/%{app_services}/d"     $file_path
    sed -i -e "/%{balancer_depends}/r $depends"  -e "/%{balancer_depends}/d" $file_path
    sed -i -e "/%{upstream_servers}/r $upstream" -e "/%{upstream_servers}/d" $file_path
    rm -f "$services" "$depends" "$upstream"

    sed -i "s/%{app_name}/$ELIXIR_PROJECT_NAME/g"                  $file_path
    sed -i "s/%{compose_image}/$APP_NAME:$APP_VERSION-prod/g"      $file_path
    sed -i "s/%{compose_dockerfile}/$PROD_DOCKERFILE/g"            $file_path
    sed -i "s/%{balancer_port}/$BALANCER_PORT/"                    $file_path
    sed -i "s/%{nginx_image_version}/$NGINX_IMAGE_VERSION/"        $file_path
    sed -i "s/%{postgres_image_version}/$POSTGRES_IMAGE_VERSION/"  $file_path

    # Without the clustering feature the release is not distributed, so
    # DNSCluster would poll DNS forever, connect to nobody and warn about
    # it on every boot. Leaving the variable unset keeps it out of the
    # supervision tree (runtime.exs falls back to :ignore).
    clustering_installed || sed -i '/^    DNS_CLUSTER_QUERY:/d' $file_path

    # Without a balancer the replicas are only reachable on their own
    # ports; its nginx config goes with it.
    if [ "$CLUSTER_BALANCER" == false ]; then
      sed -i '/^  # Single entry point/,/^$/d' $file_path
      sed -i '/^configs:/,$d'                  $file_path
    fi

    # Projects without Ecto have nothing to migrate and no database: drop
    # both services and the app anchor's references to them.
    if ! grep -q "ecto_repos" "$WORKSPACE_PATH/config/config.exs" 2>/dev/null
    then
      sed -i '/^  # One-shot migration/,/^configs:/{/^configs:/!d}' $file_path
      sed -i '/^  depends_on:$/,+2d'                                $file_path
      sed -i '/^    DATABASE_URL:/d'                                $file_path
    fi
  }

  # clustering_installed
    # Whether the clustering feature is installed in the workspace. Its
    # block in rel/env.sh.eex is what boots the release as a named
    # distributed node; without it the release starts with a short name
    # and the replicas cannot connect to each other.
  clustering_installed() {
    grep -qs "Workbench clustering:" "$WORKSPACE_PATH/rel/env.sh.eex"
  }

  # clustering_warning
    # The deployment is valid either way — replicas behind a balancer is
    # how a stateless application scales, and they need not know each
    # other exists — but running isolated must never be silent, so it is
    # said here instead of being left to a log line inside each replica.
  clustering_warning() {
    clustering_installed || warning \
      "The 'clustering' feature is not installed: these replicas run" \
      "isolated, behind the balancer but without forming a BEAM cluster." \
      "That is a valid deployment for a stateless application. To connect" \
      "them (PubSub across nodes, Presence, distributed registries), stop" \
      "here and run: ./$(basename $0) add clustering"
  }

  # deployed_message
    # Printed after a successful 'up' of the dev or prod compose.
  deployed_message() {
    echo
    echo "Application deploying at ${Li}http://localhost:$(workspace_app_port)${R}" \
      "(first boot compiles: give it a moment)."
    echo "Follow the logs with ${B}./$(basename $0) logs${R}," \
      "stop everything with ${B}./$(basename $0) stop${R}."
  }

  # cluster_deployed_message
    # Printed after a successful 'up --env cluster': one URL per replica
    # and how to look at the cluster from the inside.
  cluster_deployed_message() {
    local i=1

    echo
    clustering_warning
    echo "Cluster deploying with $CLUSTER_REPLICAS replicas:"
    if [ "$CLUSTER_BALANCER" == true ]; then
      echo "  balancer  ${Li}http://localhost:$BALANCER_PORT${R}  (round-robin entry point)"
    fi
    for port in "${CLUSTER_PORTS[@]}"
    do
      echo "  app$i      ${Li}http://localhost:$port${R}"
      i=$((i + 1))
    done
    echo
    echo "Attach to a node's release shell:"
    echo "  ${B}docker compose --file $WORKSPACE_PATH/$CLUSTER_COMPOSE_FILE \\${R}"
    echo "  ${B}  exec app1 /app/bin/$ELIXIR_PROJECT_NAME remote${R}"
    if clustering_installed; then
      echo "  iex> node()      # $ELIXIR_PROJECT_NAME@172.x.x.x"
      echo "  iex> Node.list() # the other $((CLUSTER_REPLICAS - 1))"
    fi
    if [ "$CLUSTER_BALANCER" == true ]; then
      echo
      echo "See the balancing: the X-Served-By address is the node that answered."
      echo "  ${B}curl -sI http://localhost:$BALANCER_PORT | grep X-Served-By${R}"
    fi
    echo
    echo "Stop everything with ${B}./$(basename $0) down --env cluster${R}."
  }

  # help
    # Prints help
  help() {
    section() { echo "${B}$1${R}"; }
    print_command() { echo "  ${B}$1${R}"; }
    section_content() {
      for arg in "$@"
      do
        echo "  $arg"
      done
      echo
    }

    local script_name=$(basename "$0")

    section "NAME"
    section_content "$(sed -n '2s/# //p' $0)"

    section "VERSION"
    section_content \
      "$WORKBENCH_VERSION"

    section "SYNTAXIS"
    section_content "./$script_name [COMMAND]"

    section "DESCRIPTION"
    section_content \
      "This is a script for creating ${B}Elixir${R} (${Li}https://elixir-lang.org${R}) projects" \
      "with the ${B}Phoenix${R} (${Li}https://www.phoenixframework.org${R}) framework and" \
      "deploying them on 'localhost' using a specific service architecture with" \
      "Docker containers. It eliminates the need to install anything other than" \
      "${B}Docker Desktop${R} (${Li}https://www.docker.com/products/docker-desktop${R}) in order" \
      "to create, develop and deploy the project as 'dev' or 'prod' enviroment." \
      "" \
      "The workbench stays permanently in this directory. Projects are" \
      "generated into the ${B}WORKSPACE_PATH${R} directory (config.conf), each one" \
      "owning its docker-compose.yml with its name, ports and images baked" \
      "in — several workspaces can run simultaneously without conflicts." \
      "The Elixir configuration is delegated to the ${B}workbench_igniter${R}" \
      "package (igniter/): 'new' runs 'mix workbench.setup' inside the" \
      "container — 'new2' runs 'mix workbench.setup2' instead, which only" \
      "makes a stock phx.new project bootable here — and features can be" \
      "added later with the 'add' command." \
      "" \
      "Current workspace: $WORKSPACE_PATH"

    section "COMMANDS"
    print_command "login [USER] [TOKEN]"
    section_content \
      "Login account in order to download private images." \
      "- USER:  Github username. " \
      "- TOKEN: Authentication token (classic). "

    print_command "new [OPTIONS]"
    section_content \
      "Create a new project in the workspace, configured from config.conf." \
      "- OPTIONS: It can accept all option flags from the task 'mix phx.new'" \
      "  (${Li}https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html${R})."

    print_command "new2 [OPTIONS]"
    section_content \
      "Create a new ${B}vanilla${R} project in the workspace: 'mix phx.new'" \
      "plus only what this workbench needs to run it. Step by step:" \
      "  1. 'mix phx.new' generates the stock project." \
      "  2. The workbench_igniter package is registered in its mix.exs." \
      "  3. 'mix workbench.setup2' binds the dev endpoint to 0.0.0.0 (the" \
      "     published port never reaches loopback), writes .env and" \
      "     .env.sample (the compose env_file) and lists .env in .gitignore." \
      "  4. 'mix phx.gen.release --docker' adds the production Dockerfile," \
      "     .dockerignore and rel/overlays, which phx.new does not generate" \
      "     but 'up --env prod' needs. Distributed releases are not set up:" \
      "     that is the 'clustering' feature." \
      "  5. The workspace gets its Dockerfile.local and docker-compose.yml." \
      "The Elixir project keeps its phx.new configuration untouched: install" \
      "the workbench features one by one with the 'add' command." \
      "- OPTIONS: It can accept all option flags from the task 'mix phx.new'" \
      "  (${Li}https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html${R})."

    print_command "add [FEATURE] [OPTIONS]"
    section_content \
      "Install a workbench feature on the existing project." \
      "- FEATURE: One of: healthcheck, rest, graphql, coveralls, exdoc," \
      "  enhancements, auth0, openai, credo, githooks, exmachina, mock," \
      "  exdebug, psql_extras, osmon, clustering." \
      "- OPTIONS: Flags for the 'mix workbench.install.FEATURE' task."

    print_command "setup [-e, --env ENV]"
    section_content \
      "Set or reset the database (if any) and run the seeding script." \
      "- ENV: Enviroment database to setup (Defalut: dev)."

    print_command "up [-e, --env ENV] [--replicas N] [--no-balancer]"
    section_content \
      "Deploy the application on localhost, detached: the terminal stays" \
      "free and the containers keep running ('logs' follows their output)." \
      "- ENV: Enviroment to deploy (Defalut: dev)." \
      "  ${B}cluster${R} deploys production replicas behind an nginx balancer:" \
      "  each one gets its own IP and host port, and they all share the" \
      "  'app' network alias. It replaces the pod network layout of the" \
      "  dev compose, so the database is reached by name, not on" \
      "  localhost. Meant for seeing a replicated deployment work, not" \
      "  for developing." \
      "  With the 'clustering' feature installed the replicas also form a" \
      "  real BEAM cluster: Docker's DNS answers that shared alias with" \
      "  every address, which is what DNSCluster queries to connect them." \
      "  Without it they run isolated, which is a valid deployment for a" \
      "  stateless application — the command warns and carries on." \
      "- N: Replicas of the cluster deployment (Default: $DEFAULT_CLUSTER_REPLICAS)." \
      "- --no-balancer: Skip the nginx front and publish only the" \
      "  per-replica ports. Both options are baked into the compose file," \
      "  so 'logs', 'ps', 'stop' and 'down' never need them."

    print_command "build [-e, --env ENV] [OPTIONS]"
    section_content \
      "(Re)build the workspace's app image without deploying it: the" \
      "dev image from the project's Dockerfile.local, or the production" \
      "release image ('up --env prod' also rebuilds it on each deploy)." \
      "- ENV: Enviroment image to build (Defalut: dev). 'cluster' builds" \
      "  the same production image every replica shares, and accepts the" \
      "  same --replicas and --no-balancer as 'up'. Whether that image is" \
      "  distributed is baked in by the 'clustering' feature, so" \
      "  installing it afterwards means building again." \
      "- OPTIONS: Flags for 'docker compose build', e.g. --no-cache."

    print_command "logs [-e, --env ENV] [SERVICE...]"
    section_content \
      "Follow the workspace containers logs (Ctrl+C detaches, the" \
      "containers keep running)." \
      "- ENV: Enviroment whose deployment to read (Defalut: dev)." \
      "- SERVICE: Restrict to some services (app, database, pgadmin;" \
      "  app1..appN, balancer and migrate with '--env cluster')."

    print_command "stop | down | ps [-e, --env ENV]"
    section_content \
      "Stop, remove or list the workspace containers ('stop' keeps them" \
      "for a fast restart with 'up'; 'down' removes them)." \
      "- ENV: Enviroment deployment to act on (Defalut: dev)."

    print_command "iex | bash [-e, --env ENV] [SERVICE]"
    section_content \
      "Open an IEx shell (or a plain shell) on a running container of the" \
      "workspace; exiting does not stop the application." \
      "- ENV: Enviroment deployment to attach to (Defalut: dev). Outside" \
      "  dev the container runs the release, which carries no Mix, so" \
      "  'iex' opens its remote shell ('bin/<app> remote') instead." \
      "- SERVICE: Service to attach to (Defalut: app). The cluster" \
      "  deployment names its replicas app1..appN."

    print_command "mix [ARGS...]"
    section_content \
      "Run a mix task: on the running app container when the system is" \
      "up (fast), or on a one-off container otherwise." \
      "- ARGS: The task and its options, e.g.: cover, docs, test."

    print_command "delete"
    section_content \
      "Deletes the workspace project files and its Docker compose project."

    print_command "demo [-e, --env ENV]"
    section_content \
      "Runs consecutively new, setup, up, logs & delete commands: the" \
      "logs block the demo while the application is tried out, and" \
      "Ctrl+C moves on to the teardown." \
      "- ENV: Enviroment to deploy (Defalut: dev)."

    print_command "help"
    section_content \
      "Displays the help section for the workbench script."

    section "LICENSE"
    section_content \
      "MIT license (${Li}https://mit-license.org${R})" \
      "Copyright © 2024 José Luis Pamplona Stoever"
  }

  # build_setup_flags PHOENIX_NEW_OPTIONS...
    # Translates config.conf and the phx.new options into flags for the
    # 'mix workbench.setup' task. Result in the SETUP_FLAGS array.
  build_setup_flags() {
    local NO_HTML=false ASSETS=true MAILER=true DASHBOARD=true ECTO=true
    for arg in "$@"; do
      case "$arg" in
        --no-html)      NO_HTML=true ;;
        --no-assets)    ASSETS=false ;;
        --no-ecto)      ECTO=false ;;
        --no-mailer)    MAILER=false ;;
        --no-dashboard) DASHBOARD=false ;;
      esac
    done

    SETUP_FLAGS=(
      --project-name "$PROJECT_NAME"
      --version "$INIT_VERSION"
      --elixir-version "$ELIXIR_VERSION"
      --erlang-version "$ERLANG_VERSION"
      --debian-version "$DEBIAN_VERSION"
      --interface "$INTERFACE"
      --app-port "$APP_PORT"
      --internal-port "$APP_INTERNAL_PORT"
      --repo-url "$REPO_URL"
    )
    [ -n "$ID_TYPE" ]    && SETUP_FLAGS+=( --id-type "$ID_TYPE" )
    [ -n "$TIMESTAMPS" ] && SETUP_FLAGS+=( --timestamps "$TIMESTAMPS" )
    [ -n "$CODING_GUIDELINES_URL" ] && \
      SETUP_FLAGS+=( --guidelines-url "$CODING_GUIDELINES_URL" )
    [ "$ENHANCE" == true ]   && SETUP_FLAGS+=( --enhance )
    [ "$EXDOC" == true ]     && SETUP_FLAGS+=( --exdoc )
    [ "$COVERALLS" == true ] && SETUP_FLAGS+=( --coveralls )
    [ -n "$COVERAGE_THEME" ] && SETUP_FLAGS+=( --coverage-theme "$COVERAGE_THEME" )
    [ "$HEALTH" == true ]    && SETUP_FLAGS+=( --health )
    [ "$AUTH0" == true ]     && SETUP_FLAGS+=( --auth0 )
    [ "$OPENAI" == true ]    && SETUP_FLAGS+=( --openai )
    [ "$STRIPE" == true ]    && SETUP_FLAGS+=( --stripe )
    [ "$NO_HTML" == true ]   && SETUP_FLAGS+=( --no-html )
    [ "$ASSETS" == false ]    && SETUP_FLAGS+=( --no-assets )
    [ "$MAILER" == false ]    && SETUP_FLAGS+=( --no-mailer )
    [ "$DASHBOARD" == false ] && SETUP_FLAGS+=( --no-dashboard )
    [ "$ECTO" == false ]      && SETUP_FLAGS+=( --no-ecto )
    true
  }

  # build_setup2_flags PHOENIX_NEW_OPTIONS...
    # Translates the phx.new options into flags for the 'mix
    # workbench.setup2' task, which takes no configuration from
    # config.conf: the vanilla project has nothing to configure beyond
    # what the workspace needs to boot. Result in the SETUP_FLAGS array.
  build_setup2_flags() {
    local ECTO=true
    for arg in "$@"; do
      case "$arg" in
        --no-ecto) ECTO=false ;;
      esac
    done

    SETUP_FLAGS=( --internal-port "$APP_INTERNAL_PORT" )
    [ "$ECTO" == false ] && SETUP_FLAGS+=( --no-ecto )
    true
  }

  # create_project <SETUP_COMMAND> [PHOENIX_NEW_OPTIONS...]
    # Shared body of the 'new' and 'new2' commands: prepares the
    # workspace, builds the toolchain image, generates the Phoenix
    # project, registers the igniter package and runs SETUP_COMMAND (the
    # entrypoint branch, 'workbench_setup' or 'workbench_setup2') with
    # the SETUP_FLAGS its builder left. Finally bakes the workspace's own
    # dockerfile and compose file.
  create_project() {
    local setup_command="$1"; shift

    prepare_workspace && \
    cd "$SCRIPTS_DIR" && \
    docker build \
      --build-arg UID="$(id -u)" \
      --build-arg GID="$(id -g)" \
      --file $LOCAL_DOCKERFILE --tag $TOOLCHAIN_IMAGE . && \
    docker tag $TOOLCHAIN_IMAGE $LOCAL_IMAGE && \
    cd "$WORKBENCH_PATH" && \
    docker run \
      $DOCKER_TTY_FLAGS \
      --name "${APP_NAME}_workbench_new" \
      --rm \
      --volume $SOURCE_CODE_VOLUME \
      --volume $WORKBENCH_VOLUME \
      $TOOLCHAIN_IMAGE $CONTAINER_ENTRYPOINT new \
      $ELIXIR_PROJECT_NAME "$@" && \
    register_igniter_package && \
    docker run \
      $DOCKER_TTY_FLAGS \
      --name "${APP_NAME}_workbench_${setup_command}" \
      --rm \
      --volume $SOURCE_CODE_VOLUME \
      --volume $WORKBENCH_VOLUME \
      $TOOLCHAIN_IMAGE $CONTAINER_ENTRYPOINT $setup_command "${SETUP_FLAGS[@]}" && \
    # The project keeps its own baked copy of the toolchain dockerfile,
    # so a standalone clone (no workbench) can rebuild the same dev
    # image: the compose build points at it.
    cp "$SCRIPTS_DIR/$LOCAL_DOCKERFILE" "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" && \
    # The workspace owns its orchestration: compose with real values.
    # Its build points to the project-owned Dockerfile.local — and must
    # stay there: its app service also runs the workbench one-off
    # commands (setup, add, mix), which need the toolchain. The
    # production deployment never touches this file: 'up --env prod'
    # bakes docker-compose.prod.yml from the same seed with the
    # production Dockerfile.
    bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$COMPOSE_FILE"
  }

# SCRIPT =======================================================================

if [ $# -gt 0 ]; then
  if   [ "$1" == "login" ]; then
    shift

    if [ $# -eq 0 ]; then
      args_error \
        "Github user name is missing." \
        "Try add a user name as command argument."
    elif [ $# -eq 1 ]; then
      args_error \
        "Github personal access token (classic) is missing." \
        "Try add a token as command argument."
    else
      GITHUB_USER=$1
      GITHUB_TOKEN=$2
      REGISTRY_SERVER="ghcr.io"

      echo $GITHUB_TOKEN | docker login $REGISTRY_SERVER \
        --username $GITHUB_USER \
        --password-stdin
    fi

  elif [ "$1" == "new" ]; then
    shift

    # Host ports for this workspace: first available ones.
    APP_PORT=$(first_free_port 4000)
    PGADMIN_PORT=$(first_free_port 5050)

    build_setup_flags "$@" && \
    create_project workbench_setup "$@" && \
    if [ $EXDOC == true ]; then
      workspace_compose run \
        --rm \
        --name "${APP_NAME}_workbench_documentation" \
        --volume $WORKBENCH_VOLUME \
        app $CONTAINER_ENTRYPOINT documentation \
          $EXDOC \
          true \
          $COVERALLS
    fi

  elif [ "$1" == "new2" ]; then
    shift

    # Host ports for this workspace: first available ones.
    APP_PORT=$(first_free_port 4000)
    PGADMIN_PORT=$(first_free_port 5050)

    # The vanilla creation: config.conf's feature and application
    # settings are ignored on purpose — only the project name, the
    # workspace and the stack versions still apply, since they shape the
    # project generation and the images, not the Elixir configuration.
    build_setup2_flags "$@" && \
    create_project workbench_setup2 "$@"

  elif [ "$1" == "add" ]; then
    ENTRYPOINT_COMMAND=$1; shift

    if [ $EXISTING_PROJECT == true ]; then
      if [ $# -gt 0 ]; then
        workspace_compose run \
          --rm \
          --name "${APP_NAME}_workbench_${ENTRYPOINT_COMMAND}" \
          --volume $WORKBENCH_VOLUME \
          app $CONTAINER_ENTRYPOINT add $@

      else args_error "Missing feature name. Try: ./$(basename $0) add healthcheck"; fi
    else terminate "There is no project to add features to."; fi

  elif [ "$1" == "setup" ]; then
    ENTRYPOINT_COMMAND=$1; shift

    if [ $EXISTING_PROJECT == true ]; then
      [ $# -gt 1 ] && [ "$1" == "--env" ] || [ "$1" == "-e" ] && \
        ENV_ARG="$2" || \
        ENV_ARG=dev

      workspace_compose run \
        --rm \
        --name "${APP_NAME}_workbench_${ENTRYPOINT_COMMAND}" \
        --volume $WORKBENCH_VOLUME \
        app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $ENV_ARG

    else terminate "There is no project to setup."; fi

  elif [ "$1" == "up" ]; then
    COMPOSE_COMMAND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      parse_deploy_args "$@"

      # Every deployment of a workspace shares one compose project, but
      # not the same services: dev has 'app', the cluster has app1..N
      # plus balancer and migrate, and --replicas/--no-balancer change
      # that set between runs. Without --remove-orphans the containers of
      # the previous shape stay up, unmanaged and invisible to 'ps'.
      if [ "$ENV_ARG" == "cluster" ]; then
        bake_cluster_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$CLUSTER_COMPOSE_FILE" \
          $COMPOSE_COMMAND --detach --build --remove-orphans && \
        cluster_deployed_message

      elif [ "$ENV_ARG" == "prod" ]; then
        bake_prod_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" \
          $COMPOSE_COMMAND --detach --build --remove-orphans && \
        deployed_message

      else
        workspace_compose $COMPOSE_COMMAND --detach --remove-orphans && \
        deployed_message
      fi

    else terminate "There is no project to deploy."; fi

  elif [ "$1" == "build" ]; then
    shift
    if [ $EXISTING_PROJECT == true ]; then
      parse_deploy_args "$@"

      if [ "$ENV_ARG" == "cluster" ]; then
        # Said before building: whether the image comes out distributed is
        # decided by rel/env.sh.eex, which mix release bakes into it, so
        # installing the feature afterwards means building again.
        clustering_warning
        # Every replica shares one image: building app1 builds them all.
        bake_cluster_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$CLUSTER_COMPOSE_FILE" build app1 "${DEPLOY_REST[@]}"

      elif [ "$ENV_ARG" == "prod" ]; then
        bake_prod_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" build app "${DEPLOY_REST[@]}"

      else
        # Rebuilds the workspace's own dev image (APP:local) from its
        # project-owned Dockerfile.local; the next 'up' recreates the
        # containers with it.
        workspace_compose build app "${DEPLOY_REST[@]}"
      fi

    else terminate "There is no project to build."; fi

  elif [ "$1" == "logs" ]; then
    shift
    if [ $EXISTING_PROJECT == true ]; then
      if [ "$1" == "-e" ] || [ "$1" == "--env" ]
      then ENV_ARG="$2"; shift 2
      else ENV_ARG=dev; fi

      resolve_compose_file $ENV_ARG && \
      docker compose --file "$COMPOSE_TARGET" logs --follow $@

    else terminate "There is no project."; fi

  elif [ "$1" == "stop" ] || [ "$1" == "down" ] || [ "$1" == "ps" ]; then
    COMPOSE_COMMAND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      if [ "$1" == "-e" ] || [ "$1" == "--env" ]
      then ENV_ARG="$2"; shift 2
      else ENV_ARG=dev; fi

      # 'down' clears the project, orphans of other deployments included;
      # 'stop' and 'ps' do not accept the flag.
      [ "$COMPOSE_COMMAND" == "down" ] && ORPHANS="--remove-orphans" || ORPHANS=""

      resolve_compose_file $ENV_ARG && \
      docker compose --file "$COMPOSE_TARGET" $COMPOSE_COMMAND $ORPHANS

    else terminate "There is no project."; fi

  elif [ "$1" == "iex" ] || [ "$1" == "bash" ]; then
    SESSION_KIND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      if [ "$1" == "-e" ] || [ "$1" == "--env" ]
      then ENV_ARG="$2"; shift 2
      else ENV_ARG=dev; fi

      # The service to attach to: 'app' everywhere but in the cluster,
      # where the replicas are app1..appN.
      SERVICE="${1:-app}"
      resolve_compose_file $ENV_ARG

      app_is_running "$COMPOSE_TARGET" "$SERVICE" || terminate \
        "The $SERVICE container of the $ENV_ARG deployment is not running." \
        "Start it with: ./$(basename $0) up --env $ENV_ARG"

      # The release remote shell stops the node it is attached to when its
      # input reaches EOF, so a redirected or piped stdin would take the
      # application down instead of just detaching. Only dev is safe: its
      # 'iex -S mix' runs its own VM inside the container.
      if [ "$SESSION_KIND" == "iex" ] && [ "$ENV_ARG" != "dev" ] && [ ! -t 0 ]
      then terminate \
        "'iex --env $ENV_ARG' opens the release remote shell, which stops" \
        "the node when its input reaches EOF: it needs an interactive" \
        "terminal. To evaluate one expression without attaching, use:" \
        "  docker compose --file $COMPOSE_TARGET \\" \
        "    exec -T $SERVICE /app/bin/$ELIXIR_PROJECT_NAME rpc 'EXPRESSION'"
      fi

      # Only the dev image carries Mix and the mounted source; prod and
      # cluster run the release, whose shell is 'bin/<app> remote'.
      if [ "$ENV_ARG" == "dev" ]
      then
        if [ "$SESSION_KIND" == "iex" ]
        then SESSION_COMMAND="iex -S mix"
        else SESSION_COMMAND="bash"; fi
        WORKDIR_FLAGS=( --workdir /app/src )
      else
        if [ "$SESSION_KIND" == "iex" ]
        then SESSION_COMMAND="/app/bin/$ELIXIR_PROJECT_NAME remote"
        else SESSION_COMMAND="bash"; fi
        WORKDIR_FLAGS=()
      fi

      docker compose --file "$COMPOSE_TARGET" \
        exec "${WORKDIR_FLAGS[@]}" $SERVICE $SESSION_COMMAND

    else terminate "There is no project."; fi

  elif [ "$1" == "mix" ]; then
    shift
    if [ $EXISTING_PROJECT == true ]; then
      # Warm path: exec on the running app container (fast, no startup).
      # Cold path: one-off container (starts the database dependency too).
      if app_is_running; then
        workspace_compose exec --workdir /app/src app mix $@
      else
        workspace_compose run \
          --rm \
          --name "${APP_NAME}_workbench_mix" \
          --workdir /app/src \
          app mix $@
      fi

    else terminate "There is no project."; fi

  elif [ "$1" == "delete" ]; then
    if [ $EXISTING_PROJECT == true ]; then
      confirm \
        "This action will delete all project files from $WORKSPACE_PATH" \
        "along with its containers, images and database volumes." && \
      if [ -f "$WORKSPACE_PATH/$COMPOSE_FILE" ]; then
        workspace_compose down \
          --volumes \
          --rmi local \
          --remove-orphans
      fi && \
      wipe_workspace && \
      docker rmi $LOCAL_IMAGE 2>/dev/null; \
      rm -f "$SCRIPTS_DIR/$LOCAL_DOCKERFILE"

    else terminate "There is no project to delete."; fi

  elif [ "$1" == "demo" ]; then
    WORKBENCH_SCRIPT="$WORKBENCH_PATH/$(basename $0)"; shift;

    [ $# -gt 1 ] && [ "$1" == "--env" ] || [ "$1" == "-e" ] && \
      ENV_ARG="$2" || \
      ENV_ARG=dev

    "$WORKBENCH_SCRIPT" new && \
    "$WORKBENCH_SCRIPT" setup --env $ENV_ARG && \
    "$WORKBENCH_SCRIPT" up --env $ENV_ARG && \
    {
      # Following the logs blocks the demo while the application is
      # tried out. Ctrl+C hits the whole foreground process group, so
      # without the no-op trap it would also kill this script and the
      # delete step would never run ('' instead of ':' would not do:
      # children inherit an ignored SIGINT and the follower would not
      # detach).
      trap ':' INT
      "$WORKBENCH_SCRIPT" logs
      trap - INT
      "$WORKBENCH_SCRIPT" delete
    }

  elif [ "$1" == "help" ]; then
    help
  else args_error invalid; fi
else help; fi
