defmodule WorkbenchIgniter.Features.Pgadmin do
  @moduledoc """
  pgAdmin beside the workspace's Postgres: a container in the compose,
  and the one file it opens with — `pgadmin/servers.json`, the project's
  own, naming the workspace's database so the browser lands on it
  already connected.

  The container is not written here. This cartridge *declares* it
  (`services/1`, `"pgadmin"`), and `mix workbench.compose` renders it into
  the workspace's dev and prod files at the next `./wb.sh bake`, with the
  servers file mounted as its config. What the installer writes is the
  servers file, which is also the mark: the compose is baked from what
  the project carries, never the other way round.

  It builds on **ecto** (`requires`), and it answers **only on Postgres**
  — pgAdmin administers that server and no other — so on a project whose
  driver is another one it refuses, as psql_extras does, off the
  project's facts (`PhxDelta.facts/1`) and never off an option.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @servers "pgadmin/servers.json"

  @doc "The servers file this cartridge writes, and reads as its mark."
  def servers_file, do: @servers

  @impl true
  def task, do: "workbench.install.pgadmin"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: the servers file itself.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, @servers)

  @impl true
  def requires, do: ["ecto"]

  # The container: rendered by workbench.compose, on the pod's network
  # with the database, its port published beside the app's.
  @impl true
  def services(_state), do: ["pgadmin"]

  @impl true
  def afterwards,
    do: "./wb.sh bake puts pgAdmin into the workspace's compose; the next up brings it up."

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

  # Which driver the project uses is a fact about the project, asked of
  # the project — the same source `installed?/1` reads elsewhere, never
  # the option ecto was inserted with.
  defp on_postgres(igniter) do
    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)

    if facts.database == "postgres" do
      write_servers(igniter)
    else
      Igniter.add_issue(
        igniter,
        "#{name()} administers Postgres, and this project's database is #{facts.database}. " <>
          "There is no server here for it to open, so there is nothing to install."
      )
    end
  end

  defp write_servers(igniter) do
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(igniter, "#{@servers} already exists: pgAdmin is in, skipping.")

      {false, igniter} ->
        app = Igniter.Project.Application.app_name(igniter)
        Igniter.create_new_file(igniter, @servers, template("servers.json.eex", app_name: app))
    end
  end
end
