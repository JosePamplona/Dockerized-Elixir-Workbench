# dashboard_extras — back copy

Set in the front's register (kindling). Every string here is composited
as typeset text, never generated, so it can be any size and is exact.
The blurb comes from the cartridge's NEED.md — its sentence, its Before
and its After; the features, the quote and the requirements from its
DESIGN.md — the decisions with what each one buys, a source's own
words, what it was verified on and the databases LiveDashboard has
stats for; the install line from its README. The version is not here:
the tool reads it off the cartridge's CHANGELOG.md.

## Headline

BUILT IN. SWITCHED OFF.

## Blurb

Your dashboard came with two pages that show nothing: the machine's,
greyed out, and the database's, a card asking for a library. So you
watch the machine from another terminal, and look up the same catalog
queries every time. This cartridge brings what each page was waiting for, and
nothing else. Load, memory and disks; indexes, locks, cache hits, the
queries that run long — where you already look.

## Features

- Picks the library for your database, unasked
- No database yet? Run it again later
- Lit wherever the dashboard goes, production included

## Quote

The OS Data comes from the os_mon application, which ships as part of your Erlang distribution. — Phoenix LiveDashboard guide

## Requirements

REQUIRES: PHOENIX 1.8, LIVEDASHBOARD 0.8
READS POSTGRES, MYSQL, SQLITE

## Install

`./wb.sh add dashboard_extras`

## Badge

2 PAGES

## Screenshots

1. `shot-1.png` — The machine's page, lit: load, memory, and the disks below.
2. `shot-2.png` — The database's: eight checks it used to take a search to write.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
