defmodule PitchersWeb.HealthController do  
  @moduledoc false
  use PitchersWeb, :controller
  use OpenApiSpex.ControllerSpecs

  @env Mix.env()
  @service Mix.Project.config[:app]
  @version Mix.Project.config[:version]

  # --- Development Information & Production Server health check ---------------

  tags ["Health-check"]

  operation :health,
    summary: "Health check endpoint.",
    description: """
      In production eviroment works just as a server healthcheck enpoint.
      In develop enviroment returns application information with optional extra 
      output.
      """,
    parameters: [
      verbose: [
        in: :query,
        description: """
          If is set to `true` the endpoint will give full information (only for
          develop enviroment). <br/>
          *Note: Request verbose increment system calls and database
          queries, so it takes a little longer to respond (not very suitable for
          health-cheks).*
          """,
        type: :boolean,
        example: false
      ]
    ],
    responses: [
      ok: {
        "Health-check response on development enviroment.",
        "application/json",
        PitchersWeb.OpenApi.Schemas.Health
      }
    ]

  def health(conn, params) do
    if Application.get_env(:pitchers, :dev_routes),
      do:   json(conn, info(params)),
      else: json(conn, %{health: "😊"})
  end

  # === Private ================================================================

  defp info(%{} = params) do
    verbose =
      case params["verbose"] do
        nil   -> false
        value -> String.downcase(value) == "true"
      end
    
    app =
      [verbose, %{service: @service, env: @env, version: @version}]
      |> case do
        [false, data] -> data
        [true, data] ->
          time = NaiveDateTime.utc_now()
          [erlang, elixir] =
            try do
              {versions, 0} = System.cmd("elixir", ["-v"])
              versions
              |> String.split("\n")
              |> Enum.reject(fn(e) -> e == "" end)
            rescue error -> ["", inspect(error)] end

          data |> Map.merge(%{elixir: elixir, erlang: erlang, time: time})
      end

    databases =
      @service
      |> Application.get_env(:ecto_repos)
      |> Enum.map(fn(repo) ->
        [verbose, %{repo: repo}]
        |> case do
          [false, data] -> data
          [true, data] ->
            [version, time] =
              try do
                {:ok, %{rows: [[version]]}} = repo.query("SELECT version();")
                {:ok, %{rows: [[time]]}}    = repo.query("SELECT now();")
                [version, time]
              rescue
                error -> [inspect(error), ""]
              end

            Map.merge(data, %{version: version, time: time})
        end
      end)

    %{
      app: app,
      databases: databases,
      documentation: url(~p"/doc")
    }
  end
end
