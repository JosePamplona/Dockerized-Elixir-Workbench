#!/bin/bash
# v0.0.0
# Lorem Ipsum Project
#
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃ Elixir App management script ┃ 
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
#
# CONFIGURATION ----------------------------------------------------------------

  export PROJECT_NAME="Lorem Ipsum Project"

  LOWER_CASE=$( echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' ) && \
  export              APP_NAME=$( echo "$LOWER_CASE" | tr ' ' '-' ) && \
  export   ELIXIR_PROJECT_NAME=$( echo "$LOWER_CASE" | tr ' ' '_' )
  export  COMPOSE_PROJECT_NAME=$APP_NAME
  export        CONTAINER_NAME="back-end.elixir_graphql"
  export                 IMAGE="$APP_NAME:develop"
  export    DEVELOP_DOCKERFILE="./Dockerfile.dev"
  export PRODUCTION_DOCKERFILE="./Dockerfile.prod"
  export    COMPOSE_DOCKERFILE=$PRODUCTION_DOCKERFILE
  export      SOURCE_CODE_PATH="./src"
  export    SOURCE_CODE_VOLUME="/$PWD/$SOURCE_CODE_PATH:/app/$SOURCE_CODE_PATH"
  export              ENV_FILE="./.env"
  export           README_FILE="./README.md"
  export              RUN_FILE="./run.sh"

  # Database configuration ---------------------------------------------------
  export               DB_USER="postgres"
  export               DB_PASS="postgres"
  export               DB_HOST="database_host"
  export               DB_PORT="5432"
  export               DB_NAME="lorem_ipsum_project_db"

  # PGAdmin configuration ----------------------------------------------------
  export          PGADMIN_PORT="5050"
  export         PGADMIN_EMAIL="pgadmin4@pgadmin.org"
  export      PGADMIN_PASSWORD="pass"
  export  PGADMIN_SERVERS_FILE="./servers.json"
  export     PGADMIN_PASS_FILE="./pgpass"

  # Elixir project configuration ---------------------------------------------
  export         INTERNAL_PORT="4000"
  export             HOST_PORT="4000"
  export              MIX_FILE="$SOURCE_CODE_PATH/mix.exs"
  export           CONFIG_FILE="$SOURCE_CODE_PATH/config/config.exs"
  export              DEV_FILE="$SOURCE_CODE_PATH/config/dev.exs"
  export            TIMESTAMPS="utc_datetime_usec"

  
  # Color codes
  export C1="\x1B[38;5;1m"
  #      Bold        Reset
  export B="\x1B[1m" R="\x1B[0m"
  
  # If echo handles -e option, overrides the command
  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi

# FUNCTIONS --------------------------------------------------------------------

  # readme
    # Prints readme file
  readme() {
    # wget https://github.com/charmbracelet/glow/releases/download/v1.4.1/glow_1.4.1_linux_amd64.deb	
    # sudo apt install ./glow_1.4.1_linux_amd64.deb
    if [ ! -f "$README_FILE" ]; then
      echo "The file $README_FILE does not exist."
      exit 1
    fi
    # cat "$README_FILE"
    # echo ""
    glow "$README_FILE"
  }

  # confirm <MESSAGE>
    # Prints MESSAGE and spects input prompt for continue or exit the script 
  confirm() {
    echo "⚠️  ${B}Warning${R}: $@"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then exit 0; fi
    echo ""
  }
  
  # failure
    # Prints error and spects input prompt for continue or cancel
  failure() {
    echo "🛑  ${B}${C1}Failure${R}"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then exit 1; fi
    echo ""
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

# SCRIPT -----------------------------------------------------------------------

if [ $# -gt 0 ]; then
  # Only necesary for private docker images
  if   [ $1 == "login" ]; then
    shift && \
    if [ $# -eq 0 ]; then
      args_error \
        "Github user name is missing." \
        "Try add a user name as command argument."
    elif [ $# -eq 1 ]; then
      args_error \
        "Github personal access token (classic) is missing." \
        "Try add a token as command argument."
    else
      # This solves the error:
      # retrieving credentials from store: error getting credentials -
      #   err: exit status 1,
      #   out: `exit status 2: gpg: decryption failed: No secret key`
      #
      # rm -rf ~/.password-store/docker-credential-helpers 
      # gpg --generate-key
      # pass init <your_generated_gpg-id_public_key>
      GITHUB_USER=$1 && \
      GITHUB_TOKEN=$2 && \
      REGISTRY_SERVER="ghcr.io" && \
      echo $GITHUB_TOKEN | docker login $REGISTRY_SERVER \
        --username $GITHUB_USER \
        --password-stdin
    fi

  # Tarball error will occur on Win11 using a XFAT drive for the repo on mix deps.get
  elif [ $1 == "init" ]; then
    # Configuration to properly work with docker
    RUN_COMMAND=$1 && \
    shift && \
    if [ -d $SOURCE_CODE_PATH ]; then
      confirm \
        "This action the overwrite the content of $SOURCE_CODE_PATH" \
        "directory." && \
      rm -r $SOURCE_CODE_PATH
    fi && \
    docker build \
      --file $DEVELOP_DOCKERFILE \
      --tag $IMAGE \
      . && \
    docker run \
      --rm \
      --tty \
      --interactive \
      --name "${APP_NAME}___${RUN_COMMAND}" \
      --volume "$SOURCE_CODE_VOLUME" \
      $IMAGE $RUN_FILE $RUN_COMMAND $ELIXIR_PROJECT_NAME && \
    sed -i "s/version:\s*\"[0-9]*.[0-9]*.[0-9]*\"/version: \"0.0.0\"/" $MIX_FILE && \
    sed -i "s/hostname: \"localhost\"/hostname: \"$DB_HOST\"/" $DEV_FILE && \
    sed -i "s/http: \[ip: {127, 0, 0, 1}/http: \[ip: {0, 0, 0, 0}/" $DEV_FILE && \
    echo "# .env\nexport PHX_SERVER=true" > $ENV_FILE

  elif [ $1 == "setup" ]; then
    # 1. Configures servers.json & pgpass files with credentials for PGAdmin
    # 2. Configures the elixir project
    #   2.1. Set schema timestamps
    # 3. Generates schema, changesets, context functions, tests and migration files
    # 4. Custom production ecto.reset
    RUN_COMMAND=$1 && \
    shift && \
    export COMPOSE_DOCKERFILE=$DEVELOP_DOCKERFILE && \
    sed -i "s/\"Host\": \"[^\"]\+\"/\"Host\": \"$DB_HOST\"/" \
      $PGADMIN_SERVERS_FILE && \
    sed -i "s/\"Port\": [^\"]\+/\"Port\": $DB_PORT,/" \
      $PGADMIN_SERVERS_FILE && \
    sed -i "s/\"Username\": \"[^\"]\+\"/\"Username\": \"$DB_USER\"/" \
      $PGADMIN_SERVERS_FILE && \
    echo $DB_HOST:$DB_PORT:\*:$DB_USER:$DB_PASS > $PGADMIN_PASS_FILE && \
    \
    if [ ! -z "$TIMESTAMPS" ]; then
      sed -i "s/\[timestamp_type: :.*\]/[timestamp_type: :$TIMESTAMPS]/" \
        $CONFIG_FILE
    fi && \
    \
    docker compose run \
      --build \
      --rm \
      --name "${APP_NAME}___${RUN_COMMAND}" \
      --publish $HOST_PORT:$INTERNAL_PORT \
      app $RUN_FILE $RUN_COMMAND
      
  elif [ $1 == "up" ]; then
    export COMPOSE_DOCKERFILE=$PRODUCTION_DOCKERFILE && \
    docker compose up --build

  elif [ $1 == "run" ]; then
    RUN_COMMAND=$1 && \
    shift && \
    if [ $# -gt 0 ]; then   
      export COMPOSE_DOCKERFILE=$DEVELOP_DOCKERFILE && \
      docker compose run \
        --build \
        --rm \
        --name "${APP_NAME}___${RUN_COMMAND}" \
        --publish $HOST_PORT:$INTERNAL_PORT \
        app $RUN_FILE $RUN_COMMAND $@

    else args_error "Missing command for container initialization."; fi

  elif [ $1 == "set-version" ]; then
    shift
    if [ $# -eq 0 ]; then
      args_error "Version is missing. Try add a version as command argument."
    elif [ $# -eq 1 ]; then
      export NEW_VERSION=$1
      if [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        confirm \
          "This action will update '$MIX_FILE' and '$README_FILE' " \
          "file contents." && \
        sed -i "s/version: \"[0-9]*.[0-9]*.[0-9]*\"/version: \"$NEW_VERSION\"/" $MIX_FILE && \
        sed -i "s/\[version - [0-9]*.[0-9]*.[0-9]*\]/[version - $NEW_VERSION]/" $README_FILE && \
        sed -i "s/badge\/version-[0-9]*.[0-9]*.[0-9]*/badge\/version-$NEW_VERSION/" $README_FILE && \
        echo "Version ${B}$NEW_VERSION${R} is now set." && \
        echo "Don't forget to update the CHANGELOG.md file!"
      else
        args_error \
          "${B}$NEW_VERSION${R} is not a valid version format. " \
          "Use semantic versioning standard."
      fi

    else args_error too_many; fi
  elif [ $1 == "prune" ]; then
    export CONTAINERS_TO_STOP="$(docker container ls -q)" && \
    if [ ! -z "$CONTAINERS_TO_STOP" ]; then
      echo "Stopping all containers...\n" && \
      docker stop $CONTAINERS_TO_STOP && \
      echo "\nAll containers are Stopped.\n"
    fi && \
    docker system prune -a --volumes

  else
    args_error invalid
  fi
else
  readme
fi