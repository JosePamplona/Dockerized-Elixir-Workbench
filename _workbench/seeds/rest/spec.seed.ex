defmodule %{elixir_module}Web.OpenApi.Spec do
  @moduledoc false

  alias OpenApiSpex.{
    # <!-- workbench-auth0 open -->
    Components,
    # <!-- workbench-auth0 close -->
    Info,
    OpenApi,
    Paths,
    # <!-- workbench-auth0 open -->
    SecurityScheme,
    # <!-- workbench-auth0 close -->
    Server,
    Tag
  }
  alias %{elixir_module}Web.{Endpoint, Router}

  @behaviour OpenApi
  @impl OpenApi
  @version Mix.Project.config[:version]

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
      # <!-- workbench-auth0 open -->
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{type: "http", scheme: "bearer"}
        }
      },
      # <!-- workbench-auth0 close -->
      tags: [
        # <!-- workbench-auth0 open -->
        %Tag{
          name: "User Operations",
          description: "Endpoints set for managing and interacting with system's users data. These endpoints ensure secure handling of user information."
        },
        # <!-- workbench-auth0 close -->
        # <!-- workbench-openai open -->
        %Tag{
          name: "Conversation Operations",
          description: "Endpoints set for managing and interacting with assistant conversations. These endpoints allow users to start, retrieve, continue, and delete conversations while ensuring data persistence and consistency."
        },
        # <!-- workbench-openai close -->
        # <!-- workbench-health open -->
        %Tag{
          name: "Development Operations",
          description: "Set of development operations endpoints intended for system monitoring."
        }
        # <!-- workbench-health close -->
        # <!-- workbench-default open -->
        %Tag{
          name: "Operations",
          description: "Set of default operations endpoints."
        }
        # <!-- workbench-default close -->
      ]
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
