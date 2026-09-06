defmodule Console.Events do
  @moduledoc """
  What Docker does on its own, as it happens: one `docker events` on a
  `Port`, open for as long as the console is. It has to be: the daemon
  keeps only its last 256 events, and two healthchecks every 10 s fill
  that in seven minutes (measured 2026-09-05 — `--since 2h` answered
  exactly 256 lines, all of them probes), so a feed read when a screen
  opens would hold nothing worth reading. Each event is parsed, the
  `exec_*` of the healthchecks dropped (233 of every 256), the rest
  kept in a buffer of the last `@cap` for the screen that will show
  them, and broadcast on the `"events"` topic as `{:event, event}`.

  And the reason this exists before any screen shows it: the Bench
  reads the status after a job and never on a clock, so a container
  that died, restarted or turned unhealthy *on its own* went unnoticed
  until the next job. A life event on a container of the workspace's
  project asks for a fast status — settled over `@settle` ms, so a
  `down`, a dozen events in ten seconds, asks a couple of times and
  not twelve. The Bench serialises the rest.
  """
  use GenServer

  alias Console.Bench

  @topic "events"
  @cap 500
  @settle 800
  @retry 5_000
  @wakes ~w(create start restart die stop kill destroy oom pause unpause health_status)

  defstruct port: nil, events: [], count: 0, settling: nil

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def subscribe, do: Phoenix.PubSub.subscribe(Console.PubSub, @topic)

  @doc "The events kept, oldest first."
  def recent, do: GenServer.call(__MODULE__, :recent)

  @doc "Whether the stream is open."
  def listening?, do: GenServer.call(__MODULE__, :listening?)

  @impl true
  def init(_) do
    # Not in tests: they have no daemon to listen to.
    if Application.get_env(:console, :events_at_boot, true), do: send(self(), :open)
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:recent, _from, state), do: {:reply, Enum.reverse(state.events), state}
  def handle_call(:listening?, _from, state), do: {:reply, state.port != nil, state}

  @impl true
  def handle_info(:open, state) do
    case System.find_executable("docker") do
      nil ->
        {:noreply, state}

      docker ->
        port =
          Port.open({:spawn_executable, docker}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            {:line, 65_536},
            args: ["events", "--format", "{{json .}}", "--filter", "type=container", "--filter", "type=network", "--filter", "type=volume", "--filter", "type=image"]
          ])

        {:noreply, %{state | port: port}}
    end
  end

  def handle_info({port, {:data, {:eol, raw}}}, %{port: port} = state) do
    case parse(raw) do
      nil ->
        {:noreply, state}

      event ->
        Phoenix.PubSub.broadcast(Console.PubSub, @topic, {:event, event})
        events = [event | state.events]
        {events, count} = if state.count >= @cap, do: {Enum.take(events, @cap), @cap}, else: {events, state.count + 1}
        {:noreply, wake(%{state | events: events, count: count}, event)}
    end
  end

  def handle_info({port, {:data, {:noeol, _}}}, %{port: port} = state), do: {:noreply, state}

  # The stream ends only when the daemon goes: it is opened again after
  # a while, and keeps trying — the daemon may be coming back.
  def handle_info({port, {:exit_status, _}}, %{port: port} = state) do
    Process.send_after(self(), :open, @retry)
    {:noreply, %{state | port: nil}}
  end

  def handle_info(:settle, state) do
    Bench.refresh(:status, :fast)
    {:noreply, %{state | settling: nil}}
  end

  def handle_info(_, state), do: {:noreply, state}

  # One timer at a time: the first waking event starts it, the ones
  # that follow within it ride along.
  defp wake(%{settling: nil} = state, event) do
    if wakes?(event, project()),
      do: %{state | settling: Process.send_after(self(), :settle, @settle)},
      else: state
  end

  defp wake(state, _), do: state

  defp project do
    case Bench.status() do
      %{"compose_project" => project} -> project
      _ -> nil
    end
  end

  @doc """
  Whether an event is one the status should be read again for: a life
  event of a container of the workspace's project — or of any project,
  while the status has not said which one this is.
  """
  def wakes?(%{type: "container", action: action, project: p}, project) when action in @wakes,
    do: is_nil(project) or p == project

  def wakes?(_, _), do: false

  @doc """
  A line of `docker events --format '{{json .}}'` into an event, or nil:
  the type and the action, the action's detail when it carries one
  (`health_status: unhealthy`), who — name, compose service and
  project, image — and how it ended, the exit code and the signal. The
  healthchecks' `exec_create`, `exec_start` and `exec_die` are not
  events of anything: dropped here, at the source.
  """
  def parse(raw) do
    with {:ok, %{"Type" => type, "Action" => action} = e} <- Jason.decode(raw),
         false <- String.starts_with?(action, "exec_") do
      {action, detail} =
        case String.split(action, ": ", parts: 2) do
          [a, d] -> {a, d}
          [a] -> {a, nil}
        end

      attrs = get_in(e, ["Actor", "Attributes"]) || %{}

      %{
        type: type,
        action: action,
        detail: detail,
        ts: if(is_integer(e["time"]), do: DateTime.from_unix!(e["time"])),
        id: get_in(e, ["Actor", "ID"]) || "",
        name: attrs["name"],
        service: attrs["com.docker.compose.service"],
        project: attrs["com.docker.compose.project"],
        image: attrs["image"],
        exit: attrs["exitCode"],
        signal: attrs["signal"]
      }
    else
      _ -> nil
    end
  end
end
