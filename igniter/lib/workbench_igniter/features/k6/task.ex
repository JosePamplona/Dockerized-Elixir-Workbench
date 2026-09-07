defmodule Mix.Tasks.Workbench.Install.K6 do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.K6

  @shortdoc "Adds k6 load testing to the workspace, with a smoke test to start from"

  @moduledoc """
  #{@shortdoc}

  Writes `#{K6.script_file()}` — five virtual users asking the root page
  for fifteen seconds — and declares the `k6` container the next
  `./wb.sh bake` renders into the compose, under a profile `up` never
  starts. `./wb.sh k6 [SCRIPT]` runs it. Idempotent — re-running it is
  a no-op.

  ## Example

      mix workbench.install.k6
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: K6.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: K6.install(igniter)
end
