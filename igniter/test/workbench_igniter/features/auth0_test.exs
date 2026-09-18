defmodule WorkbenchIgniter.Features.Auth0Test do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  defp installed(argv \\ []) do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.rest", [])
    |> Igniter.compose_task("workbench.install.enhancements", [])
    |> Igniter.compose_task("workbench.install.auth0", argv)
    |> apply_igniter!()
    |> Map.get(:assigns)
    |> Map.get(:test_files)
  end

  describe "mix workbench.install.auth0" do
    test "adds the dependency, supervision child and config" do
      files = installed()

      assert files["mix.exs"] =~ ~s|{:auth0_jwks, "~> 0.3"}|

      assert files["lib/test/application.ex"] =~
               "{Auth0Jwks.Strategy, [first_fetch_sync: true]}"

      assert files["config/config.exs"] =~ "config :auth0_jwks, json_library: Jason"
    end

    test "adds the AUTH0_* block to runtime.exs" do
      runtime = installed()["config/runtime.exs"]

      assert runtime =~ ~s|System.get_env("AUTH0_DOMAIN")|
      assert runtime =~ "config :auth0_jwks,"
      assert runtime =~ "auth0_audience: auth0_audience"
      # Inserted before the prod block, not inside it.
      assert [_before, _after] = String.split(runtime, "AUTH0_DOMAIN") |> Enum.take(2)
    end

    test "creates the accounts context, user schema, migration and plug" do
      files = installed(["--project-name", "Lorem Ipsum"])

      assert files["lib/test/accounts.ex"] =~ "def user_from_claim(claims, token) do"
      assert files["lib/test/accounts/user.ex"] =~ "use Test.Schema"
      assert files["lib/test/accounts/user.ex"] =~ "defenum(StatusEnum, :user_status"
      assert files["lib/test/ecto_uri.ex"] =~ "defmodule Test.EctoURI do"
      assert files["lib/test_web/plugs/token.ex"] =~ "defmodule TestWeb.Plugs.Token do"

      assert [migration] =
               files
               |> Map.keys()
               |> Enum.filter(
                 &String.match?(&1, ~r|priv/repo/migrations/\d{14}_create_users\.exs|)
               )

      assert files[migration] =~ "defmodule Test.Repo.Migrations.CreateUsers do"
      assert files[migration] =~ "StatusEnum.create_type()"
    end

    test "router: auth pipeline and authenticated /api/v1 scope with /user" do
      router = installed()["lib/test_web/router.ex"]

      assert router =~ "pipeline :auth do"
      assert router =~ "plug Auth0Jwks.Plug.ValidateToken, no_halt: true"
      assert router =~ "user_from_claim: &Test.Accounts.user_from_claim/2"
      assert router =~ "pipe_through [:api, :auth]"
      # A scope, not phx.new's commented sample of one.
      refute router =~ ~r/^\s+pipe_through :api$/m
      assert router =~ ~s|get "/user", UserController, :get|
    end

    test "rest interface: user controller, view and OpenAPI schema with tests" do
      files = installed()

      assert files["lib/test_web/controllers/user_controller.ex"] =~
               "defmodule TestWeb.UserController do"

      assert files["lib/test_web/controllers/user_json.ex"]
      assert files["lib/test_web/open_api/schemas/user.ex"]
      assert files["test/test_web/controllers/user_controller_test.exs"]
    end

    test "plants the unit tests and fixtures" do
      files = installed()

      assert files["test/test/accounts_test.exs"] =~ "defmodule Test.AccountsTest do"
      assert files["test/test/ecto_uri_test.exs"]
      assert files["test/test_web/plugs/token_test.exs"]

      assert files["test/support/fixtures/accounts_fixtures.ex"] =~
               "defmodule Test.AccountsFixtures do"
    end

    test "--interface graphql skips the rest artifacts" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.enhancements", [])
        |> Igniter.compose_task("workbench.install.auth0", ["--interface", "graphql"])
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> Map.get(:test_files)

      refute Map.has_key?(files, "lib/test_web/controllers/user_controller.ex")
      refute Map.has_key?(files, "lib/test_web/open_api/schemas/user.ex")
      # The token plug keeps its graphql branch.
      assert files["lib/test_web/plugs/token.ex"] =~ "Absinthe"
    end

    test "is a no-op with a notice when already installed" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.enhancements", [])
      |> Igniter.compose_task("workbench.install.auth0", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.auth0", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already installed"))
    end

    # The mark is the dependency, not the Accounts context: Ash's
    # authentication writes one of those too, and read as the mark it
    # made Auth0 look inserted. An Accounts that is not Auth0's is
    # refused, since the templates would overwrite it.
    test "an Accounts context of another's does not read as installed, and is not overwritten" do
      with_accounts =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.enhancements", [])
        |> Igniter.create_new_file("lib/test/accounts.ex", "defmodule Test.Accounts do\nend\n")
        |> apply_igniter!()

      assert {false, _} = WorkbenchIgniter.Features.Auth0.installed?(with_accounts)

      igniter = Igniter.compose_task(with_accounts, "workbench.install.auth0", [])
      assert [issue] = igniter.issues
      assert issue =~ "Test.Accounts already exists and is not Auth0's"

      refute Igniter.Project.Deps.has_dep?(igniter, :auth0_jwks)
    end
  end

  describe "requires enhancements" do
    test "refuses, naming it, while enhancements is not in" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.auth0", [])

      assert [issue] = igniter.issues
      assert issue =~ "auth0 builds on enhancements"
      assert issue =~ "./wb.sh add enhancements"
    end

    test "installs on top of it, the User on its Schema" do
      files = installed()

      assert files["lib/test/accounts.ex"]
      assert files["lib/test/accounts/user.ex"] =~ "use Test.Schema"
    end
  end
end
