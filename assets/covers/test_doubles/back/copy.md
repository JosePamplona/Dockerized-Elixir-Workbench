# test_doubles — back copy

Set in the front's register (understudy). Every string here is
composited as typeset text, never generated, so it can be any size and
is exact. The blurb is the cartridge's NEED.md — its sentence, its
before and its after, in the reader's second person; the features, the
quote and the requirements come from its DESIGN.md — the decisions with
what each one buys, a source's own words, what it was read against; the
install line from its README. The version is not here: the tool reads
it off the cartridge's CHANGELOG.md.

## Headline

THE REAL ONE NEVER ANSWERS

## Blurb

Your tests must not call the real thing. Today they reach the network,
or replace `File` for the whole machine and take the suite's
concurrency with it. This cartridge sends in a stand-in instead: Mox
builds a new module against a contract you declare, Mimic copies the
one you did not write and answers in its place. The performance is
identical. Nothing real is ever called.

## Features

- Mox where you own the contract
- Mimic where the module is not yours
- Every double per process: `async: true` stays
- Each cartridge owns its block of the test helper

## Quote

I always consider 'mock' to be a noun, never a verb. — José Valim, *Mocks and explicit contracts*

## Requirements

REQUIRES: ELIXIR 1.19 / OTP 28, EXUNIT
READ AGAINST: MOX 1.3, MIMIC 2.4, HAMMOX 1.0

## Install

`./wb.sh add test_doubles`

## Badge

2 DOUBLES

## Screenshots

1. `shot-1.png` — One block in the shared helper, and the dep behind it.
2. `shot-2.png` — Nine tests, and the sync column at zero.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
