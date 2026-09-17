defmodule WorkbenchIgniter.Features.Monitoring do
  @moduledoc """
  Metrics and dashboards: PromEx in the application, Prometheus and
  Grafana in the workspace.

  The Elixir side is PromEx — the dependency, a `MyApp.PromEx` module
  naming the plugins the project's shape calls for (Application, Beam,
  Phoenix; Ecto with a repo; LiveView with `phoenix_live_view`), its
  configuration, the first place in the supervision tree, and the
  `PromEx.Plug` before `Plug.Telemetry` in the endpoint, which serves
  `/metrics` on the app's port. The workspace side is two containers
  this cartridge *declares* (`services/1`: `"prometheus"`, `"grafana"`)
  and defines (`compose/1`), baked into the compose in the insert's own
  commit, each
  opening with a file the project owns: `monitoring/prometheus.yml`, the
  scrape configuration, and `monitoring/grafana/datasource.yml`, the
  provisioned datasource. What is the topology's — where the app is for
  Prometheus, where Prometheus is for Grafana, where Grafana is for the
  app — the compose hands over, so the three files say nothing about it.

  Grafana opens on its own port beside the app's, signed in already, with
  the dashboards PromEx uploads when the application starts: one per
  plugin. The mark is the PromEx module, the one thing the endpoint edit
  cannot be guarded by on its own. No requirement: a Phoenix project is
  all the Phoenix plugin asks for.
  """
  use WorkbenchIgniter.Feature

  embed_templates()
  embed_assets()
  embed_compose()

  @prometheus "monitoring/prometheus.yml"
  @datasource "monitoring/grafana/datasource.yml"

  @doc "The Prometheus configuration this cartridge writes, the project's own."
  def prometheus_file, do: @prometheus

  @doc "The Grafana datasource this cartridge writes, provisioned at start."
  def datasource_file, do: @datasource

  @impl true
  def task, do: "workbench.install.monitoring"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: the PromEx module (the endpoint edit always prepends, so
  # the whole install is guarded by it).
  @impl true
  def installed?(igniter),
    do: Igniter.Project.Module.module_exists(igniter, prom_ex_module(igniter))

  defp prom_ex_module(igniter),
    do: Module.concat(Igniter.Project.Module.module_name_prefix(igniter), PromEx)

  # The two containers, by name: Prometheus on the
  # app's /metrics and Grafana on Prometheus, Grafana's port published
  # beside the app's.
  @impl true
  def services(_state), do: ["prometheus", "grafana"]

  # The two containers, whole, on either topology. Prometheus: its block
  # (which opens its receiver when k6 is a neighbour) and its configs —
  # the project's file and the targets, which are the topology's.
  # Grafana: its block, its port — in the pod's slot, or in its own block
  # on the bridge network — its datasource config, and what the app
  # owes it: the app uploads its dashboards there on start, so it waits
  # for Grafana to be healthy, and on the bridge network is told where
  # it is.
  @impl true
  def compose(%{services: services, topology: topology} = context) do
    alias WorkbenchIgniter.ComposeFile.Service

    # Grafana's port is said to it (GF_SERVER_HTTP_PORT); Prometheus's is its image's.
    context = Map.merge(context, %{k6: "k6" in services, listens: 3000})

    if("prometheus" in services,
      do: [
        %Service{
          name: "prometheus",
          position: 50,
          title: "the Prometheus container",
          role: "observability",
          # busybox: `sh` is the shell it has.
          shells: [%{label: "sh", command: ["sh"]}],
          listens: 9090,
          body: compose_fragment("#{topology}/prometheus.yml.eex", context),
          configs: compose_fragment("#{topology}/prometheus.configs.yml.eex", context)
        }
      ],
      else: []
    ) ++
      if("grafana" in services,
        do: [
          %Service{
            name: "grafana",
            position: 60,
            title: "the Grafana container",
            role: "observability",
            # An Alpine image: `sh` is the shell it has.
            shells: [%{label: "sh", command: ["sh"]}],
            listens: 3000,
            ports: [
              %{
                name: :grafana,
                internal: 3000,
                default: 3000,
                comment: [
                  "Grafana port, with the monitoring cartridge in. Prometheus is not",
                  "published: Grafana reads it from inside this workspace."
                ]
              }
            ],
            body: compose_fragment("#{topology}/grafana.yml.eex", context),
            configs: compose_fragment("#{topology}/grafana.configs.yml.eex", context),
            app_waits: [{"grafana", "service_healthy"}],
            app_environment:
              if(topology == "scaled",
                do:
                  "    # Where the dashboards go on start (config/runtime.exs): Grafana by\n" <>
                    "    # its name here, where the pod had it on localhost.\n" <>
                    "    GRAFANA_HOST: http://grafana:3000"
              )
          }
        ],
        else: []
      )
  end

  # The metrics, a door on the app's port; Grafana is the workbench's
  # own door, off the port the compose published for it.
  @impl true
  def console, do: [doors: [{"metrics", "/metrics"}]]

  @impl true
  def afterwards,
    do:
      "Prometheus and Grafana are in the workspace's compose, in this same commit; the next up brings them up, and Grafana opens with the dashboards."

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(prom_ex_module(igniter))} already exists: monitoring is in, skipping."
        )

      {false, igniter} ->
        install_all(igniter)
    end
  end

  defp install_all(igniter) do
    # Everything below is derived from the target project.
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    prom_ex = prom_ex_module(igniter)
    endpoint = Module.concat(web_module, Endpoint)

    # Which plugins: a repo gets the Ecto plugin, phoenix_live_view the
    # LiveView one — the dependency, not the live cartridge's mark, since
    # the dashboard rides LiveView too and its metrics are as real.
    {repo?, igniter} =
      Igniter.Project.Module.module_exists(igniter, Module.concat(app_module, Repo))

    live? = Igniter.Project.Deps.has_dep?(igniter, :phoenix_live_view)

    assigns = [
      app_name: app_name,
      app_module: inspect(app_module),
      web_module: inspect(web_module),
      ecto: repo?,
      live: live?
    ]

    igniter
    |> Igniter.Project.Deps.add_dep({:prom_ex, "~> 1.12"}, on_exists: :skip)
    |> Igniter.Project.Module.create_module(
      prom_ex,
      template("prom_ex.ex.eex", assigns),
      path: "lib/#{app_name}/prom_ex.ex"
    )
    |> configure(app_name, prom_ex)
    # First in the tree: PromEx captures the init events of what starts
    # after it — the repo, the endpoint.
    |> Igniter.Project.Application.add_new_child(prom_ex)
    |> mount_plug(endpoint, prom_ex)
    |> Igniter.create_new_file(@prometheus, asset("prometheus.yml"))
    |> Igniter.create_new_file(@datasource, asset("grafana/datasource.yml"))
  end

  # What PromEx's own generator writes, less the Grafana client, which
  # is the runtime's — before the env file is imported, so test.exs has
  # the last word; PromEx off there, where nothing scrapes and no
  # Grafana listens; and the Grafana client read at runtime, since the
  # release image is built once and runs on both topologies, so its
  # address cannot be compiled in.
  defp configure(igniter, app_name, prom_ex) do
    igniter
    |> add_config(
      "config/config.exs",
      """
      # Workbench monitoring: PromEx, whose plugins MyApp.PromEx names.
      # The Grafana client is configured in runtime.exs, where the
      # workspace's address is read.
      config :#{app_name}, #{inspect(prom_ex)},
        disabled: false,
        manual_metrics_start_delay: :no_delay,
        drop_metrics_groups: [],
        metrics_server: :disabled

      """
      |> String.replace("MyApp.PromEx", inspect(prom_ex)),
      before: "import_config"
    )
    |> add_config(
      "config/test.exs",
      """

      # Workbench monitoring: nothing scrapes a test and no Grafana
      # listens, so PromEx starts nothing.
      config :#{app_name}, #{inspect(prom_ex)}, disabled: true
      """
    )
    |> add_config(
      "config/runtime.exs",
      """

      # Workbench monitoring: where the workspace's Grafana is, for the
      # dashboards PromEx uploads when the application starts. On the pod
      # topology (dev and prod) it is on localhost; on the scaled network
      # the compose names it. The credentials are the ones the compose
      # starts Grafana with.
      config :#{app_name}, #{inspect(prom_ex)},
        grafana: [
          host: System.get_env("GRAFANA_HOST", "http://localhost:3000"),
          username: "admin",
          password: "admin",
          upload_dashboards_on_start: true
        ]
      """
    )
  end

  # A block of configuration in a file the project owns, as text with
  # its comment — before the line `before:` names when it is there, at
  # the end otherwise. The PromEx module's name marks it as present;
  # a project without the file gets it with the block alone.
  defp add_config(igniter, path, block, opts \\ []) do
    # `config :app, App.PromEx`, whatever follows it.
    marker =
      block
      |> String.split("\n")
      |> Enum.find(&String.starts_with?(&1, "config "))
      |> String.split(",")
      |> Enum.take(2)
      |> Enum.join(",")

    if Igniter.exists?(igniter, path) do
      igniter
      |> Igniter.include_existing_file(path)
      |> Igniter.update_file(path, fn source ->
        Rewrite.Source.update(source, :content, &with_block(&1, block, marker, opts[:before]))
      end)
    else
      Igniter.create_new_file(igniter, path, "import Config\n" <> block)
    end
  end

  defp with_block(content, block, marker, before) do
    cond do
      String.contains?(content, marker) ->
        content

      before && String.contains?(content, before) ->
        String.replace(content, before, block <> before, global: false)

      true ->
        String.trim_trailing(content, "\n") <> "\n" <> block
    end
  end

  # Before `plug Plug.Telemetry`, as PromEx asks: a scrape is not a
  # request of the app, and served there it is not measured as one.
  # Without that plug — an endpoint edited past recognition — before the
  # first plug there is, or at the end of an endpoint with none.
  defp mount_plug(igniter, endpoint, prom_ex) do
    code = """
    # Workbench monitoring: the metrics Prometheus scrapes, before the
    # telemetry so a scrape is not counted among the requests.
    plug PromEx.Plug, prom_ex_module: #{inspect(prom_ex)}
    """

    telemetry? = &Igniter.Code.Function.argument_equals?(&1, 0, Plug.Telemetry)

    Igniter.Project.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
      with :error <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :plug,
               :any,
               telemetry?
             ),
           :error <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, :plug, :any) do
        {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :after)}
      else
        {:ok, zipper} -> {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :before)}
      end
    end)
  end
end
