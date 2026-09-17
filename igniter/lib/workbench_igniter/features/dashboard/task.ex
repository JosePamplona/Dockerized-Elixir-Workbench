defmodule Mix.Tasks.Workbench.Install.Dashboard do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Dashboard

  @shortdoc "Adds Phoenix LiveDashboard, as phx.new would have generated it"

  @moduledoc """
  #{@shortdoc}

  For a project generated with `--no-dashboard`. The cartridge asks
  `phx.new` itself what that is — the difference between the project
  generated with and without the flag, at the installer's version — and
  merges it in. The project's own edits to those files survive; a
  conflict is reported.

  Re-running it is a no-op: when the cartridge's mark is in the project
  nothing is touched and a notice says so.

  ## Example

      #{Dashboard.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Dashboard.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Dashboard.install(igniter)
end
