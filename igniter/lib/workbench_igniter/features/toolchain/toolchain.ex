defmodule WorkbenchIgniter.Features.Toolchain do
  @moduledoc """
  The editor's language server kept out of git: `/.elixir_ls/`, the
  directory ElixirLS builds the project into when an editor opens it on
  the host, ignored.

  The pin of the host's Erlang and Elixir, which this cartridge wrote
  too until v0.2.0, is `version_manager`'s: a version manager and a
  language server are two tools, and a project may have either without
  the other.
  """
  use WorkbenchIgniter.Feature

  @gitignore_comment "Elixir Language Server directory."
  @gitignore_entry "/.elixir_ls/"

  @impl true
  def archived,
    do:
      "2026-09-20: split done — version_manager carries the host's versions, and the .gitignore half comes back under a name of its own"

  @impl true
  def task, do: "workbench.install.toolchain"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: the entry itself, in the project's `.gitignore`.
  @impl true
  def installed?(igniter), do: marker_installed?(igniter, ".gitignore", @gitignore_entry)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter),
    do: WorkbenchIgniter.IgnoreFile.entry(igniter, @gitignore_comment, @gitignore_entry)
end
