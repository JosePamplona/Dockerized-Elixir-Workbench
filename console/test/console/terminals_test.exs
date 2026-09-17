defmodule Console.TerminalsTest do
  use ExUnit.Case, async: false

  alias Console.Terminals

  @target %{name: "probe", kind: :app, release: false, oneoff: false, title: "a probe"}

  # The session runs `cat`, and not docker: each line comes back as it went.
  defp open(key, extra \\ []) do
    {:ok, pid} =
      Terminals.open(
        key,
        [
          exe: System.find_executable("sh"),
          argv: ["-c", "cat"],
          target: @target,
          shell: "bash",
          head: "the head"
        ] ++
          extra
      )

    pid
  end

  setup do
    Terminals.subscribe()
    on_exit(fn -> for {key, _} <- Terminals.list(), do: Terminals.close(key) end)
    :ok
  end

  test "a session keeps its trail, echoes each line and tells whoever is attached" do
    key = {"probe", "bash"}
    open(key)
    assert_receive {:terminal, ^key, :live}
    assert %{^key => %{state: :live, target: @target, shell: "bash"}} = Terminals.list()

    assert {:ok, %{lines: [{"the head", "dim"}], state: :live}} = Terminals.attach(key)
    Terminals.send_line(key, "hello", "$ hello")
    assert_receive {:term, ^key, {:line, "$ hello", "p"}}
    assert_receive {:term, ^key, {:line, "hello", nil}}, 2000

    # Attaching again hands the whole trail, in order, and does not double the watcher.
    assert {:ok, %{lines: [{"the head", "dim"}, {"$ hello", "p"}, {"hello", nil}]}} =
             Terminals.attach(key)

    Terminals.send_line(key, "again", "$ again")
    assert_receive {:term, ^key, {:line, "again", nil}}, 2000
    refute_receive {:term, ^key, {:line, "again", nil}}, 100

    # Detached, the lines stay with the session.
    Terminals.detach(key)
    Terminals.send_line(key, "quiet", "$ quiet")
    refute_receive {:term, ^key, {:line, "quiet", nil}}, 300
    assert {:ok, %{lines: lines}} = Terminals.attach(key)
    assert {"quiet", nil} in lines
  end

  # Ctrl+C on a pipe: the command announces its PID, the session keeps
  # that line off the screen and signals what runs under the shell, and
  # the shell goes on. `env` stands in for `docker exec`, here on the host.
  test "an interrupt stops what the shell runs, and the shell stays" do
    key = {"probe", "bash"}
    ["sh" | argv] = ConsoleWeb.Terminal.announced(["bash"])

    {:ok, _} =
      Terminals.open(key,
        exe: System.find_executable("sh"),
        argv: argv,
        target: @target,
        shell: "bash",
        head: "h",
        exec: [],
        signal_exe: System.find_executable("env")
      )

    assert {:ok, _} = Terminals.attach(key)
    Terminals.send_line(key, "sleep 30; echo rc=$?", "$ sleep 30")
    assert_receive {:term, ^key, {:line, "$ sleep 30", "p"}}
    Process.sleep(300)

    Terminals.interrupt(key)
    assert_receive {:term, ^key, {:line, "^C", "p"}}
    assert_receive {:term, ^key, {:line, "rc=130", nil}}, 3000

    Terminals.send_line(key, "echo alive", "$ echo alive")
    assert_receive {:term, ^key, {:line, "alive", nil}}, 2000

    {:ok, %{lines: lines}} = Terminals.attach(key)
    refute Enum.any?(lines, fn {html, _} -> html =~ "wb-pid" end)
  end

  # A remote shell that reads EOF stops the node it is on: an iex is
  # sent SIGTERM and waited for before its port — its stdin — is closed.
  # `env` stands in for `docker exec`, here on the host.
  test "closing an iex signals it first, and takes its input away only once it has left" do
    key = {"probe", "iex"}
    mark = Path.join(System.tmp_dir!(), "wb_term_#{System.unique_integer([:positive])}")

    ["sh" | argv] =
      ConsoleWeb.Terminal.announced([
        "sh",
        "-c",
        "trap 'echo term > #{mark}; exit 0' TERM; while :; do sleep 1; done"
      ])

    {:ok, _} =
      Terminals.open(key,
        exe: System.find_executable("sh"),
        argv: argv,
        target: @target,
        shell: "iex",
        head: "h",
        exec: [],
        signal_exe: System.find_executable("env")
      )

    assert {:ok, _} = Terminals.attach(key)
    Process.sleep(300)
    Terminals.close(key)
    assert_receive {:terminal, ^key, :closed}
    assert File.read!(mark) == "term\n"
    File.rm(mark)
  end

  test "when the process ends the session stays with its trail, and a close forgets it" do
    key = {"probe", "bash"}

    {:ok, _} =
      Terminals.open(key,
        exe: System.find_executable("sh"),
        argv: ["-c", "exit 3"],
        target: @target,
        shell: "bash",
        head: "h"
      )

    assert_receive {:terminal, ^key, {:ended, 3}}, 2000
    assert %{^key => %{state: {:ended, 3}}} = Terminals.list()

    assert {:ok,
            %{lines: [{"h", "dim"}, {"— session ended (exit 3)", "dim"}], state: {:ended, 3}}} =
             Terminals.attach(key)

    Terminals.close(key)
    assert_receive {:terminal, ^key, :closed}
    assert Terminals.list() == %{}
    assert Terminals.attach(key) == :none
  end

  test "opening on a key replaces what it held, and two keys are two processes" do
    a = open({"probe", "bash"})
    b = open({"probe", "iex"})
    assert a != b
    assert map_size(Terminals.list()) == 2

    c = open({"probe", "bash"})
    assert c != a
    refute Process.alive?(a)
    assert_receive {:terminal, {"probe", "bash"}, :closed}
    assert map_size(Terminals.list()) == 2
  end

  test "Ctrl+L forgets the trail" do
    key = {"probe", "bash"}
    open(key)
    Terminals.clear(key)
    assert {:ok, %{lines: []}} = Terminals.attach(key)
  end
end
