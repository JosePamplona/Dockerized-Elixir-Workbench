# live — Design

*Revision: cartridge v0.1.1 (2026-08-30). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md); the engine is
argued in the [mailer paper](../mailer/DESIGN.md) §2.3–§2.7 and
§3.1–§3.5. This paper holds the two things live decides that no other
base cartridge has to: a mark that is not a dependency, and a
requirement.*

## Abstract

`phx.new --no-live` is the one flag that removes no dependency: the
project keeps `phoenix_live_view` and its compiler, and what it loses
is `config :phoenix_live_view` in `config.exs`, the live lines of
`app.js` — written *commented out*, not omitted — the `JS` commands
of the core components, and the LiveView usage rules. The endpoint's
`/live` socket is commented out too, but the dashboard uncomments it
on its own. So the cartridge's mark is the configuration line, the
one thing only `--live` brings, read off `config.exs` rather than
`mix.exs`; and the cartridge `requires` html, because `phx.new`'s
`live` binding is `html && live` and a delta taken without html is
empty. LiveView's own documentation no longer carries a recipe for
existing projects — "LiveView is included by default in Phoenix
applications" — and the 0.18 recipe it used to carry is what the delta
produces, at the project's version. Verified on a project born with
html and on one where html and esbuild had been inserted first — the
case that exposed the engine's trailing-newline conflict, clean since
the merge normalises it.

## 1. Problem

LiveView's installation page says [4, summary only]: "LiveView is
included by default in Phoenix applications. Therefore, to use
LiveView, you must have already installed Phoenix and created your
first application" — and provides no steps for a project that opted
out. The 0.18 guide did [5, summary only]: "If you are using a
Phoenix version earlier than v1.5 or your app already exists, continue
with the following steps" — the dependency, `live_view: [signing_salt:
…]`, `import Phoenix.LiveView.Router`, `plug :fetch_live_flash`,
`socket "/live", Phoenix.LiveView.Socket`, `live_view/0` in the web
module, the `LiveSocket` in `app.js`. In a 1.8 project generated
`--no-live` most of that is already there, because html brought it
(§2.1); what is missing is smaller and less visible, and one piece of
it — the commented `app.js` — is not something a dependency check can
see. The questions for the cartridge were what its mark is, and what
it depends on.

## 2. Background

### 2.1 What `phx.new` does with `--no-live`

`mix help phx.new` [1]:

> `--no-live` - comment out LiveView socket setup in your Endpoint and
> assets/js/app.js. Automatically disabled if --no-html is given

`put_binding/1` [2]: `live = html && Keyword.get(opts, :live, true)`,
`live_comment: if(live, do: nil, else: "// ")`. The templates [3]:

* `phx_single/config/config.exs.eex`, under `@live`:

  ```elixir
  # Configure LiveView
  config :phoenix_live_view,
    # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
    root_tag_attribute: "phx-r"
  ```

* `phx_web/endpoint.ex.eex`: the three `socket "/live"` lines prefixed
  with `"# "` when `!(@dashboard || @live)`.
* `phx_assets/app.js.eex`: from `import {Socket}` to `window.liveSocket
  = liveSocket` and the live-reload block, every line prefixed with
  `<%= @live_comment %>`; and under `<%= if not @live do %>` a
  `DOMContentLoaded` handler that hides flashes on click — the
  no-LiveView substitute for `phx-click`.
* `phx_web/components/core_components.ex.eex`: `alias
  Phoenix.LiveView.JS` and the `show/2` and `hide/2` JS commands under
  `@live`; `phx-click` on the flash under `@live and @javascript`.
* `phx_web/components/layouts.ex.eex`: `phx-click` on the theme toggle
  under `@live`; `root.html.heex.eex`: a `phx:set-theme` listener with
  live, a `DOMContentLoaded` handler without.
* `AGENTS.md`: the LiveView usage rules under `@live`, the last block
  before `<!-- usage-rules-end -->` [2].

Nothing under `@live` in `mix.exs`: `phoenix_live_view` and the
compiler are `@html`'s (html paper §2.3).

Measured [8]: on a default project without live, created nothing;
changed `AGENTS.md`, `assets/js/app.js`, `config/config.exs`,
`lib/probe_web/components/core_components.ex`,
`lib/probe_web/components/layouts.ex`,
`lib/probe_web/components/layouts/root.html.heex`. On a project with
html and without esbuild: `AGENTS.md`, `config/config.exs`,
`core_components.ex`, `lib/probe_web/endpoint.ex` — no `app.js`,
since there is none; and the endpoint, since the dashboard was off.

### 2.2 What the dashboard does to the same socket

`phx.new`'s endpoint condition is `@dashboard || @live` (§2.1): a
`--no-live` project with the dashboard has the `/live` socket
uncommented. LiveDashboard's own installation says the same from its
side — add `socket "/live", Phoenix.LiveView.Socket` to the endpoint
[6, summary only]. The socket is therefore a fact about *either*
capability, not about live.

## 3. Design

### 3.1 The mark is `config :phoenix_live_view`

Four candidates, three ruled out by §2.1 and §2.2:

1. `phoenix_live_view` in `mix.exs` — present on every html project,
   live or not. A `--no-live` project would read as having live, the
   installer would skip it, and a default project would be
   indistinguishable from one that opted out.
2. The `/live` socket in the endpoint — uncommented by the dashboard
   too; a `--no-live` project with the dashboard reads as live.
3. `LiveSocket` in `assets/js/app.js` — the line is there in both
   cases, commented in one; a regex anchored at the start of the line
   can tell them apart, but the file exists only with esbuild, and a
   project without a bundler has no `app.js` at all (§2.1).
4. **`config :phoenix_live_view` in `config/config.exs`.** Chosen: the
   one block only `@live` writes, in a file every project has.
   `facts/1` reads it as `dep.(:phoenix_live_view) and
   Regex.match?(~r/^config :phoenix_live_view\b/m, config)` — the
   dependency as a precondition, the block as the mark — and
   `installed?/1` returns `facts.live` rather than a second read, so
   the guard and the base generation agree (mailer §3.2). The cost is
   §5's first item: a project that configures LiveView by hand in
   `config.exs` for another reason reads as live.

The catalog's "flips once installed" test (ash paper §3.4) holds for
this mark as for a dependency: the delta writes the block.

### 3.2 `requires ["html"]`

`live = html && …` (§2.1): a `--no-html` project generated with
`--live` is generated without it, so `delta/3` on `%{facts | live:
true}` with `html: false` is the difference between two identical
generations — nothing. The cartridge could apply an empty delta and
add nothing, silently; or generate html and live together, which is
the html cartridge's job with its own mark and its own row in the
catalog; or refuse, naming what to insert first. The last is
`requires/0`, which grew for this case: `PhxDelta.insert/4` asks
`missing_requirements/2` before the mark, and the issue reads "live
builds on html, not in the project yet. Insert that first: ./wb.sh
add html". The catalog carries the list; the console shows it in the
box. The same mechanism serves ash's `--auth password` on live and
mailer (features README).

### 3.3 What the delta carries, and what it cannot

Everything of §2.1 that the project's shape has: the config block
always; the `app.js` lines when esbuild is in — the commented lines
become live ones, the `DOMContentLoaded` flash handler goes; the JS
commands and `phx-click` when html's components are there; the
endpoint's socket when the dashboard had not uncommented it. On a
project without esbuild the client side is absent, not commented
(§2.1): the delta cannot bring a `LiveSocket` into a file that does
not exist, and `phx.new`'s static `priv/static/assets/js/app.js` is a
comment (esbuild paper §2.1). LiveView is then configured and served
and never connected to from the browser until esbuild is in — which
is what `phx.new --no-esbuild` with live gives too. The cartridge
says so in a notice when `facts.esbuild` is false, naming the file
and the command; the README says it too.

## 4. Evaluation

**Unit tests** (`features/base_cartridges_test.exs`, run 2026-08-30 in
the suite of the mailer paper §4.1, 0 failures): the mark out on `--no-live` and in by
default; `config :phoenix_live_view` in `config.exs`, `const liveSocket
= new LiveSocket` at the start of a line in `app.js`, `alias
Phoenix.LiveView.JS` in the components after the insert; the refusal
on `--no-html`, naming html and `./wb.sh add html`, with `requires ==
["html"]` in the catalog entry; a no-op with a notice when in.

**Real project** (mailer §4.2). *Probe B* — `phx.new --no-live
--no-ecto --no-dashboard --no-mailer --no-gettext`, live inserted first:
`AGENTS.md`, `assets/js/app.js`, `config/config.exs`,
`core_components.ex`, `layouts.ex`, `root.html.heex` and
`endpoint.ex` changed — 354 insertions, 62 deletions (the
uncommenting), no issue; a second run "live is in already: skipping";
`mix workbench.status` listed live among the installed; `mix
assets.build` bundled a 327.8 kB `app.js` with LiveView in it; `mix
test` 5/5. *API-only probe, second run*: refused before html, and
refused after, html having conflicted. *Probe C* — html, esbuild,
tailwind and dashboard inserted first, then live: "AGENTS.md: the live
lines conflict" and "assets/js/app.js: the live lines conflict",
nothing written. Both files had been written by an earlier insert
(html's merge, esbuild's create), both end without a newline in
`phx.new`'s output and with one in Igniter's, and live's hunks in both
are at the end of the file: the LiveView rules block before the last
line of `AGENTS.md`, the removal of the flash handler that closes
`app.js`. The gettext paper §4 diagnoses the same byte; the engine's
`merge3/3` normalises it since (mailer §3.4), and *probe C′* (mailer
§4.4) — the same order, html, esbuild, tailwind, dashboard, then live —
inserted live with no issue: 6 files, 339 insertions, 58 deletions,
the `app.js` bundle then 327.8 kB with LiveView in it, `mix test` 5/5.

**Not measured**: a LiveView mounted and connected in a browser after
the insert; `./wb.sh add live` inside the container; a project that
uncommented its `app.js` by hand (the merge would see ours = theirs
there and carry nothing, which is right).

## 5. Limitations and open questions

* **The mark can be forged** (§3.1): a `config :phoenix_live_view`
  line written by hand for `debug_heex_annotations` reads as live.
  `phx.new` puts that option in `dev.exs`, not `config.exs`, so the
  case is unlikely and not handled.
* **No client without esbuild** (§3.3): the insert says so and inserts
  anyway, the same shape as tailwind's build dependency.
* **`--no-live` is `phx.new`'s comment-out, not an absence**: a
  project that deleted the commented lines from `app.js` instead of
  leaving them will see the delta re-add them — as a change from base
  (commented) to theirs (live) applied to ours (gone), which
  `git merge-file` reports as a conflict, since ours and theirs both
  changed the segment.

## References

Read in full on 2026-08-30 unless marked otherwise.

1. `phx_new` 1.8.9, `Mix.Tasks.Phx.New` moduledoc —
   `igniter/deps/phx_new/lib/mix/tasks/phx.new.ex`.
2. `phx_new` 1.8.9, `Phx.New.Generator` — `put_binding/1`,
   `generate_agents_md/1` — `igniter/deps/phx_new/lib/phx_new/generator.ex`.
3. `phx_new` 1.8.9, the templates `phx_single/config/config.exs.eex`,
   `phx_web/endpoint.ex.eex`, `phx_assets/app.js.eex`,
   `phx_web/components/core_components.ex.eex`,
   `phx_web/components/layouts.ex.eex`,
   `phx_web/components/layouts/root.html.heex.eex` —
   `igniter/deps/phx_new/templates/`.
4. Phoenix LiveView 1.x, *Installation* —
   <https://hexdocs.pm/phoenix_live_view/welcome.html> (served from
   <https://phoenix-live-view.hexdocs.pm/welcome.html>; the
   `installation.html` page answers 404). **Summary only**: fetched
   through a summarizer; quoted for the "included by default"
   sentence and the absence of existing-project steps.
5. Phoenix LiveView 0.18.18, *Installation*, *Existing projects* —
   <https://github.com/phoenixframework/phoenix_live_view/blob/v0.18.18/guides/introduction/installation.md>.
   **Summary only**; quoted for the manual steps the recipe used to
   list.
6. Phoenix LiveDashboard, `Phoenix.LiveDashboard` moduledoc —
   <https://hexdocs.pm/phoenix_live_dashboard/Phoenix.LiveDashboard.html>.
   **Summary only**; the endpoint socket step.
7. `igniter/lib/workbench_igniter/features/live/live.ex`, `task.ex`;
   `WorkbenchIgniter.PhxDelta.facts/1` and `insert/4`;
   `WorkbenchIgniter.Feature.missing_requirements/2`;
   `igniter/test/workbench_igniter/features/base_cartridges_test.exs`;
   the [mailer paper](../mailer/DESIGN.md) for the engine, the
   [html paper](../html/DESIGN.md) for what html brings without live.
8. `PhxDelta.delta/3` run on 2026-08-30 (mailer paper, reference 15).
