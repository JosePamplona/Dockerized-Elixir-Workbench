# exdebug — back copy

Set in the front's register (deadpan). Every string here is composited
as typeset text, never generated, so it can be any size and is exact.
Re-set 2026-09-20 against the cartridge's rewritten papers: the old
copy sold the box as part of `--enhance`, a world that is retired.

## Headline

LOOK, THEN LET IT THROUGH

## Blurb

Put `ExDebug.console/2` anywhere in a pipeline and it prints what is
passing at that point — your label and the time above it, the term in
colour, the app and its version under it — then hands the same value
on, untouched. It prints in `:dev` and `:test` only, so unlike an
`IO.inspect` you never have to go back and take it out. What
production should be told is the `Logger`'s job, not this one's.

## Features

- `{:ex_debug, "~> 1.0"}` in the deps, and nothing else
- A framed look: label, time, term, app and version
- Silent outside `:dev` and `:test`; the value passes through
- No config to keep: the defaults are the library's

## Requirements

REQUIRES: ELIXIR 1.14+, ONE WORKBENCH · VERIFIED ON 1.19.5 / OTP 27, IN MIX AND IN A RELEASE

## Badge

DEV & TEST

## Screenshots

1. `shot-1.png` — `ExDebug.console/2` inside a pipeline
2. `shot-2.png` — the library's documentation on HexDocs

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
