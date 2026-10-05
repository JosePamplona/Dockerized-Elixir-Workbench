defmodule Mix.Tasks.Workbench.Install.Graphql do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Graphql

  @shortdoc "Adds an Absinthe GraphQL API served at /graphiql to the project"

  @moduledoc """
  #{@shortdoc}

  Implements the GraphQL interface that `implement_graphql` in app.sh left
  as a stub (its TODO plan: Absinthe deps, `Web.Graphql` modules, router
  adjustment):

  * adds `absinthe`, `absinthe_plug` and `absinthe_error_payload` to the
    project deps
  * creates `MyAppWeb.Graphql.Schema` with a starter `version` query
  * router: forwards `/graphiql` to `Absinthe.Plug.GraphiQL` — the same
    URL serves the IDE (GET) and the API endpoint (POST), as the generated
    README documents
  * plants the endpoint unit tests

  ## Example

      mix workbench.install.graphql
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Graphql.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(Graphql, igniter)
end
