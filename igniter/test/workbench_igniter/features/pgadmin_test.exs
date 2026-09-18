defmodule WorkbenchIgniter.Features.PgadminTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Pgadmin

  defp install(project \\ phx_test_project()),
    do: Igniter.compose_task(project, "workbench.install.pgadmin", [])

  describe "mix workbench.install.pgadmin" do
    test "writes the servers file, the workspace's Postgres named after the app" do
      install()
      |> assert_creates("pgadmin/servers.json", fn content ->
        assert {:ok, %{"Servers" => %{"1" => server}}} = Jason.decode(content)

        assert server == %{
                 "Group" => "Dockerized workbench",
                 "Name" => "test",
                 "Host" => "localhost",
                 "Port" => 5432,
                 "MaintenanceDB" => "postgres",
                 "Username" => "postgres",
                 "PassFile" => "/var/lib/pgadmin/pgpass",
                 "SSLMode" => "prefer"
               }
      end)
    end

    test "the file is the mark" do
      assert {false, _} = Pgadmin.installed?(phx_test_project())
      assert {true, _} = install() |> apply_igniter!() |> Pgadmin.installed?()
    end

    test "is a no-op when the file is there" do
      install() |> apply_igniter!() |> install() |> assert_unchanged()
    end

    test "refuses without ecto" do
      igniter = install(test_project())
      assert [issue] = igniter.issues
      assert issue =~ "pgadmin builds on ecto"
    end

    test "refuses on another adapter" do
      igniter =
        phx_test_project()
        |> Igniter.Project.Deps.remove_dep(:postgrex)
        |> Igniter.Project.Deps.add_dep({:myxql, "~> 0.7"})
        |> apply_igniter!()
        |> install()

      assert [issue] = igniter.issues
      assert issue =~ "this project's database is mysql"
    end
  end

  describe "the manifest" do
    test "asks the workspace for the pgadmin container, whatever its state" do
      assert Pgadmin.services(%{}) == ["pgadmin"]
    end

    test "builds on ecto" do
      assert Pgadmin.requires() == [{"ecto", database: "postgres"}]
    end
  end
end
