defmodule %{elixir_module}Web.HealthcheckController do
  @moduledoc """
    Development Operations (DevOps) controller.
    """
  use %{elixir_module}Web, :controller
  use OpenApiSpex.ControllerSpecs

  @env Mix.env()
  @service Mix.Project.config[:app]
  @version Mix.Project.config[:version]

  tags ["Development Operations"]

  operation :health,
    summary: "Healthcheck endpoint.",
    description: """
      In production enviroment works just as a server healthcheck endpoint. In develop enviroment returns application information with optional extra output.
      """,
    parameters: [
      verbose: [
        in: :query,
        description: """
          If set to ___true___, the endpoint will provide full information (only for the development environments).\n
          <small>**Note:** Request verbose increment system calls and database queries, so it takes a little longer to respond (not very suitable for health cheks).</small>\n
          """,
        type: :boolean,
        example: false
      ]
    ],
    responses: [
      Responses.build(
        200,
        "Healthcheck response on development enviroment.",
        %Schema{
          description: "Healthcheck response on develop enviroment.",
          type: :object,
          properties: %{
            app: %Schema{
              type: :object,
              properties: %{
                service: %Schema{
                  type: :string,
                  description: "Application name."
                },
                version: %Schema{
                  type: :string,
                  description: "Software version."
                },
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
                  version: %Schema{
                    type: :string,
                    description: "Database version."
                  }
                }
              }
            }
          },
          required: [],
          example: %{
            app: %{
              elixir: "Elixir 1.16.2 (compiled with Erlang/OTP 25)",
              env: "dev",
              erlang: "Erlang/OTP 25 [erts-13.2.2.7] [source] [64-bit] [smp:12:12] [ds:12:12:10] [async-threads:1] [jit:ns]",
              service: "%{elixir_project_name}",
              time: "2024-06-10T06:56:59.174707",
              version: "0.0.0"
            },
            databases: [
              %{
                repo: "Elixir.%{elixir_module}.Repo",
                time: "2024-06-10T06:56:59.174086Z",
                version: "PostgreSQL 16.2 on x86_64-pc-linux-musl, compiled by gcc (Alpine 13.2.1_git20231014) 13.2.1 20231014, 64-bit"
              }
            ]
          }
        }
      )
    ]

  @doc """
    Always responds with a 200 success code.

    This controller works differently depending on the current development
    environment. In non development enviroments works just as a server 
    healthcheck endpoint. In development enviroments returns application
    information with optional extra output.

    ## Development response body
        %{
          app: %{
            env: "dev",
            service: "%{elixir_project_name}",
            version: "0.0.0",
            time: nil,
            elixir: nil,
            erlang: nil
          },
          databases: [
            %{
              repo: "Elixir.%{elixir_module}.Repo",
              time: nil,
              version: nil
            }
          ]
        }

    ## Development response body with extra output
        %{
          app: %{
            env: "dev",
            service: "%{elixir_project_name}",
            version: "0.0.0",
            time: "2024-06-10T06:56:59.174707",
            elixir: "Elixir 1.16.2 (compiled with Erlang/OTP 25)",
            erlang: "Erlang/OTP 25 [erts-13.2.2.7] [source] [64-bit] [smp:12:12] [ds:12:12:10] [async-threads:1] [jit:ns]"
          },
          databases: [
            %{
              repo: "Elixir.%{elixir_module}.Repo",
              time: "2024-06-10T06:56:59.174086Z",
              version: "PostgreSQL 16.2 on x86_64-pc-linux-musl, compiled by gcc (Alpine 13.2.1_git20231014) 13.2.1 20231014, 64-bit"
            }
          ]
        }

    ## Production response body
        %{health: "😊"}
    """

  @spec health(
      conn :: Plug.Conn.t,
      params :: %{optional(binary) => any}
    ) :: Plug.Conn.t

  def health(conn, params) do
    info =
      case Application.get_env(:%{elixir_project_name}, :dev_routes) do
        true -> info(params)
        _    -> %{health: "😊"}
      end

    conn
    |> put_status(200)
    |> json(info)
  end

  # --- Private ----------------------------------------------------------------

  defp info(params) do
    verbose =
      case params["verbose"] do
        nil   -> false
        value -> String.downcase(value) == "true" || value == "1"
      end

    {time, erlang, elixir} = server(verbose)

    %{
      app: %{
        service: @service,
        env: @env,
        version: @version,
        elixir: elixir,
        erlang: erlang,
        time: time
      },
      databases: databases(@service, verbose)
    }
  end

  defp server(verbose) do
    case verbose do
      false -> {nil, nil, nil}
      _ ->
        [erlang, elixir] =
          try do
            {versions, 0} = System.cmd("elixir", ["-v"])
            versions
            |> String.split("\n")
            |> Enum.reject(fn(e) -> e == "" end)
          rescue
            error -> ["", inspect(error)]
          end

        {NaiveDateTime.utc_now(), erlang, elixir}
    end
  end

  defp databases(service, verbose) do
    service
    |> Application.get_env(:ecto_repos)
    |> Enum.map(fn(repo) ->
      [version, time] =
        case verbose do
          false -> [nil, nil]
          _ ->
            try do
              {:ok, %{rows: [[version]]}} = repo.query("SELECT version();")
              {:ok, %{rows: [[time]]}}    = repo.query("SELECT now();")
              [version, time]
            rescue
              error -> [inspect(error), ""]
            end
        end

      %{repo: repo, version: version, time: time}
    end)
  end
end
