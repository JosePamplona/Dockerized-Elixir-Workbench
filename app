#!/bin/bash
#
# ┏━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃ App management script ┃ 
# ┗━━━━━━━━━━━━━━━━━━━━━━━┛
#
# CONFIGURATION ----------------------------------------------------------------

  export PROJECT_NAME="Massive Combat"

  LOWER_CASE=$( echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' ) && \
  export APP_NAME=$( echo "$LOWER_CASE" | tr ' ' '-' ) && \
  export ELIXIR_PROJECT_NAME=$( echo "$LOWER_CASE" | tr ' ' '_' )
  export COMPOSE_PROJECT_NAME=$( echo "$PROJECT_NAME" | tr ' ' '-' )
  export DEVELOP_IMAGE="$APP_NAME:develop"
  export SOURCE_CODE_PATH="./src"
  export SOURCE_CODE_VOLUME="/$PWD/src:/app/src"
  export MIX_FILE="$SOURCE_CODE_PATH/mix.exs"
  export DEV_FILE="$SOURCE_CODE_PATH/config/dev.exs"
  export RUN_FILE="./run.sh"
  export INTERNAL_PORT="4000"
  export HOST_PORT="80"
  
  # Text formatting codes
  export C1="\x1B[38;5;1m"
  export B="\x1B[1m"
  export R="\x1B[0m"
  
  # If echo handles -e option, overrides the command
  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi

# FUNCTIONS --------------------------------------------------------------------

  # confirm <MESSAGE>
    # Prints MESSAGE and spects input prompt for continue or exit the script 
  confirm() {
    echo "⚠️  ${B}Warning${R}: $@"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then
      exit 0
    fi
    echo ""
  }
  
  # failure
    # Prints error and spects input prompt for continue or cancel
  failure() {
    echo "🛑  ${B}${C1}Failure${R}"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then
      exit 1
    fi
    echo ""
  }

# SCRIPT -----------------------------------------------------------------------

  if [ $# -gt 0 ]; then
    if   [ $1 == "init" ]; then
      shift
      if [ -d $SOURCE_CODE_PATH ]; then
        confirm \
          "This action the overwrite the content of $SOURCE_CODE_PATH" \
          "directory." && \
        rm -r $SOURCE_CODE_PATH
      fi && \
      docker build \
        --file Dockerfile.dev \
        --tag $DEVELOP_IMAGE \
        . && \
      docker run \
        --rm \
        --tty \
        --interactive \
        --name "${APP_NAME}___init" \
        --volume "$SOURCE_CODE_VOLUME" \
        $DEVELOP_IMAGE $RUN_FILE \
        init $SOURCE_CODE_PATH $ELIXIR_PROJECT_NAME || \
      failure
    elif [ $1 == "run" ]; then
      shift
      if [ $# -gt 0 ]; then
        docker compose run \
          --build \
          --rm \
          --name "${APP_NAME}___run" \
          --publish $HOST_PORT:$INTERNAL_PORT \
          app $RUN_FILE \
          run $SOURCE_CODE_PATH $@ || \
        failure
      else
        echo "Missing command for container initialization."
        exit 1
      fi
    elif [ $1 == "setup" ]; then
      shift
      confirm "This action will modify $DEV_FILE file content."
      sed -i "s/hostname: \"localhost\"/hostname: \"database\"/" $DEV_FILE && \
      sed -i "s/http: \[ip: {127, 0, 0, 1}/http: \[ip: {0, 0, 0, 0}/" $DEV_FILE
    elif [ $1 == "set-version" ]; then
      shift
      if [ $# -eq 0 ]; then
        echo "Version is missing. Try add a version as command argument."
        exit 1
      elif [ $# -eq 1 ]; then
        export NEW_VERSION=$1
        if [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          confirm "This action will update $MIX_FILE file content."
          sed -i "s/version:\s*\"[0-9]*.[0-9]*.[0-9]*\"/version: \"$NEW_VERSION\"/" $MIX_FILE && \
          echo "Version ${B}$NEW_VERSION${R} is now set." && \
          echo "Don't forget to update the CHANGELOG.md file!"
        else
          echo "${B}$NEW_VERSION${R} is not a valid version format. Use semantic versioning standard."
          exit 1
        fi
      else
        echo "Too many arguments."
        exit 1
      fi
    else
      echo "Invalid argument."
      exit 1
    fi
  else
    readme
  fi