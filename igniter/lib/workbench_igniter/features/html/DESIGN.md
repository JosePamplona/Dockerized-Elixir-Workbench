# html — Design

*Revision: cartridge v0.1.0 (2026-08-30). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md); the engine is
argued in the [mailer paper](../mailer/DESIGN.md) §2.3–§2.7 and
§3.1–§3.5. This paper holds what html decides for itself: that it is
html alone, and what that leaves for live.*

## Abstract

`--no-html` is the largest thing `phx.new` can leave out: the
`phoenix_html`, `phoenix_live_view` and `lazy_html` dependencies and
the LiveView compiler, the `:browser` pipeline and the `/` route, the
`html`, `live_view` and `live_component` definitions of the web
module, the layouts and the core components, the page controller with
its view and template, the HTML error view, the logo, two tests, the
`.heex` formatter plugin, the live-reload socket and patterns — and,
by `phx.new`'s own rule, LiveView with it. The cartridge brings the
delta back for html and html only: `phx.new`'s `live` binding is
`html && live`, and a project without html is generated with
`--no-live` whatever it asked, so the html delta is taken against a
base whose live is off and leaves live off. That is what makes `live`
a cartridge of its own that `requires` this one. The mark is
`phoenix_html`. On a project without a bundler the delta brings
`phx.new`'s static placeholders for `app.js` and `app.css`, as
`phx.new --no-assets` would.

## 1. Problem

`mix help phx.new` [1]: "`--no-html` - do not generate HTML views",
and after the options: "if `--no-html` is given, the files generated
by `phx.gen.html` will no longer work, as important HTML components
will be missing". Phoenix's request guide describes what the project
then lacks — the browser pipeline, controllers rendering views,
`embed_templates`, layouts, `<Layouts.app>` [5] — and the components
guide what `core_components.ex` is: "a great example of defining
function components to be reused throughout our application",
imported by `use HelloWeb, :html` [6]. A JSON API that grows a page
needs all of it, in the shape `phx.new` gives it at the project's
Phoenix. Two questions for the cartridge: whether "html" means html
with LiveView, as a default project has it, and what a project without
esbuild or tailwind gets for its page's assets.

## 2. Background

### 2.1 What `phx.new` does with `--no-html`

`put_binding/1` [2]:

```elixir
html = Keyword.get(opts, :html, true)
live = html && Keyword.get(opts, :live, true)
```

— `mix help` says the same: `--no-live` is "Automatically disabled if
`--no-html` is given" [1]. `Single.generate/1`: `if
Project.html?(project), do: gen_html(project)`, which copies
`error_html.ex`, `error_html_test.exs`, `core_components.ex`,
`page_controller.ex`, `page_html.ex`, `page_html/home.html.heex`,
`page_controller_test.exs`, `layouts/root.html.heex`, `layouts.ex`,
and `priv/static/images/logo.svg` [3]; and `gen_assets/1` copies the
`:js`/`:no_js` and `:css`/`:no_css` sets when `html? or javascript?`
and `html? or css?` (esbuild and tailwind papers §2.1).

The conditionals [3]: `mix.exs` — `compilers: [:phoenix_live_view] ++
Mix.compilers()` and `{:phoenix_html, "~> 4.1"}`,
`{:phoenix_live_reload, "~> 1.2", only: :dev}`, `{:phoenix_live_view,
"~> 1.2.0"}`, `{:lazy_html, ">= 0.1.0", only: :test}`; `router.ex` —
the `:browser` pipeline (`:accepts ["html"]`, `:fetch_session`,
`:fetch_live_flash`, `:put_root_layout`, `:protect_from_forgery`,
`:put_secure_browser_headers`), the `/` scope with `get "/",
PageController, :home`, and in the dev scope `pipe_through :browser`
instead of `[:fetch_session, :protect_from_forgery]`; `app_name_web.ex`
— `import Phoenix.LiveView.Router` in `router/0`, and `live_view/0`,
`live_component/0`, `html/0` and `html_helpers/0` under `@html`;
`endpoint.ex` — `socket "/phoenix/live_reload/socket"` and `plug
Phoenix.LiveReloader` under code reloading; `config.exs` — `html:
<Web>.ErrorHTML` in `render_errors`; `dev.exs` — `config
:phoenix_live_view` with `debug_heex_annotations`, `debug_attributes`,
`enable_expensive_runtime_checks`; `test.exs` — the same runtime
checks; `runtime.exs` — the `:dev` `live_reload` block with its
patterns; `.formatter.exs` — `plugins: [Phoenix.LiveView.HTMLFormatter]`
and `.heex` in `inputs`; `app.js.eex` — `import "phoenix_html"` and
everything after it under `@html`; `AGENTS.md` — the html usage rules.

Measured [8]: on a default project without html, 10 files created
and 11 changed (`.formatter.exs`, `AGENTS.md`, `assets/js/app.js`,
`config/config.exs`, `dev.exs`, `runtime.exs`, `test.exs`,
`lib/probe_web.ex`, `endpoint.ex`, `router.ex`, `mix.exs`). On an
API-only project, 13 created — the 10 plus
`priv/static/assets/css/app.css`, `priv/static/assets/default.css`,
`priv/static/assets/js/app.js` — and 10 changed (no `assets/js/app.js`
to change). In neither case does `config/config.exs` gain `config
:phoenix_live_view`: the base cartridges test pins it ("html alone:
phx.new generates live only on top of it, on request").

### 2.2 What the endpoint's `/live` socket does with html

`endpoint.ex.eex` [3]:

```elixir
<%= if !(@dashboard || @live) do %><%= "# " %><% end %>socket "/live", Phoenix.LiveView.Socket,
```

— commented out unless the dashboard or live is on; html alone leaves
it as it was. The README of this cartridge used to list "the
endpoint's `/live` socket" among what html brings; it brings the
live-reload socket, and the `/live` socket is live's or dashboard's
(their papers).

### 2.3 The dependency that comes without the capability

`phoenix_live_view` is under `@html`, not `@live` (§2.1): a project
generated `--no-live` carries the dependency and the compiler, with
the socket commented and `config :phoenix_live_view` absent. That is
why the live cartridge's mark cannot be a dependency (live paper
§3.1), and why `facts.html` is `phoenix_html` and not
`phoenix_live_view`.

## 3. Design

### 3.1 The delta, for html alone

The cartridge is `PhxDelta.insert(igniter, __MODULE__, :html)`. Its
delta is taken with `facts.live` false — `facts/1` reads live off
`config :phoenix_live_view` in `config.exs`, which a `--no-html`
project cannot have — so both generations run with `--no-live`, and
the difference is html without LiveView: the socket stays commented,
`app.js` gets its `LiveSocket` lines commented (`live_comment: "// "`,
live paper §2.1), the components come without `Phoenix.LiveView.JS`.
The alternative — one cartridge for "html as a default project has
it", html and live together — was rejected because `phx.new` offers
`--no-live` as a choice on top of html, and a project that wants pages
without LiveView is a project `phx.new` generates on purpose. Two
cartridges, and `live` says it builds on this one.

### 3.2 No `requires`; the assets follow the project

html requires nothing: `phx.new` generates it in every combination of
the asset flags, and `gen_assets/1` decides the shape (§2.1). On a
project with esbuild the delta changes `assets/js/app.js` (the
`phoenix_html` import and the commented LiveSocket); on one without,
it creates `priv/static/assets/js/app.js` — the comment file the
esbuild paper §2.1 describes — and the two CSS placeholders, which is
what `phx.new --no-assets` gives a page: markup with Tailwind classes,
styled by the 80 kB `default.css` snapshot, no bundle. The page
works: probe C's `mix test` ran the generated page and error-view
tests on that shape. Inserting esbuild and tailwind afterwards brings
the pipelines and takes the placeholders away while they are still
`phx.new`'s (their papers §3.2, §3.3).

### 3.3 The mark: `phoenix_html`

`dep_installed?(igniter, :phoenix_html)` — the first line of the
`@html` block in `mix.exs` and the read `facts/1` makes for `html`.
`phoenix_live_view` is ruled out by §2.3; the router's `:browser`
pipeline is a project's to rename; `lib/<app>_web/components/` is a
directory a project can create for a JSON API's components.

## 4. Evaluation

**Unit tests** (`features/base_cartridges_test.exs`, run 2026-08-30 in
the suite of the mailer paper §4.1, 0 failures): the mark out on `--no-html` and in by
default; `:phoenix_html` in `mix.exs`, `pipeline :browser` in the
router, `core_components.ex` and `page_controller.ex` created, and no
`config :phoenix_live_view` in `config.exs`; a no-op with a notice
when in; and live's refusal on a `--no-html` project, naming html.

**Real project** (mailer §4.2): API-only probe, second run — html
conflicted on `AGENTS.md` after tailwind had written it (the
trailing-newline case, gettext paper §4: the html rules block is
appended at the end of the file, next to the last line — fixed in the
engine since, mailer §3.4 and §4.4). Probe C —
the same API-only project with html inserted *first*: `.formatter.exs`,
`AGENTS.md`, `config/config.exs`, `dev.exs`, `runtime.exs`,
`test.exs`, `lib/probe_web.ex`, `endpoint.ex`, `router.ex`, `mix.exs`
changed, and created `lib/probe_web/components/`, the three
controller files and `page_html/`, `priv/static/assets/`,
`priv/static/images/`, the two tests — no issue; then esbuild,
tailwind, dashboard and ecto over it, each clean; `mix compile
--warnings-as-errors`, `mix assets.build` (2.7 kB `app.js` without
LiveView), and the project's `mix test` — figures in the mailer paper
§4.3.

**Not measured**: html on a project that had written its own
`:browser` pipeline or a `/` route (the router merge is exercised on
`phx.new`'s text only); a page rendered in a browser; `phx.gen.html`
after the insert.

## 5. Limitations and open questions

* **The placeholders on a project without a bundler** (§3.2) are
  what `phx.new --no-assets` gives and what `mix help phx.new` does
  "not recommend"; the README should say a page inserted this way is
  unstyled beyond `default.css` until tailwind is in, and has no
  LiveView until esbuild and live are.
* **`phoenix_live_view` and its compiler arrive with html** (§2.3)
  whether or not live follows — `phx.new`'s choice, and the reason
  the socket line is commented rather than absent.
* **The router's dev scope changes pipeline** (`pipe_through :browser`
  instead of the session pair, §2.1) when html comes in on a project
  that already has the dashboard or the mailer route: a one-line
  change in a file the project may have edited near it.

## References

Read in full on 2026-08-30 unless marked otherwise.

1. `phx_new` 1.8.9, `Mix.Tasks.Phx.New` moduledoc —
   `igniter/deps/phx_new/lib/mix/tasks/phx.new.ex`.
2. `phx_new` 1.8.9, `Phx.New.Generator.put_binding/1` —
   `igniter/deps/phx_new/lib/phx_new/generator.ex`.
3. `phx_new` 1.8.9, `Phx.New.Single` (`template(:html, …)`,
   `gen_html/1`, `gen_assets/1`) and the templates `phx_web/*`,
   `phx_test/controllers/*`, `phx_single/mix.exs.eex`,
   `phx_single/lib/app_name_web.ex.eex`, `phx_web/router.ex.eex`,
   `phx_web/endpoint.ex.eex`, `phx_single/config/*.exs.eex`,
   `phx_single/formatter.exs.eex`, `phx_assets/app.js.eex` —
   `igniter/deps/phx_new/`.
4. Phoenix 1.8, *Directory structure* —
   <https://hexdocs.pm/phoenix/directory_structure.html>. **Summary
   only**; the description of `lib/hello_web`.
5. Phoenix 1.8, *Request life-cycle* —
   <https://hexdocs.pm/phoenix/request_lifecycle.html> (served from
   <https://phoenix.hexdocs.pm/request_lifecycle.html>). **Summary
   only**: fetched through a summarizer; quoted for the `:browser`
   pipeline, controllers, views, `embed_templates` and layouts.
6. Phoenix 1.8, *Components and HEEx* —
   <https://hexdocs.pm/phoenix/components.html> (served from
   <https://phoenix.hexdocs.pm/components.html>). **Summary only**;
   quoted for `core_components.ex` and `use HelloWeb, :html`.
7. `igniter/lib/workbench_igniter/features/html/html.ex`, `task.ex`;
   `igniter/test/workbench_igniter/features/base_cartridges_test.exs`;
   the [mailer paper](../mailer/DESIGN.md) for the engine; the
   [live paper](../live/DESIGN.md) for what html leaves to it.
8. `PhxDelta.delta/3` run on 2026-08-30 (mailer paper, reference 15).
