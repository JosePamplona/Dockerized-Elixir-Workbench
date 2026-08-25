defmodule Mix.Tasks.Workbench.Install.Githooks do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Githooks

  @shortdoc "Adds git_hooks management to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_githooks` feature: adds
  `#{inspect(Githooks.dep())}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Githooks.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Githooks.install(igniter)
end
