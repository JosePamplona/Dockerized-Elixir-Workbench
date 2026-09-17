defmodule Mix.Tasks.Workbench.Install.Osmon do
  use WorkbenchIgniter.Task

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
