# Cartridge: rest

REST API documented with OpenAPI (open_api_spex) and SwaggerUI.

* **Task**: `mix workbench.install.rest`
* **Enabled by**: `--interface rest` (the default; config.conf:
  `INTERFACE`). Mutually exclusive with `graphql`.
* **Ordering**: before `healthcheck`, which autodetects the
  `OpenApi.Spec` module in the patch set. Receives from setup the flags of
  the enabled features that shape its spec: `--auth0`, `--openai`,
  `--health`.

## Description

Sets the application up to talk to other systems through a REST API: a
structured contract, over HTTP, defining how external clients request data
and trigger actions. It establishes the `/api/v1` scope as the home for
all the project's endpoints, so every future feature that exposes
functionality has a consistent place — and a consistent style — to plug
into.

The contract is written as an OpenAPI specification, a machine-readable
description of every endpoint, parameter and response. From it the app
serves an interactive Swagger page where the API can be browsed and tried
live: any developer — on the team or outside — can see exactly how to
connect and experiment with real requests without reading the source.
Because the specification lives next to the code and is served by the app
itself, the documentation doesn't drift out of date the way a separate
document would.

This cartridge is also the foundation other features build on: auth0 adds
its `GET /user` endpoint to the scope it creates, openai adds the
conversation routes, and healthcheck detects it to generate its documented
variant. The specification adjusts to whichever of those features are
enabled, so the published contract always matches what the project
actually does.

## What it installs

* Dep `{:open_api_spex, "~> 3.21"}`.
* `MyAppWeb.OpenApi.{Spec, Requests, Responses, Schemas}` modules — the
  Spec includes tags and security scheme according to the flags (auth0 →
  bearer + users tag; openai → conversations tag; health → dev operations
  tag).
* Aliases (`OpenApiSpex.Schema`, OpenApi helpers) inside the web module's
  `controller` block, so controllers use them unqualified.
* Router: `:open_api_spec` pipeline, the `/api/v1` anchor scope, and dev
  routes `/dev/openapi` (JSON) and `/dev/swagger` (SwaggerUI).
* Unit tests for both dev endpoints.

**Idempotency**: if `OpenApi.Spec` already exists, notice and no-op.

## Options

* `--project-name` - OpenAPI Info title (default: capitalized app name).
* `--auth0` / `--openai` / `--health` - Conditional spec content.

## Contents

| File | Role |
|---|---|
| `rest.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Rest` shell |
| `templates/spec.eex` | `OpenApi.Spec` (conditional tags/security) |
| `templates/requests.eex` | Request helpers |
| `templates/responses.eex` | Response helpers |
| `templates/schemas.eex` | Schema helpers |
| `templates/open_api_controller_test.eex` | `/dev/openapi` test |
| `templates/swagger_controller_test.eex` | `/dev/swagger` test |

The related Postman collections are multi-feature and are planted by
`enhancements` from `priv/assets/rest/`.

Cartridge test: `test/workbench_igniter/features/rest_test.exs`.
