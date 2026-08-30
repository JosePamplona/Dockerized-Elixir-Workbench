defmodule WorkbenchIgniter.Features.Live do
  @moduledoc """
  LiveView — its configuration, the live socket in app.js and the endpoint, the JS commands of the core components — for a project generated with `--no-live`.

  A base cartridge: it names the `phx.new` flag and the mark and what it builds on, and
  `WorkbenchIgniter.PhxDelta` brings in whatever `phx.new` generates for
  it at the installer's version, merged onto the project's files.

  Re-running is a no-op.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.live"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{group: :workbench_igniter, example: "mix " <> task()}
  end

  @impl true
  def requires, do: ["html"]

  # The mark is the one facts/1 reads to describe the project: what only
  # --live brings is LiveView's own configuration in config.exs (the
  # dependency stays with --no-live, and the dashboard turns the
  # endpoint's socket on too).
  @impl true
  def installed?(igniter) do
    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)
    {facts.live, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)
    igniter = WorkbenchIgniter.PhxDelta.insert(igniter, __MODULE__, :live)

    # The LiveSocket lives in assets/js/app.js, which only esbuild
    # brings; phx.new's static placeholder for a project without a
    # bundler is a comment. Served, configured, and not connected to.
    if facts.live or facts.esbuild or igniter.issues != [] do
      igniter
    else
      Igniter.add_notice(
        igniter,
        "live is in, but the browser has nothing to connect with: the LiveSocket lives in " <>
          "assets/js/app.js, which esbuild brings (./wb.sh add esbuild)."
      )
    end
  end
end
