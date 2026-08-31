defmodule Mix.Tasks.Workbench.Install.Toolchain do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Toolchain

  @shortdoc "Pins the Elixir and Erlang the project runs on, for the host"

  @moduledoc """
  #{@shortdoc}

  For working on the project outside the container — an editor, a
  language server, a `mix` in your own shell — where nothing knows which
  Elixir this project is. It writes:

  * `.tool-versions` with the Elixir and Erlang running the installer
    (asdf and mise read it; the container ignores it)
  * `/.elixir_ls/` in `.gitignore`, so the language server's cache stays
    out of the repository

  The versions default to the ones actually running this task — the
  toolchain image's — because `mix.exs` only carries a requirement
  range, and a hand-written pin drifts from the image the workspace
  builds. Re-running it is a no-op: an existing `.tool-versions` is
  never overwritten.

  ## Example

      #{Toolchain.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Toolchain)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Toolchain.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Toolchain.install(igniter)
end
