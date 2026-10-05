defmodule WorkbenchIgniter.Features.Dashboard do
  @moduledoc """
  LiveDashboard — the dependency, the /dev/dashboard route and the live socket it rides on — for a project generated with `--no-dashboard`.

  A base cartridge: it names the `phx.new` flag and the mark, and
  `WorkbenchIgniter.PhxDelta` brings in whatever `phx.new` generates for
  it at the installer's version, merged onto the project's files.

  Re-running is a no-op.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.dashboard"

  @impl true
  def console, do: [doors: [{"dashboard", "/dev/dashboard"}]]

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{group: :workbench_igniter, example: "mix " <> task()}
  end

  # The mark: the first thing --no-dashboard leaves out.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, :phoenix_live_dashboard)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter), do: WorkbenchIgniter.PhxDelta.insert(igniter, __MODULE__, :dashboard)
end
