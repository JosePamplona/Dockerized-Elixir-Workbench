defmodule WorkbenchIgniter.Features.Exmachina do
  @moduledoc """
  ExMachina test factories. Installed on demand with
  `mix workbench.install.exmachina` (`wb.sh add exmachina`).
  """
  use WorkbenchIgniter.Feature

  @dep {:ex_machina, "~> 2.8", only: :test}

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def task, do: "workbench.install.exmachina"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: the dependency itself.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, elem(@dep, 0))

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
  end
end
