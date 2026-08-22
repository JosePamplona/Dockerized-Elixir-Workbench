defmodule Mix.Tasks.Workbench.Install.Graphql do
  use Igniter.Mix.Task

  @example "mix workbench.install.graphql"
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

      #{@example}
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    schema = Module.concat([web_module, Graphql, Schema])
    web_dir = web_module |> inspect() |> Macro.underscore()

    case Igniter.Project.Module.module_exists(igniter, schema) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(schema)} already exists: GraphQL is already installed, skipping."
        )

      {false, igniter} ->
        install(igniter, app_name, web_module, schema, web_dir)
    end
  end

  defp install(igniter, app_name, web_module, schema, web_dir) do
    assigns = [app_name: app_name, web_module: inspect(web_module)]

    igniter
    |> Igniter.Project.Deps.add_dep({:absinthe, "~> 1.7"}, on_exists: :skip)
    |> Igniter.Project.Deps.add_dep({:absinthe_plug, "~> 1.5"}, on_exists: :skip)
    |> Igniter.Project.Deps.add_dep({:absinthe_error_payload, "~> 1.1"}, on_exists: :skip)
    |> Igniter.Project.Module.create_module(
      schema,
      WorkbenchIgniter.template("graphql/schema.eex", assigns)
    )
    |> Igniter.Project.Module.create_module(
      Module.concat(web_module, GraphqlTest),
      WorkbenchIgniter.template("graphql/graphql_test.eex", assigns),
      path: "test/#{web_dir}/graphql_test.exs"
    )
    |> Igniter.Libs.Phoenix.add_scope(
      "/graphiql",
      """
      pipe_through :api

      # GraphQL IDE (GET) and API endpoint (POST)
      forward "/", Absinthe.Plug.GraphiQL,
        schema: #{inspect(schema)},
        json_codec: Jason
      """
    )
  end
end
