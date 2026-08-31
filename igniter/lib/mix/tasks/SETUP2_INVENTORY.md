# Inventario completo

> **Resuelto (2026-08-30).** Este inventario guió la disección de
> `workbench.setup`, hoy retirado: `setup2` tomó su nombre, y el lado
> compuesto (A) vive como la colección `chiefs_setup`
> (`lib/workbench_igniter/features/chiefs_setup/`, ver su DESIGN.md).
> Lo no-feature (C) y el schema (D) murieron como estaba previsto. Se
> conserva como registro de la decisión.

Lo agrupo por qué lo dispara, porque eso es lo que decide si sobrevive o no en setup2.

- [Inventario completo](#inventario-completo)
  - [A) Features que compone `workbench.setup` — las 14 del registro](#a-features-que-compone-workbenchsetup--las-14-del-registro)
  - [B) Features que ya están fuera del registro](#b-features-que-ya-están-fuera-del-registro)
  - [C) Configuración no-feature que también sale](#c-configuración-no-feature-que-también-sale)
  - [D) Lo que queda del `schema` de `setup`](#d-lo-que-queda-del-schema-de-setup)

## A) Features que compone `workbench.setup` — las 14 del registro

Todas fuera de setup2 (composes: []). En orden de composición:

| #   | Feature      | Task                             | Lo enciende            |
| :-: | :--          | :--                              | :--                    |
| 1   | Osmon        | `workbench.install.osmon`        | `--enhance`            |
| 2   | PsqlExtras   | `workbench.install.psql_extras`  | `--enhance`            |
| 3   | Credo        | `workbench.install.credo`        | `--enhance`            |
| 4   | Mock         | `workbench.install.mock`         | `--enhance`            |
| 5   | Exdebug      | `workbench.install.exdebug`      | `--enhance`            |
| 6   | Rest         | `workbench.install.rest`         | `--interface` rest     |
| 7   | Graphql      | `workbench.install.graphql`      | `--interface` graphql  |
| 8   | Coveralls    | `workbench.install.coveralls`    | `--coveralls`          |
| 9   | Exdoc        | `workbench.install.exdoc`        | `--exdoc`              |
| 10  | Enhancements | `workbench.install.enhancements` | `--enhance`            |
| 11  | Auth0        | `workbench.install.auth0`        | `--auth0`              |
| 12  | Openai       | `workbench.install.openai`       | `--openai` (⇒ `--auth0`) |
| 13  | Healthcheck  | `workbench.install.healthcheck`  | `--health`             |
| 14  | Stripe       | — (`pending?: true`)             | `--stripe` (⇒ `--auth0`) |

Detalles que importan: `--enhance` dispara **6** tasks (los 5 dep-only + Enhancements), `rest`/`graphql` son mutuamente excluyentes vía `--interface`, y Stripe no tiene `task.ex` — hoy solo emite el aviso de `notice_pending/2`, así que en setup2 desaparece también ese aviso.

## B) Features que ya están fuera del registro

`exmachina` y `githooks`. No los compone `setup`; solo se instalan con `./wb.sh add`. **No hay nada que mover**, pero conviene saberlo: son la prueba de que el camino "proyecto vanilla + `add` a demanda" ya funciona, que es exactamente el flujo que `setup2` habilita para el resto.

## C) Configuración no-feature que también sale

No son features, pero es el otro medio del "sin configuración extra":

- `mix.exs`: version inicial (`--version`)
- `config.exs`: `:elixir`, `ansi_enabled: true`
- `config.exs`: `generators: [timestamp_type: :utc_datetime_usec]`
- `config.exs`: `migration_primary_key` / `migration_timestamps` (`--id-type`, `--timestamps`)
- `test.exs`: `dev_routes: true`
- `.gitignore`: la entrada `/.elixir_ls/` (la de .env se queda)
- Ficheros de texto: `README.md`, `CHANGELOG.md`, `.tool-versions`
- Los post-tasks `deps.unlock` `--all` + `deps.get`: existen solo porque las deps de las features chocan con el lock recién generado por `phx.new`. Sin features, no hacen falta.

## D) Lo que queda del `schema` de `setup`

De las 27 opciones actuales sobreviven *5*, todas para renderizar `.env`: `--internal-port`, `--db-host`, `--db-port`, `--db-user`, `--db-pass`.

Mueren: `--project-name`, `--version`, `--elixir-version`, `--erlang-version`, `--debian-version`, `--id-type`, `--timestamps`, `--interface`, `--app-port`, `--repo-url`, `--guidelines-url`, `--html`, `--assets`, `--mailer`, `--dashboard`, `--enhance`, `--exdoc`, `--coveralh`, `--auth0`, `--openai`, `--stripe`.
