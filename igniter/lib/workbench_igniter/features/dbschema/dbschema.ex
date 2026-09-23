defmodule WorkbenchIgniter.Features.Dbschema do
  @moduledoc """
  The database's own page in the project's documentation, drawn from
  [DbSchema](https://dbschema.com): the model, table by table, and the
  entity-relationship diagram in the reader's theme.

  DbSchema is a desktop tool. The developer opens it on the project's
  database, exports the model to `assets/db_schema/` — a `database.dbs`
  and, per theme, a `MainLayout.svg` and a `database.md` — and this
  cartridge is what turns that export into something a reader sees:
  `mix db`, which formats the Markdown ExDoc's way (tabs per table, the
  foreign keys read as names, the HTML entities decoded) and copies the
  two SVGs into `guides/images/` as `model-light.svg` and
  `model-dark.svg`. The page names both, with GitHub's own URL
  fragments — `#gh-light-mode-only` and `#gh-dark-mode-only` — which
  ExDoc has honoured since v0.27: each theme hides the other's image,
  and no script is needed.

  A sample export rides along (`--combo`), so the page and the diagram
  are there from the first boot and `mix db` has something to read
  before anyone opens DbSchema. The page is written whether or not the
  project has a documentation site; when it has one, the page is listed
  in it, under Support.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.Features.Exdoc

  embed_templates()
  embed_assets()

  @example "mix workbench.install.dbschema --combo auth0"

  # The sample exports that ride along, by the shape of the database
  # they were taken from. Each is a directory under
  # priv/features/dbschema/assets/db_schema/.
  @combos ~w(none auth0 auth0_openai auth0_stripe auth0_openai_stripe)

  # What DbSchema exports, and where the project keeps it: the input
  # `mix db` reads.
  @source_path "assets/db_schema"
  @db_schema_files ~w(
    database.dbs
    light/MainLayout.svg
    light/database.md
    dark/MainLayout.svg
    dark/database.md
  )

  # The task the box is, and what it writes.
  @task_file "lib/mix/tasks/db.ex"
  @task_test_file "test/mix/tasks/db_test.exs"
  @page "guides/database.md"
  @light_image "guides/images/model-light.svg"
  @dark_image "guides/images/model-dark.svg"

  @impl true
  def archived,
    do:
      "2026-09-22: DbSchema is a desktop tool outside the workbench and this only dresses its export; the reference project is on Ash, whose diagrams come from Ash itself"

  @impl true
  def task, do: "workbench.install.dbschema"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      combo:
        "Which sample DbSchema export is planted under `assets/db_schema/`, so the page and the diagram have content before anyone opens DbSchema: #{Enum.map_join(@combos, ", ", &"`#{&1}`")}. Default: `none`, the bare Phoenix database."
    ]
  end

  @impl true
  def choices do
    [
      combo: [
        {"none", "a stock Phoenix database: `schema_migrations` and nothing else"},
        {"auth0", "with auth0's `users` table"},
        {"auth0_openai", "with auth0's `users` and openai's `conversations` and `messages`"},
        {"auth0_stripe", "auth0's tables: Stripe's objects live at Stripe, not in the database"},
        {"auth0_openai_stripe", "auth0's and openai's tables, on the Stripe export"}
      ]
    ]
  end

  # There is no database page without a database. exdoc is not required:
  # the page and the images are written either way, and listed in the
  # site only when the project has one.
  @impl true
  def requires, do: ["ecto"]

  @impl true
  def afterwards,
    do:
      "Export the project's own model from DbSchema over assets/db_schema/, then ./wb.sh mix db rewrites the page and the two diagrams."

  # The task is the box: a second run finds it and skips.
  @impl true
  def rerun, do: :noop

  # The mark: the `mix db` task, the file this plants and nothing else
  # does.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, @task_file)

  @doc """
  What the project carries: the combo of the export under
  `assets/db_schema/`, read off the tables its `database.dbs` names —
  `users` is auth0's, `conversations` openai's. A combo with Stripe
  reads back without it: Stripe keeps its objects at Stripe, so its
  export is the same database as the one without. `nil` when there is
  no export to read.
  """
  @impl true
  def state(igniter) do
    {dbs, igniter} = file_content(igniter, "#{@source_path}/database.dbs")

    {%{combo: dbs && combo_of(dbs)}, igniter}
  end

  defp combo_of(dbs) do
    case {String.contains?(dbs, ~s|<table name="users"|),
          String.contains?(dbs, ~s|<table name="conversations"|)} do
      {true, true} -> "auth0_openai"
      {true, false} -> "auth0"
      _ -> "none"
    end
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [combo: :string],
      defaults: [combo: "none"]
    }
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    case WorkbenchIgniter.Feature.missing_requirements(igniter, __MODULE__) do
      {[], igniter} -> install_combo(igniter, igniter.args.options[:combo] || "none")
      {missing, igniter} -> WorkbenchIgniter.Feature.refuse(igniter, __MODULE__, missing)
    end
  end

  defp install_combo(igniter, combo) when combo not in @combos do
    Igniter.add_issue(
      igniter,
      "Unknown --combo #{inspect(combo)}. One of: #{Enum.join(@combos, ", ")}."
    )
  end

  defp install_combo(igniter, combo) do
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(igniter, "#{@task_file} already exists: mix db is in, skipping.")

      {false, igniter} ->
        {name, igniter} = display_name(igniter)

        igniter
        # `mix db` decodes the entities DbSchema writes into its Markdown.
        |> Igniter.Project.Deps.add_dep({:html_entities, "~> 0.5"}, on_exists: :skip)
        |> plant(@task_file, template("db_task.eex", []))
        |> plant(@task_test_file, template("db_task_test.eex", []))
        |> plant_sources(combo, name)
        |> plant_pages(combo, name)
        |> list_in_docs()
    end
  end

  defp plant(igniter, path, content),
    do: Igniter.create_new_file(igniter, path, content, on_exists: :overwrite)

  # The export itself, where DbSchema writes it and `mix db` reads it.
  defp plant_sources(igniter, combo, name) do
    Enum.reduce(@db_schema_files, igniter, fn file, igniter ->
      plant(igniter, "#{@source_path}/#{file}", source(combo, file, name))
    end)
  end

  # What `mix db` would write, written on the insert: the page and the
  # two diagrams, so the docs site has a database page from its first
  # build and the task's own test finds its input files.
  defp plant_pages(igniter, combo, name) do
    igniter
    |> plant(@light_image, source(combo, "light/MainLayout.svg", name))
    |> plant(@dark_image, source(combo, "dark/MainLayout.svg", name))
    |> plant(@page, page(combo, name))
  end

  # The sample's own page names the SVG beside it; the planted one names
  # the two the task writes, each with the fragment that hides it in the
  # other theme.
  defp page(combo, name) do
    String.replace(
      source(combo, "light/database.md", name),
      "![img](./MainLayout.svg)",
      "![img](./assets/model-light.svg#gh-light-mode-only)\n\n" <>
        "![img](./assets/model-dark.svg#gh-dark-mode-only)"
    )
  end

  # The sample carries the name of whoever's database it was taken from
  # as a placeholder, and its own export date.
  defp source(combo, file, name) do
    today = Date.utc_today() |> Date.to_iso8601()

    asset("db_schema/#{combo}/#{file}")
    |> String.replace("%{project_name}", name)
    |> String.replace(~r/DbSchema\.com © \d{4}-\d{2}-\d{2}/, "DbSchema.com © #{today}")
  end

  # A docs site that exists already — exdoc's `docs:` block, with its
  # extras — gets the database page as one of its pages. exdoc does not
  # know about it; this is the only order.
  defp list_in_docs(igniter) do
    case Exdoc.lists_pages?(igniter) do
      {true, igniter} -> Exdoc.list_page(igniter, @page, "Database", :Support)
      {false, igniter} -> igniter
    end
  end
end
