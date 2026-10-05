# test_data — back copy

Set in the front's register (supporting). Every string here is
composited as typeset text, never generated, so it can be any size and
is exact. The blurb comes from the cartridge's NEED.md — its sentence,
its Before, its After and its Not for; the features, the quote and the
requirements from its DESIGN.md — the decisions with what each one
buys, Pryce's words for the pattern, what it was verified on; the
install line from its README. The version is not here: the tool reads
it off the cartridge's CHANGELOG.md. The badge is the front's.

Both screens are real, off a `phx.new` probe with the cartridge inserted
by `mix workbench.install.test_data`, two schemas generated and three
factories added to the module it wrote: the factory test with one
factory the database refuses, and the rules the module carries above
the factories that follow them.

## Headline

EVERYONE ELSE IS CAST.

## Blurb

Your tests need records, and only one value of each is what the test is
about. Write every user by hand and that value drowns; hide them in a
shared setup and nobody can see why the test passes. Here the defaults
are written once, the one value stays in the test, and Faker plays
everyone else. It builds data; standing in for a service is test_doubles'.

## Features

- insert(:user, name: "Ana"), the rest defaulted
- A broken factory fails under its own name
- On Ash, records made through the action
- Faker values that repeat under --seed

## Quote

Tests that don't care about the precise values in an Invoice can create one in a single line. — Nat Pryce, Test Data Builders

## Requirements

REQUIRES: ECTO OR ASH, ELIXIR 1.19
WORKS WITH EXMACHINA, FAKER, ASH

## Install

`./wb.sh add test_data`

## Badge

4 RULES

## Screenshots

1. `shot-1.png` — Two pass, one fails by name: the database refused it.
2. `shot-2.png` — The rules first, then the factories that follow them.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
