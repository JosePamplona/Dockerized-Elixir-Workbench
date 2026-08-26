# exdebug — back copy

Set in the front's register (deadpan). Every string here is composited
as typeset text, never generated, so it can be any size and is exact.

## Headline

THE VALUE PASSES UNCHANGED

## Blurb

Chain `ExDebug.console/2` anywhere in a pipeline and it prints what is
flowing through at that point — the term in a labelled frame, with the
time and the app version — then hands the same value on, untouched.
It prints in `:dev` and `:test` only; in `:prod` the call is a no-op and
the data passes through. Inspect values comfortably while developing,
and leave the calls in.

## Features

- `{:ex_debug, "~> 1.0"}` in the deps, and nothing else
- `ExDebug.console/2` with a label, a width and colours
- Prints in `:dev` and `:test`, silent in `:prod`
- Configured once for the project in `config.exs`

## Requirements

REQUIRES: DOCKER, ONE WORKBENCH · PART OF `--enhance`

## Badge

80 COLUMNS

## Screenshots

1. `shot-1.png` — `ExDebug.console/2` inside a pipeline, with a label
2. `shot-2.png` — a map and a tuple through the same call, syntax coloured
3. `shot-3.png` — the library's documentation on HexDocs

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
