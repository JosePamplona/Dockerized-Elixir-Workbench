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

  defp c(service, image, state \\ "running"),
    do: %{"Service" => service, "Image" => image, "State" => state}

  # The session is a pipe, and Elixir and git are asked for colour on it anyway.
  defp colour,
    do: [
      "-e",
      "ELIXIR_ERL_OPTIONS=-elixir ansi_enabled true",
      "-e",
      "TERM=xterm-256color",
      "-e",
      "GIT_CONFIG_COUNT=1",
      "-e",
      "GIT_CONFIG_KEY_0=color.ui",
      "-e",
      "GIT_CONFIG_VALUE_0=always"
    ]

  test "the services beside the app take a session, and the pause container never does" do
    s =
      status([
        c("app", "lorem-ipsum:local"),
        c("database", "postgres:latest"),
        c("pgadmin", "dpage/pgadmin4:latest"),
        c("network", "registry.k8s.io/pause:3.10")
      ])

    assert Enum.map(Terminal.targets(s), & &1.name) == ~w(app database pgadmin)
  end

  test "the workbench's session runs on its image, with the workbench and the build volumes mounted" do
    s = status([])
    [workbench] = Terminal.targets(s)
    {"lorem_ipsum", argv, ["exec", "-i", name]} = Terminal.argv(s, workbench, "iex")

    assert ["run", "-i", "--rm" | _] = argv
    assert "/w:/app/src" in argv
    assert "lorem_ipsum_workbench_build:/app/src/_build" in argv
    assert "lorem_ipsum_deps:/app/src/deps" in argv
    assert Enum.any?(argv, &String.ends_with?(&1, ":/app/workbench:ro"))
    assert Enum.any?(argv, &String.starts_with?(&1, "dew-ex"))
    refute Enum.any?(argv, &String.ends_with?(&1, ":local"))
    assert Enum.take(argv, -3) == ["iex", "-S", "mix"]
    # Named, so Ctrl+C can reach it; the command announces its PID first.
    assert ["--name", ^name] = Enum.drop_while(argv, &(&1 != "--name")) |> Enum.take(2)
    assert ["sh", "-c", _, "sh", "iex", "-S", "mix"] = Enum.take(argv, -7)
  end

  test "a service's session is reached again through the compose, on the same service" do
    s = status([c("app", "lorem-ipsum:local")])
    [app] = Terminal.targets(s)
    {_, argv, exec} = Terminal.argv(s, app, "bash")

    assert ["compose", "--project-name", "lorem_ipsum", "exec", "-T" | _] = argv
    assert exec == ["compose", "--project-name", "lorem_ipsum", "exec", "-T", "app"]
    assert List.last(argv) == "bash"
  end

  test "a stopped container is not a target, and with no app the workbench stands in" do
    s = status([c("app", "lorem-ipsum:local", "exited"), c("database", "postgres:latest")])
    assert Enum.map(Terminal.targets(s), & &1.name) == ~w(workbench database)
  end

  test "each target's shells, and the first is the one a row's button opens" do
    s =
      status([
        c("app", "lorem-ipsum:local"),
        c("database", "postgres:latest"),
        c("pgadmin", "dpage/pgadmin4:latest")
      ])

    [app, db, pga] = Terminal.targets(s)

    assert Terminal.shells(app) == [{"bash", "bash"}, {"iex", "iex -S mix"}]
    # The reason to open the database is the database, not its filesystem.
    assert Terminal.default_shell(db) == "psql"
    # Alpine: sh is not a choice, it is the only one.
    assert Terminal.shells(pga) == [{"sh", "sh"}]
    assert Terminal.default_shell(app) == "bash"
  end

  test "the argv: only the dev app is entered where its source is mounted" do
    s =
      status([
        c("app", "lorem-ipsum:local"),
        c("database", "postgres:latest"),
        c("pgadmin", "dpage/pgadmin4:latest")
      ])

    [app, db, pga] = Terminal.targets(s)

    assert {_, argv, _} = Terminal.argv(s, app, "bash")

    assert argv ==
             ~w(compose --project-name lorem_ipsum exec -T) ++
               colour() ++ ~w(-w /app/src app) ++ Terminal.announced(~w(bash))

    assert {_, argv, _} = Terminal.argv(s, db, "psql")

    assert argv ==
             ~w(compose --project-name lorem_ipsum exec -T) ++
               colour() ++ ["database" | Terminal.announced(~w(psql -U postgres))]

    assert {_, argv, _} = Terminal.argv(s, pga, "sh")

    assert argv ==
             ~w(compose --project-name lorem_ipsum exec -T) ++
               colour() ++ ["pgadmin" | Terminal.announced(~w(sh))]
  end

  # Before the status is here the targets are a guess and the source's
  # path is nil — docker would refuse `-v :/app/src`. The button waits.
  test "before the status, the session cannot be opened, and the reason is on the button" do
    import Phoenix.LiveViewTest
    term = %{target: nil, shell: nil, sessions: %{}, attached: nil}
    html = render_component(&Terminal.terminal/1, status: nil, term: term)
    assert html =~ ~r/<button[^>]*phx-click="term_start"[^>]*disabled/
    assert html =~ "reading the workspace"

    html =
      render_component(&Terminal.terminal/1, status: status([c("app", "x:local")]), term: term)

    refute html =~ ~r/<button[^>]*phx-click="term_start"[^>]*disabled/
  end

  test "a release replica keeps its own two shells and no source directory" do
    s = status([c("app1", "lorem-ipsum-prod:latest")])
    [replica] = Terminal.targets(s)

    assert replica.release
    assert Terminal.shells(replica) == [{"bash", "bash"}, {"rpc", "bin/app rpc"}]
    assert {_, argv, _} = Terminal.argv(s, replica, "bash")
    refute "-w" in argv
  end

  # A session is its own process and keeps its screen: the buttons are
  # never dark while one runs, they wear it — and a container that left
  # the status stays in the row while its session is there.
  test "the buttons wear their sessions, and the row keeps a session's container" do
    import Phoenix.LiveViewTest
    s = status([c("app", "lorem-ipsum:local"), c("database", "postgres:latest")])
    [app, db] = Terminal.targets(s)

    workbench = %{
      name: "workbench",
      kind: :workbench,
      release: false,
      oneoff: true,
      title: "one-off"
    }

    sessions = %{
      {"app", "iex"} => %{state: :live, target: app, shell: "iex"},
      {"database", "psql"} => %{state: {:ended, 0}, target: db, shell: "psql"},
      {"workbench", "bash"} => %{state: :live, target: workbench, shell: "bash"}
    }

    term = %{target: "app", shell: "bash", sessions: sessions, attached: nil}
    html = render_component(&Terminal.terminal/1, status: s, term: term)

    # The container's mark reads across its shells; the shell's is its own.
    assert html =~ ~r/<button[^>]*data-session="live"[^>]*>app</
    assert html =~ ~r/<button[^>]*data-session="ended"[^>]*>database</
    assert html =~ ~r/<button[^>]*data-session="live"[^>]*>workbench</
    assert html =~ ~r/<button[^>]*data-session="live"[^>]*>iex -S mix</
    refute html =~ ~r/<button[^>]*data-session[^>]*>bash</
    refute html =~ ~r/<button[^>]*phx-click="term_pick"[^>]*disabled/
    # app · bash has no session: the screen offers to open one, and says who else is open.
    assert html =~ "Open a session"
    assert html =~ "no session · 2 others open"

    # On an ended session the trail can be discarded, or a new one opened over it.
    term = %{term | target: "database", shell: "psql"}
    html = render_component(&Terminal.terminal/1, status: s, term: term)
    assert html =~ "session ended (exit 0) on database · psql · 2 others open"
    assert html =~ "Discard"
    assert html =~ "Open a session"
    refute html =~ "Close session"

    # On a live one, the input with its key, and the closing.
    term = %{term | target: "app", shell: "iex"}
    html = render_component(&Terminal.terminal/1, status: s, term: term)
    assert html =~ ~r/<input[^>]*data-key="app iex"/
    assert html =~ "Close session"
    assert html =~ "session on app · iex · 1 other open"
  end

  test "resolve: the target picked or the first, the shell when the target offers it" do
    s = status([c("app", "lorem-ipsum:local"), c("database", "postgres:latest")])
    term = %{target: "database", shell: "iex", sessions: %{}, attached: nil}
    assert {_, %{name: "database"}, "psql"} = Terminal.resolve(s, term)
    assert {_, %{name: "app"}, "iex"} = Terminal.resolve(s, %{term | target: "nope"})
    assert {_, %{name: "app"}, "bash"} = Terminal.resolve(s, %{term | target: nil, shell: "psql"})
  end
end
