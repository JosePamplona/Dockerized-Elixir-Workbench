#!/bin/bash
# Elixir App image entrypoint script

# Prints service script name with arguments detail
if [ $# -gt 0 ]; then echo "[$HOSTNAME]$0($#): $@"; fi

# CONFIGURATION ----------------------------------------------------------------
  # Text formatting codes
  export C1="\x1B[38;5;1m"
  export B="\x1B[1m"
  export R="\x1B[0m"

# FUNCTIONS --------------------------------------------------------------------

  # If echo handles -e option, overrides the command
  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi

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

  # setup() <ENV>
    # Run specific setup scripts for given enviroment.
  setup() { 
    export MIX_ENV="$1" && \
    mix ecto.drop --force --force-drop && \
    mix ecto.setup
  }

  # default_cmd()
    # Default command to initialize the server
  default_cmd() { mix phx.server; }

  schemas() { source ../schemas.sh; }

# SCRIPT -----------------------------------------------------------------------

  cd "src"

  if   [ "$1" == "new" ]; then
    shift
    if [ $# -ge 1 ]; then
      PROJECT_NAME=$1 && \
      shift && \
      {
        echo yes
        echo yes
      } | mix phx.new ./ --app $PROJECT_NAME --verbose $@ && \
      MIX_ENV=prod && \
      mix deps.get && \
      mix deps.compile

    elif [ $# -lt 2 ]; then args_error missing
    else args_error too_many; fi
  elif [ "$1" == "schemas" ]; then schemas;
  elif [ "$1" == "setup" ]; then setup $2;
  elif [ "$1" == "run" ]; then
    shift
    if [ $# -gt 0 ]; then
      eval $@
      read -n 1 -p "Press any key to stop and remove container..."
    else args_error missing; fi
  else default_cmd; fi
