defmodule WorkbenchIgniter.Features.Mailer do
  @moduledoc """
  Phoenix's mailer — Swoosh, the `Mailer` module, its configuration —
  for a project generated with `--no-mailer`.

  Standalone cartridge, the first of the base ones: a capability that
  `phx.new` decides at generation time, added after the fact. It does
  not know what a mailer is: `WorkbenchIgniter.PhxDelta` generates the
  project with and without `--no-mailer` and merges the difference in.
  Whatever `phx.new` puts in for a mailer at the installer's version —
  today: `swoosh` and `req` in `mix.exs`, `MyApp.Mailer`, the adapter
  in `config.exs`, the local adapter and mailbox route in dev, `Test`
  in test, the api-client note in prod and runtime — is what arrives.

  Re-running is a no-op: the mark is the `swoosh` dependency, which a
  project with a mailer always carries.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.mailer"

  @impl true
  def console, do: [doors: [{"mailbox", "/dev/mailbox"}]]

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{group: :workbench_igniter, example: "mix " <> task()}
  end

  # The mark: the swoosh dependency, the first thing --no-mailer leaves out.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, :swoosh)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter), do: WorkbenchIgniter.PhxDelta.insert(igniter, __MODULE__, :mailer)
end
