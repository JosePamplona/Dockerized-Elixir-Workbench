#!/bin/bash
# Contexts files generation script

# SCHEMAS ----------------------------------------------------------------------

mix phx.gen.context \
  Assistant \
  Conversation conversations \
    user_id:references:users \
    name:string \
    --merge-with-existing-context
sleep 1
mix phx.gen.context \
  Assistant \
  Message messages \
    conversation_id:references:conversations \
    index:integer \
    role:enum:assistant:function:system:user \
    content:text \
    --merge-with-existing-context
sleep 1