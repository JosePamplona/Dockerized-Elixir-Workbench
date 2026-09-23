defmodule WorkbenchIgniter.Features.DashboardExtras do
  @moduledoc """
  The two pages Phoenix LiveDashboard ships switched off, switched on:
  **OS Data** — the machine's CPU load, memory and disks — and **Ecto
  Stats** — the database's own diagnostics: index usage, locks, cache
  hits, table sizes, long-running queries.

  Neither is the dashboard's to turn on, because each needs something
  of the project. OS Data reads Erlang's `:os_mon` application, which
  only runs when the project starts it: `extra_applications` in
  `mix.exs`. Ecto Stats reads a library that knows the database
  server's statistics, one per server: `ecto_psql_extras`,
  `ecto_mysql_extras`, `ecto_sqlite3_extras`. LiveDashboard declares
  the three as optional dependencies and picks one by the repo's
  adapter.

  So the box is **shaped by the project, not refused for it**: `:os_mon`
  always, and the extras of the database the project is on — read off
  ecto's own `state/1`, the project as it is. With no database it
  installs the first half and says so; on SQL Server it does too, since
  LiveDashboard has no Ecto Stats for that server. A second run adds
  what a project has grown into (`rerun: :adds`): insert ecto
  afterwards, run this again, and the database's page lights up.

  What it does build on is the **dashboard** itself: without
  LiveDashboard there is no page to switch on (DESIGN.md).
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.Features.Ecto, as: EctoCartridge

  # The extras by ecto's database, as its `state/1` names it. The
  # requirements sit inside the ones LiveDashboard declares for its
  # optional dependencies, and carry no `only:` — they go where the
  # dashboard's own dependency goes, which `phx.new` puts in every
  # environment (DESIGN.md §3.3). SQL Server has none.
  @extras %{
    "postgres" => {:ecto_psql_extras, "~> 0.8"},
    "mysql" => {:ecto_mysql_extras, "~> 0.6"},
    "sqlite3" => {:ecto_sqlite3_extras, "~> 1.2"}
  }

  @doc "The extras dependency for each of ecto's databases that has one."
  def extras, do: @extras

  # LiveDashboard's Ecto Stats needs the extras package of the database
  # the project is on, which is ecto's state and not this box's — and
  # this box takes no option, so its own state says nothing. It answers
  # the three that exist, and which one the project carries is read off
  # the project's own deps.
  @impl true
  def deps(_state), do: Map.values(@extras)

  @impl true
  def task, do: "workbench.install.dashboard_extras"

  @impl true
  def requires, do: ["dashboard"]

  # It takes no options: a second run is how Ecto Stats arrives on a
  # project that took this box before its database.
  @impl true
  def adds, do: :all

  # The pages it lights, where the dashboard serves them. Ecto Stats is
  # a door only with a database in the project.
  @impl true
  def console do
    [
      doors: [
        {"os data", "/dev/dashboard/os_mon"},
        {"ecto stats", "/dev/dashboard/ecto_stats", when: {:cartridge, "ecto"}}
      ]
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: `:os_mon` in `extra_applications`, the half every project
  # gets, read off the same `application/0` literal the installer
  # patches. The extras are no mark: a project without a database
  # carries the box whole.
  @impl true
  def installed?(igniter) do
    igniter = Igniter.include_existing_file(igniter, "mix.exs")

    zipper =
      igniter.rewrite
      |> Rewrite.source!("mix.exs")
      |> Rewrite.Source.get(:quoted)
      |> Sourceror.Zipper.zip()

    found? =
      with {:ok, zipper} <- Igniter.Code.Function.move_to_def(zipper, :application, 0),
           {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, :extra_applications) do
        zipper
        |> Igniter.Code.List.find_list_item_index(&Igniter.Code.Common.nodes_equal?(&1, :os_mon))
        |> is_integer()
      else
        _ -> false
      end

    {found?, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    case WorkbenchIgniter.Feature.missing_requirements(igniter, __MODULE__) do
      {[], igniter} -> igniter |> os_data() |> ecto_stats()
      {missing, igniter} -> WorkbenchIgniter.Feature.refuse(igniter, __MODULE__, missing)
    end
  end

  defp os_data(igniter) do
    Igniter.Project.MixProject.update(igniter, :application, [:extra_applications], fn
      nil -> {:ok, {:code, [:os_mon]}}
      zipper -> Igniter.Code.List.append_new_to_list(zipper, :os_mon)
    end)
  end

  # Which database the project is on is a fact about the project, asked
  # of ecto's own `installed?/1` and `state/1` — the deps say it — and
  # never of what an insert was asked.
  defp ecto_stats(igniter) do
    case EctoCartridge.installed?(igniter) do
      {false, igniter} ->
        Igniter.add_notice(
          igniter,
          "No database in the project: OS Data only. Once ecto is in, run this again for Ecto Stats."
        )

      {true, igniter} ->
        {%{database: database}, igniter} = EctoCartridge.state(igniter)

        case @extras[database] do
          nil ->
            Igniter.add_notice(
              igniter,
              "LiveDashboard has no Ecto Stats for #{database}: OS Data only."
            )

          dep ->
            Igniter.Project.Deps.add_dep(igniter, dep, on_exists: :skip)
        end
    end
  end
end
