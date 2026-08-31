# healthcheck2

Liveness and readiness probes, as **the first plug of the endpoint**.
What a container orchestrator or a load balancer consumes, and nothing
else.

Install it on demand with

```sh
./wb.sh add healthcheck2
mix workbench.install.healthcheck2 --path /health
```

It is the vanilla counterpart of [healthcheck](../healthcheck/), in the
sense `new2` is of `new`: that one is a controller behind the router,
with a JSON body that grows in dev and an entry in the Swagger page;
this one answers a probe and gets out of the way. Both can coexist —
they share no file and no route.

## What it installs

**`lib/my_app_web/plugs/health.ex`** — `MyAppWeb.Plugs.Health`, two
routes split by what the platform does when one fails:

| Route | Answers | On failure the platform… | Checks |
| --- | --- | --- | --- |
| `GET /health/live` | 200 while the VM answers | restarts the container | nothing else, on purpose |
| `GET /health/ready` | 200 when the app can take traffic, 503 when it cannot | takes the instance out of the balancer | `SELECT 1` on `MyApp.Repo`, 1 s timeout |

Every answer carries `Cache-Control: no-store` and a plain-text body
(`ok` / `unavailable`). Anything that is not a `GET` on one of the two
paths passes through untouched.

**`test/my_app_web/plugs/health_test.exs`** — both routes through the
endpoint (the `/live` one asserts the conn was halted there, so the
router never saw it), the 503 with a repo that answers an error and
with one that raises, and the pass-through.

**`plug MyAppWeb.Plugs.Health`** as the first plug of
`MyAppWeb.Endpoint`, right after the `socket` declarations and before
`Plug.Static`.

No dependency, no config, no router change. When the project has no
`MyApp.Repo` (`phx.new --no-ecto`), `/ready` answers like `/live` and
`ready?/1` is the obvious place to add the checks the app depends on.

## Options

| Option | Default |
| --- | --- |
| `--path` | `/health` — prefix of both routes (`/health/live`, `/health/ready`) |

## Why it is shaped like this

The reasoning — why two routes, why liveness checks nothing, why a plug
mounted first rather than a controller, why a one-second timeout, and
where the Elixir guides disagree with the platform documentation — is
in [DESIGN.md](DESIGN.md), with the sources it rests on.

## Wiring the platform

The same release serves all three; only the platform config differs.
Kubernetes is the one that distinguishes *restart* from *stop sending
traffic*, so it is the one that uses both routes.

```yaml
# Kubernetes
containers:
- name: my_app
  startupProbe:            # waits for boot and migrations
    httpGet: { path: /health/ready, port: 4000 }
    periodSeconds: 5
    failureThreshold: 30
  livenessProbe:           # restarts only when the VM stops answering
    httpGet: { path: /health/live, port: 4000 }
    periodSeconds: 10
    failureThreshold: 3
  readinessProbe:          # pulls the pod out of the Service, no restart
    httpGet: { path: /health/ready, port: 4000 }
    periodSeconds: 10
    timeoutSeconds: 2
```

```toml
# Fly.io — one check type, and a failing Machine only stops receiving
# traffic (it is not restarted). Point it at readiness; grace_period
# must cover the release boot plus release_command.
[http_service]
  internal_port = 4000
  [[http_service.checks]]
    grace_period = "15s"
    interval = "10s"
    timeout = "2s"
    method = "GET"
    path = "/health/ready"
```

```jsonc
// AWS ECS / Fargate — two layers, both must pass when an ALB is attached.
// Target group: /health/ready, matcher 200, interval 10-15 s.
// Container healthCheck (optional, needs curl in the image):
"healthCheck": {
  "command": ["CMD-SHELL", "curl -fsS http://localhost:4000/health/live || exit 1"],
  "interval": 30, "timeout": 5, "retries": 3, "startPeriod": 60
}
// plus healthCheckGracePeriodSeconds on the service.
```

The workspace compose probes the app with a TCP connect on the
internal port (no curl in the images), which is a liveness check by
another name; it needs nothing from this cartridge. A production
compose that wants readiness swaps that `test:` for
`curl -fsS http://localhost:$PORT/health/ready`, once the runner image
carries curl.

## Idempotency

The endpoint edit always prepends, so the whole install is guarded by
the plug module: when `MyAppWeb.Plugs.Health` already exists nothing is
touched and a notice says so.

## Contents

| File | Role |
| --- | --- |
| `healthcheck2.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Healthcheck2` shell |
| `CHANGELOG.md` | The cartridge's own version history |
| `DESIGN.md` | Why it is shaped like this, with sources |
| `priv/features/healthcheck2/templates/plug.eex` | The plug |
| `priv/features/healthcheck2/templates/plug_test.eex` | Its test |

Cartridge test: `test/workbench_igniter/features/healthcheck2_test.exs`.
