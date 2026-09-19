# dashboard — back copy

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

EVERY PROCESS, IN SIGHT.

## Blurb

Something is slow in dev and you're guessing: logs, :observer if you
remember how to start it, a hunch about which process it is. This
cartridge brings back the dashboard phx.new would have given you —
processes, memory, ETS, every request timed, the repo's queries when
there is one — live in the browser at /dev/dashboard, only in dev.

## Features

- Needs neither html nor LiveView first
- The socket and the scope follow your project
- Kept to dev, as phx.new leaves it

## Quote

If you want to use the LiveDashboard in production, you should put it behind authentication and allow only admins to access it. — phx.new, in the router it writes

## Requirements

REQUIRES: PHOENIX 1.8, LIVEDASHBOARD 0.8
WITH OR WITHOUT HTML, DEV ONLY

## Install

`./wb.sh add dashboard`

## Badge

--no-dashboard

## Screenshots

1. `shot-1.png` — The home page at /dev/dashboard: the system, live.
2. `shot-2.png` — The processes, sorted by memory, the heaviest named.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
