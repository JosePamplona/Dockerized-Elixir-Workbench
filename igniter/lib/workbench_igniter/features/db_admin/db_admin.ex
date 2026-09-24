defmodule WorkbenchIgniter.Features.DbAdmin do
  @moduledoc """
  A database admin in the browser, open on the project's database: the
  tables, the rows, a query editor, without typing SQL blind into the
  server's shell client. Four of them, by what each is for (`--admin`,
  one or several):

  | `--admin` | What it is | Serves |
  | --- | --- | --- |
  | `pgadmin` | pgAdmin, Postgres' own: plans, server activity, its dashboards | postgres |
  | `phpmyadmin` | phpMyAdmin, MySQL's own: users, server variables, its exports | mysql |
  | `adminer` | Adminer, one light PHP page on any database | postgres, mysql, mssql, sqlite3 |
  | `cloudbeaver` | CloudBeaver, DBeaver in the browser: ER diagrams, a full SQL editor | postgres, mysql, mssql |

  Each admin says which databases it serves, as a requirement on its
  value (`choices/0`: `{"ecto", database: "postgres"}`), and the
  project's database — read off ecto's own `state/1`, the project as it
  is — decides which can be chosen. Without `--admin` the box is
  **shaped by the database**: its own admin where it has one (pgAdmin on
  Postgres, phpMyAdmin on MySQL), Adminer where it has none (SQL Server,
  SQLite).

  An admin is two things. A **file the project owns**, the one the
  admin opens with — who signs in, on which driver: the project's, off
  its Ecto adapter — and the file is the mark. And a **container in the
  compose**, this cartridge's too: it asks for it by name (`services/1`,
  off the files that are there) and says what it is (`compose/1`, off
  `priv/features/db_admin/compose/`) — where the database is and which
  one to open are the deployment's, so the compose says them. `mix
  workbench.compose` sets that into the workspace's dev and prod files
  in the insert's own commit. The compose is baked from what the project
  carries, never the other way round.

  Each admin is a piece of its own — its file, its container, its port
  — so a second run adds another (`rerun: :adds`), and a file that is
  there is never rewritten.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.ComposeFile.Service
  alias WorkbenchIgniter.Features.Ecto, as: EctoCartridge

  embed_templates()
  embed_compose()

  # The admins, in the order the shelf tells them: the two that are a
  # database's own, then the two that read several. `file` is what the
  # installer writes and the mark; `serves`, ecto's databases as its
  # `state/1` names them.
  @admins [
    %{
      name: "pgadmin",
      file: "pgadmin/servers.json",
      serves: ~w(postgres),
      doc: "pgAdmin, Postgres' own admin"
    },
    %{
      name: "phpmyadmin",
      file: "phpmyadmin/config.user.inc.php",
      serves: ~w(mysql),
      doc: "phpMyAdmin, MySQL's own admin"
    },
    %{
      name: "adminer",
      file: "adminer/login.php",
      serves: ~w(postgres mysql mssql sqlite3),
      doc: "Adminer, one light page on any database"
    },
    %{
      name: "cloudbeaver",
      file: "cloudbeaver/data-sources.json",
      serves: ~w(postgres mysql mssql),
      doc: "CloudBeaver, DBeaver in the browser"
    }
  ]
  @names Enum.map(@admins, & &1.name)
  @databases ~w(postgres mysql mssql sqlite3)

  # Adminer's key for each adapter — the one its URL and its login form
  # name the driver by. MySQL's is `server`, "backwards compatibility"
  # in Adminer's source; SQLite's server is the file, so it has none.
  @adminer_drivers %{
    "postgres" => "pgsql",
    "mysql" => "server",
    "mssql" => "mssql",
    "sqlite3" => "sqlite"
  }

  # CloudBeaver's provider and driver ids, as its driver list names them.
  @cloudbeaver_drivers %{
    "postgres" => {"postgresql", "postgres-jdbc"},
    "mysql" => {"mysql", "mysql8"},
    "mssql" => {"sqlserver", "microsoft"}
  }

  @doc ~s(The file each admin is written as, and marked by: `%{"pgadmin" => "pgadmin/servers.json", …}`.)
  def files, do: Map.new(@admins, &{&1.name, &1.file})

  @impl true
  def task, do: "workbench.install.db_admin"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task() <> " --admin adminer",
      schema: [admin: :csv]
    }
  end

  @impl true
  def option_docs do
    [
      admin:
        "Comma-separated, the admins to put beside the database: `pgadmin` (postgres), `phpmyadmin` (mysql), `adminer` (any database), `cloudbeaver` (postgres, mysql, mssql). No default: at least one is required."
    ]
  end

  # Each value builds on ecto in a state: the databases the admin
  # serves. One that serves them all builds on ecto all the same — it
  # needs a database to open, whichever it is.
  @impl true
  def choices do
    [
      admin:
        for admin <- @admins do
          case admin.serves do
            @databases -> {admin.name, admin.doc, ["ecto"]}
            [database] -> {admin.name, admin.doc, [{"ecto", database: database}]}
            databases -> {admin.name, admin.doc, [{"ecto", database: databases}]}
          end
        end
    ]
  end

  @impl true
  def requires, do: ["ecto"]

  # Each admin is a piece: a second run writes the ones the project
  # lacks and leaves the ones it has.
  @impl true
  def adds, do: [:admin]

  # The mark: the file of any admin.
  @impl true
  def installed?(igniter) do
    {Enum.any?(@admins, &Igniter.exists?(igniter, &1.file)), igniter}
  end

  @doc "What the project carries: the admins whose file is there."
  @impl true
  def state(igniter) do
    {%{admin: for(admin <- @admins, Igniter.exists?(igniter, admin.file), do: admin.name)},
     igniter}
  end

  # The containers, by name: the admins the project carries. Which ones
  # hangs on the state, as ecto's engine does, so the status says it.
  @impl true
  def services(:any), do: @names
  def services(%{admin: admins}), do: admins
  def services(_state), do: []

  @impl true
  def afterwards,
    do: "The admin is in the workspace's compose, in this same commit; the next up brings it up."

  # The containers, whole: each one's block — which reads where the
  # database is off the context, asked of who knows, ecto — and its port
  # on the pod, beside the app's. On the pod only: the pod is one
  # network namespace, where the database answers on 127.0.0.1 without
  # being published; the scaled network has no admin.
  @impl true
  def compose(%{topology: "pod", services: services} = context) do
    context = Map.merge(context, EctoCartridge.database(services))
    for name <- @names, name in services, do: service(name, context)
  end

  def compose(_context), do: []

  defp service("pgadmin", context) do
    # The port pgAdmin is told to listen on (PGADMIN_LISTEN_PORT).
    admin_service("pgadmin", "the pgAdmin container", 20, 5050,
      comment: [
        "pgAdmin port, with db_admin's pgadmin in. The database is not",
        "published: it is only reachable from inside this workspace."
      ],
      body: compose_fragment("pod/pgadmin.yml.eex", Map.put(context, :listens, 5050)),
      configs: compose_fragment("pod/pgadmin.configs.yml.eex", context)
    )
  end

  defp service("phpmyadmin", context) do
    # The port its Apache is told to listen on (APACHE_PORT): the
    # image's 80 moved to one of its own, the pod being one namespace.
    # A Debian image: it has bash.
    admin_service("phpmyadmin", "the phpMyAdmin container", 24, 8081,
      comment: ["phpMyAdmin port, with db_admin's phpmyadmin in."],
      shells: [%{label: "bash", command: ["bash"]}],
      body: compose_fragment("pod/phpmyadmin.yml.eex", Map.put(context, :listens, 8081))
    )
  end

  defp service("adminer", context) do
    # The image's own port.
    admin_service("adminer", "the Adminer container", 30, 8080,
      comment: ["Adminer port, with db_admin's adminer in."],
      body: compose_fragment("pod/adminer.yml.eex", context)
    )
  end

  defp service("cloudbeaver", context) do
    # The image's own port, said to it all the same. An Ubuntu image: it
    # has bash.
    admin_service("cloudbeaver", "the CloudBeaver container", 34, 8978,
      comment: ["CloudBeaver port, with db_admin's cloudbeaver in."],
      shells: [%{label: "bash", command: ["bash"]}],
      body: compose_fragment("pod/cloudbeaver.yml.eex", Map.put(context, :listens, 8978))
    )
  end

  # What the four share: dev tooling on the dev and prod pods, one
  # published port, by default the one it listens on. `sh` unless the
  # admin says otherwise: pgAdmin's and Adminer's are Alpine images.
  defp admin_service(name, title, position, listens, opts) do
    {comment, fields} = Keyword.pop!(opts, :comment)

    struct!(
      %Service{
        name: name,
        deploys: [:dev, :prod],
        position: position,
        title: title,
        role: "devtools",
        shells: [%{label: "sh", command: ["sh"]}],
        listens: listens,
        ports: [
          %{name: String.to_atom(name), internal: listens, default: listens, comment: comment}
        ],
        body: Keyword.fetch!(fields, :body)
      },
      fields
    )
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    case WorkbenchIgniter.Feature.missing_requirements(igniter, __MODULE__) do
      {[], igniter} -> install_admins(igniter)
      {missing, igniter} -> WorkbenchIgniter.Feature.refuse(igniter, __MODULE__, missing)
    end
  end

  # Which database the project is on is a fact about the project, asked
  # of the project through ecto's own `state/1` — never the option ecto
  # was inserted with. It meets, or not, what each chosen admin builds on.
  defp install_admins(igniter) do
    {%{database: database}, igniter} = EctoCartridge.state(igniter)

    # A :csv switch not given parses as [], not nil.
    chosen = Enum.uniq(igniter.args.options[:admin] || [])

    case chosen -- @names do
      _ when chosen == [] ->
        Igniter.add_issue(
          igniter,
          "--admin is required: one or several of #{Enum.join(@names, ", ")}."
        )

      [] ->
        case WorkbenchIgniter.Feature.missing_option_requirements(igniter, __MODULE__,
               admin: chosen
             ) do
          {[], igniter} -> Enum.reduce(chosen, igniter, &write(&2, &1, database))
          {missing, igniter} -> WorkbenchIgniter.Feature.refuse_values(igniter, missing)
        end

      unknown ->
        Igniter.add_issue(
          igniter,
          "--admin takes #{Enum.join(@names, ", ")}, got: #{Enum.join(unknown, ", ")}"
        )
    end
  end

  # A file that is there is the project's: never rewritten.
  defp write(igniter, name, database) do
    path = files()[name]

    if Igniter.exists?(igniter, path) do
      Igniter.add_notice(igniter, "#{path} already exists: #{name} is in, skipping.")
    else
      app = Igniter.Project.Application.app_name(igniter)
      Igniter.create_new_file(igniter, path, file(name, database, app))
    end
  end

  @doc """
  The file an admin opens with, for a database and an app: who signs in
  and on which driver, off ecto's credentials for the adapter — the
  project's. Where the database is and which one to open are the
  deployment's, said by the compose.
  """
  @spec file(String.t(), String.t(), atom() | String.t()) :: String.t()
  def file("pgadmin", "postgres", app),
    do: template("pgadmin/servers.json.eex", app_name: app)

  def file("phpmyadmin", "mysql", app) do
    %{user: user, password: password} = EctoCartridge.credentials("mysql")

    template("phpmyadmin/config.user.inc.php.eex",
      app_name: app,
      username: user,
      password: password
    )
  end

  def file("adminer", database, app),
    do: template("adminer/login.php.eex", login(database, app))

  def file("cloudbeaver", database, app) do
    {provider, driver} = Map.fetch!(@cloudbeaver_drivers, database)
    %{user: user, password: password} = EctoCartridge.credentials(database)

    template("cloudbeaver/data-sources.json.eex",
      app_name: app,
      provider: provider,
      driver: driver,
      username: user,
      password: password
    )
  end

  @doc """
  What Adminer's login file says for an adapter, the dev pod's values:
  Adminer's driver key; the server as `127.0.0.1:port`, off ecto's
  credentials, and the user; the database, `<app>_dev` as phx.new names
  it. SQLite has no server and no user — the database is the dev file,
  where the app's source is mounted.
  """
  @spec login(String.t(), atom() | String.t()) :: keyword()
  def login("sqlite3", app) do
    [
      app_name: app,
      driver: "sqlite",
      server: "",
      username: "",
      database: "/app/src/#{app}_dev.db"
    ]
  end

  def login(database, app) do
    %{user: user, port: port} = EctoCartridge.credentials(database)

    [
      app_name: app,
      driver: Map.fetch!(@adminer_drivers, database),
      server: "127.0.0.1:#{port}",
      username: user,
      database: "#{app}_dev"
    ]
  end
end
