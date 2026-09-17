defmodule Mix.Tasks.Workbench.Install.Mock do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Mock

  @shortdoc "Adds the Mock testing library to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_mock` feature: adds
  `#{inspect(Mock.dep())}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Mock.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Mock.install(igniter)
end
