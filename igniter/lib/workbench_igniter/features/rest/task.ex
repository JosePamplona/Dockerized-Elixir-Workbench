defmodule Mix.Tasks.Workbench.Install.Rest do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Rest

  @shortdoc "Adds OpenAPI (open_api_spex) REST documentation to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_rest` feature:

  * adds `{:open_api_spex, "~> 3.21"}` to the project deps
  * creates the `MyAppWeb.OpenApi.{Spec, Requests, Responses, Schemas}`
    helper modules
  * aliases `OpenApiSpex.Schema` and the OpenApi helpers inside the
    `controller` quote block of the web module, so generated controllers
    can use them unqualified
  * router: adds the `:open_api_spec` pipeline, an `/api/v1` scope as the
    anchor for future REST endpoints, and dev routes for the OpenAPI JSON
    (`/dev/openapi`) and SwaggerUI (`/dev/swagger`)
  * plants the controller unit tests

  Unlike the bash version, routes reference `OpenApiSpex.Plug.*` fully
  qualified (no fragile alias insertion) and the dev routes live in their
  own `if dev_routes` block, valid with or without mailer/dashboard.

  ## Example

      mix workbench.install.rest --project-name "Lorem Ipsum" --health

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Rest)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Rest.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(Rest, igniter)
end
