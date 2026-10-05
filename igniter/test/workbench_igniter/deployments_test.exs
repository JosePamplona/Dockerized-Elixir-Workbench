defmodule WorkbenchIgniter.DeploymentsTest do
  @moduledoc false

  # Each compose file beside the project, against what the cartridges
  # ask for: the fixtures `mix workbench.compose` is tested on, laid
  # under the names the workspace keeps them by.

  use ExUnit.Case, async: true

  alias WorkbenchIgniter.Deployments

  @fixtures Path.expand("../fixtures/compose", __DIR__)

  setup do
    dir = Path.join(System.tmp_dir!(), "wb_deploy_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  defp lay(dir, files) do
    for {name, fixture} <- files,
        do: File.cp!(Path.join(@fixtures, fixture), Path.join(dir, Atom.to_string(name)))
  end

  test "in sync when every file says what the cartridges ask for", %{dir: dir} do
    lay(dir,
      "docker-compose.yml": "dev-db.yml",
      "docker-compose.prod.yml": "prod-db.yml",
      "docker-compose.scaled.yml": "scaled-db-balancer-cluster-4.yml"
    )

    read = Deployments.read(dir, ~w(postgres pgadmin))

    assert %{baked: true, in_sync: true, stray: [], missing: []} = read.dev
    assert read.dev.services == ~w(pod app database pgadmin)
    assert %{baked: true, in_sync: true} = read.prod
    assert read.prod.services == ~w(pod app migrate database pgadmin)
    # The scaled file has no pgAdmin to render and its replicas stand for app.
    assert %{baked: true, in_sync: true, stray: [], missing: []} = read.scaled
    assert read.scaled.services == ~w(app1 app2 app3 app4 balancer migrate database)
  end

  test "a service left behind is stray, one brought in since is missing", %{dir: dir} do
    lay(dir, "docker-compose.yml": "dev-db.yml", "docker-compose.prod.yml": "prod-nodb.yml")

    # pgadmin ejected: the dev file still declares it. Prod baked with no
    # database, and ecto in since: database missing.
    read = Deployments.read(dir, ~w(postgres))

    assert %{in_sync: false, stray: ["pgadmin"], missing: []} = read.dev
    assert %{in_sync: false, stray: [], missing: ["migrate", "database"]} = read.prod
    assert %{baked: false, in_sync: nil, services: []} = read.scaled
  end

  test "declared/1 reads the services block and nothing else" do
    text = """
    name: lorem_ipsum

    x-app: &app
      image: lorem-ipsum:0.1.0-prod
      networks:
        default:

    services:
      app1:
        <<: *app
      balancer:
        image: nginx:alpine
      database:
        image: postgres:latest
    networks:
      default:
    """

    assert Deployments.declared(text) == ~w(app1 balancer database)
  end
end
