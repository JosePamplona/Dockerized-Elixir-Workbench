# WorkbenchIgniter

Port de las features del script `app.sh` a tareas
[Igniter](https://hexdocs.pm/igniter), que parchean el proyecto destino de
forma semántica (AST) en lugar de con `sed`. El plan completo de migración
está en [MIGRATION.md](MIGRATION.md).

## Estructura

```
igniter/
├── mix.exs                                       # paquete :workbench_igniter
├── lib/
│   ├── workbench_igniter.ex                      # helper de templates EEx
│   └── mix/tasks/
│       ├── workbench.setup.ex                    # tarea paraguas (configure_files + orquestación)
│       ├── workbench.install.rest.ex             # port de implement_rest (OpenAPI/Swagger)
│       ├── workbench.install.coveralls.ex        # port de implement_coveralls
│       ├── workbench.install.exdoc.ex            # port de implement_exdoc
│       ├── workbench.install.enhancements.ex     # port de implement_enhancements (módulos)
│       ├── workbench.install.graphql.ex          # API GraphQL (nuevo: en app.sh era un stub)
│       ├── workbench.install.auth0.ex            # port de implement/refine_auth0 + contexto
│       ├── workbench.install.openai.ex           # port de implement/refine_openai + contexto
│       ├── workbench.install.healthcheck.ex      # port de implement_healthcheck
│       ├── workbench.install.credo.ex            # ┐
│       ├── workbench.install.githooks.ex         # │
│       ├── workbench.install.exmachina.ex        # │ grupo trivial (fase 1):
│       ├── workbench.install.mock.ex             # │ una dep cada uno
│       ├── workbench.install.exdebug.ex          # │
│       ├── workbench.install.psql_extras.ex      # ┘
│       └── workbench.install.osmon.ex            # :os_mon en extra_applications
├── priv/templates/
│   ├── healthcheck/
│   │   ├── controller.eex                        # antes: seeds/health/rest/*.seed.ex
│   │   └── controller_test.eex                   # antes: seeds/test/web/controllers/*.seed.exs
│   ├── rest/                                     # antes: seeds/rest/*
│   └── setup/                                    # antes: seeds/* (README, .env, Dockerfiles…)
└── test/
    └── mix/tasks/
        ├── workbench.setup_test.exs
        ├── workbench.install.rest_test.exs
        ├── workbench.install.healthcheck_test.exs
        ├── workbench.install.deps_test.exs       # suite parametrizada del grupo trivial
        └── workbench.install.osmon_test.exs
```

Los módulos del paquete usan el prefijo `WorkbenchIgniter`; las tareas Mix
conservan el namespace corto `workbench.*` como interfaz de línea de comandos.

## Uso

Con `wb.sh` no hay nada que configurar: el comando `new` inyecta en el
`mix.exs` generado una dep condicional que apunta al workbench montado en
`/app/workbench` (función `workbench_dep/0`). Para usar el paquete a mano
en cualquier proyecto:

```elixir
{:workbench_igniter, path: "ruta/al/workbench/igniter", only: [:dev, :test], runtime: false}
```

y luego, para configurar un proyecto recién generado (equivalente a
`configure_files` + `config.conf` de app.sh):

```sh
mix workbench.setup --project-name "Lorem Ipsum" \
  --enhance --health --id-type uuid --timestamps naive_datetime_usec --yes
```

o instaladores individuales:

```sh
mix workbench.install.healthcheck          # muestra el diff y pide confirmación
mix workbench.install.healthcheck --yes    # aplica directo (para uso en Docker/CI)
mix workbench.install.healthcheck --endpoint /status   # ruta configurable
```

La tarea hace, en un solo patch set atómico:

| Cambio | API de Igniter | Equivalente en app.sh |
| --- | --- | --- |
| Añade `{:mock, "~> 0.3", only: :test}` | `Igniter.Project.Deps.add_dep/3` | `mix_insert` |
| `dev_routes: true` en `config/test.exs` | `Igniter.Project.Config.configure/5` | `adjust_config_test` |
| Crea `MyAppWeb.HealthcheckController` | `Igniter.Project.Module.create_module/4` | `cp seed + sed placeholders` |
| Crea el test del controller | `Igniter.Project.Module.create_module/4` | `unit_testing` |
| Scope en el router | `Igniter.Libs.Phoenix.add_scope/4` | `router_add_scope` |

El nombre del módulo, el módulo web y el nombre de la app se **deducen del
proyecto destino** (`app_name/1`, `web_module/1`, `module_name_prefix/1`):
no hay placeholders `%{elixir_module}` que inyectar desde fuera.

## Idempotencia

Ejecutar la tarea dos veces es un no-op: si `MyAppWeb.HealthcheckController`
ya existe, la tarea emite un aviso y no toca nada. Esto permite instalar
features sobre proyectos ya existentes, no solo recién generados.

## Tests

```sh
mix test
```

Los tests usan `Igniter.Test`: cada caso corre contra un proyecto Phoenix
simulado **en memoria** (`phx_test_project/0`, requiere la dep de test
`:phx_new`) — sin tocar disco, sin base de datos y sin generar proyectos
reales. Se verifica la creación de archivos en las rutas convencionales de
Phoenix, los patches sobre router/config/mix.exs y la idempotencia
(aplicar dos veces ⇒ sin cambios + aviso).

## Lecciones aprendidas (para portar el resto de features)

- **Igniter reubica módulos nuevos** a la ruta derivada de su nombre
  (`module_location: :outside_matching_folder`), lo que rompe la convención
  `controllers/` de Phoenix. La solución es registrar el patrón en el
  `.igniter.exs` del proyecto destino con
  `Igniter.Project.IgniterConfig.dont_move_file_pattern/2` (la tarea ya lo
  hace; el archivo `.igniter.exs` generado debe commitearse).
- **`add_scope` no es idempotente** (siempre añade). Cualquier instalador
  que toque el router necesita su propio guard — aquí, la existencia del
  controller vía `Igniter.Project.Module.module_exists/2`.
- Los templates EEx son el *cuerpo* del módulo: `create_module/4` añade el
  `defmodule` externo y el formateador del proyecto normaliza la indentación.

## Validado con

Elixir 1.19.5 / OTP 27, Phoenix 1.8.9, Igniter 0.8.3. Además de la suite de
tests, se validó de punta a punta contra un proyecto real generado con
`mix phx.new demo --no-assets --no-mailer --no-dashboard`: instalación
aplicada, re-ejecución no-op, `mix compile` limpio y los 5 tests generados
en verde.
