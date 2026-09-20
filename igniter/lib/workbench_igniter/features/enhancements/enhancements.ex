defmodule WorkbenchIgniter.Features.Enhancements do
  @moduledoc """
  Workbench project enhancements: base schema, helpers, the db mix
  tasks and the extended test suite.

  Full feature cartridge: manifest, install logic and the EEx templates it
  renders live in this directory; the
  `Mix.Tasks.Workbench.Install.Enhancements` shell in `task.ex` delegates
  here. The DbSchema diagrams and Postman collections it plants are
  selected by feature combo (auth0/openai/stripe/health) and live in
  `priv/features/enhancements/assets/`, embedded verbatim with
  `embed_assets/1`.

  Ordering: composed before auth0, whose User schema uses the `MyApp.Schema`
  module this feature generates.
  """
  use WorkbenchIgniter.Feature

  embed_templates()
  embed_assets()

  @example "mix workbench.install.enhancements --id-type uuid --timestamps naive_datetime_usec"

  @impl true
  def archived,
    do:
      "2026-09-20: the Phoenix line's — its Ecto generators and schema config fight Ash's domain"

  @impl true
  def task, do: "workbench.install.enhancements"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      project_name: "Display name (default: capitalized app name).",
      id_type: "Primary key type (`uuid` maps to `Ecto.UUID`). Default: `uuid`.",
      timestamps: "Timestamps type. Default: `naive_datetime_usec`.",
      interface:
        "`rest` | `graphql` | `none`. Default: `rest`. `rest` adds the changeset-aware `error_json.ex`, the error view test and the Postman collection.",
      exdoc:
        "The exdoc feature is composed too: `MyApp.Schema` carries the `@moduledoc` sections its pages read.",
      auth0:
        "The auth0 feature is composed too: the DbSchema diagrams and Postman collection of that combo, the User fixtures, and the `MyApp.Schema` bits its User schema uses.",
      openai:
        "The openai feature is composed too: the diagrams and Postman collection of that combo, and the assistant fixtures.",
      stripe: "The stripe feature is composed too: the DbSchema diagrams of that combo.",
      health: "The health_endpoint feature is composed too: the Postman collection of that combo."
    ]
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
        exdoc: false,
        auth0: false,
        openai: false,
        stripe: false,
        health: false
      ]
    }
  end

  # The mark: `MyApp.Fixtures`, the one file every shape of the install
  # writes — the Ecto and REST groups follow the project, the tests too.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, "test/support/fixtures.ex")

  # What the project carries, read off what the install wrote — and
  # each option only where it wrote something, since the groups follow
  # the project (the Ecto group needs ecto, the REST group `rest`):
  # the key and timestamp types and --exdoc's `@before_compile` off
  # `MyApp.Schema`; --interface off the error view, which renders
  # `%{error: …}` where phx.new's renders `%{errors: %{detail: …}}`;
  # --auth0 and --openai off the tables in the DbSchema model or the
  # sections of the Postman collection, --health off the collection
  # alone; --project-name off the model's page or the collection. Where
  # none of those files is there the option left no mark: `nil`.
  # --stripe leaves none anywhere: its diagrams are the auth0 ones.
  @impl true
  def state(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    {schema, igniter} = file_content(igniter, "lib/#{app_name}/schema.ex")
    {error_json, igniter} = file_content(igniter, "lib/#{app_name}_web/controllers/error_json.ex")
    {dbs, igniter} = file_content(igniter, "assets/db_schema/database.dbs")
    {model_page, igniter} = file_content(igniter, "assets/exdoc/database.md")
    {postman, igniter} = file_content(igniter, "#{app_name}.postman_collection.json")

    has? = fn content, text -> content && String.contains?(content, text) end
    # true/false where a file could carry the mark, nil where none is there.
    either = fn {a, mark_a}, {b, mark_b} ->
      if a || b, do: has?.(a, mark_a) || has?.(b, mark_b) || false
    end

    {%{
       project_name:
         capture(model_page, ~r/\A#\s*([^\n]*?)(?: - Entity-Relationship Diagram)?\s*$/m) ||
           capture(postman, ~r/"name":\s*"([^"]*)"/),
       id_type: schema && id_type_option(capture(schema, ~r/@primary_key \{:id, ([\w.:]+),/)),
       timestamps: capture(schema, ~r/@timestamps_opts \[type: :(\w+)\]/),
       interface: error_json && if(has?.(error_json, "%{error: message}"), do: "rest"),
       exdoc: schema && String.contains?(schema, "@before_compile"),
       auth0: either.({dbs, ~s|<table name="users"|}, {postman, "User Operations"}),
       openai:
         either.({dbs, ~s|<table name="conversations"|}, {postman, "Conversation Operations"}),
       stripe: nil,
       health: postman && String.contains?(postman, "Development Operations")
     }, igniter}
  end

  defp capture(nil, _regex), do: nil

  defp capture(content, regex) do
    case Regex.run(regex, content) do
      [_, value] -> value
      nil -> nil
    end
  end

  # The option the schema's key type came from: the inverse of id_type/1.
  defp id_type_option("Ecto.UUID"), do: "uuid"
  defp id_type_option(":" <> other), do: other
  defp id_type_option(_other), do: nil

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts =
      Keyword.put_new_lazy(igniter.args.options, :project_name, fn ->
        Mix.Project.config()[:app] |> to_string() |> String.capitalize()
      end)

    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "test/support/fixtures.ex already exists: enhancements are already installed, skipping."
        )

      {false, igniter} ->
        # What the project has of phx.new's capabilities is read off it,
        # not asked: the Ecto group, and the page, dashboard and mailbox
        # tests, follow the project as it is.
        {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)

        install(
          igniter,
          Keyword.merge(opts, Map.to_list(Map.take(facts, [:ecto, :html, :mailer, :dashboard])))
        )
    end
  end

  defp install(igniter, opts) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    # phx.new derives its directories from the app name; deriving them from
    # the module (Macro.underscore/1) diverges on names carrying digits
    # (app :lorem_3 -> Lorem3Web -> "lorem3_web" instead of "lorem_3_web").
    web_dir = "#{app_name}_web"
    app_dir = to_string(app_name)

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
      |> generators_config(assigns[:app_name], opts)
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

  # The same policy `MyApp.Schema` carries, written where the generators
  # and the migrations read it: one decision (`--id-type`,
  # `--timestamps`), both halves. Without this, `mix phx.gen.*` keeps
  # emitting phx.new's defaults and the tables drift from the schemas.
  defp generators_config(igniter, app_name, opts) do
    repo = Module.concat(Igniter.Project.Module.module_name_prefix(igniter), Repo)

    igniter
    |> Igniter.Project.Config.configure(
      "config.exs",
      app_name,
      [:generators, :timestamp_type],
      :utc_datetime_usec
    )
    |> config_type(app_name, repo, :migration_primary_key, opts[:id_type])
    |> config_type(app_name, repo, :migration_timestamps, opts[:timestamps])
  end

  defp config_type(igniter, _app_name, _repo, _key, nil), do: igniter

  defp config_type(igniter, app_name, repo, key, type) do
    Igniter.Project.Config.configure(igniter, "config.exs", app_name, [repo, key],
      type: String.to_atom(type)
    )
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
    |> plant_diagram(
      combo,
      "light/MainLayout.svg",
      "assets/exdoc/images/model-light.svg",
      assigns
    )
    |> plant_diagram(combo, "dark/MainLayout.svg", "assets/exdoc/images/model-dark.svg", assigns)
    |> plant_diagram(combo, "light/database.md", "assets/exdoc/database.md", assigns)
  end

  defp plant_diagram(igniter, combo, file, target, assigns) do
    today = Date.utc_today() |> Date.to_iso8601()

    content =
      asset("db_schema/#{combo}/#{file}")
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
          asset("postman/#{combo}.postman_collection.json")
          |> String.replace("%{project_name}", assigns[:project_name])

        Igniter.create_new_file(
          igniter,
          "#{assigns[:app_name]}.postman_collection.json",
          content,
          on_exists: :overwrite
        )
    end
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
