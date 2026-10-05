# tailwind — Design

*Revision: cartridge v0.1.1 (2026-08-30). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md); the engine is
argued in the [mailer paper](../mailer/DESIGN.md) §2.3–§2.7 and
§3.1–§3.5. This paper holds what tailwind decides for itself.*

## Abstract

`phx.new --no-tailwind` leaves out the `tailwind` dependency with the
`heroicons` and `daisyui` git dependencies, the `config :tailwind`
profile, the watcher, the `assets/css/app.css` source with its
plugin, and the theme script of the root layout — and, in their place,
an 80 kB `priv/static/assets/default.css` and a stylesheet link to
it, because the generated markup keeps its Tailwind classes either
way. The cartridge brings the delta back: the pipeline, and the
markup changes that follow from having it (the theme toggle, the
`daisyUI` classes of the home page). The placeholders go while they
are still `phx.new`'s, as with esbuild.
The mark is the `tailwind` dependency. The one thing proper to this
cartridge is what its `app.css` imports: `phoenix-colocated`, which
exists only with LiveView's compiler — a dependency of the *build*,
not of the insert, which the cartridge names in a notice when html is
out.

## 1. Problem

`mix help phx.new` on the flag [1]:

> `--no-tailwind` - do not include tailwind dependencies and assets.
> The generated markup will still include Tailwind CSS classes, those
> are left-in as reference for the subsequent styling of your layout
> and components

So a project without Tailwind has a layout written for it, styled by a
static `default.css` that `phx.new` ships as a snapshot. Bringing the
pipeline back is the tailwind package's *Adding to Phoenix* [5] plus
whatever `phx.new` did to the markup once it had the pipeline —
which is more than the recipe, since the root layout's theme script
and the home page's classes differ between the two generations
(§2.1).

## 2. Background

### 2.1 What `phx.new` does with `--no-tailwind`

`put_binding/1` [2]: `tailwind = Keyword.get(opts, :tailwind,
assets)`, `css: tailwind`, and `asset_builders` as in the esbuild
paper. `Single.gen_assets/1` [3]:

```elixir
if html? or css? do
  command = if css?, do: :css, else: :no_css
  copy_from(project, __MODULE__, command)
end
```

`:css` is `assets/css/app.css` and `assets/vendor/heroicons.js`;
`:no_css` is two text files, `phx_static/app.css` (49 bytes) to
`priv/static/assets/css/app.css` and `phx_static/default.css` (80 112
bytes) to `priv/static/assets/default.css`, with the template's own
comment: "the default.css file can be re-created by using the
recreate_default_css.exs file in the installer folder" [3].

The conditionals [3]: `mix.exs` — `{:tailwind, "~> 0.5", runtime:
Mix.env() == :dev}`, `{:heroicons, github: "tailwindlabs/heroicons",
tag: "v2.2.0", sparse: "optimized", app: false, compile: false, depth:
1}`, `{:daisyui, github: "saadeghi/daisyui", tag: "v5.5.20", sparse:
"packages/bundle", …}`, and the `assets.*` aliases with `tailwind
<app>`; `config.exs` — `config :tailwind, version: "4.3.0"` with the
profile `--input=assets/css/app.css
--output=priv/static/assets/css/app.css`; `dev.exs` — the `tailwind:`
watcher; `prod.exs` — `cache_static_manifest` under `@javascript or
@css`; `.gitignore`; `AGENTS.md` — the assets rules when both builders
are on; `root.html.heex` — the link to `/assets/default.css` when
`not @css`, and when `@css` the inline theme script (`phx:theme` in
`localStorage`, `data-theme` on the root element); `layouts.ex` —
the theme toggle under `@css`; `home.html.heex` — a `@css` block.
`app.css.eex` itself [3]:

```css
@import "tailwindcss" source(none);
@import "phoenix-colocated/<%= @web_app_name %>/colocated.css";
@source "../css";
@source "../js";
@source "../../lib/<%= @lib_web_name || @app_name %>";
/* Required for Tailwind to automatically pick up changes in colocated CSS files in dev */
@source "<%= if @in_umbrella do %>../../<% end %>../../_build/dev/phoenix-colocated/<%= @web_app_name %>/*/";
```

with the heroicons plugin and the daisyUI plugin below.

Measured [7]: on a default project without tailwind, created
`assets/css/app.css` and `assets/vendor/heroicons.js`; changed
`AGENTS.md`, `config/config.exs`, `config/dev.exs`,
`lib/probe_web/components/layouts.ex`,
`lib/probe_web/components/layouts/root.html.heex`,
`lib/probe_web/controllers/page_html/home.html.heex`, `mix.exs`. On an
API-only project: the same two created; `.gitignore`,
`config/config.exs`, `config/dev.exs`, `config/prod.exs`, `mix.exs`
changed. Base-only, on an API-only project with html:
`priv/static/assets/css/app.css` and `priv/static/assets/default.css`.

### 2.2 What the package asks for, and what Phoenix says

The tailwind package's README [5, summary only]: "Mix tasks for
installing and invoking tailwindcss via the stand-alone tailwindcss
cli"; the dependency with `runtime: Mix.env() == :dev`; `config
:tailwind` with `version: "4.3.0"` and a profile of `--input` and
`--output`; the watcher; an `assets/css/app.css` opening with
`@import "tailwindcss" source(none);` and `@source` lines; the
`assets.deploy` alias; `mix tailwind.install`. Phoenix's asset guide
[4, summary only]: "Phoenix ships with Heroicons embedded as CSS
classes, ensuring only used icons reach clients via Tailwind's
tree-shaking"; daisyUI "can be added as an external Tailwind plugin";
and of the flag, that `--no-tailwind` "leaves CSS markup structure in
place for manual CSS framework integration". `phx.new`'s output is the
package's recipe with heroicons and daisyUI as git dependencies read
by the CSS plugins, and one line the recipe does not have — the
`phoenix-colocated` import.

### 2.3 `phoenix-colocated`

The import resolves through `NODE_PATH` to
`_build/dev/phoenix-colocated/<app>/`, a directory written by
`phoenix_live_view`'s compiler [3, the `@source` comment]. That
compiler is in the project only with html (`:phoenix_live_view` in
`mix.exs`'s `compilers` under `@html`, html paper §2.1). Measured on
the API-only probe with tailwind and esbuild in and html out: `mix
assets.build` failed with "Can't resolve
'phoenix-colocated/probe/colocated.css' in '…/assets/css'" (mailer
paper §4.2, second run).

## 3. Design

### 3.1 The delta; the markup comes with it

The cartridge is `PhxDelta.insert(igniter, __MODULE__, :tailwind)`.
What the delta carries beyond the package's recipe is the reason this
is a cartridge and not a paragraph in a README: the root layout's
theme script and the `default.css` link, the layout's toggle, the home
page's block (§2.1) are markup changes that `phx.new` makes *because*
the pipeline is there, and a hand recipe would leave the project
loading `default.css` beside a compiled `app.css`. `git merge-file`
carries them onto the project's own layout, edits included (mailer
§3.4).

### 3.2 No `requires`, and the build's dependency named

Two dependencies were considered for `requires/0` and neither was
taken. **html**: `phx.new` generates tailwind without html
(`gen_assets/1`, `html? or css?`), and the esbuild paper §3.1 gives
the reason to follow the generator. **live**, for `phoenix-colocated`
(§2.3): the import is `phx.new`'s, present in every `app.css` it
writes, and a stock `phx.new --no-html` project with tailwind on is
generated with it too — the failure is the generator's shape, not the
insert's, and refusing the insert would refuse what `phx.new` does.
The insert is exact; the *build* needs html's compiler. So the
cartridge inserts and, when `facts.html` is false, adds a notice
naming the import and the command (`./wb.sh add html`): the one thing
it knows that the generator does not say.

### 3.3 The placeholders go; the mark

As the esbuild paper §3.2: `priv/static/assets/css/app.css` and
`priv/static/assets/default.css` are in the delta's `removed` set and
go with the insert while they are still `phx.new`'s bytes; rewritten,
they stay. The root layout no longer links `default.css` after the
insert (§2.1), so a kept one is dead weight, not a wrong style. The
first version of the engine removed nothing: probe C's `git status`
showed `css/app.css` and `js/app.js` overwritten by the first build
and `default.css` left behind (mailer §4.3).

The mark is `dep_installed?(igniter, :tailwind)`, the read `facts/1`
makes for `tailwind`.

## 4. Evaluation

**Unit tests** (`features/base_cartridges_test.exs`, run 2026-08-30 in
the suite of the mailer paper §4.1, 0 failures): the mark out on `--no-tailwind` and
in by default; `:tailwind` in `mix.exs`, `config :tailwind` in
`config.exs`, `tailwind:` in `dev.exs`; a no-op with a notice when in.

**Real project** (mailer §4.2): API-only probe, second run —
`mix workbench.install.tailwind --yes` after esbuild changed
`AGENTS.md` (27 lines: the assets rules, both builders now on),
`config/config.exs` (12), `config/dev.exs`, `mix.exs` (20: the three
dependencies and the aliases), created `assets/css/app.css` (105
lines) and `assets/vendor/heroicons.js` (43), no issue; `mix
assets.build` then failed on `phoenix-colocated` (§2.3), html not
being in. Probe C (html, esbuild, then tailwind): the same plus
`layouts.ex`, `root.html.heex` and `home.html.heex`, no issue; `mix
assets.setup` downloaded tailwindcss 4.3.0, `mix assets.build`
printed "≈ tailwindcss v4.3.0 / 🌼 daisyUI 5.5.20 / Done in 138ms".
In probe B, tailwind in from birth, the same build passed with
LiveView in.

**Not measured**: a project whose layout was restyled by hand on top of
`default.css` — the merge on `root.html.heex` is exercised only on
`phx.new`'s own text; `mix assets.deploy`; heroicons and daisyUI
fetched over git inside the toolchain container.

## 5. Limitations and open questions

* **The build needs LiveView's compiler** (§2.3, §3.2): tailwind on a
  project without html compiles nothing until html is in. The insert
  succeeds and says so; `mix assets.build` still fails with a message
  that names the import and not the cartridge.
* **Three git dependencies** (`heroicons`, `daisyui` at pinned tags,
  and the package): `mix deps.get` after the insert clones them, which
  the toolchain's `add` does and a developer running the task by hand
  must remember.
* **The theme script is inline in `root.html.heex`** and comes with
  the delta as a whole block; a project that had written its own
  theme handling into the head of that layout will conflict there, and
  the file stays untouched with the `.phx-new` beside it (mailer §3.4).

## References

Read in full on 2026-08-30 unless marked otherwise.

1. `phx_new` 1.8.9, `Mix.Tasks.Phx.New` moduledoc —
   `igniter/deps/phx_new/lib/mix/tasks/phx.new.ex`.
2. `phx_new` 1.8.9, `Phx.New.Generator.put_binding/1` —
   `igniter/deps/phx_new/lib/phx_new/generator.ex`.
3. `phx_new` 1.8.9, `Phx.New.Single` (`template(:css, …)`,
   `template(:no_css, …)`, `gen_assets/1`) and the templates
   `phx_assets/app.css.eex`, `phx_assets/heroicons.js.eex`,
   `phx_static/app.css`, `phx_static/default.css`,
   `phx_single/mix.exs.eex`, `phx_single/config/{config,dev,prod}.exs.eex`,
   `phx_web/components/layouts/root.html.heex.eex`,
   `phx_web/components/layouts.ex.eex`,
   `phx_web/controllers/page_html/home.html.heex.eex` —
   `igniter/deps/phx_new/`.
4. Phoenix 1.8, *Asset management* —
   <https://hexdocs.pm/phoenix/asset_management.html> (served from
   <https://phoenix.hexdocs.pm/asset_management.html>). **Summary
   only**: fetched through a summarizer; quoted for Heroicons, daisyUI
   and `--no-tailwind`.
5. `phoenixframework/tailwind`, README —
   <https://github.com/phoenixframework/tailwind/blob/main/README.md>.
   **Summary only**; quoted for the package description and the
   *Adding to Phoenix* steps.
6. `igniter/lib/workbench_igniter/features/tailwind/tailwind.ex`,
   `task.ex`; `igniter/test/workbench_igniter/features/base_cartridges_test.exs`;
   the [mailer paper](../mailer/DESIGN.md) for the engine.
7. `PhxDelta.delta/3` and `generate/1` run on 2026-08-30 (mailer
   paper, reference 15).
