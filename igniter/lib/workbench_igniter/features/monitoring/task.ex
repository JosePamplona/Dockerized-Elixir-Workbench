defmodule Mix.Tasks.Workbench.Install.Monitoring do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Monitoring

  @shortdoc "Adds PromEx to the app, and Prometheus with Grafana to the workspace"

  @moduledoc """
  #{@shortdoc}

  Installs `prom_ex` with a `MyApp.PromEx` module — the plugins the
  project's shape calls for, first in the supervision tree, its
  `/metrics` served by the endpoint before `Plug.Telemetry` — and the
  two files the workspace's containers open with:
  `#{Monitoring.prometheus_file()}` and `#{Monitoring.datasource_file()}`.
  Declares the `prometheus` and `grafana` services the next `./wb.sh
  bake` renders into the compose; Grafana comes up with the dashboards
  PromEx uploads. Idempotent — re-running it is a no-op.

  ## Example

      mix workbench.install.monitoring
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Monitoring.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Monitoring.install(igniter)
end
