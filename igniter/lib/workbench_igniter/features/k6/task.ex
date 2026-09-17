defmodule Mix.Tasks.Workbench.Install.K6 do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.K6

  @shortdoc "Adds k6 load testing to the workspace, with a smoke test to start from"

  @moduledoc """
  #{@shortdoc}

  Writes `#{K6.script_file()}` — five virtual users asking the root page
  for fifteen seconds — and declares the `k6` container, which
  `./wb.sh add` bakes into the compose in the same commit, under a
  profile `up` never starts. `./wb.sh k6 [SCRIPT]` runs it. Idempotent — re-running it is
  a no-op.

  ## Example

      mix workbench.install.k6
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: K6.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: K6.install(igniter)
end
