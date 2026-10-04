# Cartridge: machine_learning

A model served from inside the application, with
[Nx](https://github.com/elixir-nx/nx) — **pending**: identified, not designed yet.

* **Task**: `mix workbench.install.machine_learning` (does not exist yet)

## Description

Putting a model behind a feature usually means a second service in
another language: another runtime to deploy, a network call per answer.
Nx is numerical computing for Elixir — tensors, and compilers that run
them at native speed — and around it there is what serving a model
takes: pretrained models loaded from the project, and a serving in the
supervision tree that batches the requests of every caller. This box
is that, in a project that had none of it.

The manifest is registered so the catalog shows the box as pending,
but nothing is designed and the installer is not written: nothing can
insert it yet.

## What it is expected to bring

Not decided — this is where the design starts from, and its
`DESIGN.md` settles each line:

* **Nx and a compiler for it**, in the project's dependencies and
  configuration: without a compiled backend the tensors are computed
  in plain Elixir, which is correct and far too slow to serve.
* **A pretrained model and its serving**:
  [Bumblebee](https://github.com/elixir-nx/bumblebee) to load the
  model, an `Nx.Serving` started by the application, and one function
  the rest of the project calls.
* **Somewhere to keep the model**: it is downloaded on first use and is
  large, so the compose keeps it in a volume and not in the image.
* **An example that runs**: one task on one small model, with its
  test, so the insert is seen answering and not only compiled.

Open, for the design: which backend, and whether its precompiled
binary exists for the image's architecture; what the first download
costs and where it happens (the build, the boot, the first call); how
much memory the container then needs; which task the example is; and
the scaled deployment, where a serving can be shared by the nodes of
the cluster.

When it is built, fill this directory in like any other cartridge (see
the checklist in the package README): `DESIGN.md`, `task.ex`, its
templates under `priv/features/machine_learning/`, its test and this
README.

## Contents

| File | Role |
| --- | --- |
| `machine_learning.ex` | Manifest only (`pending?/0` returns `true`) |
| `NEED.md` | The need it answers |

Cartridge test: none until built.
