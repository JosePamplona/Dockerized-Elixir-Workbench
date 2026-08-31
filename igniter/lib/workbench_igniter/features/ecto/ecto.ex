defmodule WorkbenchIgniter.Features.Ecto do
  @moduledoc """
  Phoenix's Ecto — the repo, the adapter, its configuration, the data
  case — for a project generated with `--no-ecto`.

  A base cartridge: it names the `phx.new` flag, the mark and the two
  options `phx.new` has for it — `--database` and `--binary-id`, which
  phx.new accepts without Ecto but only Ecto reads — and
  `WorkbenchIgniter.PhxDelta` brings in whatever `phx.new` generates
  for Ecto with that database at the installer's version, merged onto
  the project's files. On top of the delta the cartridge writes the one
  thing `phx.new` leaves to the environment: the variable the release
  reads to find the database (`DATABASE_URL`, or `DATABASE_PATH` for
  SQLite), in `.env` and `.env.sample`, as `workbench.setup` does for
  a project born with Ecto.

  The workspace's compose is the workbench's: it provides a Postgres.
  Inserting Ecto into a project whose compose was baked without one is
  what `./wb.sh bake` is for, and `wb.sh add ecto` says so.

  Inserted once: changing the database of a project with data is a
  migration, not a flag. The mark is the `ecto_sql` dependency.
  """
  use WorkbenchIgniter.Feature

  # phx.new's own words for each, from `mix help phx.new`.
  @databases [
    {"postgres", "via postgrex — the one the workspace's compose provides"},
    {"mysql", "via myxql — no service in the workspace's compose"},
    {"mssql", "via tds — no service in the workspace's compose"},
    {"sqlite3", "via ecto_sqlite3 — a file, no service needed"}
  ]

  @impl true
  def task, do: "workbench.install.ecto"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task() <> " --database postgres",
      schema: [database: :string, binary_id: :boolean],
      defaults: [database: "postgres", binary_id: false]
    }
  end

  @impl true
  def choices, do: [database: @databases]

  @impl true
  def afterwards,
    do: "./wb.sh bake puts the database into the workspace's compose, then ./wb.sh setup creates it."

  @impl true
  def option_docs do
    [
      database:
        "The database adapter, as `phx.new --database` names them: `postgres` (default), `mysql`, `mssql`, `sqlite3`. The workspace's compose provides a Postgres; SQLite needs none.",
      binary_id:
        "`binary_id` as the primary key type of the Ecto schemas the generators make (`phx.new --binary-id`): the `generators` entry of `config.exs`."
    ]
  end

  # The mark: the ecto_sql dependency, the first thing --no-ecto leaves out.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, :ecto_sql)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    database = igniter.args.options[:database] || "postgres"

    cond do
      not List.keymember?(@databases, database, 0) ->
        Igniter.add_issue(
          igniter,
          "Unknown --database #{inspect(database)}. One of: #{Enum.map_join(@databases, ", ", &elem(&1, 0))}."
        )

      true ->
        case installed?(igniter) do
          {true, igniter} ->
            Igniter.add_notice(igniter, "ecto_sql is already a dependency: Ecto is in, skipping.")

          {false, igniter} ->
            app = Igniter.Project.Application.app_name(igniter)

            igniter
            |> WorkbenchIgniter.PhxDelta.apply(:ecto, %{database: database, binary_id: igniter.args.options[:binary_id] == true})
            |> env_entry(app, database)
        end
    end
  end

  # What the release reads to find the database (config/runtime.exs, from
  # phx.new): a URL for the servers, a path for SQLite. The values are
  # the workspace's — the Postgres of its compose, on localhost inside
  # the pod — as workbench.setup writes them for a project born with Ecto.
  defp env_entry(igniter, app, "sqlite3") do
    WorkbenchIgniter.env_entry(
      igniter,
      "Path of the SQLite file the release opens (:prod).",
      ~s|DATABASE_PATH="#{app}_prod.db"|
    )
  end

  defp env_entry(igniter, app, "postgres") do
    WorkbenchIgniter.env_entry(
      igniter,
      "Database connection for the release (:prod): the workspace's Postgres, on localhost inside the pod.",
      ~s|DATABASE_URL="ecto://postgres:postgres@localhost:5432/#{app}_prod"|
    )
  end

  defp env_entry(igniter, app, database) do
    WorkbenchIgniter.env_entry(
      igniter,
      "Database connection for the release (:prod). The workspace's compose provides no #{database} service: point this at yours.",
      ~s|DATABASE_URL="ecto://user:pass@localhost/#{app}_prod"|
    )
  end
end
