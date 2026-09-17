defmodule Mix.Tasks.Workbench.Install.Healthcheck do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Healthcheck

  @shortdoc "Adds a healthcheck endpoint with controller, tests and router scope"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_healthcheck` feature:

  * adds `{:mock, "~> 0.3", only: :test}` to the project deps
  * enables `dev_routes` in `config/test.exs` (the endpoint returns extended
    info only when dev routes are enabled)
  * creates `MyAppWeb.HealthcheckController`
  * creates the controller unit tests
  * adds a scope with the healthcheck route to the Phoenix router

  All changes are accumulated in a single patch set and shown as a diff
  before being applied (pass `--yes` to skip confirmation).

  ## Example

      mix workbench.install.healthcheck

  When the project has the REST/OpenAPI feature (`workbench.install.rest`) —
  detected by the presence of `MyAppWeb.OpenApi.Spec`, or forced with
  `--open-api` — the controller is generated with OpenApiSpex specs and a
  `MyAppWeb.OpenApi.Schemas.Healthcheck` schema module is added.

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Healthcheck)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Healthcheck.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Healthcheck.install(igniter)
end
