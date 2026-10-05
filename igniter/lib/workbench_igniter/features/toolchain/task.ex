defmodule Mix.Tasks.Workbench.Install.Toolchain do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Toolchain

  @shortdoc "Keeps the editor's language server directory out of git"

  @moduledoc """
  #{@shortdoc}

  For working on the project outside the container, with an editor whose
  language server is ElixirLS: it builds the project into `.elixir_ls/`,
  beside the source. It writes:

  * `/.elixir_ls/` in `.gitignore`, under its comment

  Re-running it is a no-op: the entry goes in once. The Erlang and
  Elixir the host should run are `version_manager`'s.

  ## Example

      #{Toolchain.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Toolchain.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(Toolchain, igniter)
end
