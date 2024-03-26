#!/bin/bash
# Elixir Apps images initialization script

# CONFIGURATION ----------------------------------------------------------------
  
  export SOURCE_CODE_PATH="./src"

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

  # ecto_reset()
    # Custom version of `mix ecto.reset` for production enviroment
  ecto_reset() {
    export MIX_ENV=prod \
    && mix deps.get \
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

  default_cmd() { iex -S mix phx.server; }

  schemas() {
    mix phx.gen.context \
      Lore \
      Army armies \
        name:string \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Lore \
      Formation formations \
        army:enum:vampire:orc:undead:human \
        type:enum:light_artillery:light_infantry:light_cavalry:heavy_archer:heavy_infantry:heavy_cavalry:support:hero \
        name:string \
        background:text \
        cost:integer \
        hp:integer \
        range:integer \
        movement:integer \
        attack:array:string \
        defense:array:string \
        morale:array:string \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Lore \
      Ability abilities \
        name:string \
        type:enum:passive:action \
        range:integer \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Lore \
      FormationAbility formation_abilities \
        formation_id:references:formations \
        ability_id:references:abilities \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Game \
      Player players \
        name:string \
        email:string \
        pass_hash:string \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Game \
      Match matches \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Game \
      Deck decks \
        match_id:references:matches \
        player_id:references:players \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Game \
      Turn turns \
        match_id:references:matches \
        player_id:references:players \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Game \
      Unit units \
        formation_id:references:formations \
        damage:integer \
        position:string \
        status:enum:ok:dead \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Game \
      Command commands \
        turn_id:references:turns \
        unit_id:references:units \
        action:enum:move:attack:charge:ability \
        ability_id:references:abilities \
        initial_position:string \
        final_position:string \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Game \
      Target targets \
        command_id:references:commands \
        unit_id:references:units \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Battlefield \
      Terrain terrains \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Game \
      Sector sectors \
        match_id:references:matches \
        terrain_id:references:terrains \
        position:string \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Battlefield \
      Tile tiles \
        sheet_filename:string \
        sheet_position \
        --binary-id \
        --merge-with-existing-context && \
    sleep 1 && \
    mix phx.gen.context \
      Battlefield \
      Sprite sprite \
        terrain_id:references:terrains \
        tile_id:references:tiles \
        position:string \
        --binary-id \
        --merge-with-existing-context
  }

# SCRIPT -----------------------------------------------------------------------

  cd $SOURCE_CODE_PATH && \
  if [ "$1" == "init" ]; then
    shift
    if [ $# -ge 1 ]; then
      PROJECT_NAME=$1 && \
      shift && \
      {
        echo yes
        echo yes
      } | mix phx.new ./ --app $PROJECT_NAME --verbose $@

    elif [ $# -lt 2 ]; then args_error missing
    else args_error too_many; fi
  elif [ "$1" == "schemas" ];  then schemas;
  elif [ "$1" == "db-reset" ]; then ecto_reset;
  elif [ "$1" == "run" ]; then
    shift
    if [ $# -gt 0 ]; then
      eval $@
      read -n 1 -p "Press any key to stop and remove container..."
    else args_error missing; fi
  else default_cmd; fi
