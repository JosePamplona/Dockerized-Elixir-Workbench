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
  | `--data-layer postgres` (default) / `sqlite` / `csv` / `none` | `ash_postgres` / `ash_sqlite` / `ash_csv` / — |
  | `--api json_api,graphql,typescript` | `ash_json_api`, `ash_graphql`, `ash_typescript` |
  | `--auth password,magic_link,…` | `ash_authentication`, `ash_authentication_phoenix`, with `--auth-strategy <list>` |
  | `--with pkg,pkg` | any further package, as ash-hq's *Advanced Options* |
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
    {"csv", "ash_csv"},
    {"none", nil}
  ]

  @apis [
    {"json_api", "ash_json_api"},
    {"graphql", "ash_graphql"},
    {"typescript", "ash_typescript"}
  ]

  # What `ash_authentication.add_strategy` accepts today, for the
  # catalog: `--auth` hands the list down unchecked, so a new strategy
  # works before it is listed here.
  @auth_strategies ~w(password magic_link otp api_key totp recovery_code
                      github google apple auth0 microsoft okta slack oidc
                      oauth2 dynamic_oidc webauthn)

  # ash-hq.org's Advanced Options, by section, as the packages they
  # stand for. For the docs and the catalog only: `--with` takes any
  # package, these are the ones the site offers.
  @advanced [
    ai: ~w(tidewave ash_ai usage_rules),
    finance: ~w(ash_money ash_double_entry),
    automation: ~w(ash_oban ash_state_machine ash_events),
    safety_and_security: ~w(ash_archival ash_paper_trail ash_cloak),
    dev_tools: ~w(live_debugger ash_admin),
    ui_components: ~w(mishka_chelekom cinder)
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
  @sends_email ~w(password magic_link otp)

  @doc "A --with package with what the site's command adds beside it, in order."
  def expand(pkg) do
    {before, after_} = Map.get(@companions, pkg, {[], []})
    before ++ [pkg] ++ after_
  end

  @doc "ash-hq.org's Advanced Options, by section, as package names."
  def advanced, do: @advanced

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

  # The site's OAuth2 option names these as its premade configurations.
  @oauth_providers ~w(github google apple auth0 oidc slack)

  @doc false
  def tooltips, do: @tooltips
  @doc false
  def data_layers, do: @data_layers
  @doc false
  def apis, do: @apis

  defp tagline(nil), do: "no data layer — alone"
  defp tagline(pkg), do: if(line = @tooltips[pkg], do: "#{pkg} · #{line}", else: pkg)

  defp strategy_doc(name) do
    doc =
      cond do
        doc = @tooltips[name] -> doc
        name in @oauth_providers -> "one of the site's premade OAuth2 configurations"
        true -> nil
      end

    requires =
      if(name == "api_key", do: [], else: [{"html", live: true}]) ++
        if(name in @sends_email, do: ["mailer"], else: [])

    {name, doc, requires}
  end

  defp with_doc(pkg),
    do: {pkg, @tooltips[pkg], if(pkg in @needs_live, do: [{"html", live: true}], else: [])}

  # The values the options take: the two the installer checks, closed,
  # each with the package it stands for; the two it hands down, open,
  # with what the site offers.
  @impl true
  def choices do
    [
      data_layer: Enum.map(@data_layers, fn {name, pkg} -> {name, tagline(pkg)} end),
      api: Enum.map(@apis, fn {name, pkg} -> {name, tagline(pkg)} end),
      auth: {:open, Enum.map(@auth_strategies, &strategy_doc/1)},
      with: {:open, for({group, pkgs} <- @advanced, do: {group, Enum.map(pkgs, &with_doc/1)})}
    ]
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
        {"admin", "/admin", when: {:option, :with, "ash_admin"}},
        {"oban", "/oban", when: {:option, :with, "ash_oban"}},
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
      "With a database data layer on a project born without Ecto, the database goes into the workspace's compose in the insert's own commit; ./wb.sh setup creates it."

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      data_layer:
        "Comma-separated, as the site's checkboxes — a resource picks its own: `postgres` (default), `sqlite`, `csv` (`ash_postgres`, `ash_sqlite`, `ash_csv`); `none`, alone, for no data layer.",
      api:
        "Comma-separated: `json_api`, `graphql`, `typescript` (`ash_json_api`, `ash_graphql`, `ash_typescript`).",
      auth:
        "Comma-separated authentication strategies: `ash_authentication` and `ash_authentication_phoenix`, handed `--auth-strategy`. One of `password`, `magic_link`, `api_key`, `otp`, `totp`, `github`, `google`, `auth0`, `oauth2`, `oidc`, … (the list is the installer's).",
      with:
        "Comma-separated further packages, as the site's *Advanced Options*: #{advanced() |> Keyword.values() |> List.flatten() |> Enum.join(", ")}. Any package with an Igniter installer works.",
      example: "Passed to `ash.install`: generates the example resources of the Ash guide."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [
        data_layer: :csv,
        api: :csv,
        auth: :csv,
        with: :csv,
        example: :boolean
      ],
      defaults: [data_layer: "postgres"]
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
  # package is in (`none` when Ash is in without one), the APIs and the
  # advanced packages present. The authentication strategies live in
  # the resource, not in the deps: they are read off the user resource
  # (`strategies_in/1`).
  @impl true
  def state(igniter) do
    has = &Igniter.Project.Deps.has_dep?(igniter, String.to_atom(&1))
    ash? = has.("ash")

    data_layer = if ash?, do: layers_in(has)

    {auth, igniter} =
      if has.("ash_authentication"), do: strategies(igniter), else: {nil, igniter}

    state =
      %{
        data_layer: data_layer,
        api: for({name, pkg} <- @apis, has.(pkg), do: name),
        auth: auth,
        with: for({_group, pkgs} <- @advanced, pkg <- pkgs, has.(pkg), do: pkg)
      }
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

  # The layers whose package is in; Ash in without any of them is "none".
  defp layers_in(has) do
    case for({name, pkg} <- @data_layers, pkg, has.(pkg), do: name) do
      [] -> ["none"]
      layers -> layers
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
        case packages(opts) do
          {:ok, packages} ->
            igniter
            |> queue(packages, opts)
            |> token_signing_secret(opts[:auth] || [])

          {:error, message} ->
            Igniter.add_issue(igniter, message)
        end

      {missing, igniter} ->
        WorkbenchIgniter.Feature.refuse_values(igniter, missing)
    end
  end

  @doc """
  The packages the options ask for, in the order they go to
  `mix igniter.install`: `ash`, the data layer, `ash_phoenix`, the APIs,
  authentication, then `--with`. Unknown data layers and APIs are an
  error; `--auth` and `--with` are validated by Ash's own installers.
  """
  @spec packages(keyword()) :: {:ok, [String.t()]} | {:error, String.t()}
  def packages(opts) do
    # A :csv switch not given parses as [], not nil: the default is ours.
    chosen =
      if(opts[:data_layer] in [nil, []], do: ["postgres"], else: List.wrap(opts[:data_layer]))

    with {:ok, data_layers} <- data_layers(chosen),
         {:ok, apis} <- apis(opts[:api] || []) do
      packages =
        ["ash"] ++
          data_layers ++
          ["ash_phoenix"] ++
          apis ++
          auth_packages(opts[:auth] || []) ++
          Enum.flat_map(opts[:with] || [], &expand/1)

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
    auth = opts[:auth] || []

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
        another one, run `mix workbench.install.ash --with <package>` \
        or `mix igniter.install <package>` directly.\
        """)

      missing ->
        args = missing ++ flags(opts)

        igniter
        |> Igniter.add_task("igniter.install", args)
        |> Igniter.add_notice("""
        Ash is installed by Igniter itself, once this patch set is \
        applied — the same command ash-hq.org generates for an existing \
        app, queued below:

            mix igniter.install #{Enum.join(args, " ")}

        It adds the packages to mix.exs, fetches and compiles them and \
        runs each package's own installer, so the files Ash writes \
        (domain, resources, config, migrations) show up in that \
        command's output, not in this diff.\
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

  defp skipped([]), do: ""

  defp skipped(present),
    do: "\n\nAlready in mix.exs, left out of the command: #{Enum.join(present, ", ")}."

  # The data layers are independent on the site — each a checkbox, a
  # resource picks its own — so several go in, in the site's order;
  # `none` stands alone.
  defp data_layers(names) do
    unknown = Enum.reject(names, &List.keymember?(@data_layers, &1, 0))

    cond do
      unknown != [] ->
        {:error,
         "Unknown --data-layer #{Enum.join(unknown, ", ")}. One of: #{Enum.map_join(@data_layers, ", ", &elem(&1, 0))}."}

      "none" in names and length(names) > 1 ->
        {:error, "--data-layer none stands alone: it means no data layer."}

      true ->
        {:ok, for({name, pkg} <- @data_layers, pkg, name in names, do: pkg)}
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
