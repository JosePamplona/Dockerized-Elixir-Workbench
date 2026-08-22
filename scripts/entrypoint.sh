#!/bin/bash
# Elixir App image entrypoint script (Igniter edition)

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

      { echo y; echo n; } | mix phx.new . --app $PROJECT_NAME --verbose $@

    elif [ $# -lt 2 ]; then args_error missing
    else args_error too_many; fi

  elif [ "$1" == "workbench_setup" ]; then
    shift

    mix deps.get && \
    mix workbench.setup "$@" --yes && \
    # New deps may conflict with versions pinned by the initial lock
    # (e.g. swoosh locks idna 7.x while hackney needs ~> 6.1): on
    # failure, re-resolve the whole lock.
    { mix deps.get || { mix deps.unlock --all && mix deps.get; }; } && \
    mix phx.gen.release && \
    mix release.init

  elif [ "$1" == "add" ]; then
    shift
    if [ $# -ge 1 ]; then
      FEATURE=$1; shift

      mix deps.get && \
      mix "workbench.install.$FEATURE" "$@" --yes && \
      mix deps.get

    else args_error missing; fi

  elif [ "$1" == "documentation" ]; then
    shift
    if [ $# -ge 2 ]; then
      EXDOC=$1; shift
      ECTO=$1; shift
      COVERALLS=$1; shift
      
      if [ $EXDOC == true ]; then
        if [ $ECTO == true ]; then
          mix db && \
          MIX_ENV="test" mix ecto.drop --force --force-drop && \
          MIX_ENV="test" mix ecto.create --quiet && \
          MIX_ENV="test" mix ecto.migrate --quiet
        fi && \
        if [ $COVERALLS == true ]; then mix cover || true; fi && \
        mix docs
      fi

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
