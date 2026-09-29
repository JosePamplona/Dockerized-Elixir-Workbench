defmodule WorkbenchIgniter.Features.Ash do
  @moduledoc """
  The Ash framework, installed into the project the way the installer
  on ash-hq.org does it for an *existing app*.

  Installed on demand with `mix workbench.install.ash` (`wb.sh add
  ash`), on the vanilla line.

  ## What it does, and what it leaves to Ash

  Every Ash package ships its own Igniter installer (`ash.install`,
  `ash_postgres.install`, `ash_authentication_phoenix.install`, …), and
  the command ash-hq.org generates for an existing application is one
  line: `mix igniter.install <packages> <flags>`. This cartridge turns
  the workbench's options — the same choices as the site's *Simple* and
  *Advanced Options* sections — into that command and **queues it**
  (`Igniter.add_task/3`) to run once its own patch set is applied.
  Igniter then adds the packages to `mix.exs`, fetches and compiles
  them, and runs each installer, exactly as typing the command would.
  Nothing about Ash is reimplemented here, and nothing Ash writes is
  second-guessed: `ash_postgres.install` leaves `config/dev.exs`,
  `test.exs` and `runtime.exs` alone when the repo is already configured
  there, which a `phx.new` project always is, so the workbench's
  `DATABASE_URL` wiring survives untouched.

  Why queued and not composed: `installs:` in a task's `Info` is only
  honoured along the `mix igniter.install` chain, and
  `Igniter.Util.Install` is documented as not composable. A queued task
  runs as its own `mix` process after the files are written, which is
  the one place a freshly added dependency's installer can be found.

  ## Options → packages

  | Option | Packages |
  | --- | --- |
  | `--data-layer postgres,sqlite,csv` (none given: no data layer; postgres on ecto with `postgres`, sqlite on ecto with `sqlite3`) | `ash_postgres`, `ash_sqlite`, `ash_csv` |
  | `--api json_api,graphql,typescript` | `ash_json_api`, `ash_graphql`, `ash_typescript` |
  | `--auth password,magic_link,…` | `ash_authentication`, `ash_authentication_phoenix`, with `--auth-strategy <list>` |
  | `--ai`, `--finance`, `--automation`, `--security`, `--dev-tools`, `--components` | ash-hq's *Advanced Options*, one option per section, each a closed list of the packages the site offers there |
  | `--example` | passed to `ash.install`, which generates the example resources |

  `ash` and `ash_phoenix` are always in: the workbench only makes
  Phoenix projects. Packages the project already declares in `mix.exs`
  are left out of the command; when none is left, nothing is queued and
  a notice says so.

  The one thing written by hand: with `--auth`, `TOKEN_SIGNING_SECRET`
  in `.env` (generated) and `.env.sample` (blank), the variable
  `ash_authentication`'s installer makes `config/runtime.exs` require
  in `:prod`, and that the workbench's prod compose reads from `.env`.
  """
  use WorkbenchIgniter.Feature

  @example "mix workbench.install.ash --data-layer postgres --api json_api --auth password,magic_link"

  # Ordered as the site lists them: the order the catalog shows.
  @data_layers [
    {"postgres", "ash_postgres"},
    {"sqlite", "ash_sqlite"},
    {"csv", "ash_csv"}
  ]

  # The Ecto database a data layer takes over, as the ecto cartridge
  # names it. Both installers turn the project's `<App>.Repo` into
  # their own (`use AshPostgres.Repo`, `use AshSqlite.Repo`), dropping
  # its adapter, and fail on a repo the other one already turned: so
  # each asks for Ecto on its own database, which also keeps postgres
  # and sqlite from going in together — a project has one.
  @data_layer_databases %{"postgres" => "postgres", "sqlite" => "sqlite3"}

  @apis [
    {"json_api", "ash_json_api"},
    {"graphql", "ash_graphql"},
    {"typescript", "ash_typescript"}
  ]

  # What the released `ash_authentication.add_strategy` accepts, and
  # `oauth2`, the site's OAuth2 option: it installs the packages with no
  # strategy — add_strategy has none for it —, and the provider is
  # configured by hand. `add_strategy` validates what `--auth` hands it.
  @auth_strategies ~w(password magic_link api_key oauth2)
  @by_hand ~w(oauth2)

  @oauth2_docs "https://ash-authentication.hexdocs.pm/dsl-ashauthentication-strategy-oauth2.html"

  # ash-hq.org's Advanced Options, by section, as the packages they
  # stand for: one option per section, named after it, closed on the
  # packages the site offers there — what it offers besides has no
  # installer yet (ash_hq_test says when that changes).
  # In the site's order, which is the command's.
  @advanced [
    ai: ~w(tidewave ash_ai usage_rules),
    finance: ~w(ash_money ash_double_entry),
    automation: ~w(ash_oban ash_state_machine ash_events),
    security: ~w(ash_archival ash_paper_trail ash_cloak),
    dev_tools: ~w(live_debugger ash_admin),
    components: ~w(mishka_chelekom cinder)
  ]

  # Each section's title on the site, the `data-category` its home page
  # groups the features by: what ash_hq_test finds them under, and
  # what each option's line names.
  @section_titles [
    ai: "AI",
    finance: "Finance",
    automation: "Automation",
    security: "Safety & Security",
    dev_tools: "Dev Tools",
    components: "UI Components"
  ]

  # What the site's command puts in beside a package, in the site's
  # order (its feature map, DESIGN.md [17]): `cloak` before `ash_cloak`,
  # `oban_web` after `ash_oban`, and `ash_money` before
  # `ash_double_entry`, whose option on the site requires Money.
  @companions %{
    "ash_cloak" => {["cloak"], []},
    "ash_oban" => {[], ["oban_web"]},
    "ash_double_entry" => {["ash_money"], []}
  }

  # What a choice builds on, in workbench cartridges. LiveView for the
  # packages whose installers write LiveViews (ash_authentication_phoenix
  # behind every strategy but api_key, ash_admin, oban_web with ash_oban,
  # live_debugger, cinder, Mishka's components); a mailer for the
  # strategies whose generated senders deliver with the project's
  # Mailer. The site assumes a default phx.new project and says nothing.
  @needs_live ~w(ash_admin live_debugger cinder mishka_chelekom ash_oban)

  # The data layer an advanced package cannot run without, which the
  # site does not say. ash_events takes Postgres advisory locks and
  # reads its repo off AshPostgres, and its `ash_postgres` dependency
  # is not optional. Loaded, that dependency makes ash_authentication's
  # installer pick the Postgres repo, which it creates when none is an
  # `AshPostgres.Repo` — over a SQLite repo, "repo.ex: File already
  # exists". So the package brings the data layer, in the data layers'
  # place of the command (before authentication, so the repo is turned
  # first), and builds on that layer's Ecto database.
  @data_layer_of %{"ash_events" => "postgres"}
  @sends_email ~w(password magic_link)

  @doc "An advanced package with what the site's command adds beside it, in order."
  def expand(pkg) do
    {before, after_} = Map.get(@companions, pkg, {[], []})
    before ++ [pkg] ++ after_
  end

  @doc "ash-hq.org's Advanced Options, by section, as package names."
  def advanced, do: @advanced

  @doc "Each advanced section's title on the site, by the option that stands for it."
  def section_titles, do: @section_titles

  # What each option says of itself on ash-hq.org: the first sentence
  # of the tooltip its installer widget shows on hover — the first
  # paragraph longer than a bare name (`Site.line/1`), so the check can
  # tell when the site changes it. The widget's text is not in the
  # page's HTML but in its app bundle (assets/app-*.js, the feature map
  # with `tooltip`, `adds`, `requires`, `args`; read 2026-08-29) —
  # quoted verbatim, keyed by the package or strategy the site's
  # feature stands for. What the site does not describe has no line.
  @tooltips %{
    "ash_postgres" =>
      "The swiss army knife of databases. Versatile, powerful, and battle-tested.",
    "ash_sqlite" =>
      "Small, fast, and reliable. Perfect for lightweight apps or getting started quickly.",
    "ash_csv" => "Back resources with CSV files.",
    "ash_json_api" => "Easily create a spec-compliant JSON:API, directly from your resources.",
    "ash_graphql" => "Create a powerful and flexible GraphQL API directly from your resources.",
    "ash_typescript" => "Automatic TypeScript type generation for Ash resources and actions.",
    "password" => "Allow users to log in with email & password.",
    "magic_link" => "Send users a link in their email to sign in and register.",
    "api_key" => "Generate and authenticate with API keys.",
    "oauth2" => "Sign in using an external service.",
    "tidewave" =>
      "Speed up development with AI assistants that understand your web application, how it runs, and what it delivers.",
    "ash_ai" => "First class support for a wide array of LLM tools.",
    "usage_rules" => "Supercharge your AGENTS.md!",
    "ash_money" => "A data type for representing money $$$$.",
    "ash_double_entry" => "Moving money around? Need to track financial data?",
    "ash_oban" =>
      "Oban is a background job system backed by your own SQL database packed with enterprise grade features, real-time monitoring with Oban Web, and complex workflow management with Oban Pro.",
    "ash_state_machine" =>
      "Model complex workflows backed by your resource's persistence and actions.",
    "ash_events" =>
      "Tracks and persists events when actions are performed on your resources, providing a complete audit trail and event replay.",
    "ash_archival" => "A lightweight extension to ensure that data is only ever soft deleted.",
    "ash_paper_trail" =>
      "Automatically track all changes to your resources. Track who did what and when.",
    "ash_cloak" => "Easily encrypt and decrypt your attributes.",
    "live_debugger" => "A tool for debugging LiveView applications in development.",
    "ash_admin" => "A zero-config-necessary super admin UI.",
    "mishka_chelekom" =>
      "Mishka Chelekom is a library offering various templates for components in Phoenix and Phoenix LiveView.",
    "cinder" => "A powerful data collection component for Ash resources in Phoenix LiveView."
  }

  @doc false
  def tooltips, do: @tooltips
  @doc false
  def data_layers, do: @data_layers
  @doc false
  def apis, do: @apis
  @doc false
  def auth_strategies, do: @auth_strategies

  defp tagline(pkg), do: if(line = @tooltips[pkg], do: "#{pkg} · #{line}", else: pkg)

  defp data_layer_doc({name, pkg}) do
    case @data_layer_databases[name] do
      nil -> {name, tagline(pkg)}
      database -> {name, tagline(pkg), [{"ecto", database: database}]}
    end
  end

  defp strategy_doc(name) do
    requires =
      if(name == "api_key", do: [], else: [{"html", live: true}]) ++
        if(name in @sends_email, do: ["mailer"], else: [])

    {name, strategy_gloss(name), requires}
  end

  defp strategy_gloss("oauth2"),
    do:
      "#{@tooltips["oauth2"]} Installs the packages with no strategy: the provider is configured by hand, #{@oauth2_docs}"

  defp strategy_gloss(name), do: @tooltips[name]

  defp with_doc(pkg) do
    requires =
      if(pkg in @needs_live, do: [{"html", live: true}], else: []) ++
        case @data_layer_of[pkg] do
          nil -> []
          layer -> [{"ecto", database: @data_layer_databases[layer]}]
        end

    {pkg, advanced_gloss(pkg), requires}
  end

  # The site's line, and the packages the site's command puts in beside
  # it, which the value brings too.
  defp advanced_gloss(pkg) do
    line =
      case expand(pkg) -- [pkg] do
        [] -> @tooltips[pkg]
        also -> "#{@tooltips[pkg]} Brings #{Enum.map_join(also, " and ", &"`#{&1}`")} too."
      end

    case @data_layer_of[pkg] do
      nil -> line
      layer -> "#{line} Runs on #{layer} only: brings the `#{layer}` data layer too."
    end
  end

  # The values the options take, closed: each with the package it
  # stands for, the strategies with what they build on.
  @impl true
  def choices do
    [
      data_layer: Enum.map(@data_layers, &data_layer_doc/1),
      api: Enum.map(@apis, fn {name, pkg} -> {name, tagline(pkg)} end),
      auth: Enum.map(@auth_strategies, &strategy_doc/1)
    ] ++ for({section, pkgs} <- @advanced, do: {section, Enum.map(pkgs, &with_doc/1)})
  end

  @impl true
  def task, do: "workbench.install.ash"

  # The routes the packages' own installers write in the router, each
  # behind the option that brings its package: `/oban` is oban_web's,
  # which comes with ash_oban; `/sign-in` is ash_authentication_phoenix's
  # default, there with every strategy but api_key (`auth_packages/1`).
  @impl true
  def console do
    [
      doors: [
        {"admin", "/admin", when: {:option, :dev_tools, "ash_admin"}},
        {"oban", "/oban", when: {:option, :automation, "ash_oban"}},
        {"sign in", "/sign-in", when: {:option, :auth, @auth_strategies -- ["api_key"]}},
        {"swagger", "/api/json/swaggerui", when: {:option, :api, "json_api"}},
        {"openapi", "/api/json/open_api", when: {:option, :api, "json_api"}},
        {"graphiql", "/gql/playground", when: {:option, :api, "graphql"}},
        {"typescript", "/ash-typescript", when: {:option, :api, "typescript"}}
      ]
    ]
  end

  @impl true
  def afterwards,
    do:
      "With a database data layer, the app container's `mix setup`, which Ash turns into `ash.setup`, creates the database and runs Ash's migrations at the next ./wb.sh up."

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      data_layer:
        "Comma-separated, as the site's checkboxes — a resource picks its own: `postgres`, `sqlite`, `csv` (`ash_postgres`, `ash_sqlite`, `ash_csv`). `postgres` builds on ecto with `postgres` and `sqlite` on ecto with `sqlite3`, so the two never go in together. Left out, Ash goes in with no data layer.",
      api:
        "Comma-separated: `json_api`, `graphql`, `typescript` (`ash_json_api`, `ash_graphql`, `ash_typescript`).",
      auth:
        "Comma-separated authentication strategies: `ash_authentication` and `ash_authentication_phoenix`, handed `--auth-strategy`: `password`, `magic_link`, `api_key`. `oauth2` installs both packages with no strategy, and the provider is configured by hand (https://ash-authentication.hexdocs.pm/dsl-ashauthentication-strategy-oauth2.html).",
      ai: said(:ai, ""),
      finance: said(:finance, " (`ash_double_entry` brings `ash_money` first)"),
      automation:
        said(
          :automation,
          " (`ash_oban` brings `oban_web`; `ash_events` runs on Postgres only and brings the `postgres` data layer)"
        ),
      security: said(:security, " (`ash_cloak` brings `cloak` first)"),
      dev_tools: said(:dev_tools, ""),
      components: said(:components, ""),
      example: "Passed to `ash.install`: generates the example resources of the Ash guide."
    ]
  end

  # What an option says that none of its values can, under them in a form.
  @impl true
  def option_notes, do: [data_layer: "Left out, Ash goes in with no data layer."]

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [
        data_layer: :csv,
        api: :csv,
        auth: :csv,
        ai: :csv,
        finance: :csv,
        automation: :csv,
        security: :csv,
        dev_tools: :csv,
        components: :csv,
        example: :boolean
      ]
    }
  end

  # The mark: the `ash` dependency, which every run puts in (it is the
  # first package of the command, and the one every other one needs).
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, :ash)

  # Every option is a package, and a run queues only the packages
  # mix.exs lacks: running again with more options grows the install.
  @impl true
  def adds, do: :all

  # What the project carries, read off mix.exs: the data layer whose
  # package is in (none when Ash is in without one), the APIs and the
  # advanced packages present, by section. The authentication strategies live in
  # the resource, not in the deps: they are read off the user resource
  # (`strategies_in/1`).
  @impl true
  def state(igniter) do
    has = &Igniter.Project.Deps.has_dep?(igniter, String.to_atom(&1))
    ash? = has.("ash")

    data_layer = if ash?, do: for({name, pkg} <- @data_layers, has.(pkg), do: name)

    {auth, igniter} =
      if has.("ash_authentication"), do: strategies(igniter), else: {nil, igniter}

    state =
      %{
        data_layer: data_layer,
        api: for({name, pkg} <- @apis, has.(pkg), do: name),
        auth: auth
      }
      |> Map.merge(
        Map.new(@advanced, fn {section, pkgs} -> {section, Enum.filter(pkgs, has)} end)
      )
      |> Enum.reject(fn {_, v} -> v in [nil, false, []] end)
      |> Map.new()

    {state, igniter}
  end

  # The resource ash_authentication.install writes, at its default
  # name; nil when it is not there (the installer's `--user` named it
  # otherwise), which says the strategies could not be read.
  defp strategies(igniter) do
    user = Igniter.Project.Module.module_name(igniter, "Accounts.User")

    case Igniter.Project.Module.find_module(igniter, user) do
      {:ok, {igniter, source, _zipper}} ->
        {strategies_in(Rewrite.Source.get(source, :content)), igniter}

      {:error, igniter} ->
        {nil, igniter}
    end
  end

  @doc """
  The strategies a resource's `strategies do` block declares, by the
  name of their call, in order: `password`, `magic_link`, `api_key`,
  `github`… — `remember_me` too, which the password strategy brings.
  """
  @spec strategies_in(String.t()) :: [String.t()]
  def strategies_in(content) do
    case Regex.run(~r/^( *)strategies do\n(.*?)^\1end$/ms, content) do
      [_, indent, block] ->
        ~r/^#{indent}  (\w+)/m
        |> Regex.scan(block)
        |> Enum.map(fn [_, name] -> name end)
        |> Enum.uniq()
        |> List.delete("end")

      nil ->
        []
    end
  end

  # The packages this box's commit carries, and where each came from:
  # the ones the queued command named, and the ones the installers of
  # those packages added on their own (the SAT solver Ash's policy
  # authorizer asks for when a resource first takes it, ash_authentication's
  # bcrypt, ash_oban's oban…). The note names the command and not its
  # argv: the row says the package, and the insert's line the options.
  @impl true
  def origins(opts, %{added: added}) do
    case packages(opts) do
      {:ok, packages} ->
        named = for spec <- packages, name = to_string(dep_name(spec)), name in added, do: name

        [
          {"The cartridge does not install this package itself: its options name it in the " <>
             "`mix igniter.install` it runs, the command ash-hq.org gives for an existing app, " <>
             "and that command added it at the version hex resolved then.", named},
          {"Neither the cartridge nor its command names this package: it was added at the request " <>
             "of the installer of a package that command named, at the version that installer asks for.",
           added -- named}
        ]

      {:error, _message} ->
        []
    end
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts = igniter.args.options

    case WorkbenchIgniter.Feature.missing_option_requirements(igniter, __MODULE__, opts) do
      {[], igniter} ->
        with {:ok, packages} <- packages(opts),
             :ok <- typescript_finds_the_web(igniter, opts[:api] || []) do
          igniter
          |> queue(packages, opts)
          |> token_signing_secret(opts[:auth] || [])
          |> npm_in_the_release(opts[:api] || [])
          |> rpc_endpoints_ahead(opts[:api] || [])
        else
          {:error, message} -> Igniter.add_issue(igniter, message)
        end

      {missing, igniter} ->
        WorkbenchIgniter.Feature.refuse_values(igniter, missing)
    end
  end

  # ash_typescript's installer (0.18) writes and edits the web layer at
  # `lib/` + the underscored web module, where phx.new put it at
  # `lib/<app>_web`. The two part when the app has a digit after an
  # underscore: `:lorem_ipsum_2` is `LoremIpsum2Web`, which underscores
  # back to `lorem_ipsum2_web`. There the installer stops at the first
  # file it needs, `root.html.heex`, with nothing of Ash written, so the
  # option is refused before anything is fetched.
  defp typescript_finds_the_web(igniter, apis) do
    app = Igniter.Project.Application.app_name(igniter)
    web = Igniter.Libs.Phoenix.web_module(igniter)
    where = web |> inspect() |> Macro.underscore()

    if "typescript" in apis and where != "#{app}_web" do
      {:error,
       "--api typescript cannot go into this project: ash_typescript's installer looks for " <>
         "its web files under lib/#{where}/ (#{inspect(web)} underscored), and phx.new put " <>
         "them under lib/#{app}_web/ (the app, :#{app}). A digit after an underscore in the " <>
         "app's name is where the two part: the installer would stop at the first file it " <>
         "needs, with nothing of Ash written."}
    else
      :ok
    end
  end

  @doc """
  The packages the options ask for, in the order they go to
  `mix igniter.install`: `ash`, the data layer, `ash_phoenix`, the APIs,
  authentication, then the advanced sections in the site's order.
  Unknown data layers, APIs and advanced packages are an error; `--auth`
  is validated by ash_authentication's own installer.
  """
  @spec packages(keyword()) :: {:ok, [String.t()]} | {:error, String.t()}
  def packages(opts) do
    with {:ok, data_layers} <- data_layers(List.wrap(opts[:data_layer] || []) ++ brought(opts)),
         {:ok, apis} <- apis(opts[:api] || []),
         {:ok, advanced} <- advanced(opts) do
      packages =
        ["ash"] ++
          data_layers ++
          ["ash_phoenix"] ++
          apis ++
          auth_packages(opts[:auth] || []) ++
          Enum.flat_map(advanced, &expand/1)

      {:ok, Enum.uniq(packages)}
    end
  end

  @doc """
  The flags that go with the packages: `--auth-strategy` for the
  authentication installer, `--example` for Ash's, and `--yes` when the
  task itself runs with it. `mix igniter.install` hands its argv to
  every installer it runs; each one takes the switches it declares.
  """
  @spec flags(keyword()) :: [String.t()]
  def flags(opts) do
    auth = (opts[:auth] || []) -- @by_hand

    List.flatten([
      if(auth != [], do: ["--auth-strategy", Enum.join(auth, ",")], else: []),
      # The site's TypeScript option passes this to ash_typescript's installer.
      if("typescript" in (opts[:api] || []), do: ["--framework", "react"], else: []),
      if(opts[:example], do: ["--example"], else: []),
      if(opts[:yes], do: ["--yes"], else: [])
    ])
  end

  defp queue(igniter, packages, opts) do
    {present, missing} =
      Enum.split_with(packages, &Igniter.Project.Deps.has_dep?(igniter, dep_name(&1)))

    case missing do
      [] ->
        Igniter.add_notice(igniter, """
        mix.exs already carries every Ash package asked for \
        (#{Enum.join(present, ", ")}): nothing to install. To add \
        another one, run `mix workbench.install.ash --dev-tools ash_admin` \
        or `mix igniter.install <package>` directly.\
        """)

      missing ->
        args = missing ++ flags(opts)

        igniter
        # Through the workbench's task, which fails where Igniter
        # reports issues and exits with zero (its moduledoc).
        |> Igniter.add_task("workbench.igniter_install", args)
        |> Igniter.add_notice("""
        Ash is installed by Igniter itself, once this patch set is \
        applied — the same command ash-hq.org generates for an existing \
        app, queued below:

            mix igniter.install #{Enum.join(args, " ")}

        It adds the packages to mix.exs, fetches and compiles them and \
        runs each package's own installer, so the files Ash writes \
        (domain, resources, config, migrations) show up in that \
        command's output, not in this diff. It runs through \
        `mix workbench.igniter_install`, which fails when an installer \
        reports issues, where Igniter alone exits with zero.\
        #{skipped(present)}
        """)
    end
  end

  # ash_authentication signs its tokens with `:token_signing_secret`:
  # its installer writes a literal one in config/dev.exs and makes
  # config/runtime.exs raise in :prod without TOKEN_SIGNING_SECRET —
  # which the workbench's prod compose reads from .env. The entry is
  # written now, before the queued command, so `up -e prod` never
  # meets the raise; a no-op when the variable is already declared.
  defp token_signing_secret(igniter, []), do: igniter

  defp token_signing_secret(igniter, _strategies) do
    WorkbenchIgniter.EnvFile.entry(
      igniter,
      "Signs AshAuthentication's tokens (:prod; dev has its own in config/dev.exs). Generate with: mix phx.gen.secret",
      ~s|TOKEN_SIGNING_SECRET="#{WorkbenchIgniter.secret_key_base()}"|,
      ~s|TOKEN_SIGNING_SECRET=""|
    )
  end

  # ash_typescript's installer hooks `npm install` into `assets.setup`,
  # a step Phoenix's production Dockerfile runs on a builder with no
  # node, before `COPY assets`: the release build stopped there with
  # :enoent (_004, 2026-09-25). The dev image carries node and npm;
  # the release's Dockerfile is Phoenix's, and takes them here.
  defp npm_in_the_release(igniter, apis) do
    if "typescript" in apis,
      do: WorkbenchIgniter.Dockerfile.npm(igniter),
      else: igniter
  end

  # WORKAROUND for ash-project/ash_typescript#95 (open, 2026-09-25;
  # still in 0.18.3): ash_typescript's installer writes the RPC routes
  # off `Application.get_env(:ash_typescript, :run_endpoint)` and
  # `:validate_endpoint`, which it writes to config.exs in the same
  # pass — unloaded, so nil, so `post ""` twice: the second clause
  # never matches and the generated client's POSTs to /rpc/run and
  # /rpc/validate have no route. The queued command runs as its own
  # mix process, which loads config.exs at boot: written here, ahead
  # of it, with the installer's own defaults and its own
  # `configure_new`, the installer finds them and writes the routes it
  # meant to, and leaves the config as it is. Nothing of the tool is
  # replaced, only its config brought forward. Remove when the issue
  # is closed and the fixed version is what hex resolves.
  defp rpc_endpoints_ahead(igniter, apis) do
    if "typescript" in apis do
      igniter
      |> Igniter.Project.Config.configure_new(
        "config.exs",
        :ash_typescript,
        [:run_endpoint],
        "/rpc/run"
      )
      |> Igniter.Project.Config.configure_new(
        "config.exs",
        :ash_typescript,
        [:validate_endpoint],
        "/rpc/validate"
      )
    else
      igniter
    end
  end

  defp skipped([]), do: ""

  defp skipped(present),
    do: "\n\nAlready in mix.exs, left out of the command: #{Enum.join(present, ", ")}."

  # The data layers are checkboxes on the site — a resource picks its
  # own — so several go in, in the site's order, and none checked is
  # Ash with no data layer. Postgres and SQLite never meet: each builds
  # on Ecto with its own database (`@data_layer_databases`).
  defp data_layers(names) do
    case Enum.reject(names, &List.keymember?(@data_layers, &1, 0)) do
      [] ->
        {:ok, for({name, pkg} <- @data_layers, name in names, do: pkg)}

      unknown ->
        {:error,
         "Unknown --data-layer #{Enum.join(unknown, ", ")}. One of: #{Enum.map_join(@data_layers, ", ", &elem(&1, 0))}."}
    end
  end

  defp apis(names) do
    case Enum.reject(names, &List.keymember?(@apis, &1, 0)) do
      [] ->
        {:ok, Enum.map(names, &elem(List.keyfind(@apis, &1, 0), 1))}

      unknown ->
        {:error,
         "Unknown --api #{Enum.join(unknown, ", ")}. One of: #{Enum.map_join(@apis, ", ", &elem(&1, 0))}."}
    end
  end

  # The advanced packages asked for, section by section in the site's
  # order; a package a section does not offer is an error that names
  # the ones it does.
  defp advanced(opts) do
    Enum.reduce_while(@advanced, {:ok, []}, fn {section, offered}, {:ok, acc} ->
      asked = opts[section] || []

      case asked -- offered do
        [] ->
          {:cont, {:ok, acc ++ Enum.filter(offered, &(&1 in asked))}}

        unknown ->
          {:halt,
           {:error,
            "Unknown --#{switch(section)} #{Enum.join(unknown, ", ")}. One of: #{Enum.join(offered, ", ")}."}}
      end
    end)
  end

  defp switch(section), do: section |> to_string() |> String.replace("_", "-")

  # A section's option line: the site's title and its packages.
  # The data layers the advanced packages asked for bring (`@data_layer_of`).
  defp brought(opts) do
    for {section, _} <- @advanced,
        pkg <- opts[section] || [],
        layer = @data_layer_of[pkg],
        do: layer
  end

  defp said(section, note),
    do:
      "Comma-separated, the site's *#{@section_titles[section]}* section: " <>
        Enum.map_join(@advanced[section], ", ", &"`#{&1}`") <> note <> "."

  # ash_authentication first, then its Phoenix half: the Phoenix
  # installer looks for the Accounts domain and, not finding it, *asks*
  # whether to run ash_authentication's — a prompt `--yes` does not
  # answer, which hangs a run without a terminal. Listed before it,
  # ash_authentication.install runs first with --auth-strategy and the
  # question never comes up.
  # The site's API-key option adds `ash_authentication` alone: API keys
  # have no pages. Any other strategy brings the Phoenix half.
  @doc "The authentication packages the site's command adds for these strategies."
  def auth_packages([]), do: []

  def auth_packages(strategies) do
    if Enum.all?(strategies, &(&1 == "api_key")),
      do: ["ash_authentication"],
      else: ["ash_authentication", "ash_authentication_phoenix"]
  end

  # `org/package@version` → :package, the name mix.exs declares.
  defp dep_name(spec) do
    spec
    |> String.split("@", parts: 2)
    |> hd()
    |> String.split("/")
    |> List.last()
    |> String.to_atom()
  end
end
