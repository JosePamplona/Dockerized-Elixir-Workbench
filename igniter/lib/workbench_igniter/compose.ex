defmodule WorkbenchIgniter.Compose do
  @moduledoc """
  The workspace's compose files, rendered from a plan.

  A plan names the deployment — `dev`, `prod` or `scaled` — and with it
  the topology: dev and prod are the **pod** (every service in one
  network namespace, reaching each other on `localhost`), the scaled
  deployment a **bridge** network with one IP per replica. The rest is
  what the script knows and the templates cannot: the project's name,
  the image and the Dockerfile, the host ports (chosen on the host, so
  handed over), the service versions, and two facts of the project —
  whether it runs on a database server, whether the clustering cartridge
  is in. `render/1` writes the YAML the two templates under
  `priv/compose/` describe; `mix workbench.compose` is the shell around
  it that `wb.sh bake` redirects into the workspace.

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
            database: boolean(),
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
              database: true,
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
    database: :boolean,
    clustering: :boolean,
    replicas: :integer,
    replica_ports: :string,
    balancer_port: :integer,
    balancer: :boolean
  ]

  @doc "The plan a `mix workbench.compose` argv describes, or why it does not."
  @spec plan_from_argv([String.t()]) :: {:ok, Plan.t()} | {:error, String.t()}
  def plan_from_argv(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {opts, [], []} -> build(opts)
      {_, _, [{flag, _} | _]} -> {:error, "unknown or malformed option #{flag}"}
      {_, [arg | _], _} -> {:error, "unexpected argument #{inspect(arg)}"}
    end
  end

  defp build(opts) do
    with {:ok, deploy} <- deploy(opts[:deploy]),
         {:ok, ports} <- replica_ports(deploy, opts) do
      plan =
        struct(Plan, Keyword.drop(opts, [:deploy, :replica_ports, :balancer]))
        |> Map.put(:deploy, deploy)
        |> Map.put(:replica_ports, ports)
        # `--no-balancer` is the one way to leave it out; a port means it is in.
        |> Map.update!(:balancer_port, &if(opts[:balancer] == false, do: nil, else: &1))

      check(plan)
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
        if(plan.deploy != :scaled and plan.database, do: [:pgadmin_port], else: [])

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
      database: plan.database,
      clustering: plan.clustering,
      replicas: Enum.with_index(plan.replica_ports, fn port, i -> {i + 1, port} end),
      balancer: plan.balancer_port != nil,
      balancer_port: plan.balancer_port
    )
  end

  def render(%Plan{deploy: deploy} = plan) do
    dev = deploy == :dev

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
      database: plan.database,
      dev: dev,
      # The release migrates as a deployment step, before the app; the
      # dev image migrates itself on boot, so its file has no migrator.
      migrate: not dev and plan.database,
      app_waits_for: if(dev, do: "database", else: "migrate"),
      app_waits_until: if(dev, do: "service_healthy", else: "service_completed_successfully")
    )
  end
end
