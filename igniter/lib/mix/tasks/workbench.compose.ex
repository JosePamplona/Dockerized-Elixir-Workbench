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
  host, the image tags because `config.conf` names them —
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
  * `--app-port N` - the app's host port; the container side is
    `--internal-port` (4000).
  * `--port NAME=PORT`, as many as there are - the host port of a port
    a service publishes, by the name its cartridge gives it (`pgadmin`,
    `adminer`, `grafana`). `--keep-ports-of FILE` keeps the ones FILE
    already publishes — the deployment's file as it stands — so a bake
    moves nothing. A port that comes from neither is a **need**: the
    task writes no file, prints one `need> NAME DEFAULT` line for each
    and exits with 3, for the script to choose a free port from the
    default on — ports are chosen on the host — and ask again.
  * `--version NAME=TAG`, as many as there are - a service's image tag,
    by its name (`postgres`, `mysql`, `mssql`, `pgadmin`, `adminer`,
    `k6`, `prometheus`, `grafana`, and the balancer's `nginx`). The
    cartridge has the default.
  * `--services LIST` - what the workspace runs beside the app, by
    the names the cartridges ask by, separated by commas: a database —
    `postgres`, `mysql`, `mssql`, or `sqlite`, which is no server but a
    volume for the file in a release — and `pgadmin`, `adminer`, `k6`,
    `prometheus`, `grafana`. `""` or `none` for no service at all. Absent, the project is asked. One
    database at most, and never `sqlite` on the scaled deployment:
    replicas cannot share a file. Without a database there is nothing
    to migrate; with `grafana`, the app waits for it.
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
      {:ok, plan} ->
        write(Compose.render(plan), opts[:out])

      {:needs, needs} ->
        for {name, default} <- needs, do: IO.puts("need> #{name} #{default}")
        exit({:shutdown, 3})

      {:error, why} ->
        Mix.raise("workbench.compose: " <> why)
    end
  end

  defp write(yaml, nil), do: IO.write(yaml)
  defp write(yaml, path), do: File.write!(path, yaml)
end
