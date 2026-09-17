defmodule Mix.Tasks.Workbench.Install.Exdebug do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Exdebug

  @shortdoc "Adds the ExDebug utility to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_exdebug` feature: adds
  `#{inspect(Exdebug.dep())}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Exdebug.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Exdebug.install(igniter)
end
