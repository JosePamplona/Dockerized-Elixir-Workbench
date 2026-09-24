# IGN_IMPROV — lo que Igniter ya resuelve y el workbench puede tomar

*2026-09-24. Leído en las fuentes instaladas de un workspace con ash y
todas sus opciones (igniter 0.8.4, ash 3.33.10, ash_postgres 2.7.3,
ash_authentication 4.15.0); las líneas citadas son de ese `deps/`. El
detalle del flujo de ash está en
`igniter/lib/workbench_igniter/features/ash/DESIGN.md` §2.6.*

Este papel responde dos preguntas y deja un plan:

1. ¿Conviene un chequeo que diga si ash-hq.org agregó o quitó algo que
   el cartucho de ash debería seguir? (§1)
2. ¿Qué estructuras de Igniter podría usar el workbench para mejorar su
   flujo, empezando por cómo se deshace una inserción que falla? (§2–§3)

El plan, por fases, está en §4.

---

## 1. Seguir al sitio de ash

### 1.1 Lo que ya existe

`mix workbench.ash.site` (`features/ash/site.ex`) lee el mapa de
features del bundle del sitio (`/assets/app-*.js`) y compara cada
feature del sitio con lo que el cartucho pondría en el comando:
paquetes, args y tooltip. Sale con código 1 si hay diferencias. Hoy
reporta 26 iguales y 2 para mirar (`appsignal` y `opentelemetry`,
«Installer coming soon»).

### 1.2 Lo que no ve

| Hueco | Por qué importa ahora |
| --- | --- |
| **La dirección inversa.** Recorre las features del sitio; si el sitio *quita* un paquete que el cartucho ofrece, no lo dice. | Seguiríamos ofreciendo algo que el sitio retiró. |
| **Las secciones.** No lee en qué sección está cada feature. | Desde la v0.5.0 las secciones *son* las opciones (`--ai`, `--finance`, …). Si el sitio mueve `ash_events` de *Automation* a otra sección, o abre una sección nueva, las opciones quedan mal nombradas. El HTML de la home las trae: `<div data-category="Automation">` con las claves de sus features dentro. |
| **El orden.** El comando va en el orden del sitio (`order:` en el mapa); no se compara. | El orden importa: ash_authentication antes que su mitad Phoenix (§2.5 del DESIGN). |
| **Dónde corre.** Solo a mano. | Nadie se entera hasta que alguien se acuerda. |

Lo que el chequeo **no** puede ver es la lista de estrategias de
`--auth`: esa lista es de `ash_authentication.add_strategy`, no del
sitio. Se verifica contra la fuente del paquete, no contra la web (§4,
fase 1).

### 1.3 Opinión

Sí, vale la pena, pero **extendiendo el task que hay**, no con un
script aparte: el parser, la comparación y los tests offline
(`parse/1` y `compare/1` trabajan sobre texto) ya están. Y sin
bloquear PRs: depende de la red y de un sitio ajeno, así que su lugar
es un job programado de CI (semanal) que abre un issue o falla solo
ese job, nunca el build.

---

## 2. Cuando una inserción falla: Igniter contra el workbench

### 2.1 Lo que hace Igniter

Igniter no tiene *rollback*. Tiene tres cosas distintas:

1. **Transacción en memoria.** Todos los instaladores trabajan sobre un
   mismo `%Igniter{}` (`Rewrite`); nada toca el disco hasta
   `do_or_dry_run/2`, que escribe todo junto (`Rewrite.write_all`,
   `igniter.ex:1227`). Si hay *issues*, no escribe nada
   (`igniter.ex:1165`, `1279`). Un instalador que falla *con un issue*
   no deja rastro.
2. **Restauración de `mix.exs` y `mix.lock`**, solo en
   `igniter.upgrade`: los guarda antes y ofrece restaurarlos si algo sale
   mal (`upgrades.ex:424-441`).
3. **Un aviso.** Si el árbol tiene cambios sin commit, advierte que así
   no se podrá hacer `git reset` (`igniter.ex:1341-1366`). Es decir:
   Igniter delega en git lo que no puede deshacer.

Lo que queda **fuera** de su transacción: las tareas en cola
(`add_task`, que corren como procesos `mix` *después* de escribir —
`ash.codegen`, el `igniter.install` de ash, `npm install`) y el
`deps.get`. Un `raise` en medio de un instalador no escribe nada, pero
tampoco es un issue: el proceso muere sin reporte ordenado.

### 2.2 Lo que hace el workbench

`wb.sh add` exige un árbol limpio (`require_clean_workspace`), corre la
inserción en su contenedor y, si falla, `undo_failed_insert` hace
`git checkout -- .` y `git clean -fdq` (deja los `*.phx-new` para
mezclar a mano). Si sale bien, un commit por cartucho, y `eject` es su
`git revert`.

### 2.3 Cuál es más eficaz y cuál más eficiente

| | Igniter (memoria) | Workbench (git) |
| --- | --- | --- |
| Cubre un issue antes de escribir | sí, sin costo | sí (no hay nada que deshacer) |
| Cubre un `raise` a mitad de instalador | a medias: no se escribió nada (seguía en memoria), pero el proceso muere con un stacktrace en vez de un issue | sí |
| Cubre tareas en cola (codegen, `igniter.install`, npm) | no | sí: lo que escribieron está en el árbol |
| Cubre `mix.lock` | solo en upgrade | sí (está versionado) |
| Cubre archivos ignorados (`deps/`, `_build/`, `node_modules/`, `priv/static`) | no | no (`clean` sin `-x`) |
| Cubre la base de datos y los volúmenes | no | no |
| Costo | cero | un `checkout` + `clean`: milisegundos |
| Deshacer *después* de un éxito | no existe (`igniter.remove` solo saca deps: «Igniter does not have a concept of uninstallers») | `eject` = `git revert` del commit, exacto |

**Eficacia:** gana git, sin discusión. Es el único que cubre lo que
pasa después de escribir, que es justo donde falla ash (su trabajo
entero es una tarea en cola). **Eficiencia:** gana la memoria, pero
solo porque no hace nada; su ventaja real es que un fallo detectado
*como issue* nunca escribe.

**Conclusión: son complementarios, no rivales.** El sobre de git se
queda. Lo que conviene tomar de Igniter es la disciplina de fallar
antes de escribir:

- **Todo rechazo como issue, nunca como `raise`.** Un issue se reporta
  ordenado y no escribe; un `raise` deja el proceso muerto y depende del
  sobre. La suite de conformidad puede exigirlo (fase 2).
- **Tapar los huecos del sobre**: los ignorados y los efectos fuera del
  árbol (fase 2).

### 2.4 Un dato de paso: los prompts

`DOCKER_TTY_FLAGS` da `--tty --interactive` solo con terminal. Desde la
consola el contenedor corre sin stdin: un `Mix.shell().yes?/1` (el de
ash_authentication_phoenix, que `--yes` no contesta) lee EOF y responde
*no*, y Igniter fuerza `yes` sin TTY (`install.ex:90`). No se cuelga.
Desde una terminal, espera la respuesta. El §5 del DESIGN de ash dice
«would hang under `./wb.sh add`»: hay que precisarlo.

---

## 3. Otras estructuras de Igniter que sirven

Por valor para el workbench, de más a menos.

### 3.1 `--dry-run`: ver la inserción antes de hacerla

Opción global de todo task de Igniter (`info.ex:77`). Arma el
`%Igniter{}` completo, muestra el diff, los archivos que movería o
borraría, los avisos y **las tareas que correría**, y no escribe nada
(`igniter.ex:1164-1215`).

Para el workbench: la consola podría mostrar, antes de *Insert*, lo que
el cartucho va a escribir — hoy solo se ve después, leyendo el commit.
Límite: lo que hacen las tareas en cola no aparece (en ash, casi todo);
el dry-run sí dice *qué* tareas correrían, que en ash es el comando
entero. No toca el proyecto: cumple «the project owes the workbench
nothing».

### 3.2 Upgrades: llevar un cartucho insertado a su versión nueva

`Igniter.Upgrades.run(igniter, from, to, %{"0.2.0" => [&fun/2]}, opts)`
(`upgrades.ex:11-21`) corre, en orden, los pasos entre dos versiones.
`mix igniter.upgrade pkg` los encuentra como `<pkg>.upgrade from to`.

Para el workbench: cada cartucho ya se versiona solo (su CHANGELOG), y
la consola ya lee «una inserción más vieja que la caja» en la tabla de
paquetes. Un `workbench.upgrade.<name> FROM TO` con un mapa de pasos
por versión permitiría subir un proyecto sin eject + insert.

El problema es saber `FROM` sin pedirle nada al proyecto. Se puede
derivar: la fecha del commit `Insert NAME …` contra la historia del
propio workbench da la versión que tenía el cartucho ese día (el
CHANGELOG del cartucho en el commit del workbench anterior a esa
fecha). Sin marcas, sin trailers. Es la pieza más grande de este
papel.

### 3.3 La consulta a Hex de `igniter.install`

`igniter.install` pide a Hex la última versión estable y escribe
`~> MAJOR.0` (`deps.ex:646-700`, `version.ex:25-42`). Los cartuchos,
en cambio, fijan su requisito en `deps/1` a mano (y los golden files
dependen de eso, así que no conviene cambiarlo).

Para el workbench: la misma consulta sirve para un chequeo general,
hermano del de ash: `mix workbench.deps.outdated` compara el `deps/1`
de cada cartucho con lo último de Hex y dice cuáles quedaron atrás.
Generaliza §1 a toda la estantería.

### 3.4 `--check`

Opción global: sale con código ≠ 0 si el task emitiría warnings,
issues, tareas o movimientos (`igniter.ex:1293-1320`). Poco valor aquí:
los instaladores del workbench ya se saltan todo cuando el cartucho está
(`installed?` → aviso → skip), y la suite ya prueba que la segunda
corrida no cambia nada. Queda anotado para no redescubrirlo.

### 3.5 Lo que no conviene tomar

- **`installs:` / `adds_deps`** en el `Info` de nuestros tasks: solo se
  honran por la cadena de `igniter.install` (DESIGN de ash §2.3);
  `wb.sh add` corre el task directo. Nuestros cartuchos ya componen lo
  que necesitan.
- **`igniter.remove`** para `eject`: saca deps y nada más. El revert del
  commit es el inverso exacto.
- **`.igniter.exs` con `Igniter.Extensions.Phoenix`**: ayuda a Igniter
  a ubicar módulos web, pero sería un archivo en el proyecto que hoy no
  hace falta; el `.igniter.exs` que aparece en `_001` lo escribió el
  propio Igniter al correr ash. Se queda como está.

---

## 4. Plan

Cada fase cierra con los checks de CI verdes y una entrada en el
CHANGELOG; ninguna depende de la siguiente.

### Fase 1 — El chequeo del sitio, completo (hecha, 2026-09-24)

- Hecho: `site.ex` lee las secciones de la home (`sections/1`) y las
  compara con las opciones (`compare_sections/2`): paquete agregado,
  quitado o movido de sección, sección nueva o cerrada, y las
  estrategias del sitio contra `--auth`. *Web* y *Data Layers* entran
  en la misma comparación, así que la dirección inversa queda cubierta.
- Hecho: lo que el sitio marca «coming soon» se reporta aparte (`..`) y
  no hace fallar; el task sale con 1 solo ante un `!!`.
- Hecho: tests offline con fixtures de la home y del mapa
  (`ash_site_test.exs`), incluidos un paquete movido, uno quitado, uno
  agregado, una sección cerrada, una nueva y una estrategia
  desconocida.
- Hecho: `.github/workflows/ash-site.yml`, semanal y a mano, aparte del
  build. El README de ash dice para qué sirve, cómo correrlo, cómo leer
  sus marcas y qué hacer con una diferencia.
- Descartado: comparar el orden. El campo `order` del mapa repite
  números (12, 16, 17) y pone Money en 999; no dice nada confiable.
- Pendiente: la lista de `@auth_strategies` contra la que acepta
  `ash_authentication.add_strategy`. No es del sitio sino del paquete,
  y el paquete no está en las deps de `igniter/`: hace falta leerlo de
  Hex (`mix hex.package fetch`) o de un workspace con ash.

### Fase 2 — Fallar antes de escribir, y un sobre más cerrado (chica)

- Conformidad: ningún instalador usa `raise` para rechazar; los
  rechazos son `Igniter.add_issue`. Un test que recorre las fuentes de
  `features/*/` y lo exige, como ya hace la suite con `deps/1`.
- `undo_failed_insert`: después del `checkout`/`clean`, `mix
  deps.clean --unused --unlock` en el contenedor, para que los paquetes
  que la inserción bajó no queden en el volumen `deps`.
- Si una tarea en cola corrió migraciones (hoy ninguna: ash no pasa
  `--setup`), decirlo en el mensaje de deshacer: la base no vuelve.
- DESIGN de ash §5: precisar lo del prompt (§2.4 de este papel).

### Fase 3 — Vista previa de la inserción (mediana)

- `wb.sh add --dry-run NAME …` → `mix workbench.install.NAME … --dry-run
  --yes` en el contenedor; imprime el diff, sin commit.
- Contrato `--json` para la consola: archivos con su diff, tareas que
  correrían, avisos. Igniter imprime texto; el task del workbench tendría
  que armar el JSON desde el `%Igniter{}` (`Rewrite.sources/1`,
  `igniter.tasks`, `igniter.notices`) antes de `do_or_dry_run`.
- Consola: un botón *Preview* junto a *Insert* en la forma del
  cartucho; la vista reusa `ConsoleWeb.Box.file/1` (la misma hoja que
  la pantalla Files).
- Base cartridges: el dry-run genera el proyecto dos veces (PhxDelta);
  medir el tiempo antes de ofrecerlo en ellos.

### Fase 4 — Actualizar un cartucho insertado (grande, decidir antes)

- Derivar la versión de inserción: fecha del commit `Insert NAME …` →
  commit del workbench anterior → versión en el CHANGELOG del cartucho.
- `Feature` gana `upgrades/0 :: %{version => [fun(igniter, opts)]}`,
  vacío por defecto; `mix workbench.upgrade.NAME FROM TO` corre
  `Igniter.Upgrades.run/5`.
- `wb.sh upgrade NAME`: un commit `Upgrade NAME FROM → TO`; `eject`
  tendría que revertir también esos commits.
- Consola: la tabla de paquetes ya sabe cuándo la inserción es más vieja
  que la caja; ahí va el botón.
- Decisiones abiertas: qué pasa con un proyecto cuya inserción es
  anterior al primer paso de upgrade escrito; si el upgrade se ofrece
  para colecciones.

### Fuera de fase

- `mix workbench.deps.outdated` (§3.3): útil, independiente, cuando
  haga falta.
