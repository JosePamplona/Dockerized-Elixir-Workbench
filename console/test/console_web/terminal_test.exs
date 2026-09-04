defmodule ConsoleWeb.TerminalTest do
  use ExUnit.Case, async: true

  alias ConsoleWeb.Terminal

  # A dev deployment as `wb.sh status --json` reports it: the four
  # services of the workspace's compose, the app on its :local image.
  defp status(containers) do
    %{
      "compose_project" => "lorem_ipsum",
      "workspace" => "/w",
      "project" => %{"app" => "lorem_ipsum"},
      "containers" => containers
    }
  end

  defp c(service, image, state \\ "running"), do: %{"Service" => service, "Image" => image, "State" => state}

  # The session is a pipe, and Elixir and git are asked for colour on it anyway.
  defp colour,
    do: [
      "-e", "ELIXIR_ERL_OPTIONS=-elixir ansi_enabled true",
      "-e", "TERM=xterm-256color",
      "-e", "GIT_CONFIG_COUNT=1",
      "-e", "GIT_CONFIG_KEY_0=color.ui",
      "-e", "GIT_CONFIG_VALUE_0=always"
    ]

  test "the services beside the app take a session, and the pause container never does" do
    s = status([
          c("app", "lorem-ipsum:local"),
          c("database", "postgres:latest"),
          c("pgadmin", "dpage/pgadmin4:latest"),
          c("network", "registry.k8s.io/pause:3.10")
        ])

    assert Enum.map(Terminal.targets(s), & &1.name) == ~w(app database pgadmin)
  end

  test "a stopped container is not a target, and with no app the toolchain stands in" do
    s = status([c("app", "lorem-ipsum:local", "exited"), c("database", "postgres:latest")])
    assert Enum.map(Terminal.targets(s), & &1.name) == ~w(toolchain database)
  end

  test "each target's shells, and the first is the one a row's button opens" do
    s = status([c("app", "lorem-ipsum:local"), c("database", "postgres:latest"), c("pgadmin", "dpage/pgadmin4:latest")])
    [app, db, pga] = Terminal.targets(s)

    assert Terminal.shells(app) == [{"bash", "bash"}, {"iex", "iex -S mix"}]
    # The reason to open the database is the database, not its filesystem.
    assert Terminal.default_shell(db) == "psql"
    # Alpine: sh is not a choice, it is the only one.
    assert Terminal.shells(pga) == [{"sh", "sh"}]
    assert Terminal.default_shell(app) == "bash"
  end

  test "the argv: only the dev app is entered where its source is mounted" do
    s = status([c("app", "lorem-ipsum:local"), c("database", "postgres:latest"), c("pgadmin", "dpage/pgadmin4:latest")])
    [app, db, pga] = Terminal.targets(s)

    assert {_, argv} = Terminal.argv(s, app, "bash")
    assert argv == ~w(compose --project-name lorem_ipsum exec -T) ++ colour() ++ ~w(-w /app/src app bash)

    assert {_, argv} = Terminal.argv(s, db, "psql")
    assert argv == ~w(compose --project-name lorem_ipsum exec -T) ++ colour() ++ ~w(database psql -U postgres)
    assert {_, argv} = Terminal.argv(s, pga, "sh")
    assert argv == ~w(compose --project-name lorem_ipsum exec -T) ++ colour() ++ ~w(pgadmin sh)
  end

  # Before the status is here the targets are a guess and the source's
  # path is nil — docker would refuse `-v :/app/src`. The button waits.
  test "before the status, the session cannot be opened, and the reason is on the button" do
    import Phoenix.LiveViewTest
    term = %{open: false, target: nil, shell: nil, port: nil}
    html = render_component(&Terminal.terminal/1, status: nil, term: term)
    assert html =~ ~r/<button[^>]*phx-click="term_start"[^>]*disabled/
    assert html =~ "reading the workspace"
    html = render_component(&Terminal.terminal/1, status: status([c("app", "x:local")]), term: term)
    refute html =~ ~r/<button[^>]*phx-click="term_start"[^>]*disabled/
  end

  test "a release replica keeps its own two shells and no source directory" do
    s = status([c("app1", "lorem-ipsum-prod:latest")])
    [replica] = Terminal.targets(s)

    assert replica.release
    assert Terminal.shells(replica) == [{"bash", "bash"}, {"rpc", "bin/app rpc"}]
    assert {_, argv} = Terminal.argv(s, replica, "bash")
    refute "-w" in argv
  end
end
