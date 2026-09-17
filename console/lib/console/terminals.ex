defmodule Console.Terminals do
  @moduledoc """
  The terminal's sessions, each its own process: one per container and
  shell — `app · bash`, `app · iex`, `database · psql` — under a
  supervisor of this console's, not the page's. A session outlives the
  page that opened it: reload, change tab, lose the socket, and the
  iex is still there with its screen, since the process holds the last
  lines it wrote and hands them back to whoever attaches.

  A session is keyed by `{target, shell}`. It is live while the process
  in the container runs; when that one ends the session stays, ended,
  with its trail and the exit code, until the reader opens on the same
  key again or discards it. What the reader can see of every session at
  once — live, ended — goes out on PubSub, so every page marks its
  buttons; the lines go only to the processes attached to that session.
  """
  use Supervisor

  alias Console.Terminals.Session

  @topic "terminals"

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_) do
    Supervisor.init(
      [
        {Registry, keys: :unique, name: Console.Terminals.Registry},
        {DynamicSupervisor, name: Console.Terminals.Supervisor, strategy: :one_for_one}
      ],
      strategy: :one_for_all
    )
  end

  @doc "Every page listens: `{:terminal, key, :live | {:ended, code} | :closed}`."
  def subscribe, do: Phoenix.PubSub.subscribe(Console.PubSub, @topic)

  @doc false
  def broadcast(key, state),
    do: Phoenix.PubSub.broadcast(Console.PubSub, @topic, {:terminal, key, state})

  @doc """
  Opens a session on `key`, replacing whatever the key held — an ended
  one and its trail, or a live one, closed first. `opts`: `:exe` and
  `:argv` for the Port, `:target` and `:shell` as the Terminal component
  knows them, `:app` for rpc, `:head` for the dim first line, `:exec`
  for the docker arguments that run a command in the same container
  (Ctrl+C), and `:signal_exe` to run them with something else than docker.
  """
  def open(key, opts) do
    close(key)

    DynamicSupervisor.start_child(
      Console.Terminals.Supervisor,
      {Session, Keyword.put(opts, :key, key)}
    )
  end

  @doc "Ends the session on `key`, live or ended, and forgets its trail."
  def close(key) do
    case whereis(key) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end
  end

  @doc """
  Attaches the calling process to the session on `key`: from now on it
  receives `{:term, key, {:line, html, cls}}` for each line, and gets
  back the lines so far and the session's state, in one step, so no
  line falls between the trail and the first message.
  """
  def attach(key) do
    case whereis(key) do
      nil -> :none
      pid -> GenServer.call(pid, {:attach, self()})
    end
  end

  def detach(key) do
    case whereis(key) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:detach, self()})
    end
  end

  @doc "A line of the reader's, echoed on the screen and handed to the process."
  def send_line(key, line, echo) do
    case whereis(key) do
      nil -> :none
      pid -> GenServer.cast(pid, {:line, line, echo})
    end
  end

  @doc "Ctrl+C: interrupts what the session runs, as a terminal would."
  def interrupt(key) do
    case whereis(key) do
      nil -> :none
      pid -> GenServer.cast(pid, :interrupt)
    end
  end

  @doc "Forgets the trail, as Ctrl+L cleared the screen."
  def clear(key) do
    case whereis(key) do
      nil -> :ok
      pid -> GenServer.cast(pid, :clear)
    end
  end

  @doc """
  What there is: `%{key => %{state: :live | {:ended, code}, target: t, shell: s}}`,
  the target as the Terminal component built it — so a session on a
  container that has since left the status still knows where it is.
  """
  def list do
    Console.Terminals.Registry
    |> Registry.select([{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
    |> Map.new()
  end

  def whereis(key) do
    case Registry.lookup(Console.Terminals.Registry, key) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end
end

defmodule Console.Terminals.Session do
  @moduledoc """
  One session: the Port to the process in the container, the last
  lines of its screen already turned into HTML, and who is watching.

  Ctrl+C. The Port is a pipe, and a pipe has no terminal to turn the key
  into SIGINT, so the session sends it: to the PID the command announced
  (`ConsoleWeb.Terminal.announced/1`), through a second `docker exec` in
  the same container. A shell — bash, sh, the rpc's bash — gets nothing
  itself: every process under it does, the way a terminal signals the
  foreground job and leaves the prompt. iex and psql are the process
  itself, and each does with SIGINT what it does in a terminal: iex
  opens the BEAM's BREAK menu (`c` continues, `a` leaves), psql cancels
  the query that runs.
  """
  use GenServer, restart: :temporary

  alias Console.Terminals

  @limit 2000

  # Every process under $1, found through /proc — the slim images carry
  # no pkill — signalled at once.
  @under ~S"""
  list=$1; found=""
  while [ -n "$list" ]; do
    next=""
    for f in /proc/[0-9]*/stat; do
      s=$(cat "$f" 2>/dev/null) || continue
      pid=${s%% *}; rest=${s##*) }; set -- $rest
      for q in $list; do [ "$2" = "$q" ] && next="$next $pid"; done
    done
    found="$found$next"; list=$next
  done
  [ -z "$found" ] || kill -INT $found
  """

  def start_link(opts) do
    key = Keyword.fetch!(opts, :key)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {Console.Terminals.Registry, key, meta(opts, :live)}}
    )
  end

  defp meta(opts, state),
    do: %{
      state: state,
      target: Keyword.fetch!(opts, :target),
      shell: Keyword.fetch!(opts, :shell)
    }

  @impl true
  def init(opts) do
    key = Keyword.fetch!(opts, :key)
    exe = Keyword.get(opts, :exe) || System.find_executable("docker")

    port =
      Port.open({:spawn_executable, exe}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:line, 8192},
        args: Keyword.fetch!(opts, :argv)
      ])

    state = %{
      key: key,
      port: port,
      shell: Keyword.fetch!(opts, :shell),
      release: Keyword.fetch!(opts, :target).release,
      app: Keyword.get(opts, :app, "app"),
      exec: Keyword.get(opts, :exec, []),
      signal_exe: Keyword.get(opts, :signal_exe) || System.find_executable("docker"),
      pid: nil,
      lines: [],
      count: 0,
      state: :live,
      watchers: %{}
    }

    Terminals.broadcast(key, :live)
    {:ok, put(state, Keyword.get(opts, :head, ""), "dim")}
  end

  @impl true
  def handle_call({:attach, pid}, _from, state) do
    watchers =
      case state.watchers do
        %{^pid => _} -> state.watchers
        w -> Map.put(w, pid, Process.monitor(pid))
      end

    {:reply, {:ok, %{lines: Enum.reverse(state.lines), state: state.state}},
     %{state | watchers: watchers}}
  end

  @impl true
  def handle_cast({:detach, pid}, state), do: {:noreply, forget(state, pid)}

  def handle_cast({:line, line, echo}, state) do
    state = put(state, echo, "p")

    if state.port do
      # rpc: each line is one expression handed to the release, through the bash that is open.
      text =
        if state.shell == "rpc" and state.release,
          do: "/app/bin/#{state.app} rpc \"$(cat <<'EOF_WB'\n#{line}\nEOF_WB\n)\"\n",
          else: line <> "\n"

      Port.command(state.port, text)
    end

    {:noreply, state}
  end

  def handle_cast(:clear, state), do: {:noreply, %{state | lines: [], count: 0}}

  def handle_cast(:interrupt, %{port: port, pid: pid} = state) when port != nil and pid != nil do
    script = if state.shell in ~w(iex psql), do: ~S(kill -INT "$1"), else: @under
    argv = state.exec ++ ["sh", "-c", script, "sh", pid]
    exe = state.signal_exe
    # A docker exec takes a moment, and the session keeps reading meanwhile.
    Task.start(fn -> System.cmd(exe, argv, stderr_to_stdout: true) end)
    {:noreply, put(state, "^C", "p")}
  end

  def handle_cast(:interrupt, state), do: {:noreply, state}

  @impl true
  def handle_info(
        {port, {:data, {_, "\e]wb-pid;" <> rest = line}}},
        %{port: port, pid: nil} = state
      ) do
    case Integer.parse(String.trim_trailing(rest, "\a")) do
      {pid, ""} -> {:noreply, %{state | pid: Integer.to_string(pid)}}
      _ -> {:noreply, put(state, Console.ANSI.to_html(line), nil)}
    end
  end

  def handle_info({port, {:data, {_, line}}}, %{port: port} = state),
    do: {:noreply, put(state, Console.ANSI.to_html(line), nil)}

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    Registry.update_value(Console.Terminals.Registry, state.key, &%{&1 | state: {:ended, code}})
    Terminals.broadcast(state.key, {:ended, code})

    {:noreply,
     %{state | port: nil, state: {:ended, code}}
     |> put("— session ended (exit #{code})", "dim")}
  end

  def handle_info({:DOWN, _, :process, pid, _}, state), do: {:noreply, forget(state, pid)}

  # The name goes first, by hand: the Registry would drop it on its own
  # a moment after the process dies, and the page that closed asks the
  # list, or opens on the same key, before that moment.
  #
  # An iex is told to leave before its input is taken away. Closing the
  # port is an EOF on stdin, and a remote shell that reads EOF stops
  # the node it is attached to — the app's server, for `iex --remsh` —
  # while one killed by SIGTERM shuts its own VM down and leaves the
  # node it was on alone (both measured 2026-09-16). So the session
  # signals the iex it announced and waits for it to end, up to a
  # moment, and only then closes the port.
  @impl true
  def terminate(_reason, state) do
    Registry.unregister(Console.Terminals.Registry, state.key)
    if state.port, do: leave(state)
    if state.port, do: try_close(state.port)
    Terminals.broadcast(state.key, :closed)
  end

  defp leave(%{shell: "iex", pid: pid, port: port} = state) when pid != nil do
    argv = state.exec ++ ["sh", "-c", ~S(kill -TERM "$1"), "sh", pid]
    System.cmd(state.signal_exe, argv, stderr_to_stdout: true)

    receive do
      {^port, {:exit_status, _}} -> :ok
    after
      3000 -> :ok
    end
  end

  defp leave(_), do: :ok

  defp try_close(port) do
    Port.close(port)
  rescue
    _ -> :ok
  end

  # A line on the screen: kept, capped, and told to whoever watches.
  defp put(state, html, cls) do
    for {pid, _} <- state.watchers, do: send(pid, {:term, state.key, {:line, html, cls}})
    lines = [{html, cls} | state.lines]

    if state.count >= @limit,
      do: %{state | lines: Enum.take(lines, @limit)},
      else: %{state | lines: lines, count: state.count + 1}
  end

  defp forget(state, pid) do
    case Map.pop(state.watchers, pid) do
      {nil, _} ->
        state

      {ref, w} ->
        Process.demonitor(ref, [:flush])
        %{state | watchers: w}
    end
  end
end
