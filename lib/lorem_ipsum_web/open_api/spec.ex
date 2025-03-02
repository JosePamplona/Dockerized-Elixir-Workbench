defmodule LoremIpsumWeb.OpenApi.Spec do
  @moduledoc false

  alias OpenApiSpex.{
    Components,
    Info,
    OpenApi,
    Paths,
    SecurityScheme,
    Server,
    Tag
  }
  alias LoremIpsumWeb.{Endpoint, Router}

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
        title: "Lorem Ipsum",
        version: @version,
        description: """
          Lorem Ipsum provides this collection of REST API endpoints.
          """
      },
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{type: "http", scheme: "bearer"}
        }
      },
      tags: [
        %Tag{
          name: "User Operations",
          description: "Endpoints set for managing and interacting with system's users data. These endpoints ensure secure handling of user information."
        },
        %Tag{
          name: "Conversation Operations",
          description: "Endpoints set for managing and interacting with assistant conversations. These endpoints allow users to start, retrieve, continue, and delete conversations while ensuring data persistence and consistency."
        },
        %Tag{
          name: "Development Operations",
          description: "Set of development operations endpoints intended for system monitoring."
        }
      ]
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
