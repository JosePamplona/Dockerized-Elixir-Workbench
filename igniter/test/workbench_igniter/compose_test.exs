defmodule WorkbenchIgniter.ComposeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias WorkbenchIgniter.Compose

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
    {"dev-db.yml", @dev ++ ~w(--database)},
    {"dev-nodb.yml", @dev ++ ~w(--no-database)},
    {"prod-db.yml", @prod ++ ~w(--database)},
    {"prod-nodb.yml", @prod ++ ~w(--no-database)},
    {"scaled-db-balancer-cluster-4.yml", @scaled ++ ~w(--database --clustering) ++ @balancer},
    {"scaled-db-balancer-cluster-2.yml",
     @scaled ++
       ~w(--database --clustering --replicas 2 --balancer-port 4000 --replica-ports 4001,4002)},
    {"scaled-db-balancer-nocluster-4.yml",
     @scaled ++ ~w(--database --no-clustering) ++ @balancer},
    {"scaled-db-nobalancer-cluster-4.yml",
     @scaled ++ ~w(--database --clustering) ++ @no_balancer},
    {"scaled-db-nobalancer-nocluster-4.yml",
     @scaled ++ ~w(--database --no-clustering) ++ @no_balancer},
    {"scaled-nodb-balancer-cluster-4.yml",
     @scaled ++ ~w(--no-database --clustering) ++ @balancer},
    {"scaled-nodb-balancer-nocluster-4.yml",
     @scaled ++ ~w(--no-database --no-clustering) ++ @balancer},
    {"scaled-nodb-nobalancer-cluster-4.yml",
     @scaled ++ ~w(--no-database --clustering) ++ @no_balancer},
    {"scaled-nodb-nobalancer-nocluster-4.yml",
     @scaled ++ ~w(--no-database --no-clustering) ++ @no_balancer}
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
               Compose.plan_from_argv(~w(--deploy dev --app-name x --image i --dockerfile d))
    end

    test "refuses what it does not know" do
      assert {:error, "unknown or malformed option --port"} =
               Compose.plan_from_argv(~w(--deploy dev --port 1))
    end
  end
end
