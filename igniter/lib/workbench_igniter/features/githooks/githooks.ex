defmodule WorkbenchIgniter.Features.Githooks do
  @moduledoc """
  git_hooks management. Standalone: not in the `WorkbenchIgniter.Features`
  registry — `workbench.setup` never composes it, it is installed by hand
  with `mix workbench.install.githooks`.
  """
  use WorkbenchIgniter.Feature

  @dep {:git_hooks, "~> 0.7", only: :dev, runtime: false}

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def task, do: "workbench.install.githooks"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
  end
end
