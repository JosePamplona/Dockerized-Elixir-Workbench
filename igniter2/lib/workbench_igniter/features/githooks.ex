defmodule WorkbenchIgniter.Features.Githooks do
  @moduledoc """
  git_hooks management. Standalone: not in the `WorkbenchIgniter.Features`
  registry — `workbench.setup` never composes it, it is installed by hand
  with `mix workbench.install.githooks`.

  Single-file cartridge: manifest, install logic and the mix task shell
  live in this file (template-less features don't need a directory).
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
