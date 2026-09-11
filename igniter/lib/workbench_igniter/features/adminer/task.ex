defmodule Mix.Tasks.Workbench.Install.Adminer do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Adminer

  @shortdoc "Adds Adminer to the workspace, open on the project's database, whatever the adapter"

  @moduledoc """
  #{@shortdoc}

  Writes `#{Adminer.login_file()}` — the login Adminer opens with: the
  workspace's database with its driver and user off the project's
  adapter, and the password Adminer checks itself — and declares the
  `adminer` container the next `./wb.sh bake` renders into the compose.
  Builds on ecto, on any of its adapters. Idempotent — re-running it is
  a no-op.

  ## Example

      mix workbench.install.adminer
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Adminer.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Adminer.install(igniter)
end
