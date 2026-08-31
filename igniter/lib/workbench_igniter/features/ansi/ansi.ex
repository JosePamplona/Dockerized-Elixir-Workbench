defmodule WorkbenchIgniter.Features.Ansi do
  @moduledoc """
  Coloured logs inside the container: `config :elixir, ansi_enabled: true`.

  Elixir turns ANSI off when it cannot see a terminal, and a process
  started by `docker compose up` cannot: the logs arrive as plain text
  whatever the terminal reading them can do. This turns it back on, so
  `logs` and `iex` come out coloured.

  One line of configuration, and the whole cartridge.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.ansi"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: the configuration line itself, read where it is written.
  @impl true
  def installed?(igniter) do
    {Igniter.Project.Config.configures_key?(igniter, "config.exs", :elixir, [:ansi_enabled]),
     igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    Igniter.Project.Config.configure(igniter, "config.exs", :elixir, [:ansi_enabled], true)
  end
end
