defmodule Mix.Tasks.Workbench.Executable do
  use Mix.Task

  # No @shortdoc on purpose: internal plumbing, hidden from `mix help`.
  @moduledoc """
  Makes files executable, once they are written.

      mix workbench.executable PATH...

  Internal plumbing: Igniter writes every file with the same mode, and
  a script of the release (`rel/overlays/bin/migrate`, from
  phx.gen.release, which `chmod`s it) must run. A base cartridge queues
  this task for the scripts it creates (`WorkbenchIgniter.PhxDelta`),
  so the mode is set after the patch set is confirmed and applied — a
  dry run touches nothing. A path that is not there is left alone.
  """

  @doc false
  def run(paths) do
    for path <- paths, File.regular?(path) do
      File.chmod!(path, 0o755)
      Mix.shell().info("* executable #{path}")
    end

    :ok
  end
end
