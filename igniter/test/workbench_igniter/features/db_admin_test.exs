defmodule WorkbenchIgniter.Features.DbAdminTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.DbAdmin

  defp install(project \\ phx_test_project(), argv \\ []),
    do: Igniter.compose_task(project, "workbench.install.db_admin", argv)

  # A phx.new project on another adapter: its driver in place of postgrex.
  defp on(driver) do
    phx_test_project()
    |> Igniter.Project.Deps.remove_dep(:postgrex)
    |> Igniter.Project.Deps.add_dep({driver, "~> 0.1"})
    |> apply_igniter!()
  end

  describe "without --admin: the one for the project's database" do
    test "on Postgres, pgAdmin: the servers file, the workspace's Postgres named after the app" do
      igniter = install()

      assert_creates(igniter, "pgadmin/servers.json", fn content ->
        assert {:ok, %{"Servers" => %{"1" => server}}} = Jason.decode(content)

        assert server == %{
                 "Group" => "Servers",
                 "Name" => "test",
                 "Host" => "localhost",
                 "Port" => 5432,
                 "MaintenanceDB" => "postgres",
                 "Username" => "postgres",
                 "PassFile" => "/var/lib/pgadmin/pgpass",
                 "SSLMode" => "prefer"
               }
      end)

      assert {%{admin: ["pgadmin"]}, _} = igniter |> apply_igniter!() |> DbAdmin.state()
    end

    test "on MySQL, phpMyAdmin: root signed in with no password, the server left to the compose" do
      on(:myxql)
      |> install()
      |> assert_creates("phpmyadmin/config.user.inc.php", fn content ->
        assert String.starts_with?(content, "<?php\n")
        assert content =~ "$cfg['Servers'][$i]['auth_type'] = 'config';"
        assert content =~ "$cfg['Servers'][$i]['user'] = 'root';"
        assert content =~ "$cfg['Servers'][$i]['password'] = '';"
        assert content =~ "$cfg['Servers'][$i]['verbose'] = 'test';"
        refute content =~ "['host']"
      end)
    end

    test "on SQL Server and on SQLite, which have no admin of their own, Adminer" do
      for driver <- [:tds, :ecto_sqlite3] do
        igniter = driver |> on() |> install()
        assert_creates(igniter, "adminer/login.php")
        assert {%{admin: ["adminer"]}, _} = igniter |> apply_igniter!() |> DbAdmin.state()
      end
    end

    test "every one of ecto's databases has a default, and it serves that database" do
      served =
        for {name, _doc, [{"ecto", database: d}]} <- DbAdmin.choices()[:admin],
            into: %{},
            do: {name, List.wrap(d)}

      for database <- ~w(postgres mysql mssql sqlite3) do
        admin = DbAdmin.default(database)
        assert admin in Map.keys(DbAdmin.files())
        assert database in Map.get(served, admin, [database])
      end
    end
  end

  describe "--admin adminer" do
    test "writes the login file, the workspace's Postgres named after the app" do
      install(phx_test_project(), ~w(--admin adminer))
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
      |> install(~w(--admin adminer))
      |> assert_creates("adminer/login.php", fn content ->
        assert content =~ ~s|'server' => getenv('WORKBENCH_SERVER') ?: '127.0.0.1:3306',|
        assert content =~ ~s|'driver' => 'server',|
        assert content =~ ~s|\n\t'root',\n|
      end)
    end

    test "on MSSQL: sa on 1433" do
      on(:tds)
      |> install(~w(--admin adminer))
      |> assert_creates("adminer/login.php", fn content ->
        assert content =~ ~s|'server' => getenv('WORKBENCH_SERVER') ?: '127.0.0.1:1433',|
        assert content =~ ~s|'driver' => 'mssql',|
        assert content =~ ~s|\n\t'sa',\n|
      end)
    end

    test "on SQLite: no server, no user, the dev file as the database" do
      on(:ecto_sqlite3)
      |> install(~w(--admin adminer))
      |> assert_creates("adminer/login.php", fn content ->
        assert content =~ ~s|'server' => getenv('WORKBENCH_SERVER') ?: '',|
        assert content =~ ~s|'driver' => 'sqlite',|
        assert content =~ ~s|\n\t'',\n|
        assert content =~ ~s|getenv('WORKBENCH_DATABASE') ?: '/app/src/test_dev.db',|
      end)
    end
  end

  describe "--admin cloudbeaver" do
    test "writes the connection: the driver and who signs in, the place left to the compose" do
      install(phx_test_project(), ~w(--admin cloudbeaver))
      |> assert_creates("cloudbeaver/data-sources.json", fn content ->
        assert {:ok, %{"folders" => %{}, "connections" => %{"workbench-test" => connection}}} =
                 Jason.decode(content)

        assert %{
                 "provider" => "postgresql",
                 "driver" => "postgres-jdbc",
                 "name" => "test",
                 "save-password" => true,
                 "configuration" => %{
                   "host" => "${WORKBENCH_HOST}",
                   "port" => "${WORKBENCH_PORT}",
                   "database" => "${WORKBENCH_DATABASE}",
                   "auth-model" => "native",
                   "auth-properties" => %{"user" => "postgres", "password" => "postgres"}
                 }
               } = connection
      end)
    end

    test "on MySQL and on SQL Server: CloudBeaver's ids for the driver, ecto's credentials" do
      for {dep, provider, driver, user, password} <- [
            {:myxql, "mysql", "mysql8", "root", ""},
            {:tds, "sqlserver", "microsoft", "sa", "some!Password"}
          ] do
        on(dep)
        |> install(~w(--admin cloudbeaver))
        |> assert_creates("cloudbeaver/data-sources.json", fn content ->
          assert %{"connections" => %{"workbench-test" => connection}} = Jason.decode!(content)
          assert %{"provider" => ^provider, "driver" => ^driver} = connection

          assert connection["configuration"]["auth-properties"] ==
                   %{"user" => user, "password" => password}
        end)
      end
    end

    test "refuses on SQLite, a driver CloudBeaver's server ships disabled" do
      igniter = on(:ecto_sqlite3) |> install(~w(--admin cloudbeaver))

      assert igniter.issues == [
               "--admin cloudbeaver builds on ecto with database postgres, mysql or mssql, " <>
                 "and this project's database is sqlite3."
             ]
    end
  end

  describe "several admins, and a second run" do
    test "one file each" do
      igniter = install(phx_test_project(), ~w(--admin pgadmin,adminer))
      assert_creates(igniter, "pgadmin/servers.json")
      assert_creates(igniter, "adminer/login.php")
    end

    test "a second run adds another and leaves the file that is there alone" do
      igniter = install() |> apply_igniter!() |> install(~w(--admin pgadmin,adminer))

      assert_creates(igniter, "adminer/login.php")
      assert Enum.any?(igniter.notices, &(&1 =~ "pgadmin/servers.json already exists"))
      assert {%{admin: ~w(pgadmin adminer)}, _} = igniter |> apply_igniter!() |> DbAdmin.state()
    end

    test "is a no-op when the file is there" do
      install() |> apply_igniter!() |> install() |> assert_unchanged()
    end

    test "one that does not serve the database refuses the whole run" do
      igniter = on(:myxql) |> install(~w(--admin adminer,pgadmin))

      assert igniter.issues == [
               "--admin pgadmin builds on ecto with database postgres, " <>
                 "and this project's database is mysql."
             ]

      refute Igniter.exists?(igniter, "adminer/login.php")
    end

    test "phpMyAdmin refuses off MySQL" do
      assert [issue] = install(phx_test_project(), ~w(--admin phpmyadmin)).issues
      assert issue =~ "--admin phpmyadmin builds on ecto with database mysql"
      assert issue =~ "this project's database is postgres"
    end

    test "an unknown admin is named" do
      assert install(phx_test_project(), ~w(--admin dbeaver)).issues ==
               ["--admin takes pgadmin, phpmyadmin, adminer, cloudbeaver, got: dbeaver"]
    end
  end

  describe "the mark" do
    test "the file of any admin" do
      assert {false, _} = DbAdmin.installed?(phx_test_project())
      assert {true, _} = install() |> apply_igniter!() |> DbAdmin.installed?()

      assert {true, _} =
               install(phx_test_project(), ~w(--admin cloudbeaver))
               |> apply_igniter!()
               |> DbAdmin.installed?()
    end

    test "refuses without ecto" do
      assert [issue] = install(test_project()).issues
      assert issue =~ "db_admin builds on ecto, not in the project yet"
    end
  end

  describe "the manifest" do
    test "asks the workspace for the containers of the admins the project carries" do
      assert DbAdmin.services(%{admin: ~w(pgadmin adminer)}) == ~w(pgadmin adminer)
      assert DbAdmin.services(%{}) == []
      assert DbAdmin.services(:any) == ~w(pgadmin phpmyadmin adminer cloudbeaver)
    end

    test "builds on ecto; each admin on the databases it serves" do
      assert DbAdmin.requires() == ["ecto"]

      assert [
               {"pgadmin", _, [{"ecto", database: "postgres"}]},
               {"phpmyadmin", _, [{"ecto", database: "mysql"}]},
               {"adminer", _},
               {"cloudbeaver", _, [{"ecto", database: ~w(postgres mysql mssql)}]}
             ] = DbAdmin.choices()[:admin]
    end

    test "Adminer's login values per adapter, the dev pod's" do
      assert DbAdmin.login("postgres", :lorem) ==
               [
                 app_name: :lorem,
                 driver: "pgsql",
                 server: "127.0.0.1:5432",
                 username: "postgres",
                 database: "lorem_dev"
               ]

      assert DbAdmin.login("mysql", :lorem)[:driver] == "server"
      assert DbAdmin.login("mssql", :lorem)[:server] == "127.0.0.1:1433"

      assert DbAdmin.login("sqlite3", :lorem) ==
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
