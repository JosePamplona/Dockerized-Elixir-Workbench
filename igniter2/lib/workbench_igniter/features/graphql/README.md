# Cartridge: graphql

GraphQL API with Absinthe, served at `/graphiql`.

* **Task**: `mix workbench.install.graphql`
* **Enabled by**: `--interface graphql` (config.conf: `INTERFACE`).
  Mutually exclusive with `rest`.
* **Origin**: in app.sh this feature was a "Coming soon" stub; here it is
  a new implementation, not a port.

## Description

The alternative to the REST API: exposes the application through GraphQL,
a query language where the client describes exactly the data it needs and
receives just that, nothing more. Instead of many fixed endpoints, the app
publishes a single one backed by a schema — a typed catalog of everything
that can be asked — and each client composes its own queries against it.

That inversion is the point: with REST, the server decides the shape of
every response, and clients that need less (or more) either over-fetch or
make several round trips. With GraphQL, a mobile app, a web frontend and a
reporting script can each pull a different slice of the same data from the
same endpoint, and the API can grow new fields without breaking anyone or
multiplying versions.

The cartridge ships the schema with a starter `version` query as the seed
to grow from, and serves GraphiQL — an in-browser console at the same URL
— where queries can be written, auto-completed against the schema and
tried live during development. The interface choice is made at project
creation: a project speaks REST or GraphQL, not both.

## What it installs

* Deps `absinthe ~> 1.7`, `absinthe_plug ~> 1.5`,
  `absinthe_error_payload ~> 1.1`.
* `MyAppWeb.Graphql.Schema` with a starter `version` query.
* Router: `forward "/"` in the `/graphiql` scope to
  `Absinthe.Plug.GraphiQL` — the same URL serves the IDE (GET) and the
  API endpoint (POST).
* Endpoint unit test.

**Idempotency**: if the Schema already exists, notice and no-op.

## Contents

| File | Role |
|---|---|
| `graphql.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Graphql` shell |
| `templates/schema.eex` | `MyAppWeb.Graphql.Schema` |
| `templates/graphql_test.eex` | Endpoint test |

Cartridge test: `test/workbench_igniter/features/graphql_test.exs`.
