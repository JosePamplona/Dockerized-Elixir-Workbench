defmodule Mix.Tasks.Workbench.Install.Gettext do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Gettext

  @shortdoc "Adds Phoenix's gettext, as phx.new would have generated it"

  @moduledoc """
  #{@shortdoc}

  For a project generated with `--no-gettext`. The cartridge asks
  `phx.new` itself what gettext is — the difference between the project
  generated with and without the flag, at the installer's version — and
  merges it in: the dependency, `MyAppWeb.Gettext`, `priv/gettext`, and
  the `use Gettext` lines in the components and error views. The
  project's own edits to those files survive; a conflict is reported.

  Re-running it is a no-op: when `gettext` is already a dependency
  nothing is touched and a notice says so.

  ## Example

      #{Gettext.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Gettext.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Gettext.install(igniter)
end
