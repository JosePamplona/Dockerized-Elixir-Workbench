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
    {"prod-db.yml", @prod ++ ~w(--services postgres,pgadmin)},
    {"prod-nodb.yml", @prod ++ ~w(--services none)},
    {"scaled-db-balancer-cluster-4.yml",
     @scaled ++ ~w(--services postgres,pgadmin --clustering) ++ @balancer},
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
     @scaled ++ ~w(--services none --no-clustering) ++ @no_balancer}
  ]

  describe "render/1 writes the file the bash bake wrote" do
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
  end

  describe "services/1" do
    test "a Phoenix project with Ecto asks for postgres and pgadmin" do
      assert {["postgres", "pgadmin"], _} = Compose.services(phx_test_project())
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

    test "postgres brings its pgadmin" do
      assert Ecto.services(%{database: "postgres"}) == ["postgres", "pgadmin"]
    end

    test "the other adapters bring no container yet" do
      for db <- ~w(mysql mssql sqlite3), do: assert(Ecto.services(%{database: db}) == [])
      assert Ecto.services(%{}) == []
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
