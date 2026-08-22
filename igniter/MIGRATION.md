# Plan de migración: app.sh → WorkbenchIgniter

Objetivo: `app.sh` queda como wrapper de infraestructura Docker y ciclo de
vida; todo lo que configura el proyecto Elixir migra al paquete
`:workbench_igniter` como tareas [Igniter](https://hexdocs.pm/igniter).

**Criterio de frontera:** app.sh conserva lo que ocurre *fuera* del contenedor
o *antes* de que exista `mix`; WorkbenchIgniter se lleva todo lo que ocurre
*dentro* de un proyecto Mix ya creado — incluyendo archivos que no son Elixir
(README, `.env`, Dockerfiles…), que se generan con `create_new_file` + EEx.

## Estado

- [x] Fase 0 — Prueba de concepto (`workbench.install.healthcheck`)
- [x] Fase 1 — Features triviales (deps + config)
- [x] Fase 2 — `workbench.setup` base + archivos de texto
- [x] Fase 3 — Features estructurales (`rest`, `exdoc`, `coveralls`, `graphql`, `enhancements`)
- [ ] Fase 4 — Features compuestas (`auth0`, `openai`, `stripe`)
- [x] Fase 5 — Adelgazar app.sh (`wb.sh`) y comando `add`
- [ ] Fase 6 — (Opcional) repo git propio para el paquete

## Reparto final

### Se queda en app.sh

| Elemento | Motivo |
| --- | --- |
| `login`, `up`, `setup`, `run`, `delete`, `demo`, `prune`, `remove-workbench` | Ciclo de vida de contenedores |
| `prepare_new_project`, `Dockerfile.app`, `entrypoint.sh`, `scripts/contexts/*` | Bootstrap: corren antes de que exista el proyecto |
| Lectura de `config.conf` | Se traduce a flags de `mix workbench.setup` |
| `docker-compose.yml` | Lo consume el host; usar interpolación nativa de variables de Compose y eliminar los `sed` |

### Migra a WorkbenchIgniter

| Hoy en app.sh | Tarea destino | Fase |
| --- | --- | --- |
| `implement_credo/githooks/exmachina/mock/exdebug/psql_extras/osmon` | `workbench.install.<feature>` (una c/u) ✅ | 1 |
| `implement_flameon` (comentado en app.sh; toca el live_dashboard del router) | pendiente de decisión: portarlo junto al dashboard o descartarlo | — |
| `adjust_mix`, `adjust_config*`, `adjust_gitignore`, `adjust_homepage` | `workbench.setup` | 2 |
| `create_env/readme/changelog/dockerignore/dockerfile_dev/dockerfile_prod/tool_versions/pgadmin_credentials` | `workbench.setup` (templates EEx) | 2 |
| `implement_version_task`, `db_task`, `db_schema_diagrams`, `ecto_schema`, `helper`, `changeset_error_view`, `unit_testing`, `html_entities`, `postman_collection` | `workbench.install.enhancements` ✅ | 3 |
| `implement_rest` (open_api_spex, swagger) | `workbench.install.rest` ✅ | 3 |
| `implement_exdoc`, `implement_coveralls` | `workbench.install.exdoc` / `.coveralls` ✅ | 3 |
| `implement_graphql` (stub "Coming soon" en app.sh) | `workbench.install.graphql` ✅ (implementación nueva, no port) | 3 |
| `implement_healthcheck` | `workbench.install.healthcheck` ✅ (falta variante OpenApiSpex, depende de `rest`) | 3 |
| `implement_auth0` + contexto `auth0.sh` + `refine_auth0` | `workbench.install.auth0` ✅ | 4 |
| `implement_openai` + contexto `open_ai.sh` + `refine_openai` | `workbench.install.openai` ✅ | 4 |
| `implement_stripe` | `workbench.install.stripe` (compone `auth0`) | 4 |

## Fases

### Fase 1 — Features triviales ✅

Solo `add_dep` + `configure` + (a veces) un alias en mix.exs. Reutilizan
directamente el patrón del healthcheck. Una tarea por feature con sus tests.

Completada: `credo`, `githooks`, `exmachina`, `mock`, `exdebug`,
`psql_extras` (instaladores de una dep, con tests parametrizados en
`workbench.install.deps_test.exs`) y `osmon` (`:os_mon` en
`extra_applications` vía `MixProject.update`). `healthcheck` ahora compone
`workbench.install.mock` en lugar de declarar la dep por su cuenta —
primer uso de `Igniter.compose_task` en el paquete. `flameon` quedó fuera
(ver tabla).

### Fase 2 — `workbench.setup` base ✅

Tarea paraguas que recibe los flags de `config.conf` y:

1. Aplica los ajustes base (`configure` sobre config/dev/test/runtime,
   versión inicial en mix.exs, gitignore, homepage).
2. Genera los archivos de texto desde templates EEx (los `pattern` tags
   `<!-- workbench-x open/close -->` se convierten en `<%= if @flag %>`).
3. Compone las features solicitadas vía `Igniter.compose_task`, codificando
   las dependencias entre flags (`stripe → auth0`, `openai → auth0`) que hoy
   están al inicio de app.sh.

Resultado: **un solo patch set atómico** — si algo falla, no queda un
proyecto a medias (hoy un `sed` fallido en `configure_files` sí lo deja).

Completada. Notas de implementación:

- Cubre: versión inicial, ansi/generators/migration types, hostname
  Docker-aware (dev y test), ip `0.0.0.0` en dev, `dev_routes` en test,
  gitignore, badge en homepage, y templates de README/CHANGELOG/.env/
  .dockerignore/Dockerfiles/.tool-versions/pgadmin.
- `adjust_config_runtime` (runtime.exs) quedó diferido a la fase 4: todo su
  contenido es de auth0/openai.
- Los flags aún sin instalador (`--exdoc`, `--coveralls`, `--auth0`,
  `--openai`, `--stripe`) solo condicionan README/.env y emiten un aviso.
- Quirks de Igniter encontrados: `create_new_file` solo respeta
  `on_exists: :skip` si el archivo ya está en el patch set (se guarda con
  `Igniter.exists?` en `plant/5`); `MixProject.update` interpreta
  `{:code, binario}` como código fuente a parsear (un string literal
  necesita `inspect/1`); el AST de `quote` no trae la metadata que el
  formateador de Rewrite espera — construir código con
  `Sourceror.parse_string!`.

### Fase 3 — Features estructurales ✅

Las que crean módulos/rutas y de las que otras dependen. `rest` primero
(desbloquea la fidelidad completa de `healthcheck`, `auth0`, `openai`).

`workbench.install.rest` ✅ — deps + módulos `OpenApi.{Spec, Requests,
Responses, Schemas}` + aliases en el bloque `controller` del web module +
pipeline `:open_api_spec`, scope `/api/v1` y rutas dev de swagger/openapi +
tests. `workbench.setup --interface rest` lo compone pasando los flags de
features. Desviaciones deliberadas respecto al bash: las rutas usan
`OpenApiSpex.Plug.*` totalmente calificado (sin inserción frágil de alias
en línea 4 del router), y las rutas dev viven en su propio bloque
`if dev_routes` autocontenido, válido con o sin mailer/dashboard.

Variante OpenApiSpex del healthcheck ✅ — se activa por autodetección
(presencia de `OpenApi.Spec`, también dentro del mismo patch set cuando
`setup` compone `rest` antes) o con `--open-api`. El schema vive en
`OpenApi.Schemas.Healthcheck` y el controller lo referencia — esto corrige
dos defectos de app.sh: el schema se escribía sobre
`open_api/schemas/user.ex` (bug en `implement_healthcheck`,
`HEALTH_SCHEMA_FILE`) y su contenido estaba además duplicado inline en el
controller.

`workbench.install.coveralls` ✅ — dep + `test_coverage`/`preferred_envs`
en mix.exs + `coveralls.json` + template HTML custom de excoveralls
(copiado verbatim vía `WorkbenchIgniter.asset/1`, sin render EEx — sus
`<%= %>` pertenecen al proyecto destino) + con `--exdoc` la tarea
`mix cover` y sus tests. `setup --coveralls` lo compone.

`workbench.install.exdoc` ✅ — dep + sección `docs` completa en mix.exs
(assets/extras/grupos condicionales, regexes de módulos, funciones
`before_closing_*`) + `ExDocController` con tests + pipeline `:exdoc` y
rutas `/dev/docs` + assets (logo PNG, diagrama de arquitectura según
flags, JS, página workbench transformada, placeholders) + dummies en
`_build/test` para que la suite pase antes del primer `mix docs`.
`--guidelines-url` descarga la página de convenciones con Req. Validado
con `mix docs` real. Notas: los assets binarios (PNG) pasan intactos por
`create_new_file`; el botón ExDoc del homepage NO se portó — anclaba a la
grid de iconos del homepage de Phoenix 1.7, que en 1.8 no existe (pendiente
rediseñar si se quiere).

`workbench.install.enhancements` ✅ — el resto de `implement_enhancements`:
grupo ecto (`Helper`+tests, `Schema` con ecto_enum/html_entities, tarea
`mix db`, fuentes DbSchema en `assets/db_schema/`), grupo rest
(`error_json.ex` enriquecido con render de changesets, colección Postman
por combo de features), tarea `mix version`, y la base de testing
(application/telemetry/page/dashboard/mailbox/error tests, `Fixtures`,
`MockHelper` importado en `ConnCase`). `setup --enhance` compone grupo
trivial + este. Correcciones sobre el bash: el archivo `datbase.dbs` del
combo `none` (typo), los tests de `paginate/2` en `helper_test` quedaron
condicionados a auth0 (referencian `Accounts.User`, que crea auth0 — en
bash solo funcionaba porque su config siempre lo activa), y con `--exdoc`
se planta el estado inicial que generaría `mix db` (los tests de esa tarea
mockean la copia y leen esos archivos). Las mix tasks van en
`lib/mix/tasks/` (convención estándar) en vez de `lib/mix/task/`.

`workbench.install.graphql` ✅ — **no es un port**: `implement_graphql` en
app.sh era un stub ("Coming soon"). Implementa el plan de su TODO: deps de
Absinthe (`absinthe`, `absinthe_plug`, `absinthe_error_payload`),
`Web.Graphql.Schema` con una query `version` inicial, forward de
`/graphiql` a `Absinthe.Plug.GraphiQL` (la misma URL sirve el IDE por GET
y el endpoint por POST, como documenta el README generado) y tests del
endpoint. `setup --interface graphql` lo compone. Los resolvers/schemas
por recurso quedan para cuando existan features que los necesiten
(p. ej. auth0 en modo graphql). Corrección adicional: el estado inicial de
`mix db` se planta siempre con el grupo ecto (la tarea apunta a
`assets/exdoc/` aunque la feature exdoc esté apagada — mismo acoplamiento
latente del bash que rompía sus tests en proyectos frescos).

Fase 3 completada.

Nota de zipper: en `find_and_update_module!` el zipper llega ya posicionado
en el cuerpo del módulo — `add_code(zipper, code, placement: :after)`
inserta al fondo. No usar `move_to_do_block` desde ahí: desciende al primer
do-block anidado que encuentre (p. ej. un pipeline) e inserta dentro.

### Fase 4 — Features compuestas (en curso)

`auth0`, `openai`, `stripe`. Componen sobre fase 3. Aquí se usará navegación
por zipper para las ediciones finas del router (aliases de plugs, pipelines
autenticados).

`workbench.install.auth0` ✅ — en app.sh esta feature vivía en TRES etapas
(`implement_auth0` → `mix phx.gen.context` vía `scripts/contexts/auth0.sh`
en el contenedor → `refine_auth0`/`refine_schema_user`/
`refine_migration_user` con cirugía sed sobre lo generado). El port genera
directamente el estado final (tomado del proyecto de referencia del repo):
dep `auth0_jwks` + child `Auth0Jwks.Strategy` (vía
`Application.add_new_child`) + config + bloque `AUTH0_*` en `runtime.exs`
(cierra el diferido de fase 2) + `Accounts`/`User`/migración/`EctoURI`/
`Plugs.Token` + pipeline `:auth` y scope `/api/v1` cambiado a
`[:api, :auth]` por zipper (`replace_code` sobre el `pipe_through`) +
endpoint `GET /user` (rest) + tests y `AccountsFixtures`. Requiere
`enhancements` (el schema usa `MyApp.Schema`); `setup` ordena la
composición. Nuevo patrón dont_move: `test/support/fixtures/`. Corrección:
el módulo del test del plug pasa a `Web.Plugs.TokenTest` (el seed lo
llamaba `Web.TokenTest` pero vivía en `plugs/`).

`workbench.install.openai` ✅ — mismo colapso de tres etapas que auth0:
contexto `Assistant` + schemas `Conversation`/`Message` con migraciones
ordenadas (timestamps consecutivos, messages referencia conversations) +
bloque `AI_ASSISTANT_*` en runtime.exs + controller/vista/schemas OpenAPI
y las 5 rutas `/conversation` (rest) + tests y `AssistantFixtures`.
Hallazgo: las conversaciones llaman a OpenAI vía el pool Finch de la app,
que los proyectos `--no-mailer` no tienen — el instalador asegura la dep
`finch` y el child `{Finch, name: MyApp.Finch}`. `setup --openai` implica
auth0 y ordena la composición (enhancements → auth0 → openai).

Pendiente de fase 4: `stripe` (stub "Coming soon" en app.sh, como lo era
graphql — sería implementación nueva, no port).

### Fase 5 — Adelgazar app.sh ✅ (como `wb.sh`, pendiente decidir el switch)

- `new` queda como: preparar → contenedor: `mix phx.new` + inyección de la
  path dep + `mix workbench.setup <flags> --yes` → paso de documentación.
- Eliminar de app.sh cada función ya portada (objetivo: ~3000 → ~500 líneas).
- Nuevo comando `add <feature>`: ejecuta
  `mix workbench.install.<feature> --yes` en el contenedor sobre un proyecto
  existente — capacidad nueva que el bash no tenía.

Estado: implementado como **`wb.sh` v0.6.0 (antes `ws.sh`)** con su propio
`scripts/entrypoint.sh` — app.sh queda intacto para comparar ambos
deploys. Modelo **workbench permanente / workspace separado**:

- El workbench vive fijo en su directorio (el script hace `cd` a su propia
  ubicación); los proyectos se generan en `WORKSPACE_PATH` (config.conf,
  default `./workspace`, admite rutas absolutas). Desaparecen las
  "maromas" de `prepare_new_project`/`delete_project` (mover todos los
  archivos a `_workbench/`, copiarse a sí mismo, des-moverse al borrar):
  `new` solo asegura un workspace vacío y `delete` lo vacía.
- Doble volumen: el workspace se monta en `/app/src` y el workbench en
  `/app/workbench` (read-only) — en `docker run` directo y vía
  `docker compose run --volume` para setup/add/run/documentation.
- La path dep se inyecta como función condicional `workbench_dep/0` en
  mix.exs: solo añade `{:workbench_igniter, path: ...}` si
  `$WORKBENCH_PATH` (default `/app/workbench`) existe — el proyecto queda
  **autónomo** cuando el workbench no está montado (builds de
  Dockerfile.dev/prod, editores en el host sin el workbench, etc.).
- Validado E2E (`~/Documentos/repos/wb-deploy-test`): `wb.sh new` completo
  (97.3% coverage, docs generados) y `wb.sh add githooks` sobre el
  workspace vivo.
- El nombre: `wb` = workbench; `WORKSPACE_PATH` = workspace, para no
  confundirlos.

Cambios previos del plan y hallazgos (heredados de la iteración ws.sh):

- El `new` de ws.sh: `prepare_new_project` → build/run de la imagen (igual
  que app.sh) → **un solo `sed` de bootstrap** que inyecta
  `{:workbench_igniter, path: "_workbench/igniter"}` en mix.exs → contenedor
  `workbench_setup` (deps.get → `mix workbench.setup <flags> --yes` →
  deps.get → phx.gen.release → release.init) → paso `documentation`
  (idéntico al de app.sh). `config.conf` se traduce a flags en
  `build_setup_flags` (array bash, preserva espacios en PROJECT_NAME).
- Los flags `--tty --interactive` de docker ahora son condicionales a
  `[ -t 0 ]` (CI-safe).
- **Lock de Hex**: el deps.get posterior al setup puede chocar con
  versiones ancladas por el lock inicial (swoosh fija idna 7.x; hackney,
  vía auth0_jwks, exige ~> 6.1). `ws-entrypoint.sh` re-resuelve con
  `mix deps.unlock --all && mix deps.get` en caso de fallo.
- Validado con deploy real completo (`~/Documentos/repos/ws-deploy-test`):
  proyecto Lorem Ipsum entero generado (contexts auth0+openai, 3
  migraciones, rel/, coveralls, postman, assets) y el paso `documentation`
  ejecutado — `mix db` ✓, suite de tests con **97.3% de cobertura** ✓ y
  `mix docs` generando el sitio completo ✓. Comparable 1:1 contra el
  proyecto del app.sh (repo raíz).
- La descarga de `coding.md` (guidelines) puede fallar dentro del
  contenedor: el instalador de exdoc ahora planta un placeholder en ese
  caso para que `mix docs` no rompa (con warning).
- Para correr dos deploys en paralelo hay que dar a la copia un
  `PROJECT_NAME`/puertos/nombres de contenedor distintos en su
  `config.conf` — comparten `COMPOSE_PROJECT_NAME` y el contenedor
  `database` (limitación que también tiene app.sh, no introducida por
  ws.sh).
- **Switch completado**: `app.sh` eliminado; `wb.sh` es el único script.
  Retirados también `seeds/` (solo sobrevive `Dockerfile.seed.app`, movido
  a `scripts/` y depurado de los bloques de contextos), `scripts/contexts/`,
  `scripts/entrypoint.sh`, `assets/` y `pgadmin/` de la raíz (todo vive en
  `igniter/priv/`), y `CUSTOM_SCHEMAS` de config.conf. El repo quedó
  reestructurado: workbench en la raíz, proyecto en `workspace/`.
- README nuevo redactado como `README2.md` (pendiente confirmar la
  sustitución de `README.md`).
- La página "Workbench" de la documentación ExDoc fue **eliminada** del
  instalador de exdoc (junto con el diagrama `arq.svg` que solo esa página
  usaba): la documentación del proyecto generado documenta al proyecto, no
  a la herramienta externa que lo creó.
- Heredado de app.sh (no corregido a propósito, para mantener la
  comparabilidad): la cadena `&&` del comando `new` enmascara fallos — el
  script sale con 0 aunque un paso falle.

### Fase 6 — Repo propio (opcional)

Mover `_workbench/igniter/` a su repo git para que proyectos que ya pasaron
por `remove-workbench` puedan seguir instalando features
(`{:workbench_igniter, git: "..."}`).

## Reglas para portar una feature (checklist)

- [ ] Tarea `Mix.Tasks.Workbench.Install.<Feature>` con `info/2` (flags) e `igniter/1`.
- [ ] Guard de idempotencia si toca el router u otra edición no idempotente
      (`module_exists` + `add_notice`; ver healthcheck).
- [ ] Seeds → templates EEx en `priv/templates/<feature>/` (cuerpo del módulo,
      sin `defmodule`; nombres deducidos del proyecto, no placeholders).
- [ ] Si crea archivos fuera de la convención nombre-módulo → ruta
      (p. ej. `controllers/`), registrar patrón con `dont_move_file_pattern`.
- [ ] Tests con `Igniter.Test.phx_test_project()`: creación, patches,
      idempotencia (aplicar dos veces ⇒ `assert_unchanged`).
- [ ] Borrar la función correspondiente de app.sh y sustituirla por la
      invocación de la tarea.
- [ ] Validación manual: `./app.sh demo` completo con la feature activada.

## Criterio de terminado global

`./app.sh demo` produce un proyecto idéntico (funcionalmente) al actual con
todas las combinaciones de `config.conf` habituales, y `mix test` del paquete
cubre cada instalador.
