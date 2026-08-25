defmodule WorkbenchIgniter.Features.Credo do
  @moduledoc """
  Credo static code analysis — part of the trivial dep-only group toggled
  by `--enhance`.
  """
  use WorkbenchIgniter.Feature

  @dep {:credo, "~> 1.7", only: [:dev, :test], runtime: false}

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def task, do: "workbench.install.credo"

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
