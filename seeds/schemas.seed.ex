defmodule %{elixir_module}Web.OpenApi.Schemas do
  @moduledoc false
  <!-- workbench-healthcheck open -->
  alias OpenApiSpex.Schema

  defmodule Health do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "Health-check response on develop enviroment.",
      type:        :object,
      properties: %{
        app: %Schema{
          type: :object,
          properties: %{
            service: %Schema{type: :string, description: "Application name."},
            version: %Schema{type: :string, description: "Software version."},
            env: %Schema{
              type: :string,
              description: "Server enviroment variable value."
            },
            elixir: %Schema{
              type: :string,
              description: "Server elixir version."
            },
            erlang: %Schema{
              type: :string,
              description: "Server erlang version."
            },
            time: %Schema{
              type: :timestamp,
              description: "Server current time."
            }
          }
        },
        databases: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              repo: %Schema{
                type: :string,
                description: "Database repository module."
              },
              time: %Schema{
                type: :timestamp,
                description: "Database server current time."
              },
              version: %Schema{type: :string, description: "Database version."}
            }
          }
        }
      },
      required: [],
      example: %{
        "app" => %{
          "elixir" => "Elixir 1.16.2 (compiled with Erlang/OTP 25)",
          "env" => "dev",
          "erlang" =>
            "Erlang/OTP 25 [erts-13.2.2.7] [source] [64-bit] [smp:12:12] [ds:12:12:10] [async-threads:1] [jit:ns]",
          "service" => "%{project_name}",
          "time" => "2024-06-10T06:56:59.174707",
          "version" => "0.0.0"
        },
        "databases" => [
          %{
            "repo" => "Elixir.%{elixir_module}.Repo",
            "time" => "2024-06-10T06:56:59.174086Z",
            "version" =>
              "PostgreSQL 16.2 on x86_64-pc-linux-musl, compiled by gcc (Alpine 13.2.1_git20231014) 13.2.1 20231014, 64-bit"
          }
        ]
      }
    })
  end
  <!-- workbench-healthcheck close -->
end
