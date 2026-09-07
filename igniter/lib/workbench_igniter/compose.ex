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
  is in — and the **services**: the containers the project's cartridges
  ask the workspace for, by name (`postgres`, `pgadmin`, `k6`), declared by
  each cartridge's `services/1` and gathered by `Features.services/1`.
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
            postgres_version: String.t(),
            pgadmin_version: String.t(),
            nginx_version: String.t(),
            k6_version: String.t(),
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
              postgres_version: "latest",
              pgadmin_version: "latest",
              nginx_version: "alpine",
              k6_version: "latest",
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
    postgres_version: :string,
    pgadmin_version: :string,
    nginx_version: :string,
    k6_version: :string,
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

  # What the deployment's template reads and has no default for.
  defp check(%Plan{} = plan) do
    required =
      [:app_name, :image, :dockerfile] ++
        if(plan.deploy == :scaled, do: [], else: [:app_port, :uid, :gid]) ++
        if(plan.deploy != :scaled and "pgadmin" in plan.services, do: [:pgadmin_port], else: [])

    case Enum.filter(required, &is_nil(Map.get(plan, &1))) do
      [] -> {:ok, plan}
      missing -> {:error, "missing: " <> Enum.map_join(missing, ", ", &"--#{flag(&1)}")}
    end
  end

  defp flag(key), do: key |> Atom.to_string() |> String.replace("_", "-")

  @doc "The compose file the plan describes, as text."
  @spec render(Plan.t()) :: String.t()
  def render(%Plan{deploy: :scaled} = plan) do
    scaled(
      app_name: plan.app_name,
      image: plan.image,
      dockerfile: plan.dockerfile,
      internal_port: plan.internal_port,
      postgres_version: plan.postgres_version,
      nginx_version: plan.nginx_version,
      k6_version: plan.k6_version,
      database: "postgres" in plan.services,
      k6: "k6" in plan.services,
      clustering: plan.clustering,
      replicas: Enum.with_index(plan.replica_ports, fn port, i -> {i + 1, port} end),
      balancer: plan.balancer_port != nil,
      balancer_port: plan.balancer_port
    )
  end

  def render(%Plan{deploy: deploy} = plan) do
    dev = deploy == :dev
    postgres = "postgres" in plan.services

    pod(
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
      postgres: postgres,
      pgadmin: "pgadmin" in plan.services,
      k6: "k6" in plan.services,
      dev: dev,
      # The release migrates as a deployment step, before the app; the
      # dev image migrates itself on boot, so its file has no migrator.
      migrate: not dev and postgres,
      app_waits_for: if(dev, do: "database", else: "migrate"),
      app_waits_until: if(dev, do: "service_healthy", else: "service_completed_successfully")
    )
  end
end
