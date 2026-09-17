defmodule Mix.Tasks.Workbench.Install.Pgadmin do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Pgadmin

  @shortdoc "Adds pgAdmin to the workspace, open on the project's Postgres"

  @moduledoc """
  #{@shortdoc}

  Writes `#{Pgadmin.servers_file()}` — the servers pgAdmin opens with,
  the workspace's database named after the project — and declares the
  `pgadmin` container, which `./wb.sh add` bakes into the compose in the
  same commit.
  Builds on ecto, on Postgres only. Idempotent — re-running it is a no-op.

  ## Example

      mix workbench.install.pgadmin
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Pgadmin.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Pgadmin.install(igniter)
end
