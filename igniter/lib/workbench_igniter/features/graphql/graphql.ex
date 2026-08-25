defmodule WorkbenchIgniter.Features.Graphql do
  @moduledoc """
  GraphQL API with Absinthe. Enabled when `--interface` is `graphql`,
  mutually exclusive with REST.

  Full feature cartridge: manifest, install logic and the EEx templates it
  renders live in this directory, and the
  `Mix.Tasks.Workbench.Install.Graphql` shell in `task.ex` delegates here.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.graphql"

  @impl true
  def task, do: "workbench.install.graphql"

  @impl true
  def enabled?(opts), do: opts[:interface] == "graphql"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example
    }
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    schema = Module.concat([web_module, Graphql, Schema])
    # phx.new derives its directories from the app name; deriving them from
    # the module (Macro.underscore/1) diverges on names carrying digits
    # (app :lorem_3 -> Lorem3Web -> "lorem3_web" instead of "lorem_3_web").
    web_dir = "#{app_name}_web"

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
      template("schema.eex", assigns)
    )
    |> Igniter.Project.Module.create_module(
      Module.concat(web_module, GraphqlTest),
      template("graphql_test.eex", assigns),
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
