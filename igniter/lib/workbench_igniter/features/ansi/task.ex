defmodule Mix.Tasks.Workbench.Install.Ansi do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Ansi

  @shortdoc "Turns ANSI colours back on for logs read outside a terminal"

  @moduledoc """
  #{@shortdoc}

  Sets `config :elixir, ansi_enabled: true` in `config/config.exs`.
  Elixir disables ANSI when the running process has no terminal — which
  is every container `docker compose` starts — so the logs arrive plain
  no matter what reads them. Re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Ansi.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Ansi.install(igniter)
end
