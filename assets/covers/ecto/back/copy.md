# ecto — back copy

Set in the front's register (reverent), shared by the seven base
cartridges. Every string here is composited as typeset text, never
generated, so it can be any size and is exact. The blurb is the
cartridge's NEED.md — its sentence, its before and its after, in the
reader's second person; the features, the quote and the requirements
come from its DESIGN.md (the engine's from mailer's) — the decisions
with what each one buys, a source's own words, what it was verified
with; the install line from its README. The version is not here:
the tool reads it off the cartridge's CHANGELOG.md. The screenshots are
not taken yet: the captions say what each one has to show.

## Headline

EVERY RECORD, WELL KEPT.

## Blurb

Your app has data to keep, and it started without a database. Wiring a
repo by hand means four config files, a supervision tree and tests
that share one database. This cartridge brings back what phx.new
writes for the adapter you name: the repo, migrations, a sandbox per
test, DATABASE_URL in .env — and after a bake, the server in your
workspace. Choose it once.

## Features

- The four adapters phx.new offers, checked first
- Dev, test and release configured, as phx.new would
- DATABASE_URL written where the workspace reads it
- The compose follows the project after one bake

## Quote

When passing the --no-ecto flag, Phoenix generators such as phx.gen.html, phx.gen.json, phx.gen.live, and phx.gen.context may no longer work as expected as they generate context files that rely on Ecto for the database access. — mix help phx.new

## Requirements

REQUIRES: PHOENIX 1.8, ELIXIR 1.19 / OTP 27
POSTGRES, MYSQL, MSSQL OR SQLITE3

## Install

`./wb.sh add ecto [--database DB]`

## Badge

--no-ecto

## Screenshots

1. `shot-1.png` — The insert: a Repo in the tree, its address in .env.
2. `shot-2.png` — The first migration, run against a Postgres 17 server.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
