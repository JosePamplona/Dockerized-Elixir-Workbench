defmodule Mix.Tasks.Workbench.Install.Html do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Html

  @shortdoc "Adds Phoenix's HTML views, as phx.new would have generated them"

  @moduledoc """
  #{@shortdoc}

  For a project generated with `--no-html`. The cartridge asks
  `phx.new` itself what that is — the difference between the project
  generated with and without the flag, at the installer's version — and
  merges it in. The project's own edits to those files survive; a
  conflict is reported.

  Re-running it is a no-op: when the cartridge's mark is in the project
  nothing is touched and a notice says so.

  ## Example

      #{Html.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Html.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Html.install(igniter)
end
