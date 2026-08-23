defmodule WorkbenchIgniter.Features.Exmachina do
  @moduledoc """
  ExMachina test factories. Standalone: not in the
  `WorkbenchIgniter.Features` registry — `workbench.setup` never composes
  it, it is installed by hand with `mix workbench.install.exmachina`.

  Single-file cartridge: manifest, install logic and the mix task shell
  live in this file (template-less features don't need a directory).
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

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
  end
end

defmodule Mix.Tasks.Workbench.Install.Exmachina do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Exmachina

  @shortdoc "Adds ExMachina test factories to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_exmachina` feature: adds
  `#{inspect(Exmachina.dep())}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Exmachina.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Exmachina.install(igniter)
end
