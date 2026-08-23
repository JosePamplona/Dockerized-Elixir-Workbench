defmodule WorkbenchIgniter.Features.GraphqlTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  describe "mix workbench.install.graphql" do
    test "adds the absinthe dependencies" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.graphql", [])
      |> assert_has_patch("mix.exs", """
      + | {:absinthe, "~> 1.7"},
      """)
      |> assert_has_patch("mix.exs", """
      + | {:absinthe_plug, "~> 1.5"},
      """)
      |> assert_has_patch("mix.exs", """
      + | {:absinthe_error_payload, "~> 1.1"},
      """)
    end

    test "creates the schema and the endpoint tests" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.graphql", [])
      |> assert_creates("lib/test_web/graphql/schema.ex", fn content ->
        assert content =~ "defmodule TestWeb.Graphql.Schema do"
        assert content =~ "use Absinthe.Schema"
        assert content =~ "field :version, :string"
      end)
      |> assert_creates("test/test_web/graphql_test.exs", fn content ->
        assert content =~ "defmodule TestWeb.GraphqlTest do"
        assert content =~ ~s|post(~p"/graphiql", %{"query" => "{ version }"})|
      end)
    end

    test "forwards /graphiql to Absinthe in the router" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.graphql", [])
      |> assert_has_patch("lib/test_web/router.ex", """
      + | scope "/graphiql" do
      + | pipe_through(:api)
      """)
      |> assert_has_patch("lib/test_web/router.ex", """
      + | forward("/", Absinthe.Plug.GraphiQL, schema: TestWeb.Graphql.Schema, json_codec: Jason)
      """)
    end

    test "is a no-op with a notice when already installed" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.graphql", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.graphql", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already installed"))
    end
  end

  describe "composition through workbench.setup" do
    test "--interface graphql composes the installer" do
      phx_test_project()
      |> Igniter.compose_task("workbench.setup", ["--interface", "graphql"])
      |> assert_creates("lib/test_web/graphql/schema.ex")
      |> assert_has_patch("mix.exs", """
      + | {:absinthe, "~> 1.7"},
      """)
    end
  end
end
