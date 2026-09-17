defmodule Mix.Tasks.Workbench.Install.Exmachina do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Exmachina

  @shortdoc "Adds ExMachina test factories to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_exmachina` feature: adds
  `#{inspect(Exmachina.dep())}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Exmachina.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Exmachina.install(igniter)
end
