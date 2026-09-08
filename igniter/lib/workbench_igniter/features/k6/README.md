# Cartridge: k6

Load testing with [k6](https://k6.io), run from the workspace against
the deployment that is up.

* **Task**: `mix workbench.install.k6`
* **Inserted by**: `wb.sh add k6`. Then `./wb.sh bake`, and `./wb.sh k6 [SCRIPT] [K6 ARGS]`.

## Description

k6 is a load tool, not a service of the deployment: it runs to
completion. So its container sits in the compose under `profiles: [tools]`,
which `up` never starts, and `./wb.sh k6` runs it
(`docker compose --profile tools run --rm k6 run /scripts/SCRIPT`) on
the compose of the deployment named with `--deploy`. The scripts are the
project's own, under `k6/`, mounted read-only as `/scripts`.

A script never names a host. The compose sets `BASE_URL` for the
topology k6 runs in: `http://localhost:4000` inside the pod (dev and
prod), `http://balancer` on the scaled network when the balancer is in,
`http://app:4000` — the alias every replica answers to — when it is not.

With the monitoring cartridge in as well, the compose sets `K6_OUT` and
`K6_PROMETHEUS_RW_SERVER_URL` on the container too, so every run writes
its results to the workspace's Prometheus as `k6_*` metrics, for Grafana
to draw beside the app's; nothing about the verb changes.

## What it installs

* `k6/smoke.js` — five virtual users for fifteen seconds asking the
  root page and expecting a 200. A start; grow it or add scripts beside it.
* The `k6` service, declared for `mix workbench.compose`: the
  `grafana/k6` image (`K6_IMAGE_VERSION` in `config.conf`).

**Idempotency**: the script is the mark; re-running it is a no-op.

## Contents

| File | Role |
| --- | --- |
| `k6.ex` | Manifest + logic (`info/2`, `install/1`, `services/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.K6` shell |
| `priv/features/k6/assets/smoke.js` | The starting script, copied verbatim |

Cartridge test: `test/workbench_igniter/features/k6_test.exs`.
