defmodule WorkbenchIgniter.Features.Osmon do
  @moduledoc """
  OS process monitoring (`:os_mon`) — part of the trivial group toggled by
  `--enhance`. Dep-less: it patches `extra_applications` in `mix.exs`.

  Single-file cartridge: manifest, install logic and the mix task shell
  live in this file (template-less features don't need a directory).
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.osmon"

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
    Igniter.Project.MixProject.update(igniter, :application, [:extra_applications], fn
      nil -> {:ok, {:code, [:os_mon]}}
      zipper -> Igniter.Code.List.append_new_to_list(zipper, :os_mon)
    end)
  end
end

defmodule Mix.Tasks.Workbench.Install.Osmon do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Osmon

  @shortdoc "Enables the :os_mon OTP application for system monitoring"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_osmon` feature: adds `:os_mon`
  to `extra_applications` in `mix.exs`.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Osmon.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Osmon.install(igniter)
end
