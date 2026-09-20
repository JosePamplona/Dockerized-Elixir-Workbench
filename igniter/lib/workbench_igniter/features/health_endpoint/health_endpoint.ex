defmodule WorkbenchIgniter.Features.HealthEndpoint do
  @moduledoc """
  Health endpoint with controller, tests and router scope.

  This is a full feature cartridge: manifest, install logic and the EEx
  templates it renders all live in this directory, and the
  `Mix.Tasks.Workbench.Install.HealthEndpoint` shell in `task.ex` delegates
  here. See `WorkbenchIgniter.Feature` for the conventions.

  Ordering: inserted last, after rest, so `install/1` autodetects the
  `OpenApi.Spec` module in the patch set and generates the
  OpenApiSpex-documented variant.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.health_endpoint"

  @impl true
  def archived,
    do:
      "2026-09-20: one of two boxes for one need — health_probe's probes are the one the reference takes"

  @impl true
  def task, do: "workbench.install.health_endpoint"

  @impl true
  def console, do: [doors: [{"health", "{endpoint}"}]]

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      endpoint: "Route for the health endpoint's scope. Defaults to `/health`.",
      open_api:
        "Generate the OpenApiSpex-documented variant even if the REST feature is not detected (it must be installed for it to compile)."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      composes: ["workbench.install.mock"],
      schema: [endpoint: :string, open_api: :boolean],
      defaults: [endpoint: "/health", open_api: false]
    }
  end

  # The mark: the controller (add_scope is not idempotent, so the whole
  # install is guarded by it).
  @impl true
  def installed?(igniter),
    do: Igniter.Project.Module.module_exists(igniter, controller_module(igniter))

  defp controller_module(igniter),
    do: Module.concat(Igniter.Libs.Phoenix.web_module(igniter), HealthcheckController)

  # What the project carries, read back off what the install wrote: the
  # endpoint is the router scope that routes the controller, and the
  # OpenApiSpex variant is there when its schema module is. Without
  # this the cartridge answered the default `%{}`, and the console had
  # nothing to say of `--endpoint /health3 --open-api`.
  @impl true
  def state(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    router = "lib/#{app_name}_web/router.ex"
    web_module = Igniter.Libs.Phoenix.web_module(igniter)

    {endpoint, igniter} =
      if Igniter.exists?(igniter, router) do
        igniter = Igniter.include_existing_file(igniter, router)
        content = igniter.rewrite |> Rewrite.source!(router) |> Rewrite.Source.get(:content)

        case Regex.run(
               ~r/scope\s*\(?\s*"([^"]+)"[^\n]*\bdo\b(?:(?!\bscope\b).)*?HealthcheckController/s,
               content
             ) do
          [_, path] -> {path, igniter}
          nil -> {nil, igniter}
        end
      else
        {nil, igniter}
      end

    {open_api?, igniter} =
      Igniter.Project.Module.module_exists(
        igniter,
        Module.concat([web_module, OpenApi, Schemas, Healthcheck])
      )

    state = %{endpoint: endpoint, open_api: open_api?}

    {state, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    endpoint = igniter.args.options[:endpoint]

    # Everything below is *derived from the target project* — no
    # %{elixir_module}-style placeholders provided by the caller.
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    controller = controller_module(igniter)
    test_module = Module.concat(web_module, HealthcheckControllerTest)
    # phx.new derives its directories from the app name; deriving them from
    # the module (Macro.underscore/1) diverges on names carrying digits
    # (app :lorem_3 -> Lorem3Web -> "lorem3_web" instead of "lorem_3_web").
    web_dir = "#{app_name}_web"

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
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(controller)} already exists: " <>
            "health_endpoint is already installed, skipping."
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
      template("controller.eex", assigns),
      path: "lib/#{web_dir}/controllers/healthcheck_controller.ex"
    )
    |> Igniter.Project.Module.create_module(
      test_module,
      template("controller_test.eex", assigns),
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
        template("schema.eex", assigns)
      )
    else
      igniter
    end
  end
end
