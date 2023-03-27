#!/bin/bash
# Elixir Apps images initialization script

# CONFIGURATION ----------------------------------------------------------------
  
  # Text formatting codes
  export C1="\x1B[38;5;1m"
  export B="\x1B[1m"
  export R="\x1B[0m"

  # Prints service script name with arguments detail
  if [ $# -gt 0 ]; then echo "[$HOSTNAME]$0($#): $@"; fi

  # If echo handles -e option, overrides the command
  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi

# FUNCTIONS --------------------------------------------------------------------

  # failure()
    # Prints error and spects input prompt for continue or cancel
  failure() {
    echo "🛑  ${B}${C1}Failure${R}"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then
      exit 1
    fi
    echo ""
  }

  # ecto_reset()
    # Custom version of `mix ecto.reset` for production enviroment
  ecto_reset() {
    export MIX_ENV=prod \
    && mix ecto.drop --force --force-drop \
    && mix ecto.create \
    && (
      mix ecto.migrate \
      || for FILE in ./priv/repo/migrations/*
      do
        mix ecto.migrate --step 1 \
        || { failure && rm $FILE; }
      done
    )
  }

# SCRIPT -----------------------------------------------------------------------

if [ "$1" == "init" ]; then
  shift
  if [ $# -eq 2 ]; then
    export PROJECT_PATH=$1
    export PROJECT_NAME=$2
    {
      echo yes
      echo yes
    } | mix phx.new $PROJECT_PATH --app $PROJECT_NAME --verbose
  elif [ $# -lt 2 ]; then
    echo "Missing arguments."
    exit 1
  else
    echo "Too many arguments."
    exit 1
  fi
elif [ "$1" == "run" ]; then
  shift
  if [ $# -gt 1 ]; then
    export SOURCE_CODE_PATH=$1
    shift
    cd $SOURCE_CODE_PATH && \
    eval $@
    read -n 1 -p "Press any key to stop and remove container..."
  else
    echo "Missing arguments."
    exit 1
  fi
elif [ "$1" == "setup" ]; then
  shift
  if [ $# -eq 1 ]; then
    export SOURCE_CODE_PATH=$1
    shift
    cd $SOURCE_CODE_PATH && \
    mix phx.gen.context \
      Accounts \
      User users \
        name:string \
        age:integer
  else
    echo "Missing arguments."
    exit 1
  fi
else # No arguments (Default)
  readme
fi
