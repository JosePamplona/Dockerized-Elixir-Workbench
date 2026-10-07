defmodule WorkbenchIgniter.Features.MishkaChelekom do
  @moduledoc """
  Mishka Chelekom's components, generated into the project by its own
  generator.

  Mishka Chelekom is a development dependency that writes function
  components — HEEx, Tailwind utilities, a few JavaScript hooks — into
  `lib/<app>_web/components/`, where they are the project's to edit.
  This cartridge adds the dependency and **queues the library's own
  task** (`Igniter.add_task/3`), the one its installer composes:

      mix mishka.ui.gen.components --import --helpers --global --yes

  which generates the components, the `MishkaComponents` macro that
  imports them, and swaps that macro for `import <App>Web.CoreComponents`
  in the web module, so every template of the project draws Mishka's
  `<.button>`, `<.input>`, `<.table>` and `<.flash>`. Nothing of the
  library is reimplemented here.

  Why queued and not composed: the task belongs to a dependency this
  patch set is the one to add, and a queued task runs as its own `mix`
  process after the files are written and the dependencies fetched —
  the one place it can be found (the ash cartridge queues for the same
  reason). It runs through `mix workbench.mishka_components`, which
  fails where the library's task reports issues.

  ## The decisions it owns

  * `--components` — which components, for a project that does not
    want all 74: the stylesheet of all of them is 1.46 MB minified
    (107 KB gzipped), and of ten of them 263 KB (31 KB). The library's
    batch task generates exactly the names it is given, without what
    each one needs, so the cartridge completes the list with the
    components each chosen one declares `necessary` and with
    `core/0`, the eight whose functions stand in for the ones
    `CoreComponents` exported — without those the swap would leave
    `Layouts` calling a `<.flash>` nobody defines.
  * `--no-daisy` — daisyUI out. Both libraries style the same class
    names (`collapse-content`, `indicator`, `stat-title`, `stat-value`),
    and with daisyUI in, Mishka's `collapse` opens onto a panel 0 px
    high. The option takes daisyUI's plugins out of `app.css` and its
    dependency out of `mix.exs`, paints the page's ground the themes
    painted, and rewrites the daisyUI classes of the two pages
    `phx.new` wrote — `Layouts` and the home page — as the Tailwind
    utilities they stood for.

  * `--no-format` — by default the generated components are run
    through the project's formatter, since the library leaves one of
    them a line short of it and a `mix format --check-formatted` in a
    pre-commit hook would refuse the next commit. The switch leaves
    them as the library wrote them.
  * `--mcp` — the library's MCP server on the project's own port: the
    route `mix mishka.mcp.setup` writes, forwarded in the router under
    `dev_routes` at `--mcp-path` — `/mishka-chelekom/mcp` unless told
    otherwise, a path of the library's own and not the `/mcp` another
    server would want. Of the library's three ways to serve it, this
    is the one a project in a container offers the host: the
    standalone server and the stdio entry both have the client run
    `mix`. The cartridge writes the route itself, a WORKAROUND:
    the task puts it inside `pipeline :browser` (`mcp/3`).

  Re-running adds the MCP route where it is missing and nothing else:
  a component is added afterwards with the library's own
  `mix mishka.ui.gen.component NAME`.
  """
  use WorkbenchIgniter.Feature

  embed_assets()

  @dep {:mishka_chelekom, "~> 0.0.9", only: :dev}

  @plumbing "workbench.mishka_components"

  # The project's own task that writes `.mcp.json`, planted by `--mcp`.
  @mcp_task "lib/mix/tasks/mcp.json.ex"

  # Where the MCP server is forwarded, unless told otherwise. Not the
  # library's `/mcp`: an MCP endpoint is one server's — the protocol's
  # transport gives each server "a single HTTP endpoint path" — so a
  # project with two servers needs two paths, and `/mcp` is the one any
  # of them would take. The name goes first, as Tidewave's does
  # (`/tidewave/mcp`): a `forward "/mcp"` takes everything under
  # `/mcp/`, so a path of that shape would depend on the router's order.
  @mcp_path "/mishka-chelekom/mcp"

  @site "https://mishka.tools/chelekom"

  # Where a component's page is not `docs/<name>` in dashes — the forms
  # are under `docs/forms/` — as each one's `doc_url` in the library's
  # catalog says. `icon` has no page.
  @pages %{
    "form_wrapper" => "forms",
    "toggle_field" => "forms/toggle",
    "icon" => nil
  }

  # The library's catalog at 0.0.9, under the category its own catalog
  # files give each component (`priv/components/<name>.exs`), in the
  # order of its documentation's menu. A closed list: a name outside it
  # is refused here, before anything is fetched. 0.0.10-alpha.8 carries
  # the same 74, and what the library generates besides — a project's
  # own `component_*` templates, the headless set — is not this
  # option's (DESIGN.md §3.2).
  @components [
    general:
      ~w(accordion avatar badge blockquote button card chat clipboard collapse device_mockup
         divider indicator jumbotron keyboard layout list progress rating shape skeleton
         speed_dial spinner stat stepper table table_content tabs timeline typography),
    navigations:
      ~w(breadcrumb dock dropdown footer mega_menu menu navbar pagination scroll_area sidebar),
    forms:
      ~w(checkbox_card checkbox_field color_field combobox date_time_field email_field fieldset
         file_field form_wrapper input_field native_select number_field password_field
         radio_card radio_field range_field search_field tel_field textarea_field text_field
         toggle_field url_field),
    feedback: ~w(alert banner toast),
    overlays: ~w(drawer modal overlay popover tooltip),
    media: ~w(carousel gallery icon image video)
  ]

  # The components whose functions stand in for the ones phx.new's
  # CoreComponents exports, which `--global` stops importing: `flash`
  # is alert's, `input` input_field's, `header` navbar's, and `show`
  # and `hide` modal's. `Layouts` calls two of them and Phoenix's
  # generators the rest, so a chosen list always carries these.
  @core ~w(alert button icon input_field list modal navbar table)

  # Packages whose own pages are dressed in daisyUI's classes: with
  # them in, taking daisyUI out undresses those pages.
  @daisy_bound [
    cinder: "its tables' theme is `cinder/priv/themes/daisy_ui.css`",
    ash_authentication_phoenix: "its sign-in pages take daisyUI's overrides"
  ]

  # daisyUI's two palettes as phx.new ships them, as the Tailwind greys
  # nearest to them: the base colours a class names, light and dark.
  @base %{
    "100" => {"white", "zinc-900"},
    "200" => {"zinc-100", "zinc-800"},
    "300" => {"zinc-200", "zinc-700"},
    "content" => {"zinc-950", "zinc-50"}
  }

  # daisyUI's components in the pages phx.new writes, as the utilities
  # each one stood for there. The primary button takes Mishka's own
  # primary (`--primary-light` and its fellows, in the `@theme` its
  # installer writes), so the project's `css_overrides` recolour it too.
  @classes [
    {"btn btn-ghost",
     "inline-flex h-10 items-center rounded-sm px-4 text-sm font-semibold hover:bg-zinc-100 dark:hover:bg-zinc-800"},
    {"btn btn-primary",
     "inline-flex h-10 items-center gap-1.5 rounded-sm px-4 text-sm font-semibold bg-primary-light text-white hover:bg-primary-hover-light dark:bg-primary-dark dark:text-zinc-950 dark:hover:bg-primary-hover-dark"},
    {"badge badge-warning badge-sm",
     "inline-flex items-center rounded-sm bg-amber-400 px-1.5 text-xs text-zinc-950"},
    {"navbar", "flex w-full items-center min-h-16 py-2"},
    {"card relative", "relative"},
    {"rounded-box", "rounded-lg"}
  ]

  @ground """
  /* The page's ground and ink, which daisyUI's themes painted. */
  @layer base {
    body {
      @apply bg-white text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50;
    }
  }
  """

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @doc "Every component of the library's catalog, by its category."
  def components, do: @components

  @doc "The components that stand in for `CoreComponents`, which every chosen list carries."
  def core, do: @core

  @impl true
  def deps(_state), do: [@dep]

  @impl true
  def task, do: "workbench.install.mishka_chelekom"

  # Its components are function components with LiveView's JS commands
  # and hooks, styled with Tailwind 4 utilities, and its hooks go into
  # the `app.js` esbuild bundles.
  @impl true
  def requires, do: [{"html", live: true}, "tailwind", "esbuild"]

  # The MCP route, once it is in: an endpoint for an AI tool, not a page.
  # The console knows the port the app is published on, which nothing
  # in the project says, so the line a client needs is filled there —
  # and is the client's own to keep, in its own configuration.
  @impl true
  def console do
    [
      doors: [
        {"mcp", "{mcp_path}",
         when: {:option, :mcp},
         build: "mcp.json",
         client: [
           {"Claude Code", "claude mcp add --transport http mishka-chelekom {url}"},
           {"Cursor · VS Code",
            ~s({"mcpServers": {"mishka-chelekom": {"type": "http", "url": "{url}"}}})}
         ]}
      ]
    ]
  end

  @impl true
  def choices do
    by_category =
      for {category, names} <- @components do
        {category, Enum.map(names, &with_page(&1, category))}
      end

    [components: by_category]
  end

  defp with_page(name, category) do
    case page(name, category) do
      nil -> name
      url -> {name, url}
    end
  end

  @doc "The page of a component in the library's documentation, or `nil`."
  @spec page(String.t(), atom()) :: String.t() | nil
  def page(name, category) do
    dashed = String.replace(name, "_", "-")
    default = if category == :forms, do: "forms/" <> dashed, else: dashed

    case Map.get(@pages, name, default) do
      nil -> nil
      path -> "#{@site}/docs/#{path}"
    end
  end

  @impl true
  def option_docs do
    [
      components:
        "Comma-separated: the components to generate, by the library's names (`card,badge,timeline`). The ones each needs come along, and so do the eight that stand in for `CoreComponents` (#{Enum.map_join(@core, ", ", &"`#{&1}`")}). Left out, all of them.",
      no_daisy:
        "Takes daisyUI out of the project: its plugins in `app.css`, its dependency, and its classes in `Layouts` and the home page, rewritten as Tailwind utilities. Both libraries style some of the same class names, and beside daisyUI Mishka's `collapse` does not open. Refused while a package dressed in daisyUI is in (#{Enum.map_join(@daisy_bound, ", ", fn {dep, _} -> "`#{dep}`" end)}). Default: off, daisyUI stays.",
      format:
        "The generated components are run through `mix format`, so a `mix format --check-formatted` before the next commit passes: the library leaves one of them a line short of it. Off, they stay as the library wrote them.",
      mcp:
        "The library's MCP server for AI tools, on the project's own port: the route `mix mishka.mcp.setup` writes, forwarded in the router under `dev_routes`. With it comes `mix mcp.json`, a task of the project's own that writes `.mcp.json` with the address a client connects to — the port `docker-compose.yml` publishes, or the endpoint's own without one — and `.gitignore` lists that file. Default: off.",
      mcp_path:
        "Where `--mcp` forwards the server. An MCP endpoint is one server's, so the default is a path of this library's own and not the `/mcp` its documentation uses, which another server in the project would want too. Only with `--mcp`. Default: `#{@mcp_path}`."
    ]
  end

  @impl true
  def formats, do: [mcp_path: :route]

  # The path is where `--mcp` forwards, and nothing without it.
  @impl true
  def details, do: [mcp_path: :mcp]

  @impl true
  def option_notes do
    [
      components:
        "Left out, all of them. Every component is drawn, with its variants, at #{@site} — and each name's own page beside it."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task() <> " --components card,badge,timeline --no-daisy",
      schema: [
        components: :csv,
        no_daisy: :boolean,
        format: :boolean,
        mcp: :boolean,
        mcp_path: :string
      ],
      defaults: [no_daisy: false, format: true, mcp: false, mcp_path: @mcp_path]
    }
  end

  # The mark: the dependency, which is also what the ash cartridge's
  # `--components mishka_chelekom` leaves, so the two roads to the same
  # library answer alike.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, elem(@dep, 0))

  # The route is the piece a second run puts in when it is missing —
  # on a project the ash cartridge brought the library to as well.
  @impl true
  def adds, do: [:mcp]

  @doc """
  What the project carries: the components its `MishkaComponents` macro
  imports, in the catalog's order, whether daisyUI's plugin is gone
  from `app.css`, and whether `--mcp` is in whole: the router forwarding
  to the library's MCP server and the project's `mix mcp.json` beside
  it. A project with the route alone answers that it is not, so a
  second run is offered, and adds the task. `format` leaves no mark: a formatted file is a formatted
  file, whoever ran the formatter.
  """
  @impl true
  def state(igniter) do
    {macro, igniter} = macro_source(igniter)
    {css, igniter} = WorkbenchIgniter.Feature.file_content(igniter, css_path())

    {path, igniter} = mcp_path(igniter)

    {%{
       components: components_in(macro || ""),
       no_daisy: not daisyui?(css || ""),
       format: nil,
       mcp: path != nil and Igniter.exists?(igniter, @mcp_task),
       mcp_path: path
     }, igniter}
  end

  @doc "The components a `MishkaComponents` source imports, in the catalog's order."
  @spec components_in(String.t()) :: [String.t()]
  def components_in(source) do
    found =
      ~r/^\s*import [\w.]+\.Components\.(\w+)/m
      |> Regex.scan(source, capture: :all_but_first)
      |> Enum.map(fn [module] -> Macro.underscore(module) end)

    known = Enum.flat_map(@components, &elem(&1, 1))
    Enum.filter(known, &(&1 in found)) ++ Enum.sort(found -- known)
  end

  defp daisyui?(css), do: css =~ ~r/@plugin\s+"[^"]*daisyui/

  defp css_path, do: "assets/css/app.css"

  # The path the router forwards to the library's MCP server on, read
  # off the router: wherever the project has it, whoever wrote it.
  defp mcp_path(igniter) do
    router = Module.concat(Igniter.Libs.Phoenix.web_module(igniter), Router)

    case Igniter.Project.Module.find_module(igniter, router) do
      {:ok, {igniter, source, _zipper}} ->
        {mcp_path_in(Rewrite.Source.get(source, :content)), igniter}

      {:error, igniter} ->
        {nil, igniter}
    end
  end

  @doc """
  The path a router's source forwards to the library's MCP server on,
  or `nil`: the `forward` that names `MishkaChelekom.MCP.Server`, as
  the formatter leaves it, with parentheses or without.
  """
  @spec mcp_path_in(String.t()) :: String.t() | nil
  def mcp_path_in(router) do
    forward =
      ~r/forward\(?\s*"([^"]+)",\s*Anubis\.Server\.Transport\.StreamableHTTP\.Plug,\s*server:\s*MishkaChelekom\.MCP\.Server/

    case Regex.run(forward, router, capture: :all_but_first) do
      [path] -> path
      nil -> nil
    end
  end

  # The macro is the library's file, at `<web>/components/mishka_components.ex`.
  defp macro_source(igniter) do
    module =
      Module.concat([Igniter.Libs.Phoenix.web_module(igniter), Components, MishkaComponents])

    case Igniter.Project.Module.find_module(igniter, module) do
      {:ok, {igniter, source, _zipper}} -> {Rewrite.Source.get(source, :content), igniter}
      {:error, igniter} -> {nil, igniter}
    end
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts = igniter.args.options
    daisyui? = opts[:no_daisy] != true
    # One leading slash and none trailing, whatever was typed.
    mcp_path = "/" <> String.trim(opts[:mcp_path] || @mcp_path, "/")

    with {[], igniter} <- WorkbenchIgniter.Feature.missing_requirements(igniter, __MODULE__),
         {false, igniter} <- installed?(igniter),
         {:known, []} <- {:known, unknown(opts[:components] || [])},
         {:path, false} <- {:path, opts[:mcp] == true and mcp_path == "/"},
         {:alone, false} <- {:alone, opts[:mcp] != true and mcp_path != @mcp_path},
         [] <- if(daisyui?, do: [], else: daisy_bound(igniter)) do
      igniter
      |> Igniter.Project.Deps.add_dep(@dep, on_exists: :skip)
      |> without_daisyui(daisyui?)
      |> queue(opts[:components] || [], opts[:format] != false)
      |> mcp(opts[:mcp], mcp_path)
    else
      {true, igniter} ->
        igniter
        |> Igniter.add_notice("""
        mix.exs already carries mishka_chelekom: no component is \
        generated. One is added with the library's own task, \
        `mix mishka.ui.gen.component NAME`, and imported in \
        `<App>Web.Components.MishkaComponents`.\
        """)
        |> mcp(opts[:mcp], mcp_path)

      {[_ | _] = shortfalls, igniter} ->
        WorkbenchIgniter.Feature.refuse(igniter, __MODULE__, shortfalls)

      {:alone, true} ->
        Igniter.add_issue(
          igniter,
          "--mcp-path says where --mcp forwards the MCP server: it goes with --mcp, which was not given."
        )

      {:path, true} ->
        Igniter.add_issue(
          igniter,
          "--mcp-path: the MCP server needs a path of its own, and / is the whole site's."
        )

      {:known, unknown} ->
        Igniter.add_issue(igniter, """
        --components: Mishka Chelekom has no component named \
        #{Enum.join(unknown, ", ")}. Its components: \
        #{@components |> Enum.flat_map(&elem(&1, 1)) |> Enum.sort() |> Enum.join(", ")}.\
        """)

      [_ | _] = bound ->
        Igniter.add_issue(igniter, """
        --no-daisy would undress what this project carries in daisyUI's \
        classes: #{Enum.map_join(bound, "; ", fn {dep, why} -> "#{dep} (#{why})" end)}. \
        Insert without it: daisyUI stays.\
        """)
    end
  end

  defp unknown(names), do: Enum.uniq(names) -- Enum.flat_map(@components, &elem(&1, 1))

  defp daisy_bound(igniter),
    do: Enum.filter(@daisy_bound, fn {dep, _} -> Igniter.Project.Deps.has_dep?(igniter, dep) end)

  defp queue(igniter, components, format?) do
    args = Enum.uniq(components)

    igniter
    |> Igniter.add_task(@plumbing, if(format?, do: ["--format" | args], else: args))
    |> Igniter.add_notice("""
    Mishka Chelekom's components are generated by the library's own \
    task, once this patch set is applied and the dependency fetched:

        mix mishka.ui.gen.components #{said(args)}--import --helpers --global --yes

    It writes the components into lib/<app>_web/components/, the \
    `MishkaComponents` macro that imports them — in the web module's \
    `html_helpers`, in place of `import <App>Web.CoreComponents` —, \
    its stylesheet and `@theme` in assets, and its hooks in app.js, \
    which it reformats whole. Those files show up in that command's \
    output, not in this diff. core_components.ex stays where it is, \
    imported by nothing. It runs through `mix #{@plumbing}`, which \
    fails when the task reports issues#{formatted(format?)}.\
    """)
  end

  defp formatted(true), do: " and then runs `mix format` over the components"
  defp formatted(false), do: ""

  # The library's MCP server, forwarded in the project's router under
  # `dev_routes`: the route `mix mishka.mcp.setup` writes, word for
  # word, written here.
  #
  # WORKAROUND (mishka_chelekom 0.0.9, and 0.0.10-alpha.8): on the
  # router phx.new writes, `mishka.mcp.setup` puts its `forward` inside
  # `pipeline :browser`. Its `find_insertion_point/1` asks for the
  # module's `do` block from the top of the file
  # (`Igniter.Code.Common.move_to_do_block/1`) and is handed the first
  # one in it, which is the pipeline's, then appends after that block's
  # last plug. The route answers — `forward` defines its clause
  # wherever it is expanded — but it reads as a plug of the browser
  # pipeline, and a project that edits that pipeline moves or loses it
  # (probe, 2026-10-06: Phoenix 1.8.15, a router untouched since
  # phx.new).
  #
  # So the cartridge writes the same lines at the end of the router
  # module, where the task means to put them, and does not queue the
  # task. Remove this, and queue `mishka.mcp.setup --yes` watched
  # (`Mix.Tasks.Workbench.IgniterInstall.watched/2`), when the task
  # appends to the router module's own block.
  #
  # Issue: TODO — not filed yet (draft: ISSUE-mishka_chelekom-mcp-route.md
  # at the workbench's `_local/`).
  defp mcp(igniter, true, path) do
    case mcp_path(igniter) do
      {path, igniter} when is_binary(path) ->
        igniter
        |> Igniter.add_notice(
          "--mcp: the router already forwards to the library's MCP server, at #{path}."
        )
        |> mcp_json()

      {nil, igniter} ->
        app = Igniter.Project.Application.app_name(igniter)
        router = Module.concat(Igniter.Libs.Phoenix.web_module(igniter), Router)

        igniter
        |> Igniter.Project.Module.find_and_update_module!(router, fn zipper ->
          {:ok, Igniter.Code.Common.add_code(zipper, mcp_route(app, path))}
        end)
        |> mcp_json()
        |> Igniter.add_notice("""
        The library's MCP server is forwarded at `#{path}` in the router, \
        under `dev_routes`: the route `mix mishka.mcp.setup` writes, \
        at the end of the router. With the app up, an AI tool \
        connects to http://localhost:<the app's port>#{path}: `mix \
        mcp.json` writes that address into `.mcp.json`, off the port \
        docker-compose.yml publishes or, without one, the endpoint's \
        own. The file is the machine's, and .gitignore lists it. The \
        route names a development dependency: an \
        environment that turns `dev_routes` on without it compiles \
        with a warning.\
        """)
    end
  end

  defp mcp(igniter, _off, _path), do: igniter

  # The client's side, as a task of the project's own: the address has
  # a port, and the port is a fact of where the project runs — the one
  # its compose publishes, or the endpoint's on a host with `mix` — so
  # no installer can write it once. The task reads it when it is run,
  # off the project's own files, and what it writes is the machine's:
  # ignored, as `.env` is. Each piece goes in where it is missing.
  defp mcp_json(igniter) do
    igniter =
      if Igniter.exists?(igniter, @mcp_task),
        do: igniter,
        else: Igniter.create_new_file(igniter, @mcp_task, asset("mcp.json.ex"))

    WorkbenchIgniter.IgnoreFile.entry(
      igniter,
      "What `mix mcp.json` writes: this machine's address of the MCP server.",
      "/.mcp.json"
    )
  end

  @doc "The route `mix mishka.mcp.setup --path PATH` writes, for the project's `app`."
  @spec mcp_route(atom(), String.t()) :: String.t()
  def mcp_route(app, path) do
    """
    # MCP Server for AI tools (development only)
    if Application.compile_env(#{inspect(app)}, :dev_routes) do
      forward #{inspect(path)}, Anubis.Server.Transport.StreamableHTTP.Plug,
        server: MishkaChelekom.MCP.Server
    end
    """
  end

  defp said([]), do: ""

  defp said(names),
    do: "<#{Enum.join(names, ",")}, what they need and #{Enum.join(@core, ",")}> "

  # daisyUI out, for the project that takes Mishka's components as its
  # one set: the plugins and the dependency, then what they painted.
  defp without_daisyui(igniter, true), do: igniter

  defp without_daisyui(igniter, false) do
    {css, igniter} = WorkbenchIgniter.Feature.file_content(igniter, css_path())

    if daisyui?(css || "") do
      igniter
      |> Igniter.update_file(
        css_path(),
        &Rewrite.Source.update(&1, :content, fn css -> plain_css(css) end)
      )
      |> Igniter.Project.Deps.remove_dep(:daisyui)
      |> Igniter.add_task("deps.unlock", ["daisyui"])
      |> rewritten(pages(igniter))
    else
      Igniter.add_notice(
        igniter,
        "--no-daisy: app.css carries no daisyUI plugin, nothing to take out."
      )
    end
  end

  @doc """
  `app.css` without daisyUI: its `@plugin` blocks and the comments
  phx.new wrote over them gone, and the page's ground in their place.
  """
  @spec plain_css(String.t()) :: String.t()
  def plain_css(css) do
    css
    |> String.replace(~r{/\* daisyUI Tailwind Plugin\..*?\*/\n}s, "")
    |> String.replace(~r{/\* daisyUI theme plugin\..*?\*/\n}s, "")
    |> String.replace(~r/@plugin\s+"[^"]*daisyui[^"]*"\s*\{[^}]*\}\n*/, "")
    |> String.trim_trailing("\n")
    |> Kernel.<>("\n\n" <> @ground)
  end

  # The two pages phx.new writes in daisyUI's classes: the layouts
  # module and the home page beside the controller's view.
  defp pages(igniter) do
    web = Igniter.Libs.Phoenix.web_module(igniter)

    Enum.flat_map(
      [
        {Module.concat(web, Layouts), nil},
        {Module.concat(web, PageHTML), "page_html/home.html.heex"}
      ],
      fn {module, beside} ->
        case Igniter.Project.Module.find_module(igniter, module) do
          {:ok, {_igniter, source, _zipper}} ->
            path = Rewrite.Source.get(source, :path)
            [if(beside, do: Path.join(Path.dirname(path), beside), else: path)]

          {:error, _igniter} ->
            []
        end
      end
    )
  end

  defp rewritten(igniter, paths) do
    paths = Enum.filter(paths, &Igniter.exists?(igniter, &1))

    igniter =
      Enum.reduce(paths, igniter, fn path, igniter ->
        igniter
        |> Igniter.include_existing_file(path)
        |> Igniter.update_file(
          path,
          &Rewrite.Source.update(&1, :content, fn content -> plain_classes(content) end)
        )
      end)

    # The rewritten lines are longer than the classes they replace, and
    # the layouts' are HEEx inside Elixir: the project's own formatter
    # folds them, so a `mix format --check-formatted` still passes.
    igniter
    |> Igniter.add_task("format", paths)
    |> Igniter.add_notice("""
    daisyUI is out: its plugins are gone from #{css_path()}, where the \
    page's ground is now a rule of its own, and its dependency from \
    mix.exs. The daisyUI classes of #{Enum.join(paths, " and ")} are \
    rewritten as Tailwind utilities. core_components.ex still names \
    them, and nothing imports it.\
    """)
  end

  @doc """
  A template's daisyUI classes as the Tailwind utilities they stood
  for: the components phx.new's pages use, then every base colour,
  whatever its utility and its variants (`group-hover:bg-base-300`),
  as a light and a dark grey.
  """
  @spec plain_classes(String.t()) :: String.t()
  def plain_classes(content) do
    content =
      Enum.reduce(@classes, content, fn {daisy, plain}, content ->
        String.replace(content, ~r/(?<![\w:\/-])#{Regex.escape(daisy)}(?![\w\/-])/, plain)
      end)

    Regex.replace(
      ~r/(?<![\w:\/-])((?:[a-z-]+:)*)(bg|border|text|fill)-base-(100|200|300|content)(\/\d+)?(?![\w-])/,
      content,
      fn _, variants, utility, shade, alpha ->
        {light, dark} = Map.fetch!(@base, shade)
        "#{variants}#{utility}-#{light}#{alpha} dark:#{variants}#{utility}-#{dark}#{alpha}"
      end
    )
  end
end
