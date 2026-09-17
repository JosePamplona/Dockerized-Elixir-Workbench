defmodule WorkbenchIgniter.Compose do
  @moduledoc """
  The workspace's compose files, rendered from a plan.

  A plan names the deployment — `dev`, `prod` or `scaled` — and with it
  the topology: dev and prod are the **pod** (every service in one
  network namespace, reaching each other on `localhost`), the scaled
  deployment a **bridge** network with one IP per replica. The rest is
  what the script knows and the templates cannot: the project's name,
  the image and the Dockerfile, the app's host port, whether the
  clustering cartridge is in — and the **services**: what the project's
  cartridges ask the workspace for, by name, asked for by each
  cartridge's `services/1` (gathered by `Features.services/1`) and
  defined by the same cartridge's `compose/1`. Nothing about a service
  is written here, nor named: a service's image tag arrives as
  `--version NAME=TAG` (the cartridge has the default), and a port it
  publishes as `--port NAME=PORT` — or is kept where the file already
  has it (`--keep-ports-of FILE`): a port is chosen once, on the host,
  and the file is where it lives. One the plan has from neither is a
  **need** (`{:needs, …}`), named with the default its cartridge
  declares, for the host to find a free one from.
  They arrive as `--services`, or, when the flag is absent, are read off
  the project the task runs in. `render/1` writes the topology's
  skeleton — the two templates under `priv/compose/`: the pod and the
  app, or the replicas and the balancer — with the cartridges'
  contributions set into its slots (`WorkbenchIgniter.ComposeFile`);
  `mix workbench.compose` is the shell around it that `wb.sh bake` runs
  into the workspace.

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
            uid: non_neg_integer() | nil,
            gid: non_neg_integer() | nil,
            app_port: non_neg_integer() | nil,
            internal_port: pos_integer(),
            ports: %{atom() => non_neg_integer()},
            versions: %{String.t() => String.t()},
            keep: String.t() | nil,
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
              ports: %{},
              versions: %{},
              keep: nil,
              services: [],
              clustering: false,
              replicas: 4,
              replica_ports: [],
              balancer_port: nil
  end

  alias WorkbenchIgniter.ComposeFile

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
    port: [:string, :keep],
    version: [:string, :keep],
    keep_ports_of: :string,
    services: :string,
    clustering: :boolean,
    replicas: :integer,
    replica_ports: :string,
    balancer_port: :integer,
    balancer: :boolean,
    out: :string
  ]

  @typedoc "A port a service publishes that the plan has no host port for, with its cartridge's default."
  @type need :: {name :: atom(), default :: pos_integer()}

  @doc """
  The plan a `mix workbench.compose` argv describes, or why it does not
  — or, as `{:needs, needs}`, the ports the host still has to choose.

  The services come from `--services` when it is there — names
  separated by commas, `""` or `none` for no service at all — and from
  `read_services` otherwise: by default the project the task runs in,
  through `services/1`. `--out` is the task's, not the plan's, and is
  accepted here so one argv serves both.
  """
  @spec plan_from_argv([String.t()], (-> [String.t()])) ::
          {:ok, Plan.t()} | {:needs, [need()]} | {:error, String.t()}
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
         {:ok, replica_ports} <- replica_ports(deploy, opts),
         {:ok, ports} <- pairs(opts, :port, &port/1),
         {:ok, versions} <- pairs(opts, :version, &{:ok, &1}) do
      dropped = [
        :deploy,
        :replica_ports,
        :balancer,
        :services,
        :out,
        :port,
        :version,
        :keep_ports_of
      ]

      plan =
        struct(Plan, Keyword.drop(opts, dropped))
        |> Map.put(:deploy, deploy)
        |> Map.put(:replica_ports, replica_ports)
        |> Map.put(:ports, Map.new(ports, fn {name, port} -> {String.to_atom(name), port} end))
        |> Map.put(:versions, Map.new(versions))
        |> Map.put(:keep, kept(opts[:keep_ports_of]))
        |> Map.put(:services, services_of(opts, read_services))
        # `--no-balancer` is the one way to leave it out; a port means it is in.
        |> Map.update!(:balancer_port, &if(opts[:balancer] == false, do: nil, else: &1))

      check(plan)
    end
  end

  # `--port NAME=PORT` and `--version NAME=TAG`, as many as there are.
  defp pairs(opts, key, value) do
    opts
    |> Keyword.get_values(key)
    |> Enum.reduce_while({:ok, []}, fn pair, {:ok, acc} ->
      with [name, raw] when name != "" <- String.split(pair, "=", parts: 2),
           {:ok, parsed} <- value.(raw) do
        {:cont, {:ok, acc ++ [{name, parsed}]}}
      else
        _ -> {:halt, {:error, "--#{key} takes NAME=VALUE, got #{inspect(pair)}"}}
      end
    end)
  end

  defp port(raw) do
    case Integer.parse(raw) do
      {port, ""} when port > 0 -> {:ok, port}
      _ -> :error
    end
  end

  # The file whose ports are kept, as it stands; none the first time.
  defp kept(nil), do: nil

  defp kept(path) do
    case File.read(path) do
      {:ok, text} -> text
      _ -> nil
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

  @doc """
  The services a deployment's file declares for what the project asks —
  read off the same contributions the file is rendered from
  (`Features.compose/1`), so the answer and the file cannot disagree.
  `names` must all be in the file; `optional` may be (the balancer,
  which `--no-balancer` leaves out); `replicas` says the scaled file's
  `app1`…`appN` stand where the pod's `app` is. What
  `WorkbenchIgniter.Deployments` compares each baked file against.
  A set of services no file can be made of declares nothing.
  """
  @spec service_names(Plan.deploy(), [String.t()]) :: %{
          names: [String.t()],
          optional: [String.t()],
          replicas: boolean()
        }
  def service_names(deploy, services) when deploy in [:dev, :prod, :scaled] do
    # The names do not depend on the values; any plan of this shape says them.
    plan = %Plan{
      deploy: deploy,
      services: services,
      app_name: "app",
      image: "app",
      dockerfile: "Dockerfile",
      uid: 0,
      gid: 0,
      app_port: 0
    }

    contributed =
      case contributions(plan, %{}) do
        {:ok, services} ->
          Enum.flat_map(services, &ComposeFile.services("services:\n" <> &1.body))

        {:error, _} ->
          []
      end

    if deploy == :scaled,
      do: %{names: contributed, optional: ["balancer"], replicas: true},
      else: %{names: ["pod", "app"] ++ contributed, optional: [], replicas: false}
  end

  @doc """
  The compose services one cartridge brings to a project that asks for
  `services`, across the three deployments: each by its name in the
  file, once, with the `deploys` it enters, the port it `listens` on
  inside (`nil` for one that answers nowhere), the ones of its own the
  host `published`es, and what it is to whoever draws it — `title`,
  `role`, `image`, `shells`, `position` (`WorkbenchIgniter.ComposeFile`).
  What the catalog and the status carry per cartridge, so that nothing
  downstream knows a service by name.
  """
  @spec brought(module(), [String.t()]) :: [map()]
  def brought(feature, services) do
    for deploy <- [:dev, :prod, :scaled],
        service <- contributed(feature, deploy, services),
        deploy in service.deploys,
        reduce: [] do
      acc ->
        case Enum.find_index(acc, &(&1.service == service.name)) do
          nil -> acc ++ [face(service, deploy)]
          i -> List.update_at(acc, i, &%{&1 | deploys: &1.deploys ++ [Atom.to_string(deploy)]})
        end
    end
  end

  @doc """
  The images of the house: every repository a compose the workbench
  bakes may run — the skeletons' own (the pod's pause, the balancer's
  nginx) and what each cartridge's services run, whichever of its names
  a project asks by (`services(:any)`). Without tags, sorted. What tells
  a daemon's images apart as the workbench's, with no list kept by hand.
  """
  @spec images() :: [String.t()]
  def images do
    skeleton =
      for file <- [@pod, @scaled],
          [_, repository] <- Regex.scan(~r/^ +image: ([a-z0-9][^\s:<]*)/m, File.read!(file)),
          do: repository

    brought =
      for feature <- WorkbenchIgniter.Features.catalog(),
          names = feature.services(:any),
          asked <- [names | Enum.map(names, &[&1])],
          %{image: image} when is_binary(image) <- brought(feature, asked),
          do: image

    Enum.sort(Enum.uniq(skeleton ++ brought))
  end

  defp contributed(feature, deploy, services) do
    plan = %Plan{
      deploy: deploy,
      services: services,
      app_name: "app",
      image: "app",
      dockerfile: "Dockerfile",
      uid: 0,
      gid: 0,
      app_port: 0
    }

    case feature.compose(context(plan)) do
      {:error, _} -> []
      contributed -> contributed
    end
  end

  defp face(service, deploy) do
    %{
      service: service.name,
      deploys: [Atom.to_string(deploy)],
      listens: service.listens,
      published: Enum.map(service.ports, & &1.internal),
      title: service.title,
      role: service.role,
      # The app's own image, for a one-shot on it, is nobody's to link.
      image: if(ComposeFile.image(service) == "app", do: nil, else: ComposeFile.image(service)),
      shells: service.shells,
      position: service.position
    }
  end

  # What the deployment's skeleton reads and has no default for; then
  # what the cartridges refuse (two databases, replicas on a file); then
  # the ports their services publish, each given, kept, or needed.
  defp check(%Plan{} = plan) do
    missing = Enum.filter(required(plan), &is_nil(Map.get(plan, &1)))

    with [] <- missing,
         {:ok, services} <- contributions(plan, %{}) do
      case needs(plan, services) do
        [] -> {:ok, plan}
        needs -> {:needs, needs}
      end
    else
      [_ | _] -> {:error, "missing: " <> Enum.map_join(missing, ", ", &"--#{flag(&1)}")}
      {:error, reason} -> {:error, reason}
    end
  end

  # The pod deployments need the app's port and the build identity.
  defp required(%Plan{deploy: deploy}) do
    [:app_name, :image, :dockerfile] ++
      if(deploy != :scaled, do: [:app_port, :uid, :gid], else: [])
  end

  defp flag(key), do: key |> Atom.to_string() |> String.replace("_", "-")

  defp needs(plan, services) do
    resolved = host_ports(plan, services)

    for s <- services,
        port <- s.ports,
        not Map.has_key?(resolved, port.name),
        do: {port.name, port.default}
  end

  # A port handed over wins; else the one the kept file publishes it on.
  defp host_ports(plan, services) do
    for s <- services,
        port <- s.ports,
        host =
          plan.ports[port.name] || (plan.keep && ComposeFile.host_port(plan.keep, port.internal)),
        into: %{},
        do: {port.name, host}
  end

  @doc """
  What a file is rendered from, as the skeletons and the cartridges'
  fragments read it (`@key`): the deployment (`deploy`, `dev`, and the
  `topology`, `"pod"` or `"scaled"`), the project (`app_name`, `image`,
  `dockerfile`, `uid`, `gid`, `internal_port`), the topology's own
  (`replicas`, `balancer`, `clustering`), every service asked for
  (`services`, by which a service sees its neighbours), the host ports
  resolved so far (`host_ports`) and `version`, which answers a
  service's image tag given its name and the cartridge's default.
  """
  @spec context(Plan.t(), %{atom() => pos_integer()}) :: map()
  def context(%Plan{} = plan, host_ports \\ %{}) do
    versions = plan.versions

    plan
    |> Map.from_struct()
    |> Map.drop([:ports, :versions, :keep])
    |> Map.merge(%{
      dev: plan.deploy == :dev,
      topology: if(plan.deploy == :scaled, do: "scaled", else: "pod"),
      replicas: Enum.with_index(plan.replica_ports, fn port, i -> {i + 1, port} end),
      balancer: plan.balancer_port != nil,
      host_ports: host_ports,
      version: fn name, default -> Map.get(versions, name, default) end
    })
  end

  # What the cartridges' services contribute to this plan's file, in
  # the file's order — or what one of them refuses.
  defp contributions(%Plan{} = plan, host_ports) do
    with {:ok, services} <- WorkbenchIgniter.Features.compose(context(plan, host_ports)) do
      {:ok, services |> Enum.filter(&(plan.deploy in &1.deploys)) |> Enum.sort_by(& &1.position)}
    end
  end

  @doc """
  The compose file the plan describes, as text: the topology's skeleton
  (`priv/compose/`) with what each cartridge's services contribute
  (`compose/1`) set into its slots by `WorkbenchIgniter.ComposeFile`.
  A plan `plan_from_argv/2` answered `:ok` for renders; another raises.
  """
  @spec render(Plan.t()) :: String.t()
  def render(%Plan{} = plan) do
    # Twice: the asks say which ports there are, and a service on the
    # bridge network writes its own into its block.
    with {:ok, asked} <- contributions(plan, %{}),
         host_ports = host_ports(plan, asked),
         {:ok, services} <- contributions(plan, host_ports),
         {:ok, slots} <- ComposeFile.slots(services, plan.deploy, host_ports) do
      assigns = plan |> context(host_ports) |> Map.put(:slots, slots) |> Map.to_list()
      if plan.deploy == :scaled, do: scaled(assigns), else: pod(assigns)
    else
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
