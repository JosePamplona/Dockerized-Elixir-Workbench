defmodule Mix.Tasks.Workbench.Install.Healthcheck do
  use Igniter.Mix.Task

  @shortdoc "Adds a healthcheck endpoint with controller, tests and router scope"
  @example "mix workbench.install.healthcheck"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_healthcheck` feature:

  * adds `{:mock, "~> 0.3", only: :test}` to the project deps
  * enables `dev_routes` in `config/test.exs` (the endpoint returns extended
    info only when dev routes are enabled)
  * creates `MyAppWeb.HealthcheckController`
  * creates the controller unit tests
  * adds a scope with the healthcheck route to the Phoenix router

  All changes are accumulated in a single patch set and shown as a diff
  before being applied (pass `--yes` to skip confirmation).

  ## Example

      #{@example}

  When the project has the REST/OpenAPI feature (`workbench.install.rest`) —
  detected by the presence of `MyAppWeb.OpenApi.Spec`, or forced with
  `--open-api` — the controller is generated with OpenApiSpex specs and a
  `MyAppWeb.OpenApi.Schemas.Healthcheck` schema module is added.

  ## Options

  * `--endpoint` - Route for the healthcheck scope. Defaults to `/health`.
  * `--open-api` - Generate the OpenApiSpex-documented variant even if the
    REST feature is not detected (it must be installed for it to compile).
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      composes: ["workbench.install.mock"],
      schema: [endpoint: :string, open_api: :boolean],
      defaults: [endpoint: "/health", open_api: false]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    endpoint = igniter.args.options[:endpoint]

    # Everything below is *derived from the target project* — no
    # %{elixir_module}-style placeholders provided by the caller.
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    controller = Module.concat(web_module, HealthcheckController)
    test_module = Module.concat(web_module, HealthcheckControllerTest)
    web_dir = web_module |> inspect() |> Macro.underscore()

    # The OpenApiSpex variant applies if the REST feature is present (also
    # when composed in the same patch set) or explicitly requested.
    {spec_exists, igniter} =
      Igniter.Project.Module.module_exists(
        igniter,
        Module.concat([web_module, OpenApi, Spec])
      )

    open_api? = igniter.args.options[:open_api] || spec_exists

    assigns = [
      app_name: app_name,
      app_module: inspect(app_module),
      web_module: inspect(web_module),
      endpoint: endpoint,
      open_api: open_api?
    ]

    # Deps and config patches are idempotent by themselves, but add_scope
    # always appends — so the whole install is guarded by the controller's
    # existence to make re-runs a no-op.
    case Igniter.Project.Module.module_exists(igniter, controller) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(controller)} already exists: " <>
          "healthcheck is already installed, skipping."
        )

      {false, igniter} ->
        install(
          igniter,
          endpoint,
          app_name,
          web_module,
          controller,
          test_module,
          web_dir,
          assigns
        )
    end
  end

  defp install(
    igniter,
    endpoint,
    app_name,
    web_module,
    controller,
    test_module,
    web_dir,
    assigns
  ) do
    igniter
    # The generated controller test uses the Mock library.
    |> Igniter.compose_task("workbench.install.mock", [])
    |> Igniter.Project.Config.configure("test.exs", app_name, [:dev_routes], true)
    # Phoenix keeps controllers in a `controllers/` folder that does not match
    # the module name; without this, Igniter would relocate the new files to
    # `lib/my_app_web/healthcheck_controller.ex` at write time.
    |> Igniter.Project.IgniterConfig.dont_move_file_pattern(~r"/controllers/")
    |> Igniter.Project.Module.create_module(
      controller,
      WorkbenchIgniter.template("healthcheck/controller.eex", assigns),
      path: "lib/#{web_dir}/controllers/healthcheck_controller.ex"
    )
    |> Igniter.Project.Module.create_module(
      test_module,
      WorkbenchIgniter.template("healthcheck/controller_test.eex", assigns),
      path: "test/#{web_dir}/controllers/healthcheck_controller_test.exs"
    )
    |> create_open_api_schema(web_module, assigns)
    |> Igniter.Libs.Phoenix.add_scope(
      endpoint,
      """
      pipe_through :api

      get "/", HealthcheckController, :health
      """,
      arg2: web_module
    )
  end

  # Unlike app.sh (which wrote this schema over `open_api/schemas/user.ex`
  # and duplicated it inline in the controller), the schema gets its own
  # module and the controller operation references it.
  defp create_open_api_schema(igniter, web_module, assigns) do
    if assigns[:open_api] do
      Igniter.Project.Module.create_module(
        igniter,
        Module.concat([web_module, OpenApi, Schemas, Healthcheck]),
        WorkbenchIgniter.template("healthcheck/schema.eex", assigns)
      )
    else
      igniter
    end
  end
end
