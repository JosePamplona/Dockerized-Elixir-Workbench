defmodule Mix.Tasks.Workbench.Install.PsqlExtras do
  use Igniter.Mix.Task

  @dep {:ecto_psql_extras, "~> 0.8", only: :dev}
  @shortdoc "Adds ecto_psql_extras database insights to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_psql_extras` feature: adds
  `#{inspect(@dep)}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix workbench.install.psql_extras"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
  end
end
