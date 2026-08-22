defmodule Mix.Tasks.Workbench.Install.Osmon do
  use Igniter.Mix.Task

  @shortdoc "Enables the :os_mon OTP application for system monitoring"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_osmon` feature: adds `:os_mon`
  to `extra_applications` in `mix.exs`.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix workbench.install.osmon"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.Project.MixProject.update(igniter, :application, [:extra_applications], fn
      nil -> {:ok, {:code, [:os_mon]}}
      zipper -> Igniter.Code.List.append_new_to_list(zipper, :os_mon)
    end)
  end
end
