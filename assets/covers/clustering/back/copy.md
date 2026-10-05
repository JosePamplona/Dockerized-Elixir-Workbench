# clustering — back copy

Set in the front's register (ominous). Every string here is composited
as typeset text, never generated, so it can be any size and is exact.

## Headline

NO NODE IS ALONE

## Blurb

The release boots as a named distributed node, `app@<ip>`, and
DNSCluster dials every address one DNS name resolves to. Replicas of
the same image find each other with no wire between them: PubSub
crosses nodes, Presence replicates, and a remote shell on any node
sees the whole cluster.

## Features

- `rel/env.sh.eex`: boots as a named node
- `DNS_CLUSTER_QUERY`: one name, every replica
- Coordination across replicas, not capacity

## Requirements

REQUIRES: DOCKER, A PROD RELEASE · `./wb.sh add clustering`

## Badge

PROD ONLY

## Screenshots

1. `shot-1.png` — a remote shell on one replica: `node()` and `Node.list()`

## Legal

github.com/JosePamplona/Dockerized-Elixir-Workbench
MIT licence · Actual screens shown.
