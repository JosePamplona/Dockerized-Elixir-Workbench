defmodule Mix.Tasks.Workbench.Install.Credo do
  use Igniter.Mix.Task

  @dep {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
  @shortdoc "Adds Credo static code analysis to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_credo` feature: adds
  `#{inspect(@dep)}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix workbench.install.credo"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
  end
end
