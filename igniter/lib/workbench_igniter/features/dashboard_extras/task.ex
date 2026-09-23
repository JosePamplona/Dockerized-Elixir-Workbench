defmodule Mix.Tasks.Workbench.Install.DashboardExtras do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.DashboardExtras

  @shortdoc "Switches on LiveDashboard's OS Data and Ecto Stats pages"

  @moduledoc """
  #{@shortdoc}

  Phoenix LiveDashboard ships two pages switched off, because each needs
  something of the project:

  * **OS Data** — CPU load, memory and disks — reads Erlang's `:os_mon`
    application: added to `extra_applications` in `mix.exs`, always.
  * **Ecto Stats** — index usage, locks, cache hits, table sizes,
    long-running queries — reads the extras library of the database the
    project is on: `ecto_psql_extras` on Postgres, `ecto_mysql_extras`
    on MySQL, `ecto_sqlite3_extras` on SQLite. A project without a
    database, or on SQL Server (LiveDashboard has no stats for it), gets
    OS Data alone, and a notice says so.

  The database is read off the project's dependencies, not asked.
  Re-running it adds what is missing and nothing else: a project that
  gained a database since gets its extras then.

  ## Example

      #{DashboardExtras.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: DashboardExtras.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(DashboardExtras, igniter)
end
