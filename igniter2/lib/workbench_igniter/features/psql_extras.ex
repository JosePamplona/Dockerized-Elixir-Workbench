defmodule WorkbenchIgniter.Features.PsqlExtras do
  @moduledoc """
  Postgres observability queries (`ecto_psql_extras`) — part of the trivial
  dep-only group toggled by `--enhance`.

  Single-file cartridge: manifest, install logic and the mix task shell
  live in this file (template-less features don't need a directory).
  """
  use WorkbenchIgniter.Feature

  @dep {:ecto_psql_extras, "~> 0.8", only: :dev}

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def task, do: "workbench.install.psql_extras"

  @impl true
  def enabled?(opts), do: opts[:enhance] == true

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
  end
end

defmodule Mix.Tasks.Workbench.Install.PsqlExtras do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.PsqlExtras

  @shortdoc "Adds ecto_psql_extras database insights to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_psql_extras` feature: adds
  `#{inspect(PsqlExtras.dep())}` to the project deps.
  Idempotent — re-running it is a no-op.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: PsqlExtras.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: PsqlExtras.install(igniter)
end
