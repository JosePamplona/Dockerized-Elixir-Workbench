defmodule Mix.Tasks.Workbench.Install.VersionManager do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.VersionManager

  @shortdoc "Pins the Erlang and Elixir the project runs on, for the host's version manager"

  @moduledoc """
  #{@shortdoc}

  A version manager keeps several Erlangs and Elixirs installed side by
  side on your machine and picks one per directory, off a file in it:
  `cd` into the project and `mix`, `iex` and the editor's language
  server run its versions; `cd` into the next project and they run that
  one's. The file also says the versions to whoever reads the
  repository, and keeps their history in git. It writes that file, the
  one your version manager reads:

  * `.tool-versions` with `--manager asdf` (the default): asdf's file,
    and mise reads it too
  * `mise.toml` with `--manager mise`: the file mise recommends

  The versions are the ones actually running this task — the toolchain
  image's — because `mix.exs` only carries a requirement range, and a
  hand-written pin drifts from the image the workspace builds. Elixir is pinned with its OTP (`1.19.6-otp-28`): a bare
  `1.19.6` is the precompiled build against the oldest OTP that Elixir
  supports, not the Erlang pinned beside it. Re-running it is a no-op:
  an existing version file, of either manager, is never overwritten.

  ## Example

      #{VersionManager.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(VersionManager)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: VersionManager.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: VersionManager.install(igniter)
end
