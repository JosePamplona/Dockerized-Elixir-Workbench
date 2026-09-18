defmodule WorkbenchIgniter.Features.PsqlExtrasTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  describe "mix workbench.install.psql_extras" do
    test "adds the dependency to mix.exs" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.psql_extras", [])
      |> assert_has_patch("mix.exs", """
      + | {:ecto_psql_extras, "~> 0.8", only: :dev}
      """)
    end

    test "refuses without ecto, and on another adapter, naming what the project has" do
      assert [issue] =
               test_project()
               |> Igniter.compose_task("workbench.install.psql_extras", [])
               |> Map.get(:issues)

      assert issue =~ "psql_extras builds on ecto with database postgres, not in the project yet"

      assert [issue] =
               phx_test_project()
               |> Igniter.Project.Deps.remove_dep(:postgrex)
               |> Igniter.Project.Deps.add_dep({:myxql, "~> 0.7"})
               |> apply_igniter!()
               |> Igniter.compose_task("workbench.install.psql_extras", [])
               |> Map.get(:issues)

      assert issue =~ "this project's database is mysql"
    end

    test "is a no-op when the dependency is already present" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.psql_extras", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.psql_extras", [])
      |> assert_unchanged()
    end
  end
end
