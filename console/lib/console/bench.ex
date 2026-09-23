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
  `{:bench, :stacks, tags}`, `{:bench, :installers, releases}`,
  `{:bench, :packages, readings}`,
  `{:bench, :expand, name, argv, plan}`, `{:bench, :error, key, why}`.

  The stacks, the installers and the packages are the readings that are
  not about this machine at all: the usable `hexpm/elixir` images, five
  pages of Docker Hub's API; the `phx_new` releases hex publishes; and
  what hex says of the packages a box brings (`Console.Hex`). They are
  never read on their own — not at boot, not when the screen that shows
  them opens — only when the reader presses the button beside them, and
  then they are held here for every page until pressed again. No clock
  refreshes them: a reading that costs the internet happens when
  somebody asks for it, and that way there is never a call the reader
  did not cause. The packages are kept by name, so a box whose
  dependency another box already brought is answered from memory and
  only the names nobody has asked for are fetched.

  The catalog is the workbench's, not the workspace's: it is read once
  and kept until a `new` or `delete`, or until the features directory of
  the igniter package changes on disk.
  """
  use GenServer

  alias Console.Workbench

  @topic "bench"

  defstruct status: nil,
            catalog: nil,
            stacks: nil,
            installers: nil,
            packages: %{},
            features_stamp: nil,
            expands: %{},
            in_flight: %{},
            wanted: %{},
            errors: %{}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def subscribe, do: Phoenix.PubSub.subscribe(Console.PubSub, @topic)

  @doc "The status as last read, or nil before the first reading."
  def status, do: GenServer.call(__MODULE__, :status)

  @doc "The catalog as last read, or nil; a changed features directory reads it again in the background."
  def catalog, do: GenServer.call(__MODULE__, :catalog)

  @doc "The usable stacks as last read, or nil while nobody has asked."
  def stacks, do: GenServer.call(__MODULE__, :stacks)

  @doc "The Phoenix installers as last read, or nil while nobody has asked."
  def installers, do: GenServer.call(__MODULE__, :installers)

  @doc "What hex said of each package asked for so far, by name; `%{}` before anybody asks."
  def packages, do: GenServer.call(__MODULE__, :packages)

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

  def handle_call(:stacks, _from, state), do: {:reply, state.stacks, state}
  def handle_call(:installers, _from, state), do: {:reply, state.installers, state}
  def handle_call(:packages, _from, state), do: {:reply, state.packages, state}

  def handle_call({:reading?, key}, _from, state),
    do: {:reply, Map.has_key?(state.in_flight, key), state}

  def handle_call({:error, key}, _from, state), do: {:reply, state.errors[key], state}

  def handle_call({:expand, name, argv}, _from, state) do
    case state.expands do
      %{{^name, ^argv} => plan} ->
        {:reply, {:ok, plan}, state}

      _ ->
        {:reply, :asking, ask_expand(state, name, argv)}
    end
  end

  # The recipe asked of the resident, once: a question already out is not asked again.
  defp ask_expand(state, name, argv) do
    key = {:expand, name, argv}

    if Map.has_key?(state.in_flight, key),
      do: state,
      else:
        put_in(
          state.in_flight[key],
          Task.async(fn ->
            {key, Console.Resident.ask(%{"ask" => "expand", "name" => name, "argv" => argv})}
          end)
        )
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
          take_status(state, status)

        {:catalog, {:ok, catalog}} ->
          broadcast({:bench, :catalog, catalog})
          %{state | catalog: catalog, errors: Map.delete(state.errors, :catalog)}

        {:stacks, {:ok, tags}} ->
          broadcast({:bench, :stacks, tags})
          %{state | stacks: tags, errors: Map.delete(state.errors, :stacks)}

        {:installers, {:ok, releases}} ->
          broadcast({:bench, :installers, releases})
          %{state | installers: releases, errors: Map.delete(state.errors, :installers)}

        # Kept by name and merged: what was read before stays, and a
        # second press over the same names replaces those readings.
        {:packages, readings} ->
          packages = Map.merge(state.packages, readings)
          broadcast({:bench, :packages, packages})
          %{state | packages: packages, errors: Map.delete(state.errors, :packages)}

        {{:expand, name, argv}, {:ok, plan}} ->
          broadcast({:bench, :expand, name, argv, plan})
          put_in(state.expands[{name, argv}], plan)

        {key, {:error, why}} ->
          broadcast({:bench, :error, key, why})
          %{state | errors: Map.put(state.errors, key, why)}
      end

    run_wanted(state, key)
  end

  # A reading that died rather than answered. This looked for the key by
  # `task.ref == nil`, which is never true — so it found nothing, told
  # nobody, and left the key in `in_flight` for good: every later refresh
  # of it queued into `wanted` behind a reading that was never coming
  # back, and the page went on saying nobody had asked. The ref is what
  # names the task; the key is cleared with it, the failure is kept like
  # any other so a page mounting later still sees it, and whatever was
  # asked for meanwhile runs now.
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Enum.find(state.in_flight, fn {_, task} -> task.ref == ref end) do
      {key, _} ->
        why = "the reading did not finish: " <> inspect(reason)
        broadcast({:bench, :error, key, why})

        state = %{
          state
          | in_flight: Map.delete(state.in_flight, key),
            errors: Map.put(state.errors, key, why)
        }

        run_wanted(state, key)

      nil ->
        {:noreply, state}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  # The status that arrived, onto the state.
  defp take_status(state, status) do
    # A fast reading leaves the cartridges out: what was known
    # stays — but only while the project is still there. A delete
    # answers `exists: false`, and then there is nothing to carry:
    # the doors and the inserted cartridges go with it.
    status =
      if is_nil(status["project"]) and status["exists"] and state.status,
        do: Map.put(status, "project", state.status["project"]),
        else: status

    # What the project carries may have changed: the recipes with it.
    expands =
      if state.status && status["project"] != state.status["project"],
        do: %{},
        else: state.expands

    broadcast({:bench, :status, status})
    %{state | status: status, expands: expands, errors: Map.delete(state.errors, :status)}
  end

  # A request that arrived meanwhile runs now.
  defp run_wanted(state, key) do
    case Map.pop(state.wanted, key) do
      {nil, wanted} -> {:noreply, %{state | wanted: wanted}}
      {mode, wanted} -> {:noreply, %{state | wanted: wanted} |> start(key, mode)}
    end
  end

  # The status: what wb.sh reads in tenths of a second — containers,
  # ports, git — and, for the full one, what the project carries, asked
  # of the resident BEAM (Console.Resident) rather than of a container.
  defp start(state, :status, mode) do
    mode = mode || :full
    put_in(state.in_flight[:status], Task.async(fn -> {:status, read_status(mode)} end))
  end

  # The catalog is read in this BEAM: the package is a dependency.
  defp start(state, :catalog, _),
    do:
      put_in(
        state.in_flight[:catalog],
        Task.async(fn -> {:catalog, {:ok, Console.Catalog.read()}} end)
      )

  # Docker Hub, five pages of it, over the reader's own connection.
  defp start(state, :stacks, _),
    do: put_in(state.in_flight[:stacks], Task.async(fn -> {:stacks, Workbench.stacks()} end))

  # hex, one call per package, and GitHub for the ones that come from a
  # repository there — named `name=owner/repo` — in this BEAM, together.
  defp start(state, :packages, names) do
    {repos, hex} = names |> List.wrap() |> Enum.split_with(&String.contains?(&1, "="))
    repos = for r <- repos, [name, repo] = String.split(r, "=", parts: 2), do: {name, repo}

    put_in(
      state.in_flight[:packages],
      Task.async(fn ->
        {:packages, Map.merge(Console.Hex.read(hex), Console.GitHub.read(repos))}
      end)
    )
  end

  defp start(state, :installers, _),
    do:
      put_in(
        state.in_flight[:installers],
        Task.async(fn -> {:installers, Console.Installers.list()} end)
      )

  defp read_status(:fast), do: Workbench.status(:fast)

  defp read_status(:full) do
    case Workbench.status(:fast) do
      {:ok, fast} -> if fast["exists"], do: with_project(fast), else: {:ok, fast}
      error -> error
    end
  end

  # What the project carries, asked of the resident, onto the fast reading.
  defp with_project(fast) do
    case Console.Resident.ask(%{"ask" => "status"}) do
      {:ok, project} -> {:ok, Map.put(fast, "project", project)}
      {:error, why} -> {:error, "the project could not be read: " <> why}
    end
  end

  defp broadcast(msg), do: Phoenix.PubSub.broadcast(Console.PubSub, @topic, msg)

  # The features directory, each cartridge's directory and the files in
  # it, by their modification times: a cartridge added or removed moves
  # a directory's, and one edited in place — its manifest, its
  # changelog — moves only the file's.
  defp features_stamp do
    dir = Console.Papers.features_dir()

    case File.ls(dir) do
      {:ok, entries} ->
        boxes = entries |> Enum.sort() |> Enum.map(&Path.join(dir, &1))
        files = Enum.flat_map(boxes, &files_in/1)
        Enum.map([dir | boxes ++ files], &{&1, mtime(&1)})

      _ ->
        nil
    end
  end

  defp files_in(box) do
    case File.ls(box) do
      {:ok, names} -> names |> Enum.sort() |> Enum.map(&Path.join(box, &1))
      _ -> []
    end
  end

  defp mtime(path) do
    case File.stat(path) do
      {:ok, s} -> s.mtime
      _ -> nil
    end
  end
end
