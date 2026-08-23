# Cartridge: healthcheck

Healthcheck endpoint with controller, tests and router scope.

* **Task**: `mix workbench.install.healthcheck`
* **Enabled by**: `--health` on `workbench.setup` (config.conf: `HEALTH`)
* **Ordering**: composed last, after `rest`, so the autodetection finds
  `MyAppWeb.OpenApi.Spec` in the patch set and generates the
  OpenApiSpex-documented variant.

## Description

Gives the application a healthcheck endpoint: a public route where
anything — monitoring tools, load balancers, container orchestrators, or
a teammate with a browser — can ask "are you alive?" and get an immediate
answer. Checking the health of the service becomes a single request
instead of inspecting servers from the inside.

That simple question is what modern infrastructure runs on. An
orchestrator uses it to decide whether to restart a container that stopped
responding; a load balancer uses it to route traffic only to healthy
instances; an uptime monitor uses it to alert the team the moment the
service goes down. Without a dedicated endpoint, all of those tools would
have to guess from indirect signals.

The answer adapts to the environment: in development (and wherever dev
routes are enabled) it includes extended details about the application's
state, while in production it stays minimal, revealing nothing an outsider
could exploit. When the project has the REST feature, the endpoint also
appears fully documented in the API's Swagger page, like any other part of
the contract.

## What it installs

* Composes `workbench.install.mock` (the generated test uses Mock).
* `dev_routes: true` in `config/test.exs` (the endpoint returns extended
  info only when dev routes are enabled).
* `MyAppWeb.HealthcheckController` + its unit test.
* With OpenAPI (autodetected or `--open-api`): the
  `MyAppWeb.OpenApi.Schemas.Healthcheck` schema and the documented
  controller variant.
* A `get "/"` scope in the router under the configured endpoint.

**Idempotency**: if the controller already exists, notice and no-op (the
router edit is not idempotent by itself).

## Options

* `--endpoint` - Route for the scope. Default: `/health`.
* `--open-api` - Force the OpenApiSpex variant even if the REST feature is
  not detected (it must be installed for it to compile).

## Contents

| File | Role |
|---|---|
| `healthcheck.ex` | Manifest + logic (`info/2`, `install/1`) |
| `task.ex` | `Mix.Tasks.Workbench.Install.Healthcheck` shell |
| `templates/controller.eex` | Controller (with/without OpenAPI variants) |
| `templates/controller_test.eex` | Controller unit test |
| `templates/schema.eex` | OpenAPI schema (OpenAPI variant only) |

Cartridge test: `test/workbench_igniter/features/healthcheck_test.exs`.
