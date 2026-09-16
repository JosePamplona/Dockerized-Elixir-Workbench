defmodule WorkbenchIgniter.ComposeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Compose
  alias WorkbenchIgniter.Features

  @fixtures Path.expand("../fixtures/compose", __DIR__)

  # The pod deployments, as `wb.sh bake` and `up --deploy prod` ask for them.
  @pod ~w(--app-name lorem_ipsum --uid 1000 --gid 1000 --app-port 4000 --pgadmin-port 5050
          --adminer-port 8080 --grafana-port 3000 --postgres-version latest
          --pgadmin-version latest --adminer-version 6 --nginx-version alpine)
  @dev ~w(--deploy dev --image lorem-ipsum:local --dockerfile Dockerfile.local) ++ @pod
  @prod ~w(--deploy prod --image lorem-ipsum:0.1.0-prod --dockerfile Dockerfile) ++ @pod

  # The scaled deployment, as `up --deploy scaled` asks for it: the
  # balancer takes the first port and the replicas the ones after.
  @scaled ~w(--deploy scaled --app-name lorem_ipsum --image lorem-ipsum:0.1.0-prod
             --dockerfile Dockerfile --postgres-version latest --nginx-version alpine
             --grafana-port 3000)
  @balancer ~w(--balancer-port 4000 --replica-ports 4001,4002,4003,4004)
  @no_balancer ~w(--no-balancer --replica-ports 4000,4001,4002,4003)

  @cases [
    {"dev-db.yml", @dev ++ ~w(--services postgres,pgadmin)},
    # A vanilla `new` on Postgres: the database, no pgAdmin and no port for it.
    {"dev-postgres.yml", @dev ++ ~w(--services postgres)},
    {"prod-postgres.yml", @prod ++ ~w(--services postgres)},
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
    {"prod-sqlite.yml", @prod ++ ~w(--services sqlite)},
    # The monitoring cartridge's two services; with k6, its results go to Prometheus.
    {"dev-db-monitoring.yml", @dev ++ ~w(--services postgres,pgadmin,prometheus,grafana)},
    {"dev-nodb-monitoring.yml", @dev ++ ~w(--services prometheus,grafana)},
    {"dev-db-k6-monitoring.yml", @dev ++ ~w(--services postgres,pgadmin,k6,prometheus,grafana)},
    {"prod-db-monitoring.yml", @prod ++ ~w(--services postgres,pgadmin,prometheus,grafana)},
    {"scaled-db-balancer-cluster-4-k6-monitoring.yml",
     @scaled ++ ~w(--services postgres,pgadmin,k6,prometheus,grafana --clustering) ++ @balancer},
    {"scaled-nodb-nobalancer-nocluster-4-monitoring.yml",
     @scaled ++ ~w(--services prometheus,grafana --no-clustering) ++ @no_balancer},
    # The adminer cartridge: on every adapter, beside pgAdmin or alone;
    # on SQLite it mounts the file and runs as its owner.
    {"dev-db-adminer.yml", @dev ++ ~w(--services postgres,pgadmin,adminer)},
    {"prod-postgres-adminer.yml", @prod ++ ~w(--services postgres,adminer)},
    {"dev-mysql-adminer.yml", @dev ++ ~w(--services mysql,adminer --mysql-version 8)},
    {"dev-mssql-adminer.yml", @dev ++ ~w(--services mssql,adminer --mssql-version 2022-latest)},
    {"dev-sqlite-adminer.yml", @dev ++ ~w(--services sqlite,adminer)},
    {"prod-sqlite-adminer.yml", @prod ++ ~w(--services sqlite,adminer)},
    {"scaled-db-adminer-balancer-cluster-4.yml",
     @scaled ++ ~w(--services postgres,adminer --clustering) ++ @balancer}
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

    test "asks for the adminer port with adminer, on the pod alone" do
      assert {:error, "missing: --app-port, --uid, --gid, --adminer-port"} =
               Compose.plan_from_argv(
                 ~w(--deploy dev --app-name x --image i --dockerfile d --services postgres,adminer)
               )

      assert {:ok, _} =
               Compose.plan_from_argv(
                 ~w(--deploy scaled --app-name x --image i --dockerfile d --services postgres,adminer) ++
                   @balancer
               )
    end

    test "asks for the grafana port with grafana, on every deployment" do
      assert {:error, "missing: --app-port, --uid, --gid, --grafana-port"} =
               Compose.plan_from_argv(
                 ~w(--deploy dev --app-name x --image i --dockerfile d --services prometheus,grafana)
               )

      assert {:error, "missing: --grafana-port"} =
               Compose.plan_from_argv(
                 ~w(--deploy scaled --app-name x --image i --dockerfile d --services grafana) ++
                   @balancer
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

    test "with pgadmin, adminer, k6 and monitoring inserted, every service in catalog order" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.pgadmin", [])
        |> Igniter.compose_task("workbench.install.adminer", [])
        |> Igniter.compose_task("workbench.install.k6", [])
        |> Igniter.compose_task("workbench.install.monitoring", [])
        |> apply_igniter!()

      assert {["pgadmin", "adminer", "k6", "prometheus", "grafana", "postgres"], _} =
               Compose.services(igniter)
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

  describe "service_names/2" do
    test "the pod: the database and its helpers by engine, the extras by name" do
      assert Compose.service_names(:dev, ~w(postgres pgadmin)) ==
               %{names: ~w(pod app database pgadmin), optional: [], replicas: false}

      assert Compose.service_names(:dev, ~w(mysql adminer)).names ==
               ~w(pod app database adminer)

      assert Compose.service_names(:prod, ~w(postgres k6 prometheus grafana)) ==
               %{
                 names: ~w(pod app migrate database k6 prometheus grafana),
                 optional: [],
                 replicas: false
               }

      assert Compose.service_names(:prod, ~w(mssql)).names ==
               ~w(pod app migrate database_init database)

      assert Compose.service_names(:prod, ~w(sqlite)).names == ~w(pod app migrate data_init)
      assert Compose.service_names(:dev, []).names == ~w(pod app)
    end

    test "the scaled deployment: replicas for app, the balancer optional, no pgAdmin, no Adminer" do
      assert Compose.service_names(:scaled, ~w(postgres pgadmin adminer grafana)) ==
               %{names: ~w(migrate database grafana), optional: ["balancer"], replicas: true}
    end
  end
end
