# Changelog — mishka_chelekom

Versioned on its own, independently of the workbench release that ships
it. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) applied to
what the cartridge *installs*.

## v0.1.0 - (2026-10-06)

### Added

- Mishka Chelekom's components without Ash: `{:mishka_chelekom, "~>
  0.0.9", only: :dev}` and the library's own task, queued —
  `mix mishka.ui.gen.components --import --helpers --global --yes`,
  what its installer composes. The components land in
  `lib/<app>_web/components/`, and `MishkaComponents` takes the place
  of `import <App>Web.CoreComponents` in the web module.
- `--components`: the ones to generate, by the library's names. The
  library's batch task generates exactly the names it is given, so the
  list is completed with what each component declares `necessary` and
  with the eight that stand in for `CoreComponents` (`alert`, `button`,
  `icon`, `input_field`, `list`, `modal`, `navbar`, `table`). Ten
  components are 263 KB of minified CSS (31 KB gzipped) where all 74
  are 1.46 MB (107 KB).
- `--no-daisy`: daisyUI out — its plugins in `app.css`, its
  dependency in `mix.exs`, and its classes in `Layouts` and the home
  page, rewritten as Tailwind utilities, with the page's ground as a
  rule of its own. Refused while `cinder` or
  `ash_authentication_phoenix` is in: their pages are dressed in
  daisyUI.
- The components are run through `mix format` once generated, since
  the library leaves `button.ex` a line short of it; `--no-format`
  leaves them as written.
- `--mcp`: the library's MCP server forwarded in the router, under
  `dev_routes`, at `--mcp-path` — `/mishka-chelekom/mcp` by default and
  not the library's `/mcp`: an MCP endpoint is one server's, and that
  is the path any other would want. The path is a detail of the
  switch: given without `--mcp` it is refused — the route `mix mishka.mcp.setup` writes, at the
  end of the router. A WORKAROUND: the library's task puts it inside
  `pipeline :browser` on an untouched router, so the cartridge writes
  its lines and does not queue it; to remove when the task appends to
  the router module.
- With `--mcp`, `mix chelekom.mcp.json`: a task planted in the project
  (`lib/mix/tasks/chelekom.mcp.json.ex`) that writes `.mcp.json` with the
  address a client connects to, read when it is run — the port
  `docker-compose.yml` publishes the endpoint's on, or the endpoint's
  own where there is no compose. It keeps the file's other servers,
  and `.gitignore` lists the file: it is the machine's.
- The MCP route as a door of the console, for a client: its address
  with the port the app is published on, the state of `.mcp.json`
  (missing, up to date, behind), and a button that runs
  `mix chelekom.mcp.json`. It gives no line to copy: the task writes
  what a client reads.
- Each component's page in the library's documentation as its value's
  doc, and <https://mishka.tools/chelekom> in the option's note.
- Builds on **html** with live, **tailwind** and **esbuild**
  (`requires`).
- The mark is the dependency, the same one the ash cartridge's
  `--components mishka_chelekom` leaves. A second run generates
  nothing, and adds the MCP route and its task when asked. `--mcp`
  counts as in with both: a project with the route alone is offered
  the option again, and gets the task.
- `--solve-warnings`: the fence three of the library's code blocks
  lack, written — `combobox`'s example, never opened, and `layout`'s
  `flex` and `grid`, never closed — so `mix docs` stops warning of
  them. Off by default; a WORKAROUND for mishka_chelekom 0.0.9, to
  remove when its templates carry both fences.
- `mix workbench.mishka_components`, the plumbing the queued command
  goes through: it completes the list off the fetched package's
  catalog, fails where the library's task reports issues, and formats
  what it generated.
