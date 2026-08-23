defmodule WorkbenchIgniter.Features.Mock do
  @moduledoc """
  Mock library for tests — part of the trivial dep-only group toggled by
  `--enhance`. Also composed directly by features whose generated tests
  use it (healthcheck, coveralls).

  Single-file cartridge: manifest, install logic and the mix task shell
  live in this file (template-less features don't need a directory).
  """
  use WorkbenchIgniter.Feature

  @dep {:mock, "~> 0.3", only: :test}

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def task, do: "workbench.install.mock"

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

defmodule Mix.Tasks.Workbench.Install.Mock do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Mock

  @shortdoc "Adds the Mock testing library to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_mock` feature: adds
  `#{inspect(Mock.dep())}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Mock.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Mock.install(igniter)
end
