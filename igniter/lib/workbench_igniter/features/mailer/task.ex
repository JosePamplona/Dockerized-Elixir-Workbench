defmodule Mix.Tasks.Workbench.Install.Mailer do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Mailer

  @shortdoc "Adds Phoenix's Swoosh mailer, as phx.new would have generated it"

  @moduledoc """
  #{@shortdoc}

  For a project generated with `--no-mailer`. The cartridge asks
  `phx.new` itself what a mailer is — the difference between the project
  generated with and without the flag, at the installer's version — and
  merges it in: `swoosh` and `req` in `mix.exs`, `MyApp.Mailer`, the
  configuration of every environment, the dev mailbox route. The
  project's own edits to those files survive; a conflict is reported.

  Re-running it is a no-op: when `swoosh` is already a dependency nothing
  is touched and a notice says so.

  ## Example

      #{Mailer.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Mailer.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Mailer.install(igniter)
end
