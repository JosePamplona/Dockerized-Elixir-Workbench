defmodule Mix.Tasks.Workbench.Install.Exdebug do
  use Igniter.Mix.Task

  @dep {:ex_debug, "~> 1.0"}
  @shortdoc "Adds the ExDebug utility to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_exdebug` feature: adds
  `#{inspect(@dep)}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix workbench.install.exdebug"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
  end
end
