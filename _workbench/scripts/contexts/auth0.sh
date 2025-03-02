#!/bin/bash
# Contexts files generation script

# SCHEMAS ----------------------------------------------------------------------

mix phx.gen.context \
  Accounts \
  User users \
    name:string \
    status:enum:active:blocked \
    email:string:unique \
    email_verified:boolean \
    phone_number:string \
    picture:string \
    token_sub:string:unique \
    --merge-with-existing-context
sleep 1