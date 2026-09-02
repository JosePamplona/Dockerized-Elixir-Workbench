defmodule WorkbenchIgniter.Features.PsqlExtras do
  @moduledoc """
  Postgres observability queries (`ecto_psql_extras`) — part of the
  trivial dep-only group (a chiefs_setup pick).

  It builds on **ecto**, always: the queries run through the project's
  repo, and without one there is nothing for the dependency to be an
  extension of. And it answers **only on Postgres** — `pg_stat_statements`,
  `pg_locks`, the bloat estimates are that server's own — so on a project
  whose driver is another one it refuses instead of installing a
  dependency that would have nothing to ask.

  Those are two different rules and they are kept apart. Ecto is a
  cartridge, so it is `requires`, and the console can grey the box before
  anyone presses. The driver is not a cartridge — it is the value of
  ecto's own `--database` — so it is a refusal in the installer, read off
  the project (`PhxDelta.facts/1`, the same source `installed?/1` reads)
  and never off the options this cartridge was inserted with.
  """
  use WorkbenchIgniter.Feature

  @dep {:ecto_psql_extras, "~> 0.8", only: :dev}

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def task, do: "workbench.install.psql_extras"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: the dependency itself.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, elem(@dep, 0))

  @impl true
  def requires, do: ["ecto"]

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    case WorkbenchIgniter.Feature.missing_requirements(igniter, __MODULE__) do
      {[], igniter} -> on_postgres(igniter)
      {missing, igniter} -> refuse(igniter, missing)
    end
  end

  defp refuse(igniter, missing) do
    Igniter.add_issue(
      igniter,
      "#{name()} builds on #{Enum.join(missing, " and ")}, not in the project yet. " <>
        "Insert that first: ./wb.sh add #{hd(missing)}"
    )
  end

  # Which driver the project uses is a fact about the project, so it is
  # asked of the project. `--database` was ecto's option and nobody keeps
  # what it was set to: the deps say it now, which is also what makes this
  # right on a project that changed its mind since.
  defp on_postgres(igniter) do
    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)

    if facts.database == "postgres" do
      Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
    else
      Igniter.add_issue(
        igniter,
        "#{name()} is Postgres's own observability, and this project's database is " <>
          "#{facts.database}. The queries #{elem(@dep, 0)} adds would have no server to " <>
          "ask, so there is nothing to install."
      )
    end
  end
end
