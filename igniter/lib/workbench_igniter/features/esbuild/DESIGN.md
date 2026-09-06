# esbuild — Design

*Revision: cartridge v0.1.1 (2026-08-30). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md); the engine is
argued in the [mailer paper](../mailer/DESIGN.md) §2.3–§2.7 and
§3.1–§3.5. This paper holds what esbuild decides for itself, which is
little, and what the delta takes away, which the README has to say.*

## Abstract

`phx.new --no-esbuild` leaves out the `esbuild` dependency, its
`config :esbuild` profile, the watcher, the `assets.*` aliases and the
`assets/js` sources — and puts a placeholder script in
`priv/static/assets/js/app.js` in their place, a file of comments that
tells the reader which scripts to copy into a bundle of their own. The
cartridge brings the delta back and takes the placeholder away while it
is still that file of comments; one the project rewrote stays. The mark is the `esbuild` dependency. The one
decision proper to this cartridge is that it is html-agnostic: esbuild
without html is what `phx.new` generates for that shape, sources and
config with no page to load them, and the cartridge does not refuse
it.

## 1. Problem

Phoenix's asset guide: "From Phoenix v1.7, new applications use esbuild
to prepare assets via the Elixir esbuild wrapper" [4]; `mix help
phx.new` on the flag: "`--no-esbuild` - do not include esbuild
dependencies and assets. We do not recommend setting this option,
unless for API only applications, as doing so requires you to manually
add and track JavaScript dependencies" [1]. An API-only project that
later grows a page is the case the flag was made for, and the case
where the bundler has to come back. The esbuild package's own README
has the recipe [5]; what it cannot say is where `phx.new` puts the
profile, the watcher and the aliases in *this* project, or what the
`--no-esbuild` generation put in their place.

## 2. Background

### 2.1 What `phx.new` does with `--no-esbuild`

`put_binding/1` [2]: `assets = Keyword.get(opts, :assets, true)`,
`esbuild = Keyword.get(opts, :esbuild, assets)`, `javascript: esbuild`,
`asset_builders: Enum.filter([tailwind && :tailwind, esbuild &&
:esbuild], & &1)`. `Single.gen_assets/1` [3]:

```elixir
if html? or javascript? do
  command = if javascript?, do: :js, else: :no_js
  copy_from(project, __MODULE__, command)
end
```

`:js` is `assets/js/app.js`, `assets/vendor/topbar.js`,
`assets/tsconfig.json`; `:no_js` is one text file,
`phx_static/app.js`, copied to `priv/static/assets/js/app.js` [3] —
717 bytes of comments: "For Phoenix.HTML support, including form and
button helpers copy the following scripts into your javascript bundle:
`deps/phoenix_html/priv/static/phoenix_html.js`", and the same for
`phoenix.js` and LiveView [3]. No `LiveSocket` in it.

The conditionals [3]: `mix.exs` — `{:esbuild, "~> 0.10", runtime:
Mix.env() == :dev}` under `@javascript`, and under `@asset_builders !=
[]` the `assets.setup`, `assets.build` and `assets.deploy` aliases
built from the list (`"esbuild.install --if-missing"`, `"esbuild
<app>"`, `"esbuild <app> --minify"`, then `"phx.digest"`);
`config.exs` — `config :esbuild` with `version: "0.25.4"` and the
`<app>` profile (`js/app.js --bundle --target=es2022
--outdir=../priv/static/assets/js --external:/fonts/*
--external:/images/* --alias:@=.`, `cd: assets`, `NODE_PATH` to
`deps` and the build path); `dev.exs` — the `esbuild:` watcher, and
`watchers: []` when neither builder is on; `prod.exs` — the
`cache_static_manifest` line under `@javascript or @css`;
`.gitignore` — `/priv/static/assets/` and the esbuild binary under the
same condition; `AGENTS.md` — the assets rules only when *both*
builders are on (`javascript && css`); `layouts.ex.eex` and
`core_components.ex.eex` — `phx-click` JS on the flash and the theme
toggle under `@live and @javascript`.

Measured [7]: on a default project without esbuild, created
`assets/js/app.js`, `assets/tsconfig.json`, `assets/vendor/topbar.js`;
changed `AGENTS.md`, `config/config.exs`, `config/dev.exs`,
`lib/probe_web/components/core_components.ex`,
`lib/probe_web/components/layouts.ex`, `mix.exs`. On an API-only
project the same three created and `.gitignore`, `config/config.exs`,
`config/dev.exs`, `config/prod.exs`, `mix.exs` changed. Base-only —
in the project without esbuild and not in the one with it —
`priv/static/assets/js/app.js`.

### 2.2 What the package asks for

The esbuild package's README [5, summary only]: "Mix tasks for
installing and invoking esbuild"; the dependency with `runtime:
Mix.env() == :dev` "if building assets in production, or `only: :dev`
if precompiling during development"; `config :esbuild` with a
`version:` and a profile; the watcher `{Esbuild, :install_and_run,
[:default, ~w(--sourcemap=inline --watch)]}` in `dev.exs`; the
`assets.deploy` alias `["esbuild default --minify", "phx.digest"]`;
`mix esbuild.install`. `phx.new`'s output is that recipe with the
profile named after the app, the three aliases instead of one, and
the `NODE_PATH` that lets `import "phoenix_html"` resolve to `deps/`.

## 3. Design

### 3.1 The delta, and no refusal

The cartridge is `PhxDelta.insert(igniter, __MODULE__, :esbuild)`.
The one thing it could have decided and did not is to require html:
the sources it brings are loaded by `root.html.heex`, which html owns,
and `import "phoenix_html"` in `app.js` is under `@html` in the
template (§2.1). But `phx.new` generates esbuild without html —
`gen_assets/1` copies `:js` when `html? or javascript?` — and a project
can want a bundle for a JavaScript client of a JSON API. The cartridge
follows the generator: a `requires/0` would be the cartridge knowing
better than `phx.new` what the flag means, and the html cartridge does
the symmetric thing (its paper §3.2). What the user gets on an
API-only project is exactly what `phx.new --no-html` with esbuild
gives: `assets/js/app.js` without the `phoenix_html` import and no
page.

### 3.2 The placeholder goes, when it is still the placeholder

`--no-esbuild` put `priv/static/assets/js/app.js` in the project
(§2.1); esbuild's output goes to the same path, and `.gitignore` gains
`/priv/static/assets/` with the insert. The file is in the delta's
`removed` set (mailer §3.3), and `apply/3` removes it only while it is,
byte for byte, what `phx.new` wrote — because the project may have
replaced it with a hand-made bundle, the case the flag's help
describes ("manually add and track JavaScript dependencies", §1), and
that file is the project's. The first version of the engine removed
nothing and the placeholder stayed tracked beside the pipeline until
the first build overwrote it (mailer §4.3); the unit test now asserts
both halves — gone when untouched, kept when rewritten.

### 3.3 The mark: `esbuild`

`dep_installed?(igniter, :esbuild)`, the read `facts/1` makes for
`esbuild`. `config :esbuild` in `config.exs` would do as well and is
the same fact one file later; the dependency is what the flag leaves
out first and what the package's README begins with.

## 4. Evaluation

**Unit tests** (`features/base_cartridges_test.exs`, run 2026-08-30 in
the suite of the mailer paper §4.1, 0 failures): the mark out on `--no-esbuild` and in
by default; `:esbuild` in `mix.exs`, `config :esbuild` in `config.exs`
and `esbuild:` in `dev.exs` after the insert; a no-op with a notice
when in.

**Real project** (mailer §4.2): API-only probe, second run —
`mix workbench.install.esbuild --yes` changed `.gitignore` (9 lines),
`config/config.exs` (10), `config/dev.exs`, `config/prod.exs`,
`mix.exs`, and created `assets/js/app.js`, `assets/tsconfig.json`,
`assets/vendor/topbar.js` — 225 insertions, 2 deletions, no issue.
Probe C (API-only, html first): the same files after html, no issue;
the run's `mix assets.setup` downloaded esbuild 0.25.4 and `mix
assets.build` bundled `priv/static/assets/js/app.js` — see the
mailer paper §4.3 for the figures. In probe B esbuild was in from
birth and `assets.build` wrote a 327.8 KiB bundle with LiveView in it.

**Not measured**: esbuild on a project that replaced the placeholder
with its own bundle; `mix assets.deploy`; the `--alias:@=.` and
`NODE_PATH` resolution beyond what `assets.build` exercised.

## 5. Limitations and open questions

* **A rewritten placeholder stays** (§3.2) at the path the bundle will
  be written to: the first `mix assets.build` overwrites it. That is
  what the project asked for by keeping it, and the README says so.
* **The AGENTS.md assets rules arrive only with both builders**
  (`javascript && css`, §2.1): esbuild alone changes nothing there,
  and the tailwind insert afterwards brings the block — which is where
  the html-after-tailwind conflict of the mailer paper §5 does *not*
  occur, since the block is in the middle of the file.
* **The esbuild version is `phx.new`'s** (`0.25.4` at 1.8.9), pinned
  in `config.exs`; `mix esbuild.install` downloads it on first build
  (probe C). A project wanting another sets it there.

## References

Read in full on 2026-08-30 unless marked otherwise.

1. `phx_new` 1.8.9, `Mix.Tasks.Phx.New` moduledoc —
   `igniter/deps/phx_new/lib/mix/tasks/phx.new.ex`.
2. `phx_new` 1.8.9, `Phx.New.Generator.put_binding/1` —
   `igniter/deps/phx_new/lib/phx_new/generator.ex`.
3. `phx_new` 1.8.9, `Phx.New.Single` (`template(:js, …)`,
   `template(:no_js, …)`, `gen_assets/1`) and the templates
   `phx_assets/app.js.eex`, `phx_assets/topbar.js.eex`,
   `phx_assets/tsconfig.json.eex`, `phx_static/app.js`,
   `phx_single/mix.exs.eex`, `phx_single/config/{config,dev,prod}.exs.eex`,
   `phx_single/gitignore.eex`, `phx_web/components/layouts.ex.eex`,
   `phx_web/components/core_components.ex.eex` — `igniter/deps/phx_new/`.
4. Phoenix 1.8, *Asset management* —
   <https://hexdocs.pm/phoenix/asset_management.html> (served from
   <https://phoenix.hexdocs.pm/asset_management.html>). **Summary
   only**: fetched through a summarizer; quoted for the v1.7 sentence,
   the three `assets.*` tasks and `--no-esbuild`.
5. `phoenixframework/esbuild`, README —
   <https://github.com/phoenixframework/esbuild/blob/main/README.md>.
   **Summary only**; quoted for the package description and the
   *Adding to Phoenix* steps.
6. `igniter/lib/workbench_igniter/features/esbuild/esbuild.ex`,
   `task.ex`; `igniter/test/workbench_igniter/features/base_cartridges_test.exs`;
   the [mailer paper](../mailer/DESIGN.md) for the engine.
7. `PhxDelta.delta/3` and `generate/1` run on 2026-08-30 (mailer
   paper, reference 15), including the base-only paths of an API-only
   project with html.
