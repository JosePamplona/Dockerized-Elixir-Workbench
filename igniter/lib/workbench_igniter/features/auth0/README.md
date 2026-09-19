# Cartridge: auth0

Auth0 JWT authentication: Accounts context, User schema and token plug.

* **Task**: `mix workbench.install.auth0`
* **Inserted by**: `wb.sh add auth0`. It needs an Auth0 account.
  `openai` and `stripe` build on it (`requires`).
* **Requires**: `enhancements` (the User uses `MyApp.Schema`); the
  installer refuses until it is in.
* **Options**: `--project-name` `--interface`

## Description

Lets the application have users who sign in securely, delegating the
sensitive part — passwords, identity verification, account recovery — to
Auth0, a service specialized in it. The project never stores or even sees
a password, which removes the riskiest part of authentication from its
responsibilities entirely.

The flow works on signed tokens: the user authenticates against Auth0 and
receives a token cryptographically signed by it; on every request, the app
verifies that signature against Auth0's published public keys and, when it
checks out, loads — or creates on first visit — its own record for that
user. The app thus keeps its own users table for everything the domain
needs (status, relationships to other data), while trusting Auth0 for the
question of "is this person who they claim to be?".

With that in place, the API stops being anonymous: requests pass through
an authentication pipeline, the protected scope only answers to valid
tokens, and a `GET /user` endpoint returns the caller's own profile. This
is also the groundwork for every feature that owns data per user —
openai's conversations and stripe's subscriptions both require it.

## What it installs

* Dep `{:auth0_jwks, "~> 0.3"}` and the `Auth0Jwks.Strategy` child in the
  supervision tree (JWKS fetch with RS256 alg).
* Config: `:auth0_jwks` `json_library`, and the `AUTH0_*` environment
  block in `config/runtime.exs` (including the ExDoc `auth_config.js`
  writer), inserted before the `:prod` block.
* `MyApp.Accounts` (`user_from_claim/2`), `Accounts.User` (StatusEnum +
  EctoURI), its migration, `MyApp.EctoURI` and `MyAppWeb.Plugs.Token`.
* Router: `:auth` pipeline (token validation + user loading); with
  `--interface rest`, the `/api/v1` scope switches from `:api` to
  `[:api, :auth]` (zipper surgery) and gains `GET /user` with its
  controller, JSON view and OpenAPI schema.
* Unit tests and `AccountsFixtures`.

**Idempotency**: the mark is the `auth0_jwks` dependency; with it in,
notice and no-op. An `MyApp.Accounts` that is there without it — Ash's
domain, the project's own — is refused, not overwritten.

## Contents

| File | Role |
| --- | --- |
| `auth0.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Auth0` shell |
| `templates/accounts.eex`, `user.eex`, `create_users.eex` | Context, schema and migration |
| `templates/ecto_uri.eex` | `MyApp.EctoURI` type |
| `templates/token_plug.eex` | `MyAppWeb.Plugs.Token` |
| `templates/runtime.eex` | `AUTH0_*` runtime.exs block |
| `templates/openapi_user.eex`, `user_json.eex`, `user_controller.eex` | `GET /user` endpoint (rest only) |
| `templates/*_test.eex`, `accounts_fixtures.eex` | Tests and fixtures |

Cartridge test: `test/workbench_igniter/features/auth0_test.exs`.
