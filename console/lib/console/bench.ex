defmodule Console.Bench do
  @moduledoc """
  What the console knows of the workbench, held once for every page: the
  status, the catalog, the recipes `expand` answered. A page mounting
  reads from memory and never starts a container; the readings that
  cost one — the full status boots Mix in a container, seconds — run
  only after the jobs that change what they say, and one at a time:
  a reading already in flight is the one everybody waits for.

  Every arrival is broadcast on the `"bench"` topic:
  `{:bench, :status, status}`, `{:bench, :catalog, catalog}`,
  `{:bench, :expand, name, argv, plan}`, `{:bench, :error, key, why}`.

  The catalog is the workbench's, not the workspace's: it is read once
  and kept until a `new` or `delete`, or until the features directory of
  the igniter package changes on disk.
  """
  use GenServer

  alias Console.Workbench

  @topic "bench"

  defstruct status: nil, catalog: nil, features_stamp: nil, expands: %{}, in_flight: %{}, wanted: %{}, errors: %{}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def subscribe, do: Phoenix.PubSub.subscribe(Console.PubSub, @topic)

  @doc "The status as last read, or nil before the first reading."
  def status, do: GenServer.call(__MODULE__, :status)

  @doc "The catalog as last read, or nil; a changed features directory reads it again in the background."
  def catalog, do: GenServer.call(__MODULE__, :catalog)

  @doc "Whether a reading of `key` (:status or :catalog) is in flight."
  def reading?(key), do: GenServer.call(__MODULE__, {:reading?, key})

  @doc "Why the last reading of `key` failed, or nil: a page mounting after the failure still sees it."
  def error(key), do: GenServer.call(__MODULE__, {:error, key})

  @doc """
  Asks for the status again — `:full` with the cartridges, `:fast`
  without — or the catalog. One reading at a time per key: asked while
  one is in flight, the request waits for it, and a `:full` asked
  during a `:fast` runs after it.
  """
  def refresh(key, mode \\ nil), do: GenServer.cast(__MODULE__, {:refresh, key, mode})

  @doc "A collection's plan for these options: `{:ok, plan}` from memory, or `:asking` while it is read."
  def expand(name, argv), do: GenServer.call(__MODULE__, {:expand, name, argv})

  @impl true
  def init(_) do
    state = %__MODULE__{features_stamp: features_stamp()}
    # The first readings, at boot — unless the tests say not to: they
    # would start containers.
    if Application.get_env(:console, :bench_reads_at_boot, true),
      do: {:ok, state |> start(:catalog, nil) |> start(:status, :full)},
      else: {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  def handle_call(:catalog, _from, state) do
    stamp = features_stamp()

    state =
      if stamp != state.features_stamp and not Map.has_key?(state.in_flight, :catalog),
        do: %{state | features_stamp: stamp} |> start(:catalog, nil),
        else: state

    {:reply, state.catalog, state}
  end

  def handle_call({:reading?, key}, _from, state), do: {:reply, Map.has_key?(state.in_flight, key), state}
  def handle_call({:error, key}, _from, state), do: {:reply, state.errors[key], state}

  def handle_call({:expand, name, argv}, _from, state) do
    case state.expands do
      %{{^name, ^argv} => plan} ->
        {:reply, {:ok, plan}, state}

      _ ->
        key = {:expand, name, argv}

        state =
          if Map.has_key?(state.in_flight, key),
            do: state,
            else: put_in(state.in_flight[key], Task.async(fn -> {key, Console.Resident.ask(%{"ask" => "expand", "name" => name, "argv" => argv})} end))

        {:reply, :asking, state}
    end
  end

  @impl true
  def handle_cast({:refresh, key, mode}, state) do
    # Everything again means another workspace may be there: the
    # resident of the old one is dropped.
    if key == :status and mode == :all, do: Console.Resident.reset()
    mode = if mode == :all, do: :full, else: mode

    if Map.has_key?(state.in_flight, key) do
      # Already reading: a stronger request runs after this one.
      wanted = if mode == :full or state.wanted[key] == :full, do: :full, else: mode
      {:noreply, put_in(state.wanted[key], wanted)}
    else
      {:noreply, start(state, key, mode)}
    end
  end

  @impl true
  def handle_info({ref, {key, result}}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    state = %{state | in_flight: Map.delete(state.in_flight, key)}

    state =
      case {key, result} do
        {:status, {:ok, status}} ->
          # A fast reading leaves the cartridges out: what was known stays.
          status = if is_nil(status["project"]) and state.status, do: Map.put(status, "project", state.status["project"]), else: status
          # What the project carries may have changed: the recipes with it.
          expands = if state.status && status["project"] != state.status["project"], do: %{}, else: state.expands
          broadcast({:bench, :status, status})
          %{state | status: status, expands: expands, errors: Map.delete(state.errors, :status)}

        {:catalog, {:ok, catalog}} ->
          broadcast({:bench, :catalog, catalog})
          %{state | catalog: catalog, errors: Map.delete(state.errors, :catalog)}

        {{:expand, name, argv}, {:ok, plan}} ->
          broadcast({:bench, :expand, name, argv, plan})
          put_in(state.expands[{name, argv}], plan)

        {key, {:error, why}} ->
          broadcast({:bench, :error, key, why})
          %{state | errors: Map.put(state.errors, key, why)}
      end

    # A request that arrived meanwhile runs now.
    case Map.pop(state.wanted, key) do
      {nil, wanted} -> {:noreply, %{state | wanted: wanted}}
      {mode, wanted} -> {:noreply, %{state | wanted: wanted} |> start(key, mode)}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    {key, _} = Enum.find(state.in_flight, {nil, nil}, fn {_, task} -> task.ref == nil end) || {nil, nil}
    if key, do: broadcast({:bench, :error, key, inspect(reason)})
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # The status: what wb.sh reads in tenths of a second — containers,
  # ports, git — and, for the full one, what the project carries, asked
  # of the resident BEAM (Console.Resident) rather than of a container.
  defp start(state, :status, mode) do
    mode = mode || :full
    put_in(state.in_flight[:status], Task.async(fn -> {:status, read_status(mode)} end))
  end

  # The catalog is read in this BEAM: the package is a dependency.
  defp start(state, :catalog, _), do: put_in(state.in_flight[:catalog], Task.async(fn -> {:catalog, {:ok, Console.Catalog.read()}} end))

  defp read_status(:fast), do: Workbench.status(:fast)

  defp read_status(:full) do
    with {:ok, fast} <- Workbench.status(:fast) do
      if fast["exists"] do
        case Console.Resident.ask(%{"ask" => "status"}) do
          {:ok, project} -> {:ok, Map.put(fast, "project", project)}
          {:error, why} -> {:error, "the project could not be read: " <> why}
        end
      else
        {:ok, fast}
      end
    end
  end

  defp broadcast(msg), do: Phoenix.PubSub.broadcast(Console.PubSub, @topic, msg)

  # The features directory and each cartridge's directory, by their
  # modification times: a cartridge added, removed or rewritten moves one.
  defp features_stamp do
    dir = Console.Papers.features_dir()

    case File.ls(dir) do
      {:ok, entries} ->
        [dir | Enum.map(entries, &Path.join(dir, &1))]
        |> Enum.map(fn p -> case File.stat(p) do {:ok, s} -> s.mtime; _ -> nil end end)

      _ ->
        nil
    end
  end
end
