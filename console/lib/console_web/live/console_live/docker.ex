defmodule ConsoleWeb.ConsoleLive.Docker do
  @moduledoc """
  The Docker screen's state, off the page: which document and which
  container the URL names, the readings asked of the daemon, the stats
  stream, and what the daemon says on its own.
  """
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [connected?: 1, push_patch: 2, start_async: 3]

  alias Console.{Docker, Jobs}
  alias ConsoleWeb.DockerScreen

  # Which document and which container, from the query: /docker?doc=volumes,
  # ?doc=containers&c=some_test-app-1. Opening Events is looking at what
  # the badge counted: it starts over.
  def take(%{assigns: %{tab: "docker"}} = socket, params) do
    dk = socket.assigns.dk
    doc = if params["doc"] in DockerScreen.doc_names(), do: params["doc"], else: "containers"
    pick = params["c"]

    dk = %{
      dk
      | doc: doc,
        pick: pick,
        card: if(pick == dk.pick, do: dk.card, else: nil),
        alarms: if(doc == "events", do: 0, else: dk.alarms)
    }

    socket |> assign(dk: dk) |> read() |> stream()
  end

  # Leaving the screen closes the stream; the readings stay for the way back.
  def take(socket, _params), do: stream(socket)

  # The document's readings, asked of the daemon off the page: short
  # docker commands, one task each, the answer put where the document
  # looks for it. Not in tests, which have no daemon.
  def read(%{assigns: %{tab: "docker", dk: dk, status: status}} = socket) do
    if connected?(socket) and Application.get_env(:console, :docker_reads, true),
      do: socket |> ask_daemon(dk) |> ask_doc(dk, status),
      else: socket
  end

  def read(socket), do: socket

  # The daemon's line, once; and the disk it holds, measured once per
  # visit and again after a job, which is when it changes — `system df`
  # takes seconds, and the line says so until it lands.
  defp ask_daemon(socket, dk) do
    socket =
      if is_nil(dk.daemon),
        do: start_async(socket, {:dk, :daemon}, fn -> Docker.daemon() end),
        else: socket

    if is_nil(dk.df),
      do: start_async(socket, {:dk, :df}, fn -> Docker.df() end),
      else: socket
  end

  # The verbs after which the disk is not what it was: what builds,
  # pulls, writes a volume or removes. `system df` is seconds — 28 on a
  # daemon with a hundred volumes and a build cache — so a stop, a
  # restart or a commit does not ask for it again.
  @disk_verbs [:up, :build, :bake, :new, :delete, :prune, :remove, :insert, :eject, :mix, :demo]

  @doc "A job ended: after the verbs that move the disk, it is measured again on the next read."
  def forget_disk(%{assigns: %{dk: dk}} = socket, {verb, _}) when verb in @disk_verbs,
    do: assign(socket, dk: %{dk | df: nil})

  def forget_disk(socket, _kind), do: socket

  # The readings of the document in front.
  defp ask_doc(socket, dk, status) do
    scope = dk.scope

    case dk.doc do
      "containers" ->
        socket
        |> start_async({:dk, :rows}, fn -> Docker.containers(status, scope) end)
        |> ask_card(dk.pick)

      "images" ->
        start_async(socket, {:dk, :images}, fn -> Docker.images(status, scope) end)

      # The list is milliseconds; the measurement is seconds, and lands
      # on its own when it lands.
      "volumes" ->
        socket
        |> start_async({:dk, :volumes}, fn -> Docker.volumes(status, scope) end)
        |> start_async({:dk, :sizes}, fn -> Docker.volume_sizes() end)

      "networks" ->
        start_async(socket, {:dk, :networks}, fn -> Docker.networks(status, scope) end)

      _ ->
        socket
    end
  end

  # The picked container's card, when one is picked.
  defp ask_card(socket, nil), do: socket
  defp ask_card(socket, pick), do: start_async(socket, {:dk, :card}, fn -> Docker.card(pick) end)

  # The stats stream lives with the Containers document: open while it
  # is in front and Stats is on, closed the moment it is not. The daemon
  # is asked nothing that nobody is looking at.
  def stream(socket) do
    dk = socket.assigns.dk

    want =
      connected?(socket) and socket.assigns.tab == "docker" and dk.doc == "containers" and
        dk.stats

    cond do
      want and is_nil(dk.port) -> open_stats(socket, dk)
      not want and dk.port -> close_stats(socket, dk)
      true -> socket
    end
  end

  # `docker stats` on a Port, when docker is there to run.
  defp open_stats(socket, dk) do
    case System.find_executable("docker") do
      nil ->
        socket

      docker ->
        port =
          Port.open({:spawn_executable, docker}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            {:line, 65_536},
            args: Docker.stats_args()
          ])

        assign(socket, dk: %{dk | port: port})
    end
  end

  defp close_stats(socket, dk) do
    try do
      Port.close(dk.port)
    rescue
      _ -> :ok
    end

    assign(socket, dk: %{dk | port: nil, live: %{}})
  end

  # --- what the reader does ---------------------------------------------------

  def event("dk_scope", %{"scope" => scope}, socket) when scope in ~w(workspace daemon) do
    dk = %{socket.assigns.dk | scope: scope, rows: nil, images: nil, volumes: nil, networks: nil}
    {:noreply, socket |> assign(dk: dk) |> read()}
  end

  def event("dk_stats", _, socket) do
    dk = socket.assigns.dk
    {:noreply, socket |> assign(dk: %{dk | stats: not dk.stats, live: %{}}) |> stream()}
  end

  def event("dk_pick", %{"name" => name}, socket) do
    # Picked again is put down.
    q = if socket.assigns.dk.pick == name, do: "", else: "&c=#{name}"
    {:noreply, push_patch(socket, to: "/docker?doc=containers#{q}")}
  end

  # The one act on a single container: the deployment stays whole.
  def event("dk_restart", %{"service" => service}, socket) do
    deployment = (socket.assigns.status && socket.assigns.status["deployment"]) || "dev"
    Jobs.run({:restart, service}, ["restart", "--deploy", deployment, service])
    {:noreply, socket}
  end

  # The console restarting itself: not a job, since the job would die
  # with the console before it could report; a `docker restart` sent to
  # the daemon from a process of its own, which carries it out whether
  # or not this one lives to see it. The page reconnects on its own.
  def event("dk_restart_console", _, socket) do
    spawn(fn -> Console.Docker.restart_console() end)
    {:noreply, socket}
  end

  # An image by every name it wears, or a volume, through prune: confirmed like the rest.
  def event("dk_remove", %{"names" => names}, socket) when is_binary(names) and names != "" do
    names = String.split(names)
    Jobs.run({:remove, hd(names)}, ["prune" | names], confirm: true)
    {:noreply, socket}
  end

  # --- what arrives ---------------------------------------------------------

  # What Docker did on its own: onto the feed, and onto the badge when
  # it is something that died badly — unless the reader is looking at
  # the feed right now.
  def info({:event, event}, socket) do
    dk = socket.assigns.dk
    looking = socket.assigns.tab == "docker" and dk.doc == "events"
    alarm = DockerScreen.alarm?(event, Docker.project(socket.assigns.status)) and not looking
    events = Enum.take([event | dk.events], 500)

    {:noreply,
     assign(socket,
       dk: %{dk | events: events, alarms: if(alarm, do: dk.alarms + 1, else: dk.alarms)}
     )}
  end

  # A reading of the stats stream, by container name.
  def info({port, {:data, {_, line}}}, %{assigns: %{dk: %{port: port} = dk}} = socket) do
    case Docker.stat(line) do
      nil -> {:noreply, socket}
      s -> {:noreply, assign(socket, dk: %{dk | live: Map.put(dk.live, s.name, s)})}
    end
  end

  def info({port, {:exit_status, _}}, %{assigns: %{dk: %{port: port} = dk}} = socket),
    do: {:noreply, assign(socket, dk: %{dk | port: nil})}

  # What the Docker screen asked the daemon for; a reading that failed
  # leaves the document empty rather than the page dark.
  def async({:dk, key}, {:ok, value}, socket),
    do: {:noreply, assign(socket, dk: Map.put(socket.assigns.dk, key, value))}

  def async({:dk, key}, {:exit, why}, socket),
    do:
      {:noreply,
       socket
       |> assign(dk: Map.put(socket.assigns.dk, key, if(key == :rows, do: [], else: nil)))
       |> assign(error: "docker could not be read: " <> inspect(why))}
end
