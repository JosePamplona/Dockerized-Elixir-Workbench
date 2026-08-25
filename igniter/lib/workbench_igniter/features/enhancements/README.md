# Cartridge: enhancements

Workbench base enhancements: shared schema and helper, `mix db` and
`mix version` tasks, and the base test suite.

* **Task**: `mix workbench.install.enhancements`
* **Enabled by**: `--enhance` (config.conf: `ENHANCE`), which also turns
  on the trivial dep group (osmon, psql_extras, credo, mock, exdebug —
  composed separately, see `../README.md`).
* **Ordering**: before `auth0`, whose User schema uses the `MyApp.Schema`
  this feature generates.
* **Argv from setup**: `--project-name` `--interface`
  `[--id-type --timestamps]`
  `[--exdoc --auth0 --openai --stripe --health]`
  `[--no-ecto --no-html --no-mailer --no-dashboard]`

## Description

The workbench's quality-of-life pack: everything a freshly created project
is glad to have from day one. A stock Phoenix project starts minimal on
purpose; this cartridge layers the workbench's conventions on top, so
every project built with it shares the same foundations instead of each
one reinventing them.

Concretely, it seeds three kinds of groundwork. Shared building blocks: a
base schema that fixes project-wide defaults (primary key and timestamp
types) so every future table is consistent, plus a helper with the small
functions every codebase ends up needing. Developer commands: `mix
version` to print the app version, and `mix db` to regenerate the
database documentation and diagrams that the ExDoc site publishes. And
API polish: an error view that renders validation errors in a clean,
uniform JSON shape, plus a ready-to-import Postman collection for the
project's endpoints.

The third kind is testing culture: a starter suite covering the basic
parts of the application, shared fixtures, and a mock helper wired into
the test setup — so coverage starts high and the patterns for writing new
tests are already established. Other features assume this groundwork:
auth0's User schema, for instance, builds on the base schema created
here.

## What it installs

* **Ecto group** (unless `--no-ecto`): `ecto_enum` and `html_entities`
  deps; `MyApp.Helper` and `MyApp.Schema` (+ tests); the `mix db` task;
  and the DbSchema diagrams under the project's `assets/db_schema/`,
  picking the combo for the enabled features (`none`, `auth0`,
  `auth0_openai`, …). It also plants the files `mix db` would generate
  (`assets/exdoc/database.md` and the model SVGs) so ExDoc has real pages
  from the start.
* **REST group** (`--interface rest`): enhanced `error_json.ex` (changeset
  error rendering) and the Postman collection for the enabled features
  combo (auth0/openai/health).
* The `mix version` task + test.
* **Base testing**: composes `workbench.install.mock`;
  application/telemetry tests and (conditional)
  page/dashboard/mailbox/error view tests; `MyApp.Fixtures` and
  `MyApp.MockHelper`, imported into `ConnCase`.

**Idempotency**: if `lib/mix/tasks/version.ex` already exists, notice and
no-op.

## Contents

| File | Role |
| --- | --- |
| `enhancements.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Enhancements` shell |
| `templates/*.eex` (16) | Helper/Schema, db/version tasks, error_json, base tests, fixtures, mock_helper |

| `assets/db_schema/<combo>/` | DbSchema diagram sources (verbatim), one set per auth0/openai/stripe combo |
| `assets/postman/<combo>.postman_collection.json` | Postman collections (verbatim), one per auth0/openai/health combo |

`asset/1` reads the set matching the enabled feature combo.

Cartridge test: `test/workbench_igniter/features/enhancements_test.exs`.
