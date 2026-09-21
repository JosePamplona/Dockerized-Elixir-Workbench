# credo — back copy

Set in the front's register (tireless). Every string here is composited
as typeset text, never generated, so it can be any size and is exact.
The blurb comes from the cartridge's NEED.md — its sentence, its Before,
its After and its Not for; the features, the quote and the requirements
from its DESIGN.md — the decisions with what each one buys, Credo's own
words for itself, what it needs; the install line from its README. The
version is not here: the tool reads it off the cartridge's CHANGELOG.md.
The front's badge is Credo's mark; the back's is the fact the mark's
five bars carry.

Both screens are real, off a `phx.new` probe with the cartridge inserted
by `mix workbench.install.credo --githook`: `mix credo` over a module
written the way reviews keep finding them, and the hook file exactly as
the cartridge and the precommit box left it.

## Headline

NOBODY SAYS IT TWICE.

## Blurb

You know the review: the same remarks about naming, nesting and the
function nobody calls, made by hand by someone tired of making them.
Credo makes them before the code lands — the thousandth time exactly as
the first — and with --githook, before the commit exists. It reads
style and structure, not behaviour: the bugs are still your tests' job.

## Features

- Refuses a commit before anything compiles
- A hook your first commit can pass
- Credo as its author wrote it

## Quote

Credo is a static code analysis tool for the Elixir language with a focus on teaching and code consistency. — the Credo README

## Requirements

REQUIRES: ANY MIX PROJECT, CREDO 1.7
WORKS WITH THE PRECOMMIT HOOK AND CI

## Install

`./wb.sh add credo --githook`

## Badge

5 GROUPS

## Screenshots

1. `shot-1.png` — Three remarks, no heat: `mix credo` on a shift report.
2. `shot-2.png` — Its own block in the hook, above the slow checks.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
