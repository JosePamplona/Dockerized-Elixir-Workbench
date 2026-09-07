defmodule Mix.Tasks.Workbench.Compose do
  use Mix.Task

  @shortdoc "Writes one of the workspace's compose files, from what wb.sh knows"

  @moduledoc """
  #{@shortdoc}

      mix workbench.compose --deploy dev|prod|scaled [OPTIONS] [--out FILE]

  The YAML of one deployment: on standard output, or into `--out FILE`
  — which is how `wb.sh bake` runs it, in the toolchain image with the
  workspace mounted, since the `deps.get` and `deps.compile` before the
  task write to standard output too. Everything that shapes the file
  arrives as an option — the host ports because they are chosen on the
  host, the images and versions because `config.conf` names them —
  except the services, which the task asks the project for when
  `--services` is not given: what the installed cartridges declare
  (`WorkbenchIgniter.Features.services/1`). With `--services` the task
  holds no opinion of its own, and a test can run it without a project.
  `WorkbenchIgniter.Compose` renders the plan the options make, off the
  templates under `priv/compose/`.

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
  * `--services LIST` - the containers the workspace runs beside the
    app, by name, separated by commas: `postgres`, `pgadmin`. `""` or
    `none` for no service at all. Absent, the project is asked. Without
    `postgres` there is no database and nothing to migrate; without
    `pgadmin`, no pgAdmin.
  * `--clustering` / `--no-clustering` - scaled: whether the release is
    distributed, which decides `DNS_CLUSTER_QUERY`.
  * `--replicas N`, `--replica-ports P1,P2,…` - scaled: how many, and
    the host port of each, in order.
  * `--balancer-port N` / `--no-balancer` - scaled: the entry point in
    front of the replicas, or none.
  * `--out FILE` - write the file there instead of standard output.
  """

  alias WorkbenchIgniter.Compose

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [out: :string])

    case Compose.plan_from_argv(argv) do
      {:ok, plan} -> write(Compose.render(plan), opts[:out])
      {:error, why} -> Mix.raise("workbench.compose: " <> why)
    end
  end

  defp write(yaml, nil), do: IO.write(yaml)
  defp write(yaml, path), do: File.write!(path, yaml)
end
