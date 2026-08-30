defmodule WorkbenchIgniter.Features.Gettext do
  @moduledoc """
  Phoenix's gettext — the dependency, the `Gettext` backend, `priv/gettext`
  — for a project generated with `--no-gettext`.

  A base cartridge: it names the `phx.new` flag and the mark, and
  `WorkbenchIgniter.PhxDelta` brings in whatever `phx.new` generates for
  gettext at the installer's version, merged onto the project's files.
  `core_components` and the error views read differently with and
  without it; the delta takes care of that because the base generation
  uses the project's own flags.

  Re-running is a no-op: the mark is the `gettext` dependency.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.gettext"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{group: :workbench_igniter, example: "mix " <> task()}
  end

  # The mark: the gettext dependency, the first thing --no-gettext leaves out.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, :gettext)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter), do: WorkbenchIgniter.PhxDelta.insert(igniter, __MODULE__, :gettext)

end
