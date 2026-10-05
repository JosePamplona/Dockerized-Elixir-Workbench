defmodule WorkbenchIgniter.Features.Exdebug do
  @moduledoc """
  A look at what passes through a pipeline, that the code can keep.

  `ExDebug.console/2` prints the value at one point of a pipeline —
  labelled, timestamped, framed, with the application and its version
  under it — and returns it untouched. It prints in `:dev` and `:test`
  only, so unlike an `IO.inspect/2` or a `dbg/1` the call does not have
  to come out before the code ships.

  The cartridge is the dependency and nothing else. It carries no
  `only:` restriction on purpose: the environment check lives inside
  `console/2`, so a call left in a pipeline still has to compile in
  `:prod` (DESIGN.md). Nothing is written to `config/`, either — every
  formatting key the library reads already defaults inside it.
  """
  use WorkbenchIgniter.Feature

  @dep {:ex_debug, "~> 1.0"}

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def deps(_state), do: [@dep]

  @impl true
  def task, do: "workbench.install.exdebug"

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
