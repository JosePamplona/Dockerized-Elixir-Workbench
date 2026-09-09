defmodule WorkbenchIgniter.Compose do
  @moduledoc """
  The workspace's compose files, rendered from a plan.

  A plan names the deployment — `dev`, `prod` or `scaled` — and with it
  the topology: dev and prod are the **pod** (every service in one
  network namespace, reaching each other on `localhost`), the scaled
  deployment a **bridge** network with one IP per replica. The rest is
  what the script knows and the templates cannot: the project's name,
  the image and the Dockerfile, the host ports (chosen on the host, so
  handed over), the service versions, whether the clustering cartridge
  is in — and the **services**: what the project's cartridges ask the
  workspace for, by name — a database (`postgres`, `mysql`, `mssql`,
  or `sqlite`: no server, a volume for the file in a release), `pgadmin`,
  `k6`, `prometheus` and `grafana` — declared by each cartridge's
  `services/1` and gathered by `Features.services/1`. One database at most; the servers take the
  credentials phx.new configures the project with
  (`WorkbenchIgniter.Features.Ecto.credentials/1`), so the compose and
  the project agree without a line of configuration.
  They arrive as `--services`, or, when the flag is absent, are read off
  the project the task runs in. `render/1` writes the YAML the two
  templates under `priv/compose/` describe; `mix workbench.compose` is
  the shell around it that `wb.sh bake` runs into the workspace.

  The templates carry the prose of the files they write: a compose the
  reader opens should say why it is shaped as it is. Their control tags
  sit at the end of the line before a block and at the end of the
  block's last line, so a block that is out leaves no blank behind.
  """

  defmodule Plan do
    @moduledoc "What one compose file is made of. Built by `WorkbenchIgniter.Compose.plan_from_argv/1`."

    @type deploy :: :dev | :prod | :scaled

    @type t :: %__MODULE__{
            deploy: deploy(),
            app_name: String.t(),
            image: String.t(),
            dockerfile: String.t(),
            uid: pos_integer() | nil,
            gid: pos_integer() | nil,
            app_port: pos_integer() | nil,
            internal_port: pos_integer(),
            pgadmin_port: pos_integer() | nil,
            pgadmin_internal_port: pos_integer(),
            grafana_port: pos_integer() | nil,
            grafana_internal_port: pos_integer(),
            postgres_version: String.t(),
            pgadmin_version: String.t(),
            nginx_version: String.t(),
            k6_version: String.t(),
            mysql_version: String.t(),
            mssql_version: String.t(),
            prometheus_version: String.t(),
            grafana_version: String.t(),
            services: [String.t()],
            clustering: boolean(),
            replicas: pos_integer(),
            replica_ports: [pos_integer()],
            balancer_port: pos_integer() | nil
          }

    defstruct deploy: nil,
              app_name: nil,
              image: nil,
              dockerfile: nil,
              uid: nil,
              gid: nil,
              app_port: nil,
              internal_port: 4000,
              pgadmin_port: nil,
              pgadmin_internal_port: 5050,
              grafana_port: nil,
              grafana_internal_port: 3000,
              postgres_version: "latest",
              pgadmin_version: "latest",
              nginx_version: "alpine",
              k6_version: "latest",
              mysql_version: "8",
              mssql_version: "2022-latest",
              prometheus_version: "latest",
              grafana_version: "latest",
              services: [],
              clustering: false,
              replicas: 4,
              replica_ports: [],
              balancer_port: nil
  end

  require EEx

  @pod Path.expand("../../priv/compose/pod.yml.eex", __DIR__)
  @scaled Path.expand("../../priv/compose/scaled.yml.eex", __DIR__)
  @external_resource @pod
  @external_resource @scaled

  EEx.function_from_file(:defp, :pod, @pod, [:assigns])
  EEx.function_from_file(:defp, :scaled, @scaled, [:assigns])

  @switches [
    deploy: :string,
    app_name: :string,
    image: :string,
    dockerfile: :string,
    uid: :integer,
    gid: :integer,
    app_port: :integer,
    internal_port: :integer,
    pgadmin_port: :integer,
    pgadmin_internal_port: :integer,
    grafana_port: :integer,
    grafana_internal_port: :integer,
    postgres_version: :string,
    pgadmin_version: :string,
    nginx_version: :string,
    k6_version: :string,
    mysql_version: :string,
    mssql_version: :string,
    prometheus_version: :string,
    grafana_version: :string,
    services: :string,
    clustering: :boolean,
    replicas: :integer,
    replica_ports: :string,
    balancer_port: :integer,
    balancer: :boolean,
    out: :string
  ]

  @doc """
  The plan a `mix workbench.compose` argv describes, or why it does not.

  The services come from `--services` when it is there — names
  separated by commas, `""` or `none` for no service at all — and from
  `read_services` otherwise: by default the project the task runs in,
  through `services/1`. `--out` is the task's, not the plan's, and is
  accepted here so one argv serves both.
  """
  @spec plan_from_argv([String.t()], (-> [String.t()])) :: {:ok, Plan.t()} | {:error, String.t()}
  def plan_from_argv(argv, read_services \\ &project_services/0) do
    case OptionParser.parse(argv, strict: @switches) do
      {opts, [], []} -> build(opts, read_services)
      {_, _, [{flag, _} | _]} -> {:error, "unknown or malformed option #{flag}"}
      {_, [arg | _], _} -> {:error, "unexpected argument #{inspect(arg)}"}
    end
  end

  @doc """
  The services the project asks for, off its installed cartridges
  (`WorkbenchIgniter.Features.services/1`). Same shape as the status
  readings: the igniter comes back with the files it read.
  """
  @spec services(Igniter.t()) :: {[String.t()], Igniter.t()}
  def services(igniter), do: WorkbenchIgniter.Features.services(igniter)

  # The project the task runs in, read as `workbench.status` reads it:
  # a plain task, only the rewrite application that reads the source.
  defp project_services do
    Application.ensure_all_started(:rewrite)
    {services, _igniter} = services(Igniter.new())
    services
  end

  defp build(opts, read_services) do
    with {:ok, deploy} <- deploy(opts[:deploy]),
         {:ok, ports} <- replica_ports(deploy, opts) do
      plan =
        struct(Plan, Keyword.drop(opts, [:deploy, :replica_ports, :balancer, :services, :out]))
        |> Map.put(:deploy, deploy)
        |> Map.put(:replica_ports, ports)
        |> Map.put(:services, services_of(opts, read_services))
        # `--no-balancer` is the one way to leave it out; a port means it is in.
        |> Map.update!(:balancer_port, &if(opts[:balancer] == false, do: nil, else: &1))

      check(plan)
    end
  end

  # Named on the command line, or asked of the project when they are not.
  defp services_of(opts, read_services) do
    case Keyword.fetch(opts, :services) do
      {:ok, "none"} -> []
      {:ok, list} -> list |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
      :error -> read_services.()
    end
  end

  defp deploy("dev"), do: {:ok, :dev}
  defp deploy("prod"), do: {:ok, :prod}
  defp deploy("scaled"), do: {:ok, :scaled}
  defp deploy(nil), do: {:error, "--deploy is required: dev, prod or scaled"}
  defp deploy(other), do: {:error, "unknown deployment #{inspect(other)}: dev, prod or scaled"}

  # One host port per replica, in order; only the scaled deployment has them.
  defp replica_ports(:scaled, opts) do
    replicas = Keyword.get(opts, :replicas, 4)
    ports = opts[:replica_ports] || ""

    parsed =
      ports
      |> String.split(",", trim: true)
      |> Enum.map(&Integer.parse/1)

    cond do
      Enum.any?(parsed, &(&1 == :error or elem(&1, 1) != "")) ->
        {:error, "--replica-ports takes host ports separated by commas, got #{inspect(ports)}"}

      length(parsed) != replicas ->
        {:error, "--replica-ports names #{length(parsed)} ports for #{replicas} replicas"}

      true ->
        {:ok, Enum.map(parsed, &elem(&1, 0))}
    end
  end

  defp replica_ports(_deploy, _opts), do: {:ok, []}

  @databases ~w(postgres mysql mssql sqlite)

  @doc """
  The services a deployment's file declares for what the project asks —
  off the same conditions the templates render by, so the answer and
  the file cannot disagree. `names` must all be in the file; `optional`
  may be (the balancer, which `--no-balancer` leaves out); `replicas`
  says the scaled file's `app1`…`appN` stand where the pod's `app` is.
  What `WorkbenchIgniter.Deployments` compares each baked file against.
  """
  @spec service_names(Plan.deploy(), [String.t()]) :: %{
          names: [String.t()],
          optional: [String.t()],
          replicas: boolean()
        }
  def service_names(deploy, services) when deploy in [:dev, :prod, :scaled] do
    engine = Enum.find(services, &(&1 in @databases))
    server = engine in ~w(postgres mysql mssql)
    sqlite = engine == "sqlite"
    init = if(engine == "mssql", do: ["database_init"], else: [])

    case deploy do
      :scaled ->
        # No pod, no pgAdmin: the scaled template renders neither.
        %{
          names:
            if(server, do: ["migrate"] ++ init ++ ["database"], else: []) ++
              for(s <- ~w(k6 prometheus grafana), s in services, do: s),
          optional: ["balancer"],
          replicas: true
        }

      deploy ->
        dev = deploy == :dev

        %{
          names:
            ["network", "app"] ++
              if(not dev and (server or sqlite), do: ["migrate"], else: []) ++
              init ++
              if(sqlite and not dev, do: ["data_init"], else: []) ++
              if(server, do: ["database"], else: []) ++
              for(s <- ~w(pgadmin k6 prometheus grafana), s in services, do: s),
          optional: [],
          replicas: false
        }
    end
  end

  # What the deployment's template reads and has no default for, and
  # the two shapes no file can take: two databases, or replicas on a file.
  defp check(%Plan{} = plan) do
    missing = Enum.filter(required(plan), &is_nil(Map.get(plan, &1)))
    databases = Enum.filter(plan.services, &(&1 in @databases))

    cond do
      missing != [] ->
        {:error, "missing: " <> Enum.map_join(missing, ", ", &"--#{flag(&1)}")}

      length(databases) > 1 ->
        {:error, "one database at most, got " <> Enum.join(databases, " and ")}

      plan.deploy == :scaled and "sqlite" in databases ->
        {:error, "a scaled deployment cannot run on SQLite: the replicas cannot share a file"}

      true ->
        {:ok, plan}
    end
  end

  # The pod deployments need the app's port and the build identity; a
  # port is asked for with the service that publishes it — pgAdmin's on
  # the pod, Grafana's on every topology.
  defp required(%Plan{deploy: deploy, services: services}) do
    pod = deploy != :scaled

    [:app_name, :image, :dockerfile] ++
      if(pod, do: [:app_port, :uid, :gid], else: []) ++
      if(pod and "pgadmin" in services, do: [:pgadmin_port], else: []) ++
      if("grafana" in services, do: [:grafana_port], else: [])
  end

  defp flag(key), do: key |> Atom.to_string() |> String.replace("_", "-")

  # The database the plan carries, as the templates read it: the engine,
  # whether it is a server (a container with a healthcheck) or the file,
  # and the credentials the server is configured with.
  defp database(%Plan{services: services}) do
    engine = Enum.find(services, &(&1 in @databases))
    server = engine in ~w(postgres mysql mssql)
    credentials = if server, do: WorkbenchIgniter.Features.Ecto.credentials(engine), else: nil

    [
      engine: engine,
      server: server,
      sqlite: engine == "sqlite",
      db_user: credentials && credentials.user,
      db_password: credentials && credentials.password
    ]
  end

  @doc "The compose file the plan describes, as text."
  @spec render(Plan.t()) :: String.t()
  def render(%Plan{deploy: :scaled} = plan) do
    scaled(
      [
        app_name: plan.app_name,
        image: plan.image,
        dockerfile: plan.dockerfile,
        internal_port: plan.internal_port,
        postgres_version: plan.postgres_version,
        nginx_version: plan.nginx_version,
        k6_version: plan.k6_version,
        mysql_version: plan.mysql_version,
        mssql_version: plan.mssql_version,
        prometheus_version: plan.prometheus_version,
        grafana_version: plan.grafana_version,
        grafana_port: plan.grafana_port,
        grafana_internal_port: plan.grafana_internal_port,
        k6: "k6" in plan.services,
        prometheus: "prometheus" in plan.services,
        grafana: "grafana" in plan.services,
        # What every replica waits for: the migration, and Grafana when
        # the app uploads its dashboards there on start.
        app_waits:
          if(database(plan)[:server],
            do: [{"migrate", "service_completed_successfully"}],
            else: []
          ) ++
            if("grafana" in plan.services, do: [{"grafana", "service_healthy"}], else: []),
        clustering: plan.clustering,
        replicas: Enum.with_index(plan.replica_ports, fn port, i -> {i + 1, port} end),
        balancer: plan.balancer_port != nil,
        balancer_port: plan.balancer_port
      ] ++ database(plan)
    )
  end

  def render(%Plan{deploy: deploy} = plan) do
    dev = deploy == :dev
    database = database(plan)
    server = database[:server]

    pod(
      [
        app_name: plan.app_name,
        image: plan.image,
        dockerfile: plan.dockerfile,
        uid: plan.uid,
        gid: plan.gid,
        app_port: plan.app_port,
        internal_port: plan.internal_port,
        pgadmin_port: plan.pgadmin_port,
        pgadmin_internal_port: plan.pgadmin_internal_port,
        postgres_version: plan.postgres_version,
        pgadmin_version: plan.pgadmin_version,
        k6_version: plan.k6_version,
        mysql_version: plan.mysql_version,
        mssql_version: plan.mssql_version,
        prometheus_version: plan.prometheus_version,
        grafana_version: plan.grafana_version,
        grafana_port: plan.grafana_port,
        grafana_internal_port: plan.grafana_internal_port,
        postgres: database[:engine] == "postgres",
        pgadmin: "pgadmin" in plan.services,
        k6: "k6" in plan.services,
        prometheus: "prometheus" in plan.services,
        grafana: "grafana" in plan.services,
        dev: dev,
        # The release migrates as a deployment step, before the app — on a
        # server or on the SQLite file; the dev image migrates itself on
        # boot, so its file has no migrator. The app waits for the migrator
        # in a release, and for the server in dev; for nothing on a file —
        # and for Grafana, when it uploads its dashboards there on start.
        migrate: not dev and (server or database[:sqlite]),
        app_waits:
          if(dev,
            do: if(server, do: [{"database", "service_healthy"}], else: []),
            else:
              if(server or database[:sqlite],
                do: [{"migrate", "service_completed_successfully"}],
                else: []
              )
          ) ++
            if("grafana" in plan.services, do: [{"grafana", "service_healthy"}], else: [])
      ] ++ database
    )
  end
end
