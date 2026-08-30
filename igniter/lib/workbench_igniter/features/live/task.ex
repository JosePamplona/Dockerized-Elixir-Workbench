defmodule Mix.Tasks.Workbench.Install.Live do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Live

  @shortdoc "Adds Phoenix LiveView, as phx.new would have generated it"

  @moduledoc """
  #{@shortdoc}

  For a project generated with `--no-live`. The cartridge asks
  `phx.new` itself what that is — the difference between the project
  generated with and without the flag, at the installer's version — and
  merges it in. The project's own edits to those files survive; a
  conflict is reported.

  It builds on html: `phx.new` generates it only with html, and
  the cartridge refuses, naming it, when it is not in the project.

  Re-running it is a no-op: when the cartridge's mark is in the project
  nothing is touched and a notice says so.

  ## Example

      #{Live.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Live.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Live.install(igniter)
end
