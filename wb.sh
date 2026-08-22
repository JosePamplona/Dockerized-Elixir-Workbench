#!/bin/bash
# Dockerized workbench script (Igniter edition)
# v0.6.0
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
    LOCAL_DOCKERFILE="Dockerfile.local"
    LOCAL_DOCKERFILE_SEED="Dockerfile.seed.local"
    PROD_DOCKERFILE="Dockerfile"
    COMPOSE_FILE="docker-compose.yml"
    PROD_COMPOSE_FILE="docker-compose.prod.yml"
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
    # Port the server binds INSIDE the containers; the host ports are
    # chosen per workspace and mapped to this one in its compose file.
    APP_INTERNAL_PORT="4000"
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
    sed -i "s/%{postgres_image_version}/$POSTGRES_IMAGE_VERSION/" $file_path
    sed -i "s/%{pgadmin_image_version}/$PGADMIN_IMAGE_VERSION/"  $file_path

    # Remove the database & pgadmin services on projects without Ecto
    # (the network holder and the pod structure remain).
    if ! grep -q "ecto_repos" "$WORKSPACE_PATH/config/config.exs" 2>/dev/null
    then
      sed -i '/^  database:/,$d'            $file_path
      sed -i '/^    depends_on:/,+2d'       $file_path
      sed -i '/# pgAdmin port/,/:5050$/d'   $file_path
    fi
  }

  # workspace_app_port
    # Reads the application host port from the workspace's compose file.
  workspace_app_port() {
    sed -n 's/^ *- \([0-9]*\):4000$/\1/p' "$WORKSPACE_PATH/$COMPOSE_FILE" | \
    head -n 1
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
      "container, and features can be added later with the 'add' command." \
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

    print_command "add [FEATURE] [OPTIONS]"
    section_content \
      "Install a workbench feature on the existing project." \
      "- FEATURE: One of: healthcheck, rest, graphql, coveralls, exdoc," \
      "  enhancements, auth0, openai, credo, githooks, exmachina, mock," \
      "  exdebug, psql_extras, osmon." \
      "- OPTIONS: Flags for the 'mix workbench.install.FEATURE' task."

    print_command "setup [-e, --env ENV]"
    section_content \
      "Set or reset the database (if any) and run the seeding script." \
      "- ENV: Enviroment database to setup (Defalut: dev)."

    print_command "up [-e, --env ENV]"
    section_content \
      "Deploy the application on localhost." \
      "- ENV: Enviroment to deploy (Defalut: dev)."

    print_command "run [ARGS...]"
    section_content \
      "Deploy the application executing custom entrypoint commands." \
      "- ARGS: Command(s) to be executed as back-end entrypoint. "

    print_command "delete"
    section_content \
      "Deletes the workspace project files and its Docker compose project."

    print_command "demo [-e, --env ENV]"
    section_content \
      "Runs consecutively new, setup, up & delete commands." \
      "- ENV: Enviroment to deploy (Defalut: dev)."

    print_command "prune"
    section_content \
      "Stops all containers and prune Docker."

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
    ENTRYPOINT_COMMAND=$1; shift

    # Host ports for this workspace: first available ones.
    APP_PORT=$(first_free_port 4000)
    PGADMIN_PORT=$(first_free_port 5050)

    build_setup_flags "$@" && \
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
      --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
      --rm \
      --volume $SOURCE_CODE_VOLUME \
      --volume $WORKBENCH_VOLUME \
      $TOOLCHAIN_IMAGE $CONTAINER_ENTRYPOINT new \
      $ELIXIR_PROJECT_NAME $@ && \
    register_igniter_package && \
    docker run \
      $DOCKER_TTY_FLAGS \
      --name "${APP_NAME}___workbench_setup" \
      --rm \
      --volume $SOURCE_CODE_VOLUME \
      --volume $WORKBENCH_VOLUME \
      $TOOLCHAIN_IMAGE $CONTAINER_ENTRYPOINT workbench_setup "${SETUP_FLAGS[@]}" && \
    # The project keeps its own baked copy of the toolchain dockerfile,
    # so a standalone clone (no workbench) can rebuild the same dev
    # image: the compose build points at it.
    cp "$SCRIPTS_DIR/$LOCAL_DOCKERFILE" "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" && \
    # The workspace owns its orchestration: compose with real values.
    # Its build points to the project-owned Dockerfile.local; switching
    # to the production Dockerfile is a manual edit of the compose file.
    bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$COMPOSE_FILE" && \
    if [ $EXDOC == true ]; then
      workspace_compose run \
        --rm \
        --name "${APP_NAME}___documentation" \
        --volume $WORKBENCH_VOLUME \
        app $CONTAINER_ENTRYPOINT documentation \
          $EXDOC \
          true \
          $COVERALLS
    fi

  elif [ "$1" == "add" ]; then
    ENTRYPOINT_COMMAND=$1; shift

    if [ $EXISTING_PROJECT == true ]; then
      if [ $# -gt 0 ]; then
        workspace_compose run \
          --rm \
          --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
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
        --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
        --volume $WORKBENCH_VOLUME \
        app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $ENV_ARG

    else terminate "There is no project to setup."; fi

  elif [ "$1" == "up" ]; then
    COMPOSE_COMMAND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      [ $# -gt 1 ] && [ "$1" == "--env" ] || [ "$1" == "-e" ] && \
        ENV_ARG="$2" || \
        ENV_ARG=dev

      if [ "$ENV_ARG" == "prod" ]; then
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
        # The production image is self-contained: no source code volume,
        # and its Dockerfile takes no build identity (runs as nobody).
        sed -i '/^    volumes:/,+1d' "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" && \
        sed -i '/^      # These arguments/,/GID:/d' \
          "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" && \
        docker compose \
          --file "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" $COMPOSE_COMMAND --build

      else
        workspace_compose $COMPOSE_COMMAND
      fi

    else terminate "There is no project to deploy."; fi

  elif [ "$1" == "run" ]; then
    ENTRYPOINT_COMMAND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      if [ $# -gt 0 ]; then
        workspace_compose run \
          --rm \
          --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
          --volume $WORKBENCH_VOLUME \
          app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $@

      else args_error "Missing command for container initialization."; fi
    else terminate "There is no project to deploy."; fi

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
    "$WORKBENCH_SCRIPT" delete

  elif [ "$1" == "prune" ]; then
    CONTAINERS_TO_STOP="$(docker container ls -q)"

    if [ ! -z "$CONTAINERS_TO_STOP" ]; then
      echo "Stopping all containers...\n"
      docker stop $CONTAINERS_TO_STOP && \
      echo "\nAll containers are Stopped.\n"
    fi && \
    docker system prune -a --volumes

  elif [ "$1" == "help" ]; then
    help
  else args_error invalid; fi
else help; fi
