defmodule WorkbenchIgniter.Features.Pgadmin do
  @moduledoc """
  pgAdmin beside the workspace's Postgres: a container in the compose,
  and the one file it opens with — `pgadmin/servers.json`, the project's
  own, naming the workspace's database so the browser lands on it
  already connected.

  The container is this cartridge's too: it asks for it by name
  (`services/1`, `"pgadmin"`) and says what it is (`compose/1`, off
  `priv/features/pgadmin/compose/`) — its block, its port on the pod, the
  servers file as its config. `mix workbench.compose` sets that into the
  workspace's dev and prod files in the insert's own commit (`wb.sh add`
  bakes before it commits). What the
  installer writes is the servers file, which is also the mark: the
  compose is baked from what the project carries, never the other way
  round.

  It builds on **ecto** (`requires`), and it answers **only on Postgres**
  — pgAdmin administers that server and no other — so on a project whose
  driver is another one it refuses, as psql_extras does, off the
  project's facts (`PhxDelta.facts/1`) and never off an option.
  """
  use WorkbenchIgniter.Feature

  embed_templates()
  embed_compose()

  @servers "pgadmin/servers.json"

  # The port pgAdmin is told to listen on (PGADMIN_LISTEN_PORT), and so
  # the one the pod publishes for it.
  @listens 5050

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
  def requires, do: [{"ecto", database: "postgres"}]

  # The container, by name: on the pod's network
  # with the database, its port published beside the app's.
  @impl true
  def services(_state), do: ["pgadmin"]

  # The container, whole: its block, its port on the pod — beside the
  # app's, by default 5050 — and the servers file as its config. On the
  # pod only: the scaled network has no pgAdmin.
  @impl true
  def compose(%{topology: "pod", services: services} = context) do
    if "pgadmin" in services do
      [
        %WorkbenchIgniter.ComposeFile.Service{
          name: "pgadmin",
          deploys: [:dev, :prod],
          position: 20,
          title: "the pgAdmin container",
          role: "devtools",
          # An Alpine image: `sh` is the shell it has.
          shells: [%{label: "sh", command: ["sh"]}],
          listens: @listens,
          ports: [
            %{
              name: :pgadmin,
              internal: @listens,
              default: 5050,
              comment: [
                "pgAdmin port, with the pgadmin cartridge in. The database is not",
                "published: it is only reachable from inside this workspace."
              ]
            }
          ],
          body: compose_fragment("pod/pgadmin.yml.eex", Map.put(context, :listens, @listens)),
          configs: compose_fragment("pod/pgadmin.configs.yml.eex", context)
        }
      ]
    else
      []
    end
  end

  def compose(_context), do: []

  @impl true
  def afterwards,
    do: "pgAdmin is in the workspace's compose, in this same commit; the next up brings it up."

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  # Which driver the project uses is a fact about the project, asked of
  # the project through ecto's own `state/1` — never the option ecto was
  # inserted with: the requirement says `database: "postgres"`, and the
  # refusal names what the project has instead.
  def install(igniter) do
    case WorkbenchIgniter.Feature.missing_requirements(igniter, __MODULE__) do
      {[], igniter} -> write_servers(igniter)
      {missing, igniter} -> WorkbenchIgniter.Feature.refuse(igniter, __MODULE__, missing)
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
