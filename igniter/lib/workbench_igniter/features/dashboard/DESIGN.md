# dashboard — Design

*Revision: cartridge v0.1.0 (2026-08-30). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md); the engine is
argued in the [mailer paper](../mailer/DESIGN.md) §2.3–§2.7 and
§3.1–§3.5. This paper holds what the dashboard decides for itself,
which is the smallest of the eight.*

## Abstract

`phx.new --no-dashboard` leaves out three things: the
`phoenix_live_dashboard` dependency, the `live_dashboard "/dashboard"`
route in the router's dev scope with its `import`, and the
`RequestLogger` plug in the endpoint — and it comments out the
endpoint's `/live` socket when live is off too. The cartridge brings
the delta back, in every shape of project: `phx.new` generates the
dashboard with or without html, with or without live, and the route's
pipeline and the socket's state follow the project. LiveDashboard's
own installation guide asks for the same four steps; the delta is
those steps at the project's Phoenix, with `phx.new`'s `dev_routes`
guard. The mark is the dependency. It opens a console door,
`/dev/dashboard`.

## 1. Problem

LiveDashboard "provides real-time performance monitoring and debugging
tools for Phoenix developers" [4, summary only], and `phx.new` puts it
in every project unless `--no-dashboard` — "do not include
Phoenix.LiveDashboard" [1]. Its guide for an existing app is short
[4]: the dependency; `live_view: [signing_salt: …]` and `socket
"/live", Phoenix.LiveView.Socket` in the endpoint; `import
Phoenix.LiveDashboard.Router` and `live_dashboard "/dashboard"` in a
dev-only scope; and, for production, authentication. The question for
the cartridge was whether anything of that depends on html or live —
the dashboard is a LiveView, served on the LiveView socket, inside a
browser pipeline — and the answer is in `phx.new`'s templates.

## 2. Background

### 2.1 What `phx.new` does with `--no-dashboard`

`put_binding/1` [2]: `dashboard = Keyword.get(opts, :dashboard, true)`.
No template is copied for it; it is three conditionals [3]:

* `phx_single/mix.exs.eex`: `{:phoenix_live_dashboard, "~> 0.8.3"}`.
* `phx_web/endpoint.ex.eex`: the `/live` socket lines prefixed with
  `"# "` when `!(@dashboard || @live)`, and after the code-reloading
  block:

  ```elixir
  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
  ```

* `phx_web/router.ex.eex`: the dev scope exists when `@dashboard ||
  @mailer` — "Enable LiveDashboard in development", `if
  Application.compile_env(:<app>, :dev_routes) do` — with `import
  Phoenix.LiveDashboard.Router` and its comment ("If you want to use
  the LiveDashboard in production, you should put it behind
  authentication and allow only admins to access it… you can use
  Plug.BasicAuth") under `@dashboard`; inside, `scope "/dev" do` with
  `pipe_through :browser` when `@html` and `pipe_through
  [:fetch_session, :protect_from_forgery]` when not; then
  `live_dashboard "/dashboard", metrics: <Web>.Telemetry` under
  `@dashboard`.

`config.exs`'s `live_view: [signing_salt: …]` is unconditional in
`phx.new` [3], so the guide's second step is already in every
project.

Measured [8]: created nothing; changed `lib/probe_web/endpoint.ex`,
`lib/probe_web/router.ex`, `mix.exs` — on a default project without
the dashboard, on one without live either, and on an API-only project
alike.

### 2.2 What LiveDashboard asks for

[4, summary only]: the dependency; "Update your endpoint configuration
in `config/config.exs`: `live_view: [signing_salt: "SECRET_SALT"]`";
"Add the socket declaration to your endpoint: `socket "/live",
Phoenix.LiveView.Socket`"; in the router `import
Phoenix.LiveDashboard.Router` and, under a dev-only condition, a scope
piping through `:browser` with `live_dashboard "/dashboard"`; and for
production a pipeline with `Plug.BasicAuth`. `phx.new`'s output is
that, with `metrics: <Web>.Telemetry` wired to the telemetry module
every project has, the `RequestLogger` plug the guide does not
mention, and `dev_routes` as the condition instead of `Mix.env()`.

## 3. Design

### 3.1 The delta; no `requires`

The cartridge is `PhxDelta.insert(igniter, __MODULE__, :dashboard)`.
Two requirements were considered. **html**: the dashboard's pages are
LiveViews rendered in the browser, and `:browser` is html's pipeline —
but `phx.new` generates the dashboard without html with a pipeline of
its own, `[:fetch_session, :protect_from_forgery]` (§2.1), and the
API-only probe served it that way. **live**: the dashboard rides the
`/live` socket — and the endpoint condition `@dashboard || @live` is
`phx.new` saying the socket is the dashboard's as much as live's
(§2.1), which is why the live cartridge's mark is not the socket
(live paper §3.1). `phoenix_live_dashboard` depends on
`phoenix_live_view` on Hex, and `mix deps.get` after the insert
resolves it whatever the project's flags. No requirement, then: the
cartridge follows the generator, like esbuild and tailwind.

### 3.2 The socket, and the router's scope, follow the project

On a project without live the delta uncomments the three socket lines;
on one with live, the endpoint is not in the delta at all (the base
already has the socket). On a project with the mailer the dev scope
exists and the delta adds the import and the route inside it; on one
without, the delta brings the scope too, with the pipeline the
project's html decides. None of this is the cartridge's code: it is
`facts/1` reading the shape and `phx.new` rendering both sides
(mailer §3.2). The base cartridges test pins the first case
(`--no-dashboard --no-live`: `socket "/live"` at the start of a line
after the insert).

### 3.3 The mark; the door

`dep_installed?(igniter, :phoenix_live_dashboard)` — the read
`facts/1` makes for `dashboard`, and the only one of the three
conditionals that is a fact about the capability rather than about
the socket or the router. `console/0` names the door,
`{"dashboard", "/dev/dashboard"}`: the path the dev scope serves,
which exists in the workspace's dev deployment (`dev_routes` is true
in `dev.exs`) and not in prod, where LiveDashboard's guide wants
authentication the cartridge does not add (§2.2) — the project's
decision, as `phx.new` leaves it.

## 4. Evaluation

**Unit tests** (`features/base_cartridges_test.exs`, run 2026-08-30 in
the suite of the mailer paper §4.1, 0 failures): the mark out on `--no-dashboard` and
in by default; on a `--no-dashboard --no-live` project,
`:phoenix_live_dashboard` in `mix.exs`, `live_dashboard "/dashboard"`
in the router, and `socket "/live"` uncommented in the endpoint; a
no-op with a notice when in.

**Real project** (mailer §4.2): API-only probe, second run —
`mix workbench.install.dashboard --yes` changed `lib/probe_web/endpoint.ex`
(10 insertions, 3 deletions: the socket uncommented, the plug),
`lib/probe_web/router.ex` (9 and 1: the import and the route in the
scope the mailer had opened, its pipeline the session pair) and
`mix.exs` (1), no issue; the project compiled and its tests passed
with the dashboard in and no html. Probe B (html born, live inserted):
endpoint, router, `mix.exs` — 13 insertions, 1 deletion — no issue,
the socket already on. Probe C (html, esbuild, tailwind inserted
first): the same three files, no issue.

Through the workbench itself: `./wb.sh add dashboard` on a
`new2 --no-mailer --no-dashboard` workspace committed *Insert
dashboard* with `phoenix_live_dashboard` fetched (mailer paper §4.5).

**Not measured**: `/dev/dashboard` opened in a browser after the
insert; the `RequestLogger` cookie; the dashboard's Ecto stats page on a project that inserts
ecto afterwards (the route is the same; the page appears with the
repo).

## 5. Limitations and open questions

* **No production access**: `dev_routes` only, as `phx.new` writes
  it; the guide's `Plug.BasicAuth` pipeline is the project's to add.
  The console's door is a dev door.
* **The dashboard on a project without html** works on the session
  pipeline `phx.new` gives it (§3.1), unstyled by the project's
  layout — LiveDashboard brings its own — and measured only as "the
  route compiles and the tests pass", not opened.
* **Uncommenting the socket on a `--no-live` project** is a change to
  the endpoint that a later live insert then finds already made
  (§3.2): correct, and the reason the live cartridge cannot use the
  socket as its mark.

## References

Read in full on 2026-08-30 unless marked otherwise.

1. `phx_new` 1.8.9, `Mix.Tasks.Phx.New` moduledoc —
   `igniter/deps/phx_new/lib/mix/tasks/phx.new.ex`.
2. `phx_new` 1.8.9, `Phx.New.Generator.put_binding/1` —
   `igniter/deps/phx_new/lib/phx_new/generator.ex`.
3. `phx_new` 1.8.9, the templates `phx_single/mix.exs.eex`,
   `phx_web/endpoint.ex.eex`, `phx_web/router.ex.eex`,
   `phx_single/config/config.exs.eex` — `igniter/deps/phx_new/templates/`.
4. Phoenix LiveDashboard 0.8, `Phoenix.LiveDashboard` moduledoc —
   <https://hexdocs.pm/phoenix_live_dashboard/Phoenix.LiveDashboard.html>
   (served from <https://phoenix-live-dashboard.hexdocs.pm/Phoenix.LiveDashboard.html>).
   **Summary only**: fetched through a summarizer; quoted for the
   description and the installation steps.
5. `igniter/lib/workbench_igniter/features/dashboard/dashboard.ex`,
   `task.ex`; `igniter/test/workbench_igniter/features/base_cartridges_test.exs`;
   the [mailer paper](../mailer/DESIGN.md) for the engine, the
   [live paper](../live/DESIGN.md) §3.1 for the socket as a mark.
6. `PhxDelta.delta/3` run on 2026-08-30 (mailer paper, reference 15).
