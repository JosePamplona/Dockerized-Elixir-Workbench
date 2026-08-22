defmodule Mix.Tasks.Workbench.Install.Rest do
  use Igniter.Mix.Task

  @example "mix workbench.install.rest --project-name \"Lorem Ipsum\" --health"
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

      #{@example}

  ## Options

  * `--project-name` - Display name for the OpenAPI Info title
    (default: capitalized app name).
  * `--auth0` - Include the bearer security scheme and the users tag.
  * `--openai` - Include the assistant request params and conversations tag.
  * `--health` - Include the development operations tag.
  """

  @tag_user """
  %Tag{
    name: "User Operations",
    description:
      "Endpoints set for managing and interacting with system's users data. These endpoints ensure secure handling of user information."
  }\
  """
  @tag_conversation """
  %Tag{
    name: "Conversation Operations",
    description:
      "Endpoints set for managing and interacting with assistant conversations. These endpoints allow users to start, retrieve, continue, and delete conversations while ensuring data persistence and consistency."
  }\
  """
  @tag_health """
  %Tag{
    name: "Development Operations",
    description:
      "Set of development operations endpoints intended for system monitoring."
  }\
  """
  @tag_default """
  %Tag{
    name: "Operations",
    description: "Set of default operations endpoints."
  }\
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [
        project_name: :string,
        auth0: :boolean,
        openai: :boolean,
        health: :boolean
      ],
      defaults: [auth0: false, openai: false, health: false]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts =
      Keyword.put_new_lazy(igniter.args.options, :project_name, fn ->
        Mix.Project.config()[:app] |> to_string() |> String.capitalize()
      end)

    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    spec_module = Module.concat([web_module, OpenApi, Spec])
    web_dir = web_module |> inspect() |> Macro.underscore()

    case Igniter.Project.Module.module_exists(igniter, spec_module) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(spec_module)} already exists: REST/OpenAPI is already installed, skipping."
        )

      {false, igniter} ->
        install(igniter, app_name, web_module, web_dir, opts)
    end
  end

  defp install(igniter, app_name, web_module, web_dir, opts) do
    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)

    igniter
    |> Igniter.Project.Deps.add_dep({:open_api_spex, "~> 3.21"}, on_exists: :skip)
    |> Igniter.Project.IgniterConfig.dont_move_file_pattern(~r"/controllers/")
    |> create_open_api_modules(web_module, opts)
    |> add_controller_aliases(web_module)
    |> adjust_router(router, app_name, web_module)
    |> create_tests(web_module, web_dir)
  end

  # --- OpenApi helper modules -------------------------------------------------

  defp create_open_api_modules(igniter, web_module, opts) do
    assigns = [
      web_module: inspect(web_module),
      project_name: opts[:project_name],
      auth0: opts[:auth0],
      openai: opts[:openai],
      open_api_aliases: open_api_aliases(opts),
      tags: tags(opts)
    ]

    igniter
    |> Igniter.Project.Module.create_module(
      Module.concat([web_module, OpenApi, Spec]),
      WorkbenchIgniter.template("rest/spec.eex", assigns)
    )
    |> Igniter.Project.Module.create_module(
      Module.concat([web_module, OpenApi, Requests]),
      WorkbenchIgniter.template("rest/requests.eex", assigns)
    )
    |> Igniter.Project.Module.create_module(
      Module.concat([web_module, OpenApi, Responses]),
      WorkbenchIgniter.template("rest/responses.eex", assigns)
    )
    |> Igniter.Project.Module.create_module(
      Module.concat([web_module, OpenApi, Schemas]),
      WorkbenchIgniter.template("rest/schemas.eex", assigns)
    )
  end

  defp open_api_aliases(opts) do
    ~w(Info OpenApi Paths Server Tag)
    |> Kernel.++(if opts[:auth0], do: ~w(Components SecurityScheme), else: [])
    |> Enum.sort()
    |> Enum.join(", ")
  end

  defp tags(opts) do
    default? = not (opts[:auth0] or opts[:openai] or opts[:health])

    [
      opts[:auth0] && @tag_user,
      opts[:openai] && @tag_conversation,
      opts[:health] && @tag_health,
      default? && @tag_default
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.map_join(",\n", &indent(&1, 6))
  end

  defp indent(content, spaces) do
    pad = String.duplicate(" ", spaces)

    content
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> pad <> line
    end)
  end

  # --- Web module (lib/my_app_web.ex) -----------------------------------------

  defp add_controller_aliases(igniter, web_module) do
    aliases = """
    alias OpenApiSpex.Schema
    alias #{inspect(web_module)}.OpenApi.{Requests, Responses, Schemas}
    """

    Igniter.Project.Module.find_and_update_module!(igniter, web_module, fn zipper ->
      with {:ok, zipper} <- Igniter.Code.Function.move_to_def(zipper, :controller, 0),
           {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, :quote, 1),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
        {:ok, Igniter.Code.Common.add_code(zipper, aliases, placement: :after)}
      else
        :error ->
          {:warning,
           """
           Could not add the OpenApi aliases to the controller block of \
           #{inspect(web_module)}. Please add them manually:

           #{aliases}\
           """}
      end
    end)
  end

  # --- Router -----------------------------------------------------------------

  defp adjust_router(igniter, router, app_name, web_module) do
    igniter
    |> Igniter.Libs.Phoenix.add_pipeline(
      :open_api_spec,
      "plug OpenApiSpex.Plug.PutApiSpec, module: #{inspect(web_module)}.OpenApi.Spec",
      router: router,
      warn_on_present?: false
    )
    |> Igniter.Libs.Phoenix.add_scope(
      "/api/v1",
      """
      pipe_through :api

      # API REST endpoints
      """,
      arg2: web_module,
      router: router
    )
    |> add_dev_routes(router, app_name)
  end

  defp add_dev_routes(igniter, router, app_name) do
    code = """
    # Enable Swagger documentation in development
    if Application.compile_env(:#{app_name}, :dev_routes) do
      scope "/dev" do
        pipe_through [:fetch_session, :protect_from_forgery]

        # SwaggerUI interface for REST-API documentation
        get "/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/dev/openapi"
      end

      # OpenAPI schema (json file)
      scope "/dev" do
        pipe_through [:api, :open_api_spec]

        get "/openapi", OpenApiSpex.Plug.RenderSpec, []
      end
    end
    """

    Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
      # The zipper is at the module body; add_code with :after places the
      # block at the bottom of the module (same as add_scope's placement).
      {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :after)}
    end)
  end

  # --- Unit tests -------------------------------------------------------------

  defp create_tests(igniter, web_module, web_dir) do
    assigns = [web_module: inspect(web_module)]

    igniter
    |> Igniter.Project.Module.create_module(
      Module.concat(web_module, OpenApiControllerTest),
      WorkbenchIgniter.template("rest/open_api_controller_test.eex", assigns),
      path: "test/#{web_dir}/controllers/open_api_controller_test.exs"
    )
    |> Igniter.Project.Module.create_module(
      Module.concat(web_module, SwaggerControllerTest),
      WorkbenchIgniter.template("rest/swagger_controller_test.eex", assigns),
      path: "test/#{web_dir}/controllers/swagger_controller_test.exs"
    )
  end
end
