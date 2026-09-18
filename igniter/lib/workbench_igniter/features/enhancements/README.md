# Cartridge: enhancements

Workbench base enhancements: shared schema and helper, the `mix db`
task, and the base test suite.

* **Task**: `mix workbench.install.enhancements`
* **Inserted by**: `wb.sh add enhancements`; a chiefs_setup pick,
  inserted after the trivial dep group (osmon, psql_extras, credo, mock,
  exdebug — see `../README.md`).
* **Ordering**: before `auth0`, whose User schema uses the `MyApp.Schema`
  this feature generates (`auth0` refuses until this is in).
* **Options**: `--project-name` `--interface`
  `[--id-type --timestamps]`
  `[--exdoc --auth0 --openai --stripe --health]` name the fellow
  cartridges that shape what it plants — what the project has of Ecto,
  html, the mailer and the dashboard is read off the project, not asked.
  As a chiefs_setup pick it receives `--interface --exdoc --health`.

## Description

The workbench's quality-of-life pack: everything a freshly created project
is glad to have from day one. A stock Phoenix project starts minimal on
purpose; this cartridge layers the workbench's conventions on top, so
every project built with it shares the same foundations instead of each
one reinventing them.

Concretely, it seeds three kinds of groundwork. Shared building blocks: a
base schema that fixes project-wide defaults (primary key and timestamp
types) so every future table is consistent, plus a helper with the small
functions every codebase ends up needing. A developer command: `mix db`
to regenerate the database documentation and diagrams that the ExDoc
site publishes. And
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

* **Ecto group** (when the project has Ecto): `ecto_enum` and `html_entities`
  deps; the generators and migration configuration `--id-type` and
  `--timestamps` decide (`migration_primary_key`, `migration_timestamps`
  and `generators: [timestamp_type: :utc_datetime_usec]` in
  `config.exs`) — the same policy `MyApp.Schema` carries, written where
  `mix phx.gen.*` reads it, so the tables cannot drift from the schemas;
  `MyApp.Helper` and `MyApp.Schema` (+ tests); the `mix db` task;
  and the DbSchema diagrams under the project's `assets/db_schema/`,
  picking the combo for the enabled features (`none`, `auth0`,
  `auth0_openai`, …). It also plants the files `mix db` would generate
  (`assets/exdoc/database.md` and the model SVGs) so ExDoc has real pages
  from the start.
* **REST group** (`--interface rest`): enhanced `error_json.ex` (changeset
  error rendering) and the Postman collection for the enabled features
  combo (auth0/openai/health).
* **Base testing**: composes `workbench.install.mock`;
  application/telemetry tests and (conditional)
  page/dashboard/mailbox tests (each when the project has html, the
  dashboard, the mailer — read off the project) and the error view test
  (`rest`); `MyApp.Fixtures` and
  `MyApp.MockHelper`, imported into `ConnCase`.

**Idempotency**: if `test/support/fixtures.ex` already exists, notice
and no-op. (The mark was the `mix version` task until v1.0.0, when the
task moved to versioning.)

## Contents

| File | Role |
| --- | --- |
| `enhancements.ex` | Manifest + logic |
| `task.ex` | `Mix.Tasks.Workbench.Install.Enhancements` shell |
| `templates/*.eex` (14) | Helper/Schema, the db task, error_json, base tests, fixtures, mock_helper |

| `assets/db_schema/<combo>/` | DbSchema diagram sources (verbatim), one set per auth0/openai/stripe combo |
| `assets/postman/<combo>.postman_collection.json` | Postman collections (verbatim), one per auth0/openai/health combo |

`asset/1` reads the set matching the enabled feature combo.

Cartridge test: `test/workbench_igniter/features/enhancements_test.exs`.
