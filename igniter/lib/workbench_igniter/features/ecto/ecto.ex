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

  The workspace's compose is the workbench's: it provides the server
  the adapter needs — a Postgres, a MySQL or an MSSQL, configured with
  phx.new's own dev credentials — and, for SQLite in a release, a
  volume for the file. Which one is this cartridge's `services/1` to
  say, off the adapter it reads; `connection/2` is the one table of
  those credentials, the compose and `.env` both written from it.
  Inserting Ecto into a project whose compose was baked without a
  database is what `./wb.sh bake` is for, and `wb.sh add ecto` says so.

  Inserted once: changing the database of a project with data is a
  migration, not a flag. The mark is the `ecto_sql` dependency.
  """
  use WorkbenchIgniter.Feature

  # phx.new's own words for each, from `mix help phx.new`.
  @databases [
    {"postgres", "via postgrex — a Postgres in the workspace's compose"},
    {"mysql", "via myxql — a MySQL in the workspace's compose"},
    {"mssql", "via tds — an MSSQL in the workspace's compose"},
    {"sqlite3", "via ecto_sqlite3 — a file; a volume for it in a release"}
  ]

  # phx.new's own dev credentials per server, which the compose's
  # service is configured to answer to: one table, read by the `.env`
  # line below and by the compose templates.
  @credentials %{
    "postgres" => %{user: "postgres", password: "postgres", port: 5432},
    "mysql" => %{user: "root", password: "", port: 3306},
    "mssql" => %{user: "sa", password: "some!Password", port: 1433}
  }

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
    do:
      "./wb.sh bake puts the database into the workspace's compose, then ./wb.sh setup creates it."

  @impl true
  def option_docs do
    [
      database:
        "The database adapter, as `phx.new --database` names them: `postgres` (default), `mysql`, `mssql`, `sqlite3`. The workspace's compose provides the server; SQLite is a file, with a volume for it in a release.",
      binary_id:
        "`binary_id` as the primary key type of the Ecto schemas the generators make (`phx.new --binary-id`): the `generators` entry of `config.exs`."
    ]
  end

  # The mark: the ecto_sql dependency, the first thing --no-ecto leaves out.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, :ecto_sql)

  # The adapter, as phx.new names it, read off the driver in the deps —
  # the same reading the status makes of the project's shape; postgres
  # when no other driver says otherwise.
  @impl true
  # Both options, as the project carries them: the database off the
  # adapter, and `binary_id` off the generators entry. It reported the
  # database alone until 2026-09-10, so a project born with
  # `--binary-id` read as if it had not been.
  def state(igniter) do
    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)
    {%{database: facts.database, binary_id: facts.binary_id}, igniter}
  end

  # The server the adapter needs, in the workspace: one of the three, by
  # engine. pgAdmin is a cartridge of its own (pgadmin), no longer
  # riding with the database. SQLite runs no server, but a release still
  # needs a place for its file that outlives the container — a data
  # volume — so it is a service the project asks the workspace for too.
  @impl true
  def services(%{database: "postgres"}), do: ["postgres"]
  def services(%{database: "mysql"}), do: ["mysql"]
  def services(%{database: "mssql"}), do: ["mssql"]
  def services(%{database: "sqlite3"}), do: ["sqlite"]
  def services(_state), do: []

  @doc """
  phx.new's dev credentials for a server adapter — `user`, `password`,
  `port` — which the workspace's compose configures its service with.
  `nil` for SQLite, which has none.
  """
  @spec credentials(String.t()) ::
          %{user: String.t(), password: String.t(), port: pos_integer()} | nil
  def credentials(database), do: @credentials[database]

  @doc """
  The `.env` line the release reads to find its database
  (`config/runtime.exs`, from phx.new): `DATABASE_URL` for a server —
  the workspace's, on localhost inside the pod, with the credentials
  above — or `DATABASE_PATH` for SQLite, the path inside the release
  container where the compose mounts the `data` volume. Written here
  after an insert and by `workbench.setup` for a project born with Ecto.
  """
  @spec connection(String.t(), atom() | String.t()) :: String.t()
  def connection("sqlite3", app), do: ~s|DATABASE_PATH="/app/data/#{app}_prod.db"|

  def connection(database, app) do
    %{user: user, password: password, port: port} = credentials(database)
    ~s|DATABASE_URL="ecto://#{user}:#{password}@localhost:#{port}/#{app}_prod"|
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    database = igniter.args.options[:database] || "postgres"

    if List.keymember?(@databases, database, 0) do
      case installed?(igniter) do
        {true, igniter} ->
          Igniter.add_notice(igniter, "ecto_sql is already a dependency: Ecto is in, skipping.")

        {false, igniter} ->
          app = Igniter.Project.Application.app_name(igniter)

          igniter
          |> WorkbenchIgniter.PhxDelta.apply(:ecto, %{
            database: database,
            binary_id: igniter.args.options[:binary_id] == true
          })
          |> env_entry(app, database)
      end
    else
      Igniter.add_issue(
        igniter,
        "Unknown --database #{inspect(database)}. One of: #{Enum.map_join(@databases, ", ", &elem(&1, 0))}."
      )
    end
  end

  # What the release reads to find the database: `connection/2`, with a
  # word on where it points.
  defp env_entry(igniter, app, "sqlite3") do
    WorkbenchIgniter.env_entry(
      igniter,
      "Path of the SQLite file the release opens (:prod): the workspace's data volume, mounted there.",
      connection("sqlite3", app)
    )
  end

  defp env_entry(igniter, app, database) do
    WorkbenchIgniter.env_entry(
      igniter,
      "Database connection for the release (:prod): the workspace's #{server(database)}, on localhost inside the pod.",
      connection(database, app)
    )
  end

  defp server("postgres"), do: "Postgres"
  defp server("mysql"), do: "MySQL"
  defp server("mssql"), do: "MSSQL"
end
