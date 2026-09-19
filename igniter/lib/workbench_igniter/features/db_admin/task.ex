defmodule Mix.Tasks.Workbench.Install.DbAdmin do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.DbAdmin

  @shortdoc "Adds a database admin to the workspace, open on the project's database"

  @moduledoc """
  #{@shortdoc}

  A database admin in the browser — the tables, the rows, a query
  editor — beside the project's database, already pointing at it:

  * `pgadmin` — pgAdmin, Postgres' own admin
  * `phpmyadmin` — phpMyAdmin, MySQL's own admin
  * `adminer` — Adminer, one light page on any database
  * `cloudbeaver` — CloudBeaver, DBeaver in the browser, on Postgres,
    MySQL and SQL Server

  Without `--admin` it is the one for the project's database: pgAdmin
  on Postgres, phpMyAdmin on MySQL, Adminer on SQL Server and SQLite.
  An admin that does not serve the project's database is refused, with
  what the project has.

  For each admin it writes the file it opens with — who signs in, on
  which driver, off the project's Ecto adapter — and declares its
  container, which `./wb.sh add` bakes into the compose in the same
  commit. Builds on ecto. A second run adds another admin; a file that
  is there is never rewritten.

  ## Example

      #{DbAdmin.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(DbAdmin)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: DbAdmin.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: DbAdmin.install(igniter)
end
