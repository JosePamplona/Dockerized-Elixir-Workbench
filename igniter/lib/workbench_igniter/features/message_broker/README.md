# Cartridge: message_broker

A message broker in the workspace, with the app publishing to it and
consuming from it — **pending**: identified, not designed yet.

* **Task**: `mix workbench.install.message_broker` (does not exist yet)

## Description

Two parts of a system that must not wait for each other need something
between them that takes a message and keeps it until it is handled.
This box is that: the broker as a service of the workspace, and in the
project the code that publishes and the supervised pipeline that
consumes.

The manifest is registered so the catalog shows the box as pending,
but nothing is designed and the installer is not written: nothing can
insert it yet.

## What it is expected to bring

Not decided — this is where the design starts from, and its
`DESIGN.md` settles each line:

* **The broker, in the compose**: [RabbitMQ](https://www.rabbitmq.com),
  declared by the cartridge like every other service
  (`compose/1`, role `messaging`), with its management page as a
  published address.
* **The pipeline, in the project**: [Broadway](https://hexdocs.pm/broadway)
  with its RabbitMQ producer for consuming, and a publisher beside it.
* **An example that runs**: one message published and consumed, with
  its test, so the insert is seen working and not only compiled.

Open, for the design: whether the broker is an option, as `db_admin`
offers several admins; how the three deployments differ (one consumer
in the pod, several replicas consuming in the scaled one); and what
the project's `.env` carries.

When it is built, fill this directory in like any other cartridge (see
the checklist in the package README): `DESIGN.md`, `task.ex`, its
templates under `priv/features/message_broker/`, its test and this
README.

## Contents

| File | Role |
| --- | --- |
| `message_broker.ex` | Manifest only (`pending?/0` returns `true`) |
| `NEED.md` | The need it answers |

Cartridge test: none until built.
