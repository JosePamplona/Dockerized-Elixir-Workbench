defmodule Mix.Tasks.Workbench.Install.Tailwind do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Tailwind

  @shortdoc "Adds Phoenix's Tailwind CSS pipeline, as phx.new would have generated it"

  @moduledoc """
  #{@shortdoc}

  For a project generated with `--no-tailwind`. The cartridge asks
  `phx.new` itself what that is — the difference between the project
  generated with and without the flag, at the installer's version — and
  merges it in. The project's own edits to those files survive; a
  conflict is reported.

  Re-running it is a no-op: when the cartridge's mark is in the project
  nothing is touched and a notice says so.

  ## Example

      #{Tailwind.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Tailwind.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Tailwind.install(igniter)
end
