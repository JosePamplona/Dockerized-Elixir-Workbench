defmodule WorkbenchIgniter.Features.Rest do
  @moduledoc """
  REST API with OpenApiSpex documentation. Mutually exclusive with
  GraphQL: chiefs_setup inserts one of the two, as its `--interface`
  choice says (rest is the default).

  Full feature cartridge: manifest, install logic and the EEx templates it
  renders live in this directory, and the `Mix.Tasks.Workbench.Install.Rest`
  shell in `task.ex` delegates here.

  Ordering: inserted before healthcheck, so healthcheck autodetects the
  `OpenApi.Spec` module in the patch set and generates its
  OpenApiSpex-documented variant (chiefs_setup keeps that order).
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.rest --project-name \"Lorem Ipsum\" --health"

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

  @impl true
  def task, do: "workbench.install.rest"

  @impl true
  def console, do: [doors: [{"swagger", "/dev/swagger"}, {"openapi", "/dev/openapi"}]]

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      project_name: "Display name for the OpenAPI Info title (default: capitalized app name).",
      auth0: "Include the bearer security scheme and the users tag.",
      openai: "Include the assistant request params and conversations tag.",
      health: "Include the development operations tag."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
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

  # The mark: the OpenAPI spec module.
  @impl true
  def installed?(igniter),
    do: Igniter.Project.Module.module_exists(igniter, open_api_spec(igniter))

  defp open_api_spec(igniter),
    do: Module.concat([Igniter.Libs.Phoenix.web_module(igniter), OpenApi, Spec])

  # What the project carries, read off the spec module the mark is: the
  # title of its `%Info{}`, the bearer scheme --auth0 adds, and the tags
  # --openai and --health add (`@tag_conversation`, `@tag_health`).
  @impl true
  def state(igniter) do
    case Igniter.Project.Module.find_module(igniter, open_api_spec(igniter)) do
      {:ok, {igniter, source, _zipper}} ->
        spec = Rewrite.Source.get(source, :content)

        title =
          case Regex.run(~r/title:\s*"([^"]*)"/, spec) do
            [_, title] -> title
            nil -> nil
          end

        {%{
           project_name: title,
           auth0: String.contains?(spec, "%SecurityScheme{"),
           openai: String.contains?(spec, ~s|name: "Conversation Operations"|),
           health: String.contains?(spec, ~s|name: "Development Operations"|)
         }, igniter}

      {:error, igniter} ->
        {%{project_name: nil, auth0: false, openai: false, health: false}, igniter}
    end
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts =
      Keyword.put_new_lazy(igniter.args.options, :project_name, fn ->
        Mix.Project.config()[:app] |> to_string() |> String.capitalize()
      end)

    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    spec_module = open_api_spec(igniter)
    # phx.new derives its directories from the app name; deriving them from
    # the module (Macro.underscore/1) diverges on names carrying digits
    # (app :lorem_3 -> Lorem3Web -> "lorem3_web" instead of "lorem_3_web").
    web_dir = "#{app_name}_web"

    case installed?(igniter) do
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
      template("spec.eex", assigns)
    )
    |> Igniter.Project.Module.create_module(
      Module.concat([web_module, OpenApi, Requests]),
      template("requests.eex", assigns)
    )
    |> Igniter.Project.Module.create_module(
      Module.concat([web_module, OpenApi, Responses]),
      template("responses.eex", assigns)
    )
    |> Igniter.Project.Module.create_module(
      Module.concat([web_module, OpenApi, Schemas]),
      template("schemas.eex", assigns)
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
      template("open_api_controller_test.eex", assigns),
      path: "test/#{web_dir}/controllers/open_api_controller_test.exs"
    )
    |> Igniter.Project.Module.create_module(
      Module.concat(web_module, SwaggerControllerTest),
      template("swagger_controller_test.eex", assigns),
      path: "test/#{web_dir}/controllers/swagger_controller_test.exs"
    )
  end
end
