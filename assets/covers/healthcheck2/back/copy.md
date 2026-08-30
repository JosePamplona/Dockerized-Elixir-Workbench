# healthcheck2 — back copy

Set in the front's register (laconic). Every string here is composited
as typeset text, never generated, so it can be any size and is exact.
The blurb, the features, the quote and the requirements come from the
cartridge's DESIGN.md — the problem, the decisions with what each one
buys, a source's own words, what it was verified on and what it runs
under; the install line from its README. The version is not here: the
tool reads it off the cartridge's CHANGELOG.md.

## Headline

ALIVE IS NOT READY.

## Blurb

Every few seconds the platform asks your application two questions:
is it alive, and can it take traffic. They are not the same question.
Answer them with one route and a dead database restarts every
replica — and no restart brings a database back. This cartridge
answers each on its own route, first in the endpoint, before anything
else runs.

## Features

- Liveness that never restarts you for a lost database
- Readiness that sheds traffic before requests time out
- Answers before the router, the logs, the session

## Quote

Incorrect implementation of liveness probes can lead to cascading failures. — Kubernetes documentation

## Requirements

REQUIRES: PHOENIX 1.8, ELIXIR 1.19 / OTP 27
WORKS WITH KUBERNETES, FLY.IO, AWS ECS

## Install

`./wb.sh add healthcheck2`

## Badge

EVERY ENV

## Screenshots

1. `shot-1.png` — Alive, ready — and then not: the database stopped.
2. `shot-2.png` — Seven tests through the endpoint, none through the router.

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
