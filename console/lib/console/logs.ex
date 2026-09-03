defmodule Console.Logs do
  @moduledoc """
  The logs of the workspace's compose project, followed: one `docker
  compose logs --follow` on a `Port`, whichever deployment is up — the
  three composes share the project name, so the project is enough and
  no compose file has to be named. Each line is parsed into the
  service, its timestamp and the text, kept in a buffer of the last
  `@cap` for whoever opens the screen later, and broadcast on the
  `"logs"` topic as `{:log, line}`.

  `follow --follow` attaches to the containers there are when it
  starts: after an up or a down the stream is started again
  (`follow/2` with `restart: true`), which the page asks for when the
  status that follows such a job arrives.
  """
  use GenServer

  @topic "logs"
  @cap 2000
  @tail 500

  defstruct project: nil, port: nil, lines: [], count: 0

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Follows the project's logs; starts the stream again when asked, or when it is not running."
  def follow(project, opts \\ []), do: GenServer.cast(__MODULE__, {:follow, project, opts[:restart] == true})

  @doc "The lines kept, oldest first."
  def backlog, do: GenServer.call(__MODULE__, :backlog)

  @doc "Whether a stream is running, and for which project."
  def following, do: GenServer.call(__MODULE__, :following)

  def subscribe, do: Phoenix.PubSub.subscribe(Console.PubSub, @topic)

  @impl true
  def init(_), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_cast({:follow, nil, _}, state), do: {:noreply, close(state)}

  def handle_cast({:follow, project, restart}, state) do
    if state.port && state.project == project && not restart do
      {:noreply, state}
    else
      state = close(state)

      port =
        Port.open({:spawn_executable, System.find_executable("docker")}, [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          {:line, 8192},
          args: ["compose", "--project-name", project, "logs", "--follow", "--timestamps", "--no-color", "--tail", to_string(@tail)]
        ])

      # A stream started again reads the tail again: the buffer starts over
      # with it, and every page is told to start over too, or the same
      # lines would stand twice on a page that had the old buffer.
      Phoenix.PubSub.broadcast(Console.PubSub, @topic, {:logs, :restarted})
      {:noreply, %{state | project: project, port: port, lines: [], count: 0}}
    end
  end

  @impl true
  def handle_call(:backlog, _from, state), do: {:reply, Enum.reverse(state.lines), state}
  def handle_call(:following, _from, state), do: {:reply, state.port && state.project, state}

  @impl true
  def handle_info({port, {:data, {:eol, raw}}}, %{port: port} = state) do
    case parse(raw) do
      nil -> {:noreply, state}
      line ->
        Phoenix.PubSub.broadcast(Console.PubSub, @topic, {:log, line})
        lines = [line | state.lines]
        {lines, count} = if state.count >= @cap, do: {Enum.take(lines, @cap), @cap}, else: {lines, state.count + 1}
        {:noreply, %{state | lines: lines, count: count}}
    end
  end

  def handle_info({port, {:data, {:noeol, _}}}, %{port: port} = state), do: {:noreply, state}

  # The stream ends on its own when there is nothing to follow (no
  # containers): the next status with some starts it again.
  def handle_info({port, {:exit_status, _}}, %{port: port} = state), do: {:noreply, %{state | port: nil}}
  def handle_info(_, state), do: {:noreply, state}

  defp close(%{port: nil} = state), do: state

  defp close(state) do
    try do
      Port.close(state.port)
    rescue
      _ -> :ok
    end

    %{state | port: nil}
  end

  @doc """
  A line of `compose logs --timestamps` into `%{service, ts, text}`:
  the container's name (`database-1`, `app2-1`) minus its ordinal is
  the service. Compose's own notices (no `|`) are dropped.
  """
  def parse(raw) do
    case Regex.run(~r/^(\S+?)\s+\| (\S+) ?(.*)$/, raw) do
      [_, container, ts, text] ->
        %{service: String.replace(container, ~r/-\d+$/, ""), ts: ts, text: text}

      _ ->
        nil
    end
  end
end
