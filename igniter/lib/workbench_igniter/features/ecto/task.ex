defmodule Mix.Tasks.Workbench.Install.Ecto do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Ecto

  @shortdoc "Adds Phoenix's Ecto with a database adapter, as phx.new would have generated it"

  @moduledoc """
  #{@shortdoc}

  For a project generated with `--no-ecto`. The cartridge asks `phx.new`
  itself what Ecto is for the chosen database — the difference between
  the project generated with and without the flag, at the installer's
  version — and merges it in: the dependencies, `MyApp.Repo`, the
  configuration of every environment, the repo in the supervision tree,
  the `ecto.*` aliases, `priv/repo`, the data case. It then writes the
  variable the release reads to find the database in `.env` and
  `.env.sample`. The project's own edits to those files survive; a
  conflict is reported.

  Re-running it is a no-op: when `ecto_sql` is already a dependency
  nothing is touched and a notice says so.

  ## Example

      #{Ecto.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Ecto)}

  ## After inserting

  The workspace's compose was baked for the project as it was: without
  a database service. `./wb.sh add` bakes it again in the insert's own
  commit, with the server the project now expects. The app container
  runs `mix setup` at every boot, and `ecto.setup` in it creates the
  database at the next `./wb.sh up`.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Ecto.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(Ecto, igniter)
end
