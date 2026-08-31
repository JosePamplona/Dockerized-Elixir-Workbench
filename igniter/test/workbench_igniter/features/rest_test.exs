defmodule WorkbenchIgniter.Features.RestTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  describe "mix workbench.install.rest" do
    test "creates the OpenApi helper modules" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.rest", ["--project-name", "Lorem Ipsum"])
      |> assert_creates("lib/test_web/open_api/spec.ex", fn content ->
        assert content =~ "defmodule TestWeb.OpenApi.Spec do"
        assert content =~ ~s|title: "Lorem Ipsum"|
        assert content =~ "Paths.from_router(Router)"
      end)
      |> assert_creates("lib/test_web/open_api/requests.ex")
      |> assert_creates("lib/test_web/open_api/responses.ex")
      |> assert_creates("lib/test_web/open_api/schemas.ex")
    end

    test "adds the open_api_spex dependency" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.rest", [])
      |> assert_has_patch("mix.exs", """
      + | {:open_api_spex, "~> 3.21"},
      """)
    end

    test "aliases the OpenApi helpers in the web module controller block" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.rest", [])
      |> assert_has_patch("lib/test_web.ex", """
      + | alias OpenApiSpex.Schema
      + | alias TestWeb.OpenApi.{Requests, Responses, Schemas}
      """)
    end

    test "adds the pipeline, api scope and dev routes to the router" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.rest", [])
      |> assert_has_patch("lib/test_web/router.ex", """
      + | pipeline :open_api_spec do
      + | plug(OpenApiSpex.Plug.PutApiSpec, module: TestWeb.OpenApi.Spec)
      + | end
      """)
      |> assert_has_patch("lib/test_web/router.ex", """
      + | scope "/api/v1", TestWeb do
      + | pipe_through(:api)
      """)
      |> assert_has_patch("lib/test_web/router.ex", """
      + | get("/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/dev/openapi")
      """)
      |> assert_has_patch("lib/test_web/router.ex", """
      + | get("/openapi", OpenApiSpex.Plug.RenderSpec, [])
      """)
    end

    test "without feature flags the spec has the default tag and no security" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.rest", [])
        |> apply_igniter!()

      spec = igniter.assigns[:test_files]["lib/test_web/open_api/spec.ex"]

      assert spec =~ ~s|name: "Operations"|
      refute spec =~ "SecurityScheme"
      refute spec =~ ~s|name: "User Operations"|
    end

    test "--auth0 and --health include their tags and the security scheme" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.rest", ["--auth0", "--health"])
        |> apply_igniter!()

      spec = igniter.assigns[:test_files]["lib/test_web/open_api/spec.ex"]
      requests = igniter.assigns[:test_files]["lib/test_web/open_api/requests.ex"]

      assert spec =~ "securitySchemes"
      assert spec =~ ~s|name: "User Operations"|
      assert spec =~ ~s|name: "Development Operations"|
      refute spec =~ ~s|name: "Operations"|
      # Without --openai the assistant params are not generated.
      refute requests =~ "assistant_query_params"
    end

    test "--openai includes the assistant request params" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.rest", ["--openai"])
        |> apply_igniter!()

      assert igniter.assigns[:test_files]["lib/test_web/open_api/requests.ex"] =~
               "assistant_query_params"
    end

    test "creates the controller tests in the conventional folder" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.rest", [])
        |> apply_igniter!()

      files = Map.keys(igniter.assigns[:test_files])

      assert "test/test_web/controllers/open_api_controller_test.exs" in files
      assert "test/test_web/controllers/swagger_controller_test.exs" in files
    end

    test "is a no-op with a notice when already installed" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.rest", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.rest", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already installed"))
    end
  end

  describe "composition through chiefs_setup" do
    test "the default interface composes the installer with the recipe argv" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.chiefs_setup", [])
      |> assert_creates("lib/test_web/open_api/spec.ex", fn content ->
        # The recipe's --health: the spec carries the operations tag.
        assert content =~ ~s|name: "Development Operations"|
      end)
    end
  end
end
