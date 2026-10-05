# coverage — back copy

Set in the front's register (cartographic). Every string here is
composited as typeset text, never generated, so it can be any size and
is exact. The blurb comes from the cartridge's NEED.md — its sentence,
its Before, its After and its Not for; the features and the
requirements from its DESIGN.md — the decisions with what each one
buys; the install line from its README. The version is not here: the
tool reads it off the cartridge's CHANGELOG.md. The badge is the
front's.

## Headline

CHART WHAT THE TESTS MISSED

## Blurb

Your suite is green, and it says nothing about the lines it never ran.
This cartridge charts them: `mix cover` runs the suite and hands you a
percentage, a report that shows every file line by line, and a minimum
the build refuses to go under. It will not tell you the tests are
right — only where they never looked.

## Features

- A report page with your project's name
- Fails the build under 80%, one number to raise
- Leaves out the wiring phx.new wrote
- The same report as Markdown, in TESTING.md

## Requirements

REQUIRES: EXCOVERALLS 0.18
WORKS IN CI, OR BEFORE EVERY COMMIT

## Install

`./wb.sh add coverage`

## Badge

80% MIN

## Screenshots

1. `shot-1.png` — The report: 93.4%, over a floor of 80.
2. `shot-2.png` — In red, the lines nobody ran.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
