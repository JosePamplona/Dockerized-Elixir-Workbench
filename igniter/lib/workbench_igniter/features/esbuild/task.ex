defmodule Mix.Tasks.Workbench.Install.Esbuild do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Esbuild

  @shortdoc "Adds Phoenix's esbuild JavaScript bundling, as phx.new would have generated it"

  @moduledoc """
  #{@shortdoc}

  For a project generated with `--no-esbuild`. The cartridge asks
  `phx.new` itself what that is — the difference between the project
  generated with and without the flag, at the installer's version — and
  merges it in. The project's own edits to those files survive; a
  conflict is reported.

  Re-running it is a no-op: when the cartridge's mark is in the project
  nothing is touched and a notice says so.

  ## Example

      #{Esbuild.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Esbuild.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Esbuild.install(igniter)
end
