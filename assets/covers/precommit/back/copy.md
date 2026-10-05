# precommit — back copy

Set in the front's register (scrupulous). Every string here is
composited as typeset text, never generated, so it can be any size and
is exact. The blurb comes from the cartridge's NEED.md — its sentence,
its Before and After, and the Not for, since it saves a buyer the one
mistake this box invites; the features, the quote and the requirements
from its DESIGN.md — the decisions with what each one buys, git's own
words, what it was verified on. The install line is the README's. The
version is not here: the tool reads it off the cartridge's CHANGELOG.md.

The badge is the one the front does not carry: `4 CHECKS` was stamped
on the photographic hero once and taken off, where a typeset chip read
as a sticker from another system. On the back everything is typeset,
and the fact goes where the box states its facts.

## Headline

HELD AT YOUR DOOR.

## Blurb

The build goes red twenty minutes after the push, over a file nobody
formatted — and your machine has no Elixir to have caught it. This hook
runs the project's own checks in the project's own container, before
the commit exists, and refuses it on the first failure. It is a shell
script you can read and reorder. It stops you, and only you: what must
hold for everyone is CI's.

## Features

- Runs in the container: the host needs only Docker
- Every cartridge owns its block of the hook
- The formatter first, the suite only when asked

## Quote

Exiting with a non-zero status from this script causes the git commit command to abort before creating a commit. — githooks(5), the Git manual

## Requirements

REQUIRES: DOCKER ON THE HOST, GIT
WORKS WITH CREDO AND COVERALLS

## Install

`./wb.sh add precommit`

## Badge

4 CHECKS

## Screenshots

1. `shot-1.png` — Refused at the door: the formatter, in the container.
2. `shot-2.png` — The hook is a file you own, one block per box.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
