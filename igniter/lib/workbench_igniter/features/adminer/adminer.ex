defmodule WorkbenchIgniter.Features.Adminer do
  @moduledoc """
  Adminer beside the workspace's database, whatever the adapter: a
  container in the compose, and the one file it opens with —
  `adminer/login.php`, the project's own, an Adminer plugin naming the
  workspace's database with its driver and user, filling the login form
  in, and holding the password Adminer checks itself.

  The container is not written here. This cartridge *declares* it
  (`services/1`, `"adminer"`), and `mix workbench.compose` renders it into
  the workspace's dev and prod files at the next `./wb.sh bake`, with the
  project's `adminer/` mounted as the image's `plugins-enabled/`. What the
  installer writes is the login file, which is also the mark: the compose
  is baked from what the project carries, never the other way round.

  It builds on **ecto** (`requires`), on every adapter ecto has: the
  driver and the user in the file are read off the project's facts
  (`PhxDelta.facts/1`, the same source `installed?/1` reads elsewhere)
  and never off an option. Where the server is and which database to
  open are the deployment's, so the compose hands them over as
  environment; the file carries the dev pod's values, for an Adminer run
  by hand beside it.

  The à-la-carte counterpart of pgadmin — the collection's pick,
  Postgres alone and deeper on it — as healthcheck2 is of healthcheck.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @login "adminer/login.php"

  # Adminer's key for each adapter — the one its URL and its login form
  # name the driver by. MySQL's is `server`, "backwards compatibility"
  # in Adminer's source; SQLite's server is the file, so it has none.
  @drivers %{
    "postgres" => "pgsql",
    "mysql" => "server",
    "mssql" => "mssql",
    "sqlite3" => "sqlite"
  }

  @doc "The login file this cartridge writes, and reads as its mark."
  def login_file, do: @login

  @impl true
  def task, do: "workbench.install.adminer"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: the login file itself.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, @login)

  @impl true
  def requires, do: ["ecto"]

  # The container: rendered by workbench.compose, on the pod's network
  # with the database, its port published beside the app's.
  @impl true
  def services(_state), do: ["adminer"]

  @impl true
  def afterwards,
    do: "./wb.sh bake puts Adminer into the workspace's compose; the next up brings it up."

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    case WorkbenchIgniter.Feature.missing_requirements(igniter, __MODULE__) do
      {[], igniter} -> write_login(igniter)
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

  # Which adapter the project uses is a fact about the project, asked of
  # the project — never the option ecto was inserted with.
  defp write_login(igniter) do
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(igniter, "#{@login} already exists: Adminer is in, skipping.")

      {false, igniter} ->
        {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)
        assigns = login(facts.database, facts.app)
        Igniter.create_new_file(igniter, @login, template("login.php.eex", assigns))
    end
  end

  @doc """
  What the login file says for an adapter, the dev pod's values: Adminer's
  driver key; the server as `127.0.0.1:port`, off ecto's credentials, and
  the user; the database, `<app>_dev` as phx.new names it. SQLite has no
  server and no user — the database is the dev file, where the app's
  source is mounted.
  """
  @spec login(String.t(), atom() | String.t()) :: keyword()
  def login("sqlite3", app) do
    [
      app_name: app,
      driver: "sqlite",
      server: "",
      username: "",
      database: "/app/src/#{app}_dev.db"
    ]
  end

  def login(database, app) do
    %{user: user, port: port} = WorkbenchIgniter.Features.Ecto.credentials(database)

    [
      app_name: app,
      driver: Map.fetch!(@drivers, database),
      server: "127.0.0.1:#{port}",
      username: user,
      database: "#{app}_dev"
    ]
  end
end
