defmodule WorkbenchIgniter.Features.Osmon do
  @moduledoc """
  OS process monitoring (`:os_mon`) — part of the trivial group toggled by
  `--enhance`. Dep-less: it patches `extra_applications` in `mix.exs`.
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
