#!/bin/bash
# Migrations generation script

# SCHEMAS ----------------------------------------------------------------------

mix phx.gen.context \
  Lore \
  Army armies \
    name:string \
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
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Lore \
  Ability abilities \
    name:string \
    type:enum:passive:action \
    range:integer \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Lore \
  FormationAbility formation_abilities \
    formation_id:references:formations \
    ability_id:references:abilities \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Game \
  Player players \
    name:string \
    email:string \
    pass_hash:string \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Game \
  Match matches \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Game \
  Deck decks \
    match_id:references:matches \
    player_id:references:players \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Game \
  Turn turns \
    match_id:references:matches \
    player_id:references:players \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Game \
  Unit units \
    formation_id:references:formations \
    damage:integer \
    position:string \
    status:enum:ok:dead \
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
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Game \
  Target targets \
    command_id:references:commands \
    unit_id:references:units \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Battlefield \
  Terrain terrains \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Game \
  Sector sectors \
    match_id:references:matches \
    terrain_id:references:terrains \
    position:string \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Battlefield \
  Tile tiles \
    sheet_filename:string \
    sheet_position \
    --merge-with-existing-context && \
sleep 1 && \
mix phx.gen.context \
  Battlefield \
  Sprite sprite \
    terrain_id:references:terrains \
    tile_id:references:tiles \
    position:string \
    --merge-with-existing-context