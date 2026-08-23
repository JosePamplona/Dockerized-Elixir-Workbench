defmodule WorkbenchIgniter.Features.Exdebug do
  @moduledoc """
  ExDebug helper — part of the trivial dep-only group toggled by
  `--enhance`.

  Single-file cartridge: manifest, install logic and the mix task shell
  live in this file (template-less features don't need a directory).
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

defmodule Mix.Tasks.Workbench.Install.Exdebug do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Exdebug

  @shortdoc "Adds the ExDebug utility to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_exdebug` feature: adds
  `#{inspect(Exdebug.dep())}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Exdebug.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Exdebug.install(igniter)
end
