defmodule Mix.Tasks.Workbench.Install.HealthProbe do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.HealthProbe

  @shortdoc "Adds liveness and readiness probes as the first plug of the endpoint"

  @moduledoc """
  #{@shortdoc}

  The vanilla health check: what a container orchestrator or a load
  balancer consumes, and nothing else. It installs

  * `MyAppWeb.Plugs.Health`, answering `GET /health/live` (200 while the
    VM answers) and `GET /health/ready` (200 when the application can
    take traffic, 503 when it cannot — `SELECT 1` on the repo with a
    one-second timeout)
  * its test, in `test/my_app_web/plugs/health_test.exs`
  * `plug MyAppWeb.Plugs.Health` as the first plug of `MyAppWeb.Endpoint`,
    so a probe never reaches `Plug.Static`, `Plug.SSL`, the logger, the
    parsers, the session or the router

  No dependency, no config, no router change. When the project has no
  `MyApp.Repo` (`phx.new --no-ecto`), `/ready` answers like `/live`.

  Re-running it is a no-op: when the plug module already exists nothing
  is touched and a notice says so.

  ## Example

      #{HealthProbe.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(HealthProbe)}

  ## Wiring the platform

  The same release answers all three; only the platform config differs.

      # Kubernetes
      startupProbe:   { httpGet: { path: /health/ready, port: 4000 }, failureThreshold: 30, periodSeconds: 5 }
      livenessProbe:  { httpGet: { path: /health/live,  port: 4000 }, periodSeconds: 10 }
      readinessProbe: { httpGet: { path: /health/ready, port: 4000 }, periodSeconds: 10, timeoutSeconds: 2 }

      # Fly.io (fly.toml) - one check type: point it at readiness
      [[http_service.checks]]
        path = "/health/ready"
        grace_period = "15s"
        interval = "10s"
        timeout = "2s"

      # AWS ECS - ALB target group on /health/ready; optional container
      # healthCheck on /health/live (needs curl in the image)

  The cartridge README carries the full wiring; DESIGN.md, the
  reasoning behind the split and its sources.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: HealthProbe.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: HealthProbe.install(igniter)
end
