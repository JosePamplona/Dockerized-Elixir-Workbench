# exdebug — back copy

Set in the front's register (deadpan). Every string here is composited
as typeset text, never generated, so it can be any size and is exact.

## Headline

LOOK, THEN LET IT THROUGH

## Blurb

Put `ExDebug.console/2` anywhere in a pipeline and it prints what is
passing at that point — the term in a labelled frame, with the time
and the app version — then hands the same value on, untouched. It
prints in `:dev` and `:test` only; in `:prod` the call is a no-op and
the data goes through. Inspect values comfortably while developing,
and leave the calls where they are.

## Features

- `{:ex_debug, "~> 1.0"}` in the deps, and nothing else
- `ExDebug.console/2` with a label, a width and colours
- Prints in `:dev` and `:test`, silent in `:prod`
- Installed by `--enhance`; re-running is a no-op

## Requirements

REQUIRES: DOCKER, ONE WORKBENCH · PART OF `--enhance`

## Badge

DEV & TEST

## Screenshots

1. `shot-1.png` — `ExDebug.console/2` inside a pipeline
2. `shot-2.png` — the library's documentation on HexDocs

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
