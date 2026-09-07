defmodule Mix.Tasks.Workbench.Compose do
  use Mix.Task

  @shortdoc "Writes one of the workspace's compose files, from what wb.sh knows"

  @moduledoc """
  #{@shortdoc}

      mix workbench.compose --deploy dev|prod|scaled [OPTIONS] > docker-compose.yml

  The YAML of one deployment, on standard output: `wb.sh bake` runs
  this in the toolchain image and redirects it into the workspace. The
  task holds no opinion of its own about the project: everything that
  shapes the file arrives as an option — the host ports because they
  are chosen on the host, the two facts of the project because the
  script reads them today. `WorkbenchIgniter.Compose` renders the plan
  the options make, off the templates under `priv/compose/`.

  ## Options

  * `--deploy dev|prod|scaled` - which file. Required.
  * `--app-name NAME` - the Elixir project name (`lorem_ipsum`): the
    compose project's `name` and the prefix of its database.
  * `--image IMAGE`, `--dockerfile FILE` - the app's image and what
    builds it: the dev image and `Dockerfile.local`, or the release.
  * `--uid N`, `--gid N` - the build identity the dev image is born with.
  * `--app-port N`, `--pgadmin-port N` - host ports of the pod; the
    container side is `--internal-port` (4000) and
    `--pgadmin-internal-port` (5050).
  * `--postgres-version V`, `--pgadmin-version V`, `--nginx-version V` -
    the service images' tags.
  * `--database` / `--no-database` - whether the project runs on a
    database server (on by default). Without one there is no database,
    no pgAdmin and nothing to migrate.
  * `--clustering` / `--no-clustering` - scaled: whether the release is
    distributed, which decides `DNS_CLUSTER_QUERY`.
  * `--replicas N`, `--replica-ports P1,P2,…` - scaled: how many, and
    the host port of each, in order.
  * `--balancer-port N` / `--no-balancer` - scaled: the entry point in
    front of the replicas, or none.
  """

  alias WorkbenchIgniter.Compose

  @impl Mix.Task
  def run(argv) do
    case Compose.plan_from_argv(argv) do
      {:ok, plan} -> IO.write(Compose.render(plan))
      {:error, why} -> Mix.raise("workbench.compose: " <> why)
    end
  end
end
