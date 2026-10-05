defmodule WorkbenchIgniter.Features.DashboardExtrasTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  @task "workbench.install.dashboard_extras"

  # A phx.new project moved to another of ecto's databases: the driver
  # in the deps is what says which.
  defp on_database(igniter, driver) do
    igniter
    |> Igniter.Project.Deps.remove_dep(:postgrex)
    |> Igniter.Project.Deps.add_dep(driver)
    |> apply_igniter!()
  end

  defp without_ecto(igniter) do
    igniter
    |> Igniter.Project.Deps.remove_dep(:postgrex)
    |> Igniter.Project.Deps.remove_dep(:ecto_sql)
    |> apply_igniter!()
  end

  describe "mix workbench.install.dashboard_extras" do
    test "on Postgres: :os_mon and ecto_psql_extras" do
      phx_test_project()
      |> Igniter.compose_task(@task, [])
      |> assert_has_patch("mix.exs", """
      - | extra_applications: [:logger, :runtime_tools]
      + | extra_applications: [:logger, :runtime_tools, :os_mon]
      """)
      |> assert_has_patch("mix.exs", """
      + | {:ecto_psql_extras, "~> 0.8"}
      """)
    end

    test "the extras follow the project's database" do
      for {driver, extras} <- [
            {{:myxql, ">= 0.0.0"}, ~s|{:ecto_mysql_extras, "~> 0.6"}|},
            {{:ecto_sqlite3, ">= 0.0.0"}, ~s|{:ecto_sqlite3_extras, "~> 1.2"}|}
          ] do
        phx_test_project()
        |> on_database(driver)
        |> Igniter.compose_task(@task, [])
        |> assert_has_patch("mix.exs", "+ | #{extras}")
      end
    end

    test "on SQL Server, which LiveDashboard has no stats for: OS Data alone, and a notice" do
      igniter =
        phx_test_project()
        |> on_database({:tds, ">= 0.0.0"})
        |> Igniter.compose_task(@task, [])

      assert igniter.issues == []
      assert Enum.any?(igniter.notices, &(&1 =~ "no Ecto Stats for mssql"))
      refute diff(igniter) =~ "_extras"
      assert diff(igniter) =~ ":os_mon"
    end

    test "without a database: OS Data alone; a second run, once ecto is in, adds the extras" do
      igniter =
        phx_test_project()
        |> without_ecto()
        |> Igniter.compose_task(@task, [])

      assert igniter.issues == []
      assert Enum.any?(igniter.notices, &(&1 =~ "run this again for Ecto Stats"))
      refute diff(igniter) =~ "_extras"

      igniter
      |> apply_igniter!()
      |> Igniter.Project.Deps.add_dep({:ecto_sql, "~> 3.13"})
      |> Igniter.Project.Deps.add_dep({:postgrex, ">= 0.0.0"})
      |> apply_igniter!()
      |> Igniter.compose_task(@task, [])
      |> assert_has_patch("mix.exs", """
      + | {:ecto_psql_extras, "~> 0.8"}
      """)
    end

    test "refuses without the dashboard, saying how to get it" do
      assert [issue] =
               test_project()
               |> Igniter.compose_task(@task, [])
               |> Map.get(:issues)

      assert issue =~ "dashboard_extras builds on dashboard, not in the project yet"
      assert issue =~ "./wb.sh add dashboard"
    end

    test "is a no-op when both halves are in" do
      phx_test_project()
      |> Igniter.compose_task(@task, [])
      |> apply_igniter!()
      |> Igniter.compose_task(@task, [])
      |> assert_unchanged()
    end

    test "leaves a dependency the project already declares as it is" do
      igniter =
        phx_test_project()
        |> Igniter.Project.Deps.add_dep({:ecto_psql_extras, "~> 0.7", only: :dev})
        |> apply_igniter!()
        |> Igniter.compose_task(@task, [])

      assert diff(igniter) =~ ":os_mon"
      refute diff(igniter) =~ "ecto_psql_extras"
    end
  end
end
