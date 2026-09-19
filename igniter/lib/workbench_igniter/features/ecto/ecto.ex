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
  database bakes it again, in the insert's own commit (`wb.sh add`).

  Inserted once: changing the database of a project with data is a
  migration, not a flag. The mark is the `ecto_sql` dependency.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.ComposeFile.Service

  embed_compose()

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
      "The database is in the workspace's compose, in this same commit; ./wb.sh setup creates it."

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
  # engine. pgAdmin is a cartridge's (db_admin), no longer
  # riding with the database. SQLite runs no server, but a release still
  # needs a place for its file that outlives the container — a data
  # volume — so it is a service the project asks the workspace for too.
  @impl true
  def services(:any), do: ~w(postgres mysql mssql sqlite)
  def services(%{database: "postgres"}), do: ["postgres"]
  def services(%{database: "mysql"}), do: ["mysql"]
  def services(%{database: "mssql"}), do: ["mssql"]
  def services(%{database: "sqlite3"}), do: ["sqlite"]
  def services(_state), do: []

  # What a database is in a compose file, all of it here: the server by
  # engine; in a release the one-shot `migrate` the app waits for (the
  # dev image migrates itself on boot), with what has to be there before
  # it — the database MSSQL's image cannot create by a variable
  # (`database_init`), a place nobody can write in for the SQLite file
  # (`data_init`) — and, on the bridge network, where the database is
  # now that it is not on localhost. The first in the file (position 10):
  # what administers a database comes after it.
  # The names `services/1` asks by: one per engine.
  @engines ~w(postgres mysql mssql sqlite)

  @impl true
  def compose(%{services: services, deploy: deploy} = context) do
    case Enum.filter(services, &(&1 in @engines)) do
      [] ->
        []

      [_, _ | _] = engines ->
        {:error, "one database at most, got " <> Enum.join(engines, " and ")}

      ["sqlite"] when deploy == :scaled ->
        {:error, "a scaled deployment cannot run on SQLite: the replicas cannot share a file"}

      [_engine] ->
        database = database(services)
        compose(context.topology, database, Map.merge(context, database))
    end
  end

  # The bridge network: the database is not on localhost any more.
  defp compose("scaled", database, context) do
    url = "ecto://#{database.db_user}:#{database.db_password}@database/#{context.app_name}_prod"

    [
      %Service{
        name: "migrate",
        deploys: [:scaled],
        position: 10,
        title: "the one-shot migration",
        role: "job",
        body: compose_fragment("scaled/migrate.yml.eex", context),
        app_waits: [{"migrate", "service_completed_successfully"}],
        app_environment: "    DATABASE_URL: #{url}"
      }
    ] ++
      if(database.engine == "mssql",
        do: [one_shot("database_init", "scaled/database_init.yml.eex", [:scaled], context)],
        else: []
      ) ++
      [
        %Service{
          name: "database",
          deploys: [:scaled],
          position: 10,
          title: "the workspace's database",
          role: "database",
          shells: shells(database),
          listens: database.db_port,
          body: compose_fragment("scaled/#{database.engine}.yml.eex", context)
        }
      ]
  end

  defp compose("pod", database, context) do
    release = [:prod]

    [
      %Service{
        name: "migrate",
        deploys: release,
        position: 10,
        title: "the one-shot migration",
        role: "job",
        body: compose_fragment("pod/migrate.yml.eex", context),
        app_waits: [{"migrate", "service_completed_successfully"}]
      }
    ] ++
      if(database.engine == "mssql",
        do: [one_shot("database_init", "pod/database_init.yml.eex", release, context)],
        else: []
      ) ++
      if(database.sqlite,
        do: [
          %Service{
            name: "data_init",
            deploys: release,
            position: 10,
            title: "the one-shot that hands the data volume to the release",
            role: "job",
            body: compose_fragment("pod/data_init.yml.eex", context),
            app_volumes:
              "      # The SQLite file, on a volume that outlives the container: the\n" <>
                "      # release opens it where DATABASE_PATH (.env) says, /app/data.\n" <>
                "      - data:/app/data",
            volumes:
              "  # The SQLite file of the release: 'delete' drops it with the project.\n  data:"
          }
        ],
        else: []
      ) ++
      if(database.server,
        do: [
          %Service{
            name: "database",
            deploys: [:dev, :prod],
            position: 10,
            title: "the workspace's database",
            role: "database",
            shells: shells(database),
            listens: database.db_port,
            body: compose_fragment("pod/#{database.engine}.yml.eex", context),
            # In dev the app waits for the server itself; in a release, for
            # the migrator, and a migration that completed implies a healthy one.
            app_waits: if(context.dev, do: [{"database", "service_healthy"}], else: [])
          }
        ],
        else: []
      )
  end

  @doc """
  The database among the services a project asks for, as a compose
  fragment reads it: the `engine`, whether it is a `server` (a
  container with a healthcheck) or the `sqlite` file, and the
  credentials the server is configured with (`credentials/1`). What
  this cartridge's own fragments take, and what a neighbour asks —
  Adminer, to say where the database is.
  """
  @spec database([String.t()]) :: %{
          engine: String.t() | nil,
          server: boolean(),
          sqlite: boolean(),
          db_user: String.t() | nil,
          db_password: String.t() | nil,
          db_port: pos_integer() | nil
        }
  def database(services) do
    engine = Enum.find(services, &(&1 in @engines))
    server = engine in ~w(postgres mysql mssql)
    credentials = if server, do: credentials(engine), else: nil

    %{
      engine: engine,
      server: server,
      sqlite: engine == "sqlite",
      db_user: credentials && credentials.user,
      db_password: credentials && credentials.password,
      db_port: credentials && credentials.port
    }
  end

  # What a session on the database can be: its own client first —
  # the reason to open the database is the database, not its
  # filesystem — with the user the compose configures the server with,
  # then the shell its image has.
  defp shells(%{engine: "postgres", db_user: user}),
    do: [%{label: "psql", command: ["psql", "-U", user]}, %{label: "bash", command: ["bash"]}]

  defp shells(%{engine: "mysql", db_user: user}),
    do: [%{label: "mysql", command: ["mysql", "-u", user]}, %{label: "bash", command: ["bash"]}]

  defp shells(%{engine: "mssql", db_user: user, db_password: password}) do
    [
      %{
        label: "sqlcmd",
        command: [
          "/opt/mssql-tools18/bin/sqlcmd",
          "-C",
          "-S",
          "localhost",
          "-U",
          user,
          "-P",
          password
        ]
      },
      %{label: "bash", command: ["bash"]}
    ]
  end

  defp one_shot(name, fragment, deploys, context) do
    %Service{
      name: name,
      deploys: deploys,
      position: 10,
      title: "the one-shot that creates the database",
      role: "job",
      body: compose_fragment(fragment, context)
    }
  end

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
    WorkbenchIgniter.EnvFile.entry(
      igniter,
      "Path of the SQLite file the release opens (:prod): the workspace's data volume, mounted there.",
      connection("sqlite3", app)
    )
  end

  defp env_entry(igniter, app, database) do
    WorkbenchIgniter.EnvFile.entry(
      igniter,
      "Database connection for the release (:prod): the workspace's #{server(database)}, on localhost inside the pod.",
      connection(database, app)
    )
  end

  defp server("postgres"), do: "Postgres"
  defp server("mysql"), do: "MySQL"
  defp server("mssql"), do: "MSSQL"
end
