defmodule %{elixir_module}Web.OpenApi.Spec do
  @moduledoc false

  alias OpenApiSpex.{Info, OpenApi, Paths, Server}
  alias %{elixir_module}Web.{Endpoint, Router}

  @behaviour OpenApi

  @version Mix.Project.config[:version]

  @impl OpenApi
  @doc false
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "%{project_name}",
        version: @version,
        description: """
          %{project_name} provides this collection of REST API endpoints.
          """
      },
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router),
      tags: [
        <!-- workbench-healthcheck open -->
        %OpenApiSpex.Tag{
          name: "Development Operations",
          description: "Set of development operations endpoints intended for system monitoring."
        }
        <!-- workbench-healthcheck close -->
      ]
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
