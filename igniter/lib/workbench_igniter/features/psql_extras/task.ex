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
