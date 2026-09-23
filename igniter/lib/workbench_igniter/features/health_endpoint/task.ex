defmodule Mix.Tasks.Workbench.Install.HealthEndpoint do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.HealthEndpoint

  @shortdoc "Adds a health endpoint with controller, tests and router scope"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_healthcheck` feature:

  * adds `{:mock, "~> 0.3", only: :test}` to the project deps
  * enables `dev_routes` in `config/test.exs` (the endpoint returns extended
    info only when dev routes are enabled)
  * creates `MyAppWeb.HealthcheckController`
  * creates the controller unit tests
  * adds a scope with the health route to the Phoenix router

  All changes are accumulated in a single patch set and shown as a diff
  before being applied (pass `--yes` to skip confirmation).

  ## Example

      mix workbench.install.health_endpoint

  When the project has the REST/OpenAPI feature (`workbench.install.rest`) —
  detected by the presence of `MyAppWeb.OpenApi.Spec`, or forced with
  `--open-api` — the controller is generated with OpenApiSpex specs and a
  `MyAppWeb.OpenApi.Schemas.Healthcheck` schema module is added.

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(HealthEndpoint)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: HealthEndpoint.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(HealthEndpoint, igniter)
end
