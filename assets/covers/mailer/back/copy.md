# mailer — back copy

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

EVERY LETTER, SEEN FIRST.

## Blurb

Your app sends mail, and you want to read it before anyone else does.
Without a mailer you wire a real account into dev, or inspect a struct
and hope. This cartridge asks phx.new for the mailer it would have
written: every mail lands in /dev/mailbox, tests assert on it, and
production sends through the adapter you choose.

## Features

- What phx.new writes, at your Phoenix's version
- Your own edits survive the three-way merge
- A conflict leaves the file untouched, reported
- No guessed provider: production stays your choice

## Quote

Given three files <current>, <base> and <other>, git merge-file incorporates all changes that lead from <base> to <other> into <current>. — git-merge-file(1)

## Requirements

REQUIRES: PHOENIX 1.8, ELIXIR 1.19
VERIFIED WITH PHX.NEW 1.8.9 AND 1.8.12

## Install

`./wb.sh add mailer`

## Badge

--no-mailer

## Screenshots

1. `shot-1.png` — The first mail, kept at /dev/mailbox and read in the browser.
2. `shot-2.png` — One insert: phx.new asked twice, the difference merged in.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
