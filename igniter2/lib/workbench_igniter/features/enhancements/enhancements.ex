defmodule WorkbenchIgniter.Features.Enhancements do
  @moduledoc """
  Workbench project enhancements: base schema, helpers, db/version mix
  tasks and the extended test suite. Toggled by `--enhance` (which also
  turns on the trivial dep-only group).

  Full feature cartridge: manifest, install logic and the EEx templates it
  renders live in this directory; the
  `Mix.Tasks.Workbench.Install.Enhancements` shell in `task.ex` delegates
  here. The DbSchema diagrams and Postman collections it plants are
  multi-feature combos (auth0/openai/stripe/health), so they stay in
  `priv/assets/` and are read with `WorkbenchIgniter.asset/1`.

  Ordering: composed before auth0, whose User schema uses the `MyApp.Schema`
  module this feature generates.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.enhancements --id-type uuid --timestamps naive_datetime_usec"

  @impl true
  def task, do: "workbench.install.enhancements"

  @impl true
  def flag, do: :enhance

  @impl true
  def argv(opts) do
    ["--project-name", opts[:project_name], "--interface", opts[:interface]] ++
      if(opts[:id_type], do: ["--id-type", opts[:id_type]], else: []) ++
      if(opts[:timestamps], do: ["--timestamps", opts[:timestamps]], else: []) ++
      flags(opts, [:exdoc, :auth0, :openai, :stripe, :health]) ++
      no_flags(opts, [:ecto, :html, :mailer, :dashboard])
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      composes: ["workbench.install.mock"],
      schema: [
        project_name: :string,
        id_type: :string,
        timestamps: :string,
        interface: :string,
        ecto: :boolean,
        html: :boolean,
        mailer: :boolean,
        dashboard: :boolean,
        exdoc: :boolean,
        auth0: :boolean,
        openai: :boolean,
        stripe: :boolean,
        health: :boolean
      ],
      defaults: [
        id_type: "uuid",
        timestamps: "naive_datetime_usec",
        interface: "rest",
        ecto: true,
        html: true,
        mailer: true,
        dashboard: true,
        exdoc: false,
        auth0: false,
        openai: false,
        stripe: false,
        health: false
      ]
    }
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts =
      Keyword.put_new_lazy(igniter.args.options, :project_name, fn ->
        Mix.Project.config()[:app] |> to_string() |> String.capitalize()
      end)

    if Igniter.exists?(igniter, "lib/mix/tasks/version.ex") do
      Igniter.add_notice(
        igniter,
        "lib/mix/tasks/version.ex already exists: enhancements are already installed, skipping."
      )
    else
      install(igniter, opts)
    end
  end

  defp install(igniter, opts) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    web_dir = web_module |> inspect() |> Macro.underscore()
    app_dir = app_module |> inspect() |> Macro.underscore()

    assigns = [
      app_name: app_name,
      app_module: inspect(app_module),
      web_module: inspect(web_module),
      project_name: opts[:project_name],
      id_type: id_type(opts[:id_type]),
      timestamps: opts[:timestamps],
      ecto: opts[:ecto],
      exdoc: opts[:exdoc],
      auth0: opts[:auth0],
      openai: opts[:openai]
    ]

    dirs = %{app: app_dir, web: web_dir}

    igniter
    |> Igniter.Project.IgniterConfig.dont_move_file_pattern(~r"/controllers/")
    |> ecto_group(dirs, assigns, opts)
    |> rest_group(dirs, assigns, opts)
    |> version_task(assigns)
    |> unit_testing(dirs, app_module, assigns, opts)
  end

  defp id_type("uuid"), do: "Ecto.UUID"
  defp id_type(other), do: ":#{other}"

  defp plant(igniter, template, path, assigns) do
    Igniter.create_new_file(igniter, path, template(template, assigns), on_exists: :overwrite)
  end

  # --- Ecto group -------------------------------------------------------------

  defp ecto_group(igniter, dirs, assigns, opts) do
    if opts[:ecto] do
      igniter
      |> Igniter.Project.Deps.add_dep({:ecto_enum, "~> 1.4"}, on_exists: :skip)
      |> Igniter.Project.Deps.add_dep({:html_entities, "~> 0.5"}, on_exists: :skip)
      |> plant("helper.eex", "lib/#{dirs.app}/helper.ex", assigns)
      |> plant("helper_test.eex", "test/#{dirs.app}/helper_test.exs", assigns)
      |> plant("schema.eex", "lib/#{dirs.app}/schema.ex", assigns)
      |> plant("db_task.eex", "lib/mix/tasks/db.ex", assigns)
      |> plant("db_task_test.eex", "test/mix/tasks/db_test.exs", assigns)
      |> db_schema_diagrams(assigns, opts)
    else
      igniter
    end
  end

  @db_schema_files ~w(
    database.dbs
    light/MainLayout.svg
    light/database.md
    dark/MainLayout.svg
    dark/database.md
  )

  defp db_schema_diagrams(igniter, assigns, opts) do
    combo = diagram_combo(opts)

    igniter
    |> then(fn igniter ->
      Enum.reduce(@db_schema_files, igniter, fn file, igniter ->
        plant_diagram(igniter, combo, file, "assets/db_schema/#{file}", assigns)
      end)
    end)
    |> initial_db_docs(combo, assigns, opts)
  end

  # Plants the files `mix db` would generate, so ExDoc has real database
  # pages (instead of a placeholder) and the db task tests — which mock
  # the copy — find their input files. Always planted with the ecto group:
  # the db task targets assets/exdoc/ even when the ExDoc feature is off.
  defp initial_db_docs(igniter, combo, assigns, _opts) do
    igniter
    |> plant_diagram(combo, "light/MainLayout.svg", "assets/exdoc/images/model-light.svg", assigns)
    |> plant_diagram(combo, "dark/MainLayout.svg", "assets/exdoc/images/model-dark.svg", assigns)
    |> plant_diagram(combo, "light/database.md", "assets/exdoc/database.md", assigns)
  end

  defp plant_diagram(igniter, combo, file, target, assigns) do
    today = Date.utc_today() |> Date.to_iso8601()

    content =
      WorkbenchIgniter.asset("db_schema/#{combo}/#{file}")
      |> String.replace("%{project_name}", assigns[:project_name])
      |> String.replace(~r/DbSchema\.com © \d{4}-\d{2}-\d{2}/, "DbSchema.com © #{today}")

    Igniter.create_new_file(igniter, target, content, on_exists: :overwrite)
  end

  defp diagram_combo(opts) do
    if opts[:auth0] do
      ~w(auth0 openai stripe)a
      |> Enum.filter(&opts[&1])
      |> Enum.map_join("_", &Atom.to_string/1)
    else
      "none"
    end
  end

  # --- REST group -------------------------------------------------------------

  defp rest_group(igniter, dirs, assigns, opts) do
    if opts[:interface] == "rest" do
      igniter
      # Replaces the phx-generated error view with the enhanced one
      # (changeset error rendering).
      |> plant("error_json.eex", "lib/#{dirs.web}/controllers/error_json.ex", assigns)
      |> postman_collection(assigns, opts)
    else
      igniter
    end
  end

  defp postman_collection(igniter, assigns, opts) do
    case ~w(auth0 openai health)a |> Enum.filter(&opts[&1]) |> Enum.map_join("-", &to_string/1) do
      "" ->
        igniter

      combo ->
        content =
          WorkbenchIgniter.asset("rest/#{combo}.postman_collection.json")
          |> String.replace("%{project_name}", assigns[:project_name])

        Igniter.create_new_file(
          igniter,
          "#{assigns[:app_name]}.postman_collection.json",
          content,
          on_exists: :overwrite
        )
    end
  end

  # --- mix version ------------------------------------------------------------

  defp version_task(igniter, assigns) do
    igniter
    |> plant("version_task.eex", "lib/mix/tasks/version.ex", assigns)
    |> plant("version_task_test.eex", "test/mix/tasks/version_test.exs", assigns)
  end

  # --- Base unit testing ------------------------------------------------------

  defp unit_testing(igniter, dirs, app_module, assigns, opts) do
    igniter
    # MockHelper and the planted tests use the Mock library.
    |> Igniter.compose_task("workbench.install.mock", [])
    |> plant("application_test.eex", "test/#{dirs.app}/application_test.exs", assigns)
    |> plant("telemetry_test.eex", "test/#{dirs.web}/telemetry_test.exs", assigns)
    |> plant_if(
      opts[:html],
      "page_controller_test.eex",
      "test/#{dirs.web}/controllers/page_controller_test.exs",
      assigns
    )
    |> plant_if(
      opts[:dashboard],
      "dashboard_controller_test.eex",
      "test/#{dirs.web}/controllers/dashboard_controller_test.exs",
      assigns
    )
    |> plant_if(
      opts[:mailer],
      "mailbox_controller_test.eex",
      "test/#{dirs.web}/controllers/mailbox_controller_test.exs",
      assigns
    )
    |> plant_if(
      opts[:interface] == "rest",
      "error_json_test.eex",
      "test/#{dirs.web}/controllers/error_json_test.exs",
      assigns
    )
    |> plant("fixtures.eex", "test/support/fixtures.ex", assigns)
    |> plant("mock_helper.eex", "test/support/mock_helper.ex", assigns)
    |> import_mock_helper(app_module)
  end

  defp plant_if(igniter, condition, template, path, assigns) do
    if condition, do: plant(igniter, template, path, assigns), else: igniter
  end

  defp import_mock_helper(igniter, app_module) do
    path = "test/support/conn_case.ex"
    anchor = "import #{inspect(app_module)}Web.ConnCase"
    import_line = "import #{inspect(app_module)}.MockHelper"

    if Igniter.exists?(igniter, path) do
      igniter
      |> Igniter.include_existing_file(path)
      |> Igniter.update_file(path, fn source ->
        Rewrite.Source.update(source, :content, &insert_import(&1, anchor, import_line))
      end)
    else
      Igniter.add_warning(
        igniter,
        "Could not import #{inspect(app_module)}.MockHelper into #{path}: file not found."
      )
    end
  end

  defp insert_import(content, anchor, import_line) do
    cond do
      String.contains?(content, import_line) ->
        content

      String.contains?(content, anchor) ->
        String.replace(content, anchor, anchor <> "\n      " <> import_line, global: false)

      true ->
        content
    end
  end
end
