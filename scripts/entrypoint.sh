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

  # default_cmd()
    # Default command to initialize the server
  default_cmd() { mix phx.server; }

# SCRIPT -----------------------------------------------------------------------

  cd "src"

  if   [ "$1" == "new" ]; then
    shift
    if [ $# -ge 1 ]; then
      PROJECT_NAME=$1; shift
      
      { echo y; echo n; } | mix phx.new ./ --app $PROJECT_NAME --verbose $@

    elif [ $# -lt 2 ]; then args_error missing
    else args_error too_many; fi

  elif [ "$1" == "implementation_tasks" ]; then
    shift
    if [ $# -ge 4 ]; then
      AUTH0=$1; shift
      AUTH0_CONTEXT_FILE=$1; shift
      CUSTOM_SCHEMAS=$1; shift
      CUSTOM_SCHEMAS_CONTEXT_FILE=$1; shift
      
      mix deps.get && \
      if [ $AUTH0 == true ]; then source ../$AUTH0_CONTEXT_FILE; fi && \
      if [ $CUSTOM_SCHEMAS == true ]; then
        source ../$CUSTOM_SCHEMAS_CONTEXT_FILE
      fi

    elif [ $# -lt 4 ]; then args_error missing
    else args_error too_many; fi

  elif [ "$1" == "documentation" ]; then
    shift
    if [ $# -ge 2 ]; then
      EXDOC=$1; shift
      COVERALLS=$1; shift
      
      if [ $EXDOC == true ] && [ $COVERALLS == true ]; then
        MIX_ENV="test" && mix ecto.drop --force --force-drop && \
        MIX_ENV="test" && mix ecto.create --quiet && \
        MIX_ENV="test" && mix ecto.migrate --quiet && \
        mix cover || true
      fi && \
      if [ $EXDOC == true ]; then mix docs; fi

    elif [ $# -lt 2 ]; then args_error missing
    else args_error too_many; fi

  elif [ "$1" == "setup" ]; then
    shift
    if [ $# -gt 0 ]; then
      export MIX_ENV="$1" && \
      mix ecto.drop --force --force-drop && \
      mix ecto.setup
    
    else args_error missing; fi
    
  elif [ "$1" == "run" ]; then
    shift
    if [ $# -gt 0 ]; then
      eval $@
      read -n 1 -p "Press any key to stop and remove container..."
    
    else args_error missing; fi

  else default_cmd; fi
