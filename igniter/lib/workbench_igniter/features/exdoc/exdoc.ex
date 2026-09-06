defmodule WorkbenchIgniter.Features.Exdoc do
  @moduledoc """
  ExDoc documentation site served by the app, with per-feature extra pages
  (coverage, auth token, database diagram).

  Full feature cartridge: manifest, install logic, EEx templates and the
  text assets it plants (theme JS, extra pages) live in this directory;
  the `Mix.Tasks.Workbench.Install.Exdoc` shell in `task.ex` delegates
  here. The only asset kept out of the module is the binary logo, planted
  from `priv/features/exdoc/images/` via `plant_binary_asset/3`.
  """
  use WorkbenchIgniter.Feature

  embed_templates()
  embed_assets()

  @example "mix workbench.install.exdoc --project-name \"Lorem Ipsum\" --coveralls"

  @impl true
  def task, do: "workbench.install.exdoc"

  @impl true
  def console, do: [doors: [{"docs", "/dev/docs"}]]

  @impl true
  def afterwards,
    do: "./wb.sh mix docs generates the site; --build does it on the insert."

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      project_name: "Display name (default: capitalized app name).",
      repo_url: "Repository URL for `source_url`/`authors`.",
      version:
        "The version the pages are stamped with (titles, the 404 page) until `mix version` sets the real one. Default: `0.0.0`.",
      coveralls:
        "The coveralls feature is composed too: the coverage report is served beside the docs (`/cover`), with its page and the controller action.",
      auth0:
        "The auth0 feature is composed too: the \"Get access tokens\" page and its scripts, to try the API from the docs.",
      build:
        "Run `mix docs` once the insert is applied, so the site has pages on first boot. Off by default: it needs the dependencies fetched and compiled."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [
        project_name: :string,
        version: :string,
        repo_url: :string,
        coveralls: :boolean,
        auth0: :boolean,
        build: :boolean
      ],
      defaults: [
        version: "0.0.0",
        repo_url: "https://github.com/user/repo",
        coveralls: false,
        auth0: false,
        build: false
      ]
    }
  end

  # The mark: the controller that serves the docs.
  @impl true
  def installed?(igniter),
    do: Igniter.Project.Module.module_exists(igniter, controller_module(igniter))

  defp controller_module(igniter),
    do: Module.concat(Igniter.Libs.Phoenix.web_module(igniter), ExDocController)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    # Whether the project has Ecto — the database page and diagram — is
    # read off the project, not asked.
    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)

    opts =
      igniter.args.options
      |> Keyword.put(:ecto, facts.ecto)
      |> Keyword.put_new_lazy(:project_name, fn ->
        Mix.Project.config()[:app] |> to_string() |> String.capitalize()
      end)

    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    controller = controller_module(igniter)

    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(controller)} already exists: ExDoc is already installed, skipping."
        )

      {false, igniter} ->
        install(igniter, app_name, app_module, web_module, controller, opts)
    end
  end

  defp install(igniter, app_name, app_module, web_module, controller, opts) do
    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
    # phx.new derives its directories from the app name; deriving them from
    # the module (Macro.underscore/1) diverges on names carrying digits
    # (app :lorem_3 -> Lorem3Web -> "lorem3_web" instead of "lorem_3_web").
    web_dir = "#{app_name}_web"

    igniter
    |> Igniter.Project.Deps.add_dep({:ex_doc, "~> 0.38", only: :dev, runtime: false},
      on_exists: :skip
    )
    |> Igniter.Project.IgniterConfig.dont_move_file_pattern(~r"/controllers/")
    |> create_controller(controller, web_module, web_dir, app_name, opts)
    |> configure_mix_project(app_name, app_module, web_module, opts)
    |> adjust_router(router, app_name, web_module, opts)
    |> plant_assets(app_name, opts)
    |> plant_test_dummies(opts)
    |> build_docs(opts)
  end

  # `--build`: generate the site once the patch set is applied, so the
  # docs door has pages the first time it is opened. Queued, never run
  # inline — `mix docs` needs the dependencies fetched and compiled,
  # which only happens after the files land.
  defp build_docs(igniter, opts) do
    if opts[:build], do: Igniter.add_task(igniter, "docs", []), else: igniter
  end

  # --- Controller and tests ---------------------------------------------------

  defp create_controller(igniter, controller, web_module, web_dir, app_name, opts) do
    assigns = [
      app_name: app_name,
      web_module: inspect(web_module),
      project_name: opts[:project_name],
      version: opts[:version],
      coveralls: opts[:coveralls]
    ]

    igniter
    |> Igniter.Project.Module.create_module(
      controller,
      template("controller.eex", assigns),
      path: "lib/#{web_dir}/controllers/exdoc_controller.ex"
    )
    |> Igniter.Project.Module.create_module(
      Module.concat(web_module, ExDocControllerTest),
      template("controller_test.eex", assigns),
      path: "test/#{web_dir}/controllers/exdoc_controller_test.exs"
    )
  end

  # --- mix.exs ----------------------------------------------------------------

  defp configure_mix_project(igniter, app_name, app_module, web_module, opts) do
    set = fn igniter, key, code ->
      Igniter.Project.MixProject.update(igniter, :project, [key], fn _zipper ->
        {:ok, {:code, code}}
      end)
    end

    igniter
    |> set.(:name, inspect(opts[:project_name]))
    |> set.(:source_url, inspect(opts[:repo_url]))
    |> set.(:docs, docs_source(app_name, app_module, web_module, opts))
    |> add_before_closing_tags(app_module, opts)
  end

  defp docs_source(_app_name, app_module, web_module, opts) do
    mod = inspect(app_module)
    web = inspect(web_module)
    owner = opts[:repo_url] |> String.trim_trailing("/") |> String.split("/") |> Enum.at(-2)

    assets =
      join(
        [
          ~s|"assets/exdoc/config" => "/"|,
          only(opts[:coveralls], ~s|"cover" => "/"|),
          ~s|"assets/exdoc/images" => "/assets"|,
          ~s|"assets/exdoc/js" => "/assets"|
        ],
        ",\n    "
      )

    extras =
      join(
        [
          ~s|{"README.md", [title: "Overview"]}|,
          ~s|{"CHANGELOG.md", [title: "Changelog"]}|,
          only(opts[:auth0], ~s|{"assets/exdoc/token.md", [title: "Get access tokens"]}|),
          only(opts[:ecto], ~s|{"assets/exdoc/database.md", [title: "Database"]}|),
          only(opts[:coveralls], ~s|{"TESTING.md", [title: "Test Suite Report"]}|)
        ],
        ",\n    "
      )

    support =
      join(
        [
          only(opts[:auth0], ~s|"assets/exdoc/token.md"|),
          only(opts[:coveralls], ~s|"TESTING.md"|),
          only(opts[:ecto], ~s|"assets/exdoc/database.md"|)
        ],
        ",\n      "
      )

    """
    [
      source_ref: "main",
      authors: ["#{owner}"],
      homepage_url: "#{opts[:repo_url]}",
      logo: "assets/exdoc/images/app-logo.png",
      output: "doc",
      main: "readme",
      assets: %{
        #{assets}
      },
      extras: [
        #{extras}
      ],
      groups_for_extras: [
        Project: [
          "README.md",
          "CHANGELOG.md"
        ],
        Support: [
          #{support}
        ]
      ],
      groups_for_modules: [
        Contexts: ~r/^#{mod}\\.(?!(.*\\..*|Mailer|Repo|Helper|Release|.*Ecto.*)$).*$/,
        Schemas: ~r/^#{mod}\\..*\\.(?!.*(Enum)$).*$/,
        Types: ~r/^#{mod}\\..*(Enum|EctoURI)$/,
        Web: ~r/^#{web}(?!(.Plug..*|.*(Controller|HTML|JSON))$)/,
        Plugs: ~r/^#{web}.Plug..*$/,
        Controllers: ~r/^#{web}.*(Controller)$/,
        Views: ~r/^#{web}.*(HTML|JSON)$/
      ],
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1
    ]
    """
  end

  defp add_before_closing_tags(igniter, app_module, opts) do
    scripts =
      join(
        [
          ~s|  <script src="./assets/themedImage.js"></script>|,
          opts[:auth0] &&
            ~s|  <script src="https://cdn.auth0.com/js/auth0-spa-js/2.0/auth0-spa-js.production.js"></script>|,
          opts[:auth0] && ~s|  <script src="./assets/auth_config.js"></script>|,
          opts[:auth0] && ~s|  <script src="./assets/token.js"></script>|
        ],
        "\n"
      )

    code = template("before_closing.eex", scripts: scripts)
    mix_project = Module.concat(app_module, MixProject)

    Igniter.Project.Module.find_and_update_module!(igniter, mix_project, fn zipper ->
      {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :after)}
    end)
  end

  # --- Router -----------------------------------------------------------------

  defp adjust_router(igniter, router, app_name, web_module, opts) do
    cover_route =
      if opts[:coveralls],
        do: ~s|    get "/docs/cover", ExDocController, :cover\n|,
        else: ""

    code = """
    # ExDoc documentation site
    if Application.compile_env(:#{app_name}, :dev_routes) do
      scope "/dev", #{inspect(web_module)} do
        pipe_through :exdoc

        get "/docs/", ExDocController, :index
    #{cover_route}    get "/docs/*path", ExDocController, :handle
      end
    end
    """

    igniter
    |> Igniter.Libs.Phoenix.add_pipeline(
      :exdoc,
      """
      # The docs live in the standard `doc/` output dir, outside priv:
      # these routes are dev-only, where the VM cwd is the project root.
      plug Plug.Static,
        at: "/dev/docs",
        from: "doc",
        cache_control_for_etags: "public, max-age=86400",
        gzip: true
      """,
      router: router,
      warn_on_present?: false
    )
    |> Igniter.Project.Module.find_and_update_module!(router, fn zipper ->
      {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :after)}
    end)
  end

  # --- assets/exdoc -----------------------------------------------------------

  defp plant_assets(igniter, _app_name, opts) do
    igniter
    |> plant_asset("js/docs_config.js", "assets/exdoc/config/docs_config.js")
    |> plant_logo()
    |> plant_asset("js/themedImage.js", "assets/exdoc/js/themedImage.js")
    |> plant_if(opts[:auth0], "js/token.js", "assets/exdoc/js/token.js")
    |> plant_if(opts[:auth0], "token.md", "assets/exdoc/token.md")
    |> plant_testing_placeholder(opts)
    |> plant_database_placeholder(opts)
  end

  defp plant_asset(igniter, asset, path) do
    Igniter.create_new_file(igniter, path, asset(asset), on_exists: :overwrite)
  end

  defp plant_if(igniter, condition, asset, path) do
    if condition, do: plant_asset(igniter, asset, path), else: igniter
  end

  # The logo is a binary asset: copied verbatim after the patch set is
  # applied, never through the rewrite pipeline (which would normalize
  # its trailing bytes). See WorkbenchIgniter.plant_binary_asset/4.
  defp plant_logo(igniter) do
    plant_binary_asset(igniter, "images/app-logo.png", "assets/exdoc/images/app-logo.png")
  end

  # TESTING.md is generated (and overwritten) by `mix cover` at the
  # project root; a placeholder keeps `mix docs` from failing on a missing
  # extra file, and an existing report is never clobbered.
  defp plant_testing_placeholder(igniter, opts) do
    if opts[:coveralls] do
      Igniter.create_new_file(
        igniter,
        "TESTING.md",
        asset("TESTING.md"),
        on_exists: :skip
      )
    else
      igniter
    end
  end

  # The database.md page is generated by the enhancements feature; until
  # that runs, a placeholder keeps `mix docs` from failing on a missing
  # extra file.
  defp plant_database_placeholder(igniter, opts) do
    if opts[:ecto] and not Igniter.exists?(igniter, "assets/exdoc/database.md") do
      Igniter.create_new_file(
        igniter,
        "assets/exdoc/database.md",
        "# Database\n\n> Run `mix db` to generate the database documentation.\n",
        on_exists: :skip
      )
    else
      igniter
    end
  end

  # --- Dummy documentation pages ----------------------------------------------

  # Lets the generated test suite (and coverage reports) pass before
  # `mix docs` has ever run. They live in the gitignored `doc/` output dir
  # and are overwritten by the real documentation.
  defp plant_test_dummies(igniter, opts) do
    dir = "doc"
    name = opts[:project_name]
    version = opts[:version]

    igniter
    |> Igniter.create_new_file(
      "#{dir}/index.html",
      "<title>#{name} v#{version} — Documentation</title>\n",
      on_exists: :overwrite
    )
    |> Igniter.create_new_file(
      "#{dir}/404.html",
      "<title>404 — #{name} v#{version}</title>\n",
      on_exists: :overwrite
    )
    |> plant_cover_dummy(dir, opts)
  end

  defp plant_cover_dummy(igniter, dir, opts) do
    if opts[:coveralls] do
      Igniter.create_new_file(igniter, "#{dir}/excoveralls.html", "<title>Coverage</title>\n",
        on_exists: :overwrite
      )
    else
      igniter
    end
  end

  # --- Helpers ----------------------------------------------------------------

  defp only(condition, string), do: if(condition, do: string)

  defp join(items, separator) do
    items
    |> Enum.filter(&is_binary/1)
    |> Enum.join(separator)
  end
end
