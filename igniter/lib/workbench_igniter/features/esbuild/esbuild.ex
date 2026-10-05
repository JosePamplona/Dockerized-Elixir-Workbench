defmodule WorkbenchIgniter.Features.Esbuild do
  @moduledoc """
  esbuild — the dependency, its configuration, the watcher and the assets aliases — for a project generated with `--no-esbuild`.

  A base cartridge: it names the `phx.new` flag and the mark, and
  `WorkbenchIgniter.PhxDelta` brings in whatever `phx.new` generates for
  it at the installer's version, merged onto the project's files.

  Re-running is a no-op.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.esbuild"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{group: :workbench_igniter, example: "mix " <> task()}
  end

  # The mark: the first thing --no-esbuild leaves out.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, :esbuild)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter), do: WorkbenchIgniter.PhxDelta.insert(igniter, __MODULE__, :esbuild)
end
