defmodule WorkbenchIgniter.ComposeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Compose
  alias WorkbenchIgniter.Features

  @fixtures Path.expand("../fixtures/compose", __DIR__)

  # The pod deployments, as `wb.sh bake` and `up --deploy prod` ask for them.
  @pod ~w(--app-name lorem_ipsum --uid 1000 --gid 1000 --app-port 4000 --pgadmin-port 5050
          --postgres-version latest --pgadmin-version latest --nginx-version alpine)
  @dev ~w(--deploy dev --image lorem-ipsum:local --dockerfile Dockerfile.local) ++ @pod
  @prod ~w(--deploy prod --image lorem-ipsum:0.1.0-prod --dockerfile Dockerfile) ++ @pod

  # The scaled deployment, as `up --deploy scaled` asks for it: the
  # balancer takes the first port and the replicas the ones after.
  @scaled ~w(--deploy scaled --app-name lorem_ipsum --image lorem-ipsum:0.1.0-prod
             --dockerfile Dockerfile --postgres-version latest --nginx-version alpine)
  @balancer ~w(--balancer-port 4000 --replica-ports 4001,4002,4003,4004)
  @no_balancer ~w(--no-balancer --replica-ports 4000,4001,4002,4003)

  @cases [
    {"dev-db.yml", @dev ++ ~w(--services postgres,pgadmin)},
    {"dev-nodb.yml", @dev ++ ["--services", ""]},
    {"dev-db-k6.yml", @dev ++ ~w(--services postgres,pgadmin,k6)},
    {"prod-db.yml", @prod ++ ~w(--services postgres,pgadmin)},
    {"prod-nodb.yml", @prod ++ ~w(--services none)},
    {"prod-db-k6.yml", @prod ++ ~w(--services postgres,pgadmin,k6)},
    {"scaled-db-balancer-cluster-4.yml",
     @scaled ++ ~w(--services postgres,pgadmin --clustering) ++ @balancer},
    {"scaled-db-balancer-cluster-4-k6.yml",
     @scaled ++ ~w(--services postgres,pgadmin,k6 --clustering) ++ @balancer},
    {"scaled-db-nobalancer-cluster-4-k6.yml",
     @scaled ++ ~w(--services postgres,pgadmin,k6 --clustering) ++ @no_balancer},
    {"scaled-db-balancer-cluster-2.yml",
     @scaled ++
       ~w(--services postgres --clustering --replicas 2 --balancer-port 4000 --replica-ports 4001,4002)},
    {"scaled-db-balancer-nocluster-4.yml",
     @scaled ++ ~w(--services postgres,pgadmin --no-clustering) ++ @balancer},
    {"scaled-db-nobalancer-cluster-4.yml",
     @scaled ++ ~w(--services postgres,pgadmin --clustering) ++ @no_balancer},
    {"scaled-db-nobalancer-nocluster-4.yml",
     @scaled ++ ~w(--services postgres,pgadmin --no-clustering) ++ @no_balancer},
    {"scaled-nodb-balancer-cluster-4.yml",
     @scaled ++ ~w(--services none --clustering) ++ @balancer},
    {"scaled-nodb-balancer-nocluster-4.yml",
     @scaled ++ ~w(--services none --no-clustering) ++ @balancer},
    {"scaled-nodb-nobalancer-cluster-4.yml",
     @scaled ++ ~w(--services none --clustering) ++ @no_balancer},
    {"scaled-nodb-nobalancer-nocluster-4.yml",
     @scaled ++ ~w(--services none --no-clustering) ++ @no_balancer},
    {"dev-mysql.yml", @dev ++ ~w(--services mysql --mysql-version 8)},
    {"prod-mysql.yml", @prod ++ ~w(--services mysql --mysql-version 8)},
    {"scaled-mysql-balancer-cluster-4.yml",
     @scaled ++ ~w(--services mysql --mysql-version 8 --clustering) ++ @balancer},
    {"dev-mssql.yml", @dev ++ ~w(--services mssql --mssql-version 2022-latest)},
    {"prod-mssql.yml", @prod ++ ~w(--services mssql --mssql-version 2022-latest)},
    {"scaled-mssql-balancer-cluster-4.yml",
     @scaled ++ ~w(--services mssql --mssql-version 2022-latest --clustering) ++ @balancer},
    {"dev-sqlite.yml", @dev ++ ~w(--services sqlite)},
    {"prod-sqlite.yml", @prod ++ ~w(--services sqlite)}
  ]

  describe "render/1 writes the fixture" do
    for {fixture, argv} <- @cases do
      test fixture do
        {:ok, plan} = Compose.plan_from_argv(unquote(argv))
        assert Compose.render(plan) == File.read!(Path.join(@fixtures, unquote(fixture)))
      end
    end
  end

  describe "plan_from_argv/1" do
    test "wants a deployment" do
      assert {:error, "--deploy is required" <> _} = Compose.plan_from_argv(@pod)
    end

    test "knows three deployments" do
      assert {:error, "unknown deployment \"staging\"" <> _} =
               Compose.plan_from_argv(~w(--deploy staging) ++ @pod)
    end

    test "counts the replica ports" do
      assert {:error, "--replica-ports names 3 ports for 4 replicas"} =
               Compose.plan_from_argv(@scaled ++ ~w(--balancer-port 4000 --replica-ports 1,2,3))
    end

    test "names what a deployment needs" do
      assert {:error, "missing: --app-port, --uid, --gid, --pgadmin-port"} =
               Compose.plan_from_argv(
                 ~w(--deploy dev --app-name x --image i --dockerfile d --services postgres,pgadmin)
               )
    end

    test "asks for the pgadmin port only with pgadmin" do
      assert {:error, "missing: --app-port, --uid, --gid"} =
               Compose.plan_from_argv(
                 ~w(--deploy dev --app-name x --image i --dockerfile d --services postgres)
               )
    end

    test "asks the project for the services when --services is not given" do
      {:ok, plan} = Compose.plan_from_argv(@dev, fn -> ["postgres", "pgadmin"] end)
      assert plan.services == ["postgres", "pgadmin"]
      assert Compose.render(plan) == File.read!(Path.join(@fixtures, "dev-db.yml"))
    end

    test "takes --services as given, trimmed, and never asks then" do
      {:ok, plan} =
        Compose.plan_from_argv(@dev ++ ["--services", "postgres, pgadmin"], fn ->
          flunk("asked")
        end)

      assert plan.services == ["postgres", "pgadmin"]
    end

    test "accepts --out without making it part of the plan" do
      {:ok, plan} = Compose.plan_from_argv(@dev ++ ~w(--services none --out /tmp/x.yml))
      refute Map.has_key?(plan, :out)
    end

    test "refuses what it does not know" do
      assert {:error, "unknown or malformed option --port"} =
               Compose.plan_from_argv(~w(--deploy dev --port 1))
    end

    test "one database at most" do
      assert {:error, "one database at most, got postgres and mysql"} =
               Compose.plan_from_argv(@dev ++ ~w(--services postgres,mysql))
    end

    test "no SQLite on the scaled deployment" do
      assert {:error, "a scaled deployment cannot run on SQLite" <> _} =
               Compose.plan_from_argv(@scaled ++ ~w(--services sqlite) ++ @balancer)
    end
  end

  describe "services/1" do
    test "a Phoenix project with Ecto asks for postgres alone: pgadmin is a cartridge" do
      assert {["postgres"], _} = Compose.services(phx_test_project())
    end

    test "with pgadmin and k6 inserted, the three in catalog order" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.pgadmin", [])
        |> Igniter.compose_task("workbench.install.k6", [])
        |> apply_igniter!()

      assert {["pgadmin", "k6", "postgres"], _} = Compose.services(igniter)
    end

    test "a project without ecto_sql asks for nothing" do
      assert {[], _} = Compose.services(test_project())
    end

    test "is what Features.services/1 says" do
      {ours, _} = Compose.services(phx_test_project())
      {theirs, _} = Features.services(phx_test_project())
      assert ours == theirs
    end
  end

  describe "the ecto cartridge's services" do
    alias WorkbenchIgniter.Features.Ecto

    test "each adapter asks for its own: a server, or a place for the file" do
      assert Ecto.services(%{database: "postgres"}) == ["postgres"]
      assert Ecto.services(%{database: "mysql"}) == ["mysql"]
      assert Ecto.services(%{database: "mssql"}) == ["mssql"]
      assert Ecto.services(%{database: "sqlite3"}) == ["sqlite"]
      assert Ecto.services(%{}) == []
    end

    test "connection/2 is phx.new's dev credentials on the workspace's service, or the file's path" do
      assert Ecto.connection("postgres", :test) ==
               ~s|DATABASE_URL="ecto://postgres:postgres@localhost:5432/test_prod"|

      assert Ecto.connection("mysql", :test) ==
               ~s|DATABASE_URL="ecto://root:@localhost:3306/test_prod"|

      assert Ecto.connection("mssql", :test) ==
               ~s|DATABASE_URL="ecto://sa:some!Password@localhost:1433/test_prod"|

      assert Ecto.connection("sqlite3", :test) == ~s|DATABASE_PATH="/app/data/test_prod.db"|
      assert Ecto.credentials("sqlite3") == nil
    end

    test "reads the adapter off the project" do
      assert {%{database: "postgres"}, _} = Ecto.state(phx_test_project())
    end
  end

  describe "mix workbench.compose --out" do
    @tag :tmp_dir
    test "writes the file instead of printing it", %{tmp_dir: dir} do
      path = Path.join(dir, "docker-compose.yml")
      Mix.Task.rerun("workbench.compose", @dev ++ ~w(--services postgres,pgadmin --out) ++ [path])
      assert File.read!(path) == File.read!(Path.join(@fixtures, "dev-db.yml"))
    end
  end
end
