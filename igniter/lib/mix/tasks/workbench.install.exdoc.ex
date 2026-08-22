defmodule Mix.Tasks.Workbench.Install.Exdoc do
  use Igniter.Mix.Task

  @example "mix workbench.install.exdoc --project-name \"Lorem Ipsum\" --coveralls"
  @shortdoc "Adds ExDoc documentation served at /dev/docs to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_exdoc` feature:

  * adds `{:ex_doc, "~> 0.38", only: :dev, runtime: false}` to the deps
  * configures `name`, `source_url` and the full `docs` section in
    `mix.exs` (assets, extras, groups and regex-based module groups),
    plus the `before_closing_*_tag` helper functions
  * creates `MyAppWeb.ExDocController` (index / coverage / 404 fallback)
    with its unit tests
  * router: `:exdoc` pipeline (`Plug.Static` over the standard `doc/`
    output dir, already gitignored by phx.new) and dev routes under
    `/dev/docs`
  * plants the documentation assets under `assets/exdoc/`: logo, theme
    JS, and the conditional pages (token, coding guidelines, database
    placeholder), plus the root `TESTING.md` placeholder for `mix cover`
  * seeds dummy pages in `doc/` so the test suite passes before the first
    `mix docs` run

  ## Example

      #{@example}

  ## Options

  * `--project-name` - Display name (default: capitalized app name).
  * `--repo-url` - Repository URL for `source_url`/`authors`.
  * `--guidelines-url` - URL of a coding guidelines markdown to download
    as the "Coding guidelines" page. Optional.
  * `--coveralls` - The project uses the coveralls feature (adds the
    coverage assets, page and controller action).
  * `--auth0`, `--openai`, `--stripe` - Feature flags (auth0 adds the
    token page and scripts).
  * `--no-ecto` - Project created without Ecto (skips the database page
    and diagram).
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [
        project_name: :string,
        repo_url: :string,
        guidelines_url: :string,
        coveralls: :boolean,
        auth0: :boolean,
        openai: :boolean,
        stripe: :boolean,
        ecto: :boolean
      ],
      defaults: [
        repo_url: "https://github.com/user/repo",
        coveralls: false,
        auth0: false,
        openai: false,
        stripe: false,
        ecto: true
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts =
      Keyword.put_new_lazy(igniter.args.options, :project_name, fn ->
        Mix.Project.config()[:app] |> to_string() |> String.capitalize()
      end)

    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    controller = Module.concat(web_module, ExDocController)

    case Igniter.Project.Module.module_exists(igniter, controller) do
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
    web_dir = web_module |> inspect() |> Macro.underscore()

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
  end

  # --- Controller and tests ---------------------------------------------------

  defp create_controller(igniter, controller, web_module, web_dir, app_name, opts) do
    assigns = [
      app_name: app_name,
      web_module: inspect(web_module),
      project_name: opts[:project_name],
      coveralls: opts[:coveralls]
    ]

    igniter
    |> Igniter.Project.Module.create_module(
      controller,
      WorkbenchIgniter.template("exdoc/controller.eex", assigns),
      path: "lib/#{web_dir}/controllers/exdoc_controller.ex"
    )
    |> Igniter.Project.Module.create_module(
      Module.concat(web_module, ExDocControllerTest),
      WorkbenchIgniter.template("exdoc/controller_test.eex", assigns),
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
          only(opts[:coveralls], ~s|{"TESTING.md", [title: "Testing reports"]}|),
          only(
            opts[:guidelines_url],
            ~s|{"assets/exdoc/coding.md", [title: "Coding guidelines"]}|
          )
        ],
        ",\n    "
      )

    support =
      join(
        [
          only(opts[:auth0], ~s|"assets/exdoc/token.md"|),
          only(opts[:coveralls], ~s|"TESTING.md"|),
          only(opts[:ecto], ~s|"assets/exdoc/database.md"|),
          only(opts[:guidelines_url], ~s|"assets/exdoc/coding.md"|)
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

    code = WorkbenchIgniter.template("exdoc/before_closing.eex", scripts: scripts)
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
    |> plant_asset("exdoc/js/docs_config.js", "assets/exdoc/config/docs_config.js")
    |> plant_asset("exdoc/images/app-logo.png", "assets/exdoc/images/app-logo.png")
    |> plant_asset("exdoc/js/themedImage.js", "assets/exdoc/js/themedImage.js")
    |> plant_if(opts[:auth0], "exdoc/js/token.js", "assets/exdoc/js/token.js")
    |> plant_if(opts[:auth0], "exdoc/token.md", "assets/exdoc/token.md")
    |> plant_testing_placeholder(opts)
    |> plant_database_placeholder(opts)
    |> download_guidelines(opts)
  end

  defp plant_asset(igniter, asset, path) do
    Igniter.create_new_file(igniter, path, WorkbenchIgniter.asset(asset), on_exists: :overwrite)
  end

  defp plant_if(igniter, condition, asset, path) do
    if condition, do: plant_asset(igniter, asset, path), else: igniter
  end

  # TESTING.md is generated (and overwritten) by `mix cover` at the project
  # root; a placeholder keeps `mix docs` from failing on a missing extra
  # file, and an existing report is never clobbered.
  defp plant_testing_placeholder(igniter, opts) do
    if opts[:coveralls] do
      Igniter.create_new_file(
        igniter,
        "TESTING.md",
        WorkbenchIgniter.asset("exdoc/testing.md"),
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

  defp download_guidelines(igniter, opts) do
    case opts[:guidelines_url] do
      nil ->
        igniter

      url ->
        try do
          Igniter.create_new_file(igniter, "assets/exdoc/coding.md", Req.get!(url).body,
            on_exists: :overwrite
          )
        rescue
          error ->
            # The page is referenced from the mix.exs docs extras: a
            # placeholder keeps `mix docs` working when the download fails.
            igniter
            |> Igniter.create_new_file(
              "assets/exdoc/coding.md",
              "# Coding guidelines\n\n> Download failed during setup; " <>
                "fetch the page from <#{url}> and replace this file.\n",
              on_exists: :skip
            )
            |> Igniter.add_warning(
              "Could not download the coding guidelines from #{url} " <>
                "(#{Exception.message(error)}); a placeholder page was created."
            )
        end
    end
  end

  # --- Dummy documentation pages ----------------------------------------------

  # Lets the generated test suite (and coverage reports) pass before
  # `mix docs` has ever run. They live in the gitignored `doc/` output dir
  # and are overwritten by the real documentation.
  defp plant_test_dummies(igniter, opts) do
    dir = "doc"
    name = opts[:project_name]

    igniter
    |> Igniter.create_new_file(
      "#{dir}/index.html",
      "<title>#{name} v0.0.0 — Documentation</title>\n",
      on_exists: :overwrite
    )
    |> Igniter.create_new_file(
      "#{dir}/404.html",
      "<title>404 — #{name} v0.0.0</title>\n",
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
