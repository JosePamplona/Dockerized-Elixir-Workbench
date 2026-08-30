defmodule WorkbenchIgniter.Features.Auth0 do
  @moduledoc """
  Auth0 JWT authentication with the Accounts context and User schema.

  Full feature cartridge: manifest, install logic and the EEx templates it
  renders live in this directory; the `Mix.Tasks.Workbench.Install.Auth0`
  shell in `task.ex` delegates here.

  Ordering: composed after enhancements (the User schema uses
  `MyApp.Schema`) and before openai (conversations belong to users).
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.auth0 --project-name \"Lorem Ipsum\""

  @impl true
  def task, do: "workbench.install.auth0"

  @impl true
  def flag, do: :auth0

  @impl true
  def argv(opts) do
    ["--project-name", opts[:project_name], "--interface", opts[:interface]]
  end

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      project_name: "Display name (default: capitalized app name).",
      interface: "`rest` | `graphql` | `none`. Default: `rest`."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [project_name: :string, interface: :string],
      defaults: [interface: "rest"]
    }
  end

  @impl true
  def choices, do: [interface: [{"rest", "a JSON controller and its OpenAPI schema"}, {"graphql", "an Absinthe schema and resolvers"}]]

  # The mark: the Accounts context, the first module the installer creates.
  @impl true
  def installed?(igniter),
    do: Igniter.Project.Module.module_exists(igniter, accounts_module(igniter))

  defp accounts_module(igniter),
    do: Module.concat(Igniter.Project.Module.module_name_prefix(igniter), Accounts)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts =
      Keyword.put_new_lazy(igniter.args.options, :project_name, fn ->
        Mix.Project.config()[:app] |> to_string() |> String.capitalize()
      end)

    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    accounts = accounts_module(igniter)

    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(accounts)} already exists: Auth0 is already installed, skipping."
        )

      {false, igniter} ->
        install(igniter, app_module, opts)
    end
  end

  defp install(igniter, app_module, opts) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    # phx.new derives its directories from the app name; deriving them from
    # the module (Macro.underscore/1) diverges on names carrying digits
    # (app :lorem_3 -> Lorem3Web -> "lorem3_web" instead of "lorem_3_web").
    web_dir = "#{app_name}_web"
    app_dir = to_string(app_name)

    assigns = [
      app_name: app_name,
      app_module: inspect(app_module),
      web_module: inspect(web_module),
      project_name: opts[:project_name],
      rest: opts[:interface] == "rest",
      graphql: opts[:interface] == "graphql"
    ]

    dirs = %{app: app_dir, web: web_dir}

    igniter
    |> Igniter.Project.Deps.add_dep({:auth0_jwks, "~> 0.3"}, on_exists: :skip)
    |> Igniter.Project.IgniterConfig.dont_move_file_pattern(~r"/controllers/")
    # Like controllers/, the fixtures/ subfolder is a Phoenix convention
    # that Igniter cannot derive from the module name.
    |> Igniter.Project.IgniterConfig.dont_move_file_pattern(~r"test/support/fixtures/")
    # Start the process to request the JSON Web Key Set (with RS256 alg).
    |> Igniter.Project.Application.add_new_child({Auth0Jwks.Strategy, first_fetch_sync: true})
    |> Igniter.Project.Config.configure(
      "config.exs",
      :auth0_jwks,
      [:json_library],
      {:code, Sourceror.parse_string!("Jason")}
    )
    |> configure_runtime(assigns)
    |> create_modules(dirs, assigns)
    |> adjust_router(app_module, web_module, opts)
    |> rest_interface(dirs, web_module, assigns, opts)
    |> create_tests(dirs, assigns, opts)
  end

  defp plant(igniter, template, path, assigns) do
    Igniter.create_new_file(igniter, path, template(template, assigns), on_exists: :overwrite)
  end

  # --- runtime.exs ------------------------------------------------------------

  @runtime_anchor "if config_env() == :prod do"

  defp configure_runtime(igniter, assigns) do
    block = template("runtime.eex", assigns)
    path = "config/runtime.exs"

    if Igniter.exists?(igniter, path) do
      igniter
      |> Igniter.include_existing_file(path)
      |> Igniter.update_file(path, fn source ->
        Rewrite.Source.update(source, :content, &insert_runtime_block(&1, block))
      end)
    else
      Igniter.add_warning(
        igniter,
        "config/runtime.exs not found; please add the Auth0 runtime configuration manually."
      )
    end
  end

  defp insert_runtime_block(content, block) do
    cond do
      String.contains?(content, "AUTH0_DOMAIN") ->
        content

      String.contains?(content, @runtime_anchor) ->
        String.replace(content, @runtime_anchor, block <> @runtime_anchor, global: false)

      true ->
        content <> "\n" <> block
    end
  end

  # --- Modules ----------------------------------------------------------------

  defp create_modules(igniter, dirs, assigns) do
    [timestamp] = WorkbenchIgniter.migration_timestamps(igniter, 1)

    igniter
    |> plant("ecto_uri.eex", "lib/#{dirs.app}/ecto_uri.ex", assigns)
    |> plant("accounts.eex", "lib/#{dirs.app}/accounts.ex", assigns)
    |> plant("user.eex", "lib/#{dirs.app}/accounts/user.ex", assigns)
    |> plant(
      "create_users.eex",
      "priv/repo/migrations/#{timestamp}_create_users.exs",
      assigns
    )
    |> plant("token_plug.eex", "lib/#{dirs.web}/plugs/token.ex", assigns)
  end

  # --- Router -----------------------------------------------------------------

  defp adjust_router(igniter, app_module, web_module, opts) do
    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)

    igniter
    |> Igniter.Libs.Phoenix.add_pipeline(
      :auth,
      """
      plug Auth0Jwks.Plug.ValidateToken, no_halt: true

      plug Auth0Jwks.Plug.GetUser,
        no_halt: true,
        user_from_claim: &#{inspect(app_module)}.Accounts.user_from_claim/2

      plug #{inspect(web_module)}.Plugs.Token
      """,
      router: router,
      warn_on_present?: false
    )
    |> then(fn igniter ->
      if opts[:interface] == "rest" do
        authenticate_api_scope(igniter, router)
      else
        igniter
      end
    end)
  end

  # Switches the /api/v1 scope (created by the rest feature) from
  # pipe_through :api to pipe_through [:api, :auth].
  defp authenticate_api_scope(igniter, router) do
    Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
      with {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :scope,
               [2, 3],
               &Igniter.Code.Function.argument_equals?(&1, 0, "/api/v1")
             ),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper),
           {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :pipe_through,
               1
             ) do
        {:ok, Igniter.Code.Common.replace_code(zipper, "pipe_through [:api, :auth]")}
      else
        :error ->
          {:warning,
           "Could not switch the /api/v1 scope to the [:api, :auth] pipelines. " <>
             "Please update your router manually."}
      end
    end)
  end

  # --- REST interface ---------------------------------------------------------

  defp rest_interface(igniter, dirs, web_module, assigns, opts) do
    if opts[:interface] == "rest" do
      igniter
      |> plant("openapi_user.eex", "lib/#{dirs.web}/open_api/schemas/user.ex", assigns)
      |> plant("user_json.eex", "lib/#{dirs.web}/controllers/user_json.ex", assigns)
      |> plant("user_controller.eex", "lib/#{dirs.web}/controllers/user_controller.ex", assigns)
      |> Igniter.Libs.Phoenix.append_to_scope(
        "/api/v1",
        ~s|get "/user", UserController, :get|,
        arg2: web_module
      )
    else
      igniter
    end
  end

  # --- Unit tests -------------------------------------------------------------

  defp create_tests(igniter, dirs, assigns, opts) do
    igniter
    |> plant("accounts_test.eex", "test/#{dirs.app}/accounts_test.exs", assigns)
    |> plant("ecto_uri_test.eex", "test/#{dirs.app}/ecto_uri_test.exs", assigns)
    |> plant("token_test.eex", "test/#{dirs.web}/plugs/token_test.exs", assigns)
    |> plant("accounts_fixtures.eex", "test/support/fixtures/accounts_fixtures.ex", assigns)
    |> plant_if(
      opts[:interface] == "rest",
      "user_controller_test.eex",
      "test/#{dirs.web}/controllers/user_controller_test.exs",
      assigns
    )
  end

  defp plant_if(igniter, condition, template, path, assigns) do
    if condition, do: plant(igniter, template, path, assigns), else: igniter
  end
end
