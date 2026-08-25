defmodule WorkbenchIgniter.Features.Exdebug do
  @moduledoc """
  ExDebug helper — part of the trivial dep-only group toggled by
  `--enhance`.
  """
  use WorkbenchIgniter.Feature

  @dep {:ex_debug, "~> 1.0"}

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def task, do: "workbench.install.exdebug"

  @impl true
  def enabled?(opts), do: opts[:enhance] == true

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
