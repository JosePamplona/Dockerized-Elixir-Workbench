defmodule WorkbenchIgniter.Features.HealthEndpointTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  # Every test runs against an in-memory Phoenix project (app: :test,
  # modules Test / TestWeb) — no files are written to disk.

  describe "mix workbench.install.health_endpoint" do
    test "creates the controller and its test in Phoenix conventional paths" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.health_endpoint", [])
      |> assert_creates(
        "lib/test_web/controllers/healthcheck_controller.ex",
        fn content ->
          assert content =~ "defmodule TestWeb.HealthcheckController do"
          assert content =~ "use TestWeb, :controller"
          assert content =~ "Application.get_env(:test, :dev_routes, false)"
        end
      )
      |> assert_creates(
        "test/test_web/controllers/healthcheck_controller_test.exs",
        fn content ->
          assert content =~ "defmodule TestWeb.HealthcheckControllerTest do"
          assert content =~ "use TestWeb.ConnCase"
          assert content =~ ~s|alias Test.Repo|
        end
      )
    end

    test "files stay in controllers/ after the patch set is applied" do
      # Regression: without the dont_move_files pattern, Igniter relocates
      # the new modules to lib/test_web/healthcheck_controller.ex on write.
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.health_endpoint", [])
        |> apply_igniter!()

      files = Map.keys(igniter.assigns[:test_files])

      assert "lib/test_web/controllers/healthcheck_controller.ex" in files
      assert "test/test_web/controllers/healthcheck_controller_test.exs" in files
      refute "lib/test_web/healthcheck_controller.ex" in files
    end

    test "adds the /health scope to the router" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.health_endpoint", [])
      |> assert_has_patch(
        "lib/test_web/router.ex",
        """
        + | scope "/health", TestWeb do
        + | pipe_through :api
        + |
        + | get "/", HealthcheckController, :health
        + | end
        """
      )
    end

    test "enables dev_routes in config/test.exs" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.health_endpoint", [])
      |> assert_has_patch(
        "config/test.exs",
        """
        + |config :test, dev_routes: true
        """
      )
    end

    test "adds the mock test dependency" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.health_endpoint", [])
      |> assert_has_patch(
        "mix.exs",
        """
        + | {:mock, "~> 0.3", only: :test},
        """
      )
    end

    test "registers the controllers/ pattern in .igniter.exs" do
      # Igniter's convention is that a file's path derives from its module
      # name (TestWeb.HealthcheckController -> lib/test_web/healthcheck_controller.ex)
      # and, on write, it actively relocates any new module to that canonical
      # path — even overriding an explicit `path:`. Phoenix breaks the
      # convention with its `controllers/` subfolder, so the installer must
      # exempt it via `dont_move_files` in the target project's `.igniter.exs`
      # (the ~r"lib/mix" entry is Igniter's own default, same reason).
      phx_test_project()
      |> Igniter.compose_task("workbench.install.health_endpoint", [])
      |> assert_has_patch(
        ".igniter.exs",
        """
        + | dont_move_files: [~r/\\/controllers\\//, ~r"lib/mix"],
        """
      )
    end

    test "--endpoint overrides the scope route" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.health_endpoint", ["--endpoint", "/status"])
      |> assert_has_patch(
        "lib/test_web/router.ex",
        """
        + | scope "/status", TestWeb do
        """
      )
      |> assert_creates(
        "test/test_web/controllers/healthcheck_controller_test.exs",
        fn content ->
          assert content =~ ~s|get(~p"/status")|
        end
      )
    end

    test "without the REST feature the controller has no OpenApiSpex specs" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.health_endpoint", [])
        |> apply_igniter!()

      controller =
        igniter.assigns[:test_files]["lib/test_web/controllers/healthcheck_controller.ex"]

      refute controller =~ "OpenApiSpex.ControllerSpecs"

      refute Map.has_key?(
               igniter.assigns[:test_files],
               "lib/test_web/open_api/schemas/healthcheck.ex"
             )
    end

    test "with the REST feature installed it generates the OpenApiSpex variant" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.rest", [])
        |> Igniter.compose_task("workbench.install.health_endpoint", [])
        |> apply_igniter!()

      controller =
        igniter.assigns[:test_files]["lib/test_web/controllers/healthcheck_controller.ex"]

      schema = igniter.assigns[:test_files]["lib/test_web/open_api/schemas/healthcheck.ex"]

      assert controller =~ "use OpenApiSpex.ControllerSpecs"
      assert controller =~ "operation(:health,"
      assert controller =~ "Schemas.Healthcheck.schema()"
      assert schema =~ "defmodule TestWeb.OpenApi.Schemas.Healthcheck do"
    end

    test "--open-api forces the documented variant without the REST feature" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.health_endpoint", ["--open-api"])
        |> apply_igniter!()

      controller =
        igniter.assigns[:test_files]["lib/test_web/controllers/healthcheck_controller.ex"]

      assert controller =~ "use OpenApiSpex.ControllerSpecs"
    end

    test "is a no-op with a notice when the controller already exists" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.health_endpoint", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.health_endpoint", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already installed"))
    end
  end
end
