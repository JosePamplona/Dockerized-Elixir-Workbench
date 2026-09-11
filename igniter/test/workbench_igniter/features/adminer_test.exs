defmodule WorkbenchIgniter.Features.AdminerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Adminer

  defp install(project \\ phx_test_project()),
    do: Igniter.compose_task(project, "workbench.install.adminer", [])

  # A phx.new project on another adapter: its driver in place of postgrex.
  defp on(driver) do
    phx_test_project()
    |> Igniter.Project.Deps.remove_dep(:postgrex)
    |> Igniter.Project.Deps.add_dep({driver, "~> 0.1"})
    |> apply_igniter!()
  end

  describe "mix workbench.install.adminer" do
    test "writes the login file, the workspace's Postgres named after the app" do
      install()
      |> assert_creates("adminer/login.php", fn content ->
        assert content =~ "require_once('plugins/login-servers.php');"
        assert content =~ "class WorkbenchLogin extends AdminerLoginServers"
        assert content =~ "new Adminer\\Password($password_hash)"

        assert content =~ ~s|array('test' => array(|
        assert content =~ ~s|'server' => getenv('WORKBENCH_SERVER') ?: '127.0.0.1:5432',|
        assert content =~ ~s|'driver' => 'pgsql',|
        assert content =~ ~s|\n\t'postgres',\n|
        assert content =~ ~s|getenv('WORKBENCH_DATABASE') ?: 'test_dev',|
        assert content =~ ~s|'$2y$12$|
      end)
    end

    test "on MySQL: Adminer's own key for the driver, root, the server's port" do
      on(:myxql)
      |> install()
      |> assert_creates("adminer/login.php", fn content ->
        assert content =~ ~s|'server' => getenv('WORKBENCH_SERVER') ?: '127.0.0.1:3306',|
        assert content =~ ~s|'driver' => 'server',|
        assert content =~ ~s|\n\t'root',\n|
      end)
    end

    test "on MSSQL: sa on 1433" do
      on(:tds)
      |> install()
      |> assert_creates("adminer/login.php", fn content ->
        assert content =~ ~s|'server' => getenv('WORKBENCH_SERVER') ?: '127.0.0.1:1433',|
        assert content =~ ~s|'driver' => 'mssql',|
        assert content =~ ~s|\n\t'sa',\n|
      end)
    end

    test "on SQLite: no server, no user, the dev file as the database" do
      on(:ecto_sqlite3)
      |> install()
      |> assert_creates("adminer/login.php", fn content ->
        assert content =~ ~s|'server' => getenv('WORKBENCH_SERVER') ?: '',|
        assert content =~ ~s|'driver' => 'sqlite',|
        assert content =~ ~s|\n\t'',\n|
        assert content =~ ~s|getenv('WORKBENCH_DATABASE') ?: '/app/src/test_dev.db',|
      end)
    end

    test "the file is the mark" do
      assert {false, _} = Adminer.installed?(phx_test_project())
      assert {true, _} = install() |> apply_igniter!() |> Adminer.installed?()
    end

    test "is a no-op when the file is there" do
      install() |> apply_igniter!() |> install() |> assert_unchanged()
    end

    test "refuses without ecto" do
      igniter = install(test_project())
      assert [issue] = igniter.issues
      assert issue =~ "adminer builds on ecto"
    end
  end

  describe "the manifest" do
    test "asks the workspace for the adminer container, whatever its state" do
      assert Adminer.services(%{}) == ["adminer"]
    end

    test "builds on ecto" do
      assert Adminer.requires() == ["ecto"]
    end

    test "the login's values per adapter, the dev pod's" do
      assert Adminer.login("postgres", :lorem) ==
               [
                 app_name: :lorem,
                 driver: "pgsql",
                 server: "127.0.0.1:5432",
                 username: "postgres",
                 database: "lorem_dev"
               ]

      assert Adminer.login("mysql", :lorem)[:driver] == "server"
      assert Adminer.login("mssql", :lorem)[:server] == "127.0.0.1:1433"

      assert Adminer.login("sqlite3", :lorem) ==
               [
                 app_name: :lorem,
                 driver: "sqlite",
                 server: "",
                 username: "",
                 database: "/app/src/lorem_dev.db"
               ]
    end
  end
end
