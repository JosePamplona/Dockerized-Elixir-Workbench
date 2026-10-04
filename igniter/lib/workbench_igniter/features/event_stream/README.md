# Cartridge: event_stream

An event log in the workspace, with the app writing to it and reading
from it — **pending**: identified, not designed yet.

* **Task**: `mix workbench.install.event_stream` (does not exist yet)

## Description

A queue forgets a message once it is handled. A log does not: it keeps
the events in order, every group of consumers reads from its own
position, and a consumer that arrives late, fell behind or had a bug
can read again from where it needs to. This box is that: the log as a
service of the workspace, and in the project the code that writes
events and the supervised pipeline that reads them.

The manifest is registered so the catalog shows the box as pending,
but nothing is designed and the installer is not written: nothing can
insert it yet.

## What it is expected to bring

Not decided — this is where the design starts from, and its
`DESIGN.md` settles each line:

* **The log, in the compose**: [Apache Kafka](https://kafka.apache.org),
  declared by the cartridge like every other service (`compose/1`,
  role `messaging`), and a page to look at its topics.
* **The pipeline, in the project**: [Broadway](https://hexdocs.pm/broadway)
  with its Kafka producer for reading, and a writer beside it.
* **An example that runs**: one event written and read by a consumer
  group, with its test.

Open, for the design: whether the log is an option (a Kafka-compatible
server that is lighter to run in development); how long events are
kept; and the scaled deployment, where the replicas are one consumer
group and the partitions decide who reads what.

When it is built, fill this directory in like any other cartridge (see
the checklist in the package README): `DESIGN.md`, `task.ex`, its
templates under `priv/features/event_stream/`, its test and this
README.

## Contents

| File | Role |
| --- | --- |
| `event_stream.ex` | Manifest only (`pending?/0` returns `true`) |
| `NEED.md` | The need it answers |

Cartridge test: none until built.
