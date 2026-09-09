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

  # The daemon's line, once.
  defp ask_daemon(socket, %{daemon: nil}),
    do: start_async(socket, {:dk, :daemon}, fn -> Docker.daemon() end)

  defp ask_daemon(socket, _dk), do: socket

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

      # The list is milliseconds; the two measurements are seconds, and
      # land on their own when they land.
      "volumes" ->
        socket
        |> start_async({:dk, :volumes}, fn -> Docker.volumes(status, scope) end)
        |> start_async({:dk, :sizes}, fn -> Docker.volume_sizes() end)
        |> start_async({:dk, :df}, fn -> Docker.df() end)

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

  # Always confirmed: the console runs wb.sh under --yes and asks itself.
  def event("dk_prune", %{"what" => what}, socket) when what in ["", "images", "build"] do
    Jobs.run({:prune, nil}, ["prune" | if(what == "", do: [], else: ["--" <> what])],
      confirm: true
    )

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
