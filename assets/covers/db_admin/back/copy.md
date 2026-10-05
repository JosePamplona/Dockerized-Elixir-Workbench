# db_admin — back copy

Set in the front's register (lucid). Every string here is composited as
typeset text, never generated, so it can be any size and is exact. The
blurb comes from the cartridge's NEED.md — its sentence, its Before and
its After; the features and the requirements from its DESIGN.md — the
decisions with what each one buys, the databases each admin serves; the
install line from its README. The version is not here: the tool reads it
off the cartridge's CHANGELOG.md. The front's badge is the four admins'
marks; the back's is their count.

## Headline

NO MORE SQL IN THE DARK

## Blurb

You wanted one look at a table and got a shell: into the container,
then psql, mysql or sqlcmd, \dt or its cousin, and the same query
retyped for every table. This cartridge puts a database admin in the
browser beside your database, on its own port, already open on it — the
one made for your database, or any of the four you ask for.

## Features

- Picks the admin made for your database
- Opens on your database, signed in
- Add another admin whenever you like

## Requirements

REQUIRES: ECTO, ON ANY OF ITS DATABASES
SERVES POSTGRES, MYSQL, SQL SERVER, SQLITE

## Install

`./wb.sh add db_admin`

## Badge

4 ADMINS

## Screenshots

1. `shot-1.png` — Adminer on Postgres: the password was all you typed.
2. `shot-2.png` — phpMyAdmin on MySQL: signed in before you arrived.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
