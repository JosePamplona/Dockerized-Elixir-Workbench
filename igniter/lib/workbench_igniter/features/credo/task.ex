defmodule Mix.Tasks.Workbench.Install.Credo do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Credo

  @shortdoc "Adds Credo static code analysis to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_credo` feature: adds
  `#{inspect(Credo.dep())}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Credo.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Credo.install(igniter)
end
