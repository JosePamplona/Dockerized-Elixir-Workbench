defmodule Mix.Tasks.Workbench.Install.Githooks do
  use Igniter.Mix.Task

  @dep {:git_hooks, "~> 0.7", only: :dev, runtime: false}
  @shortdoc "Adds git_hooks management to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_githooks` feature: adds
  `#{inspect(@dep)}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix workbench.install.githooks"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
  end
end
