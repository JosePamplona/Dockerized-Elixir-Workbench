defmodule ConsoleWeb.ConsoleLive.Term do
  @moduledoc """
  The terminal's state, off the page: the target and the shell the
  reader picked, the session open on a container as a Port, and each
  line that goes in and comes out.
  """
  use ConsoleWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_patch: 2]

  alias ConsoleWeb.Terminal

  # --- what the reader does ---------------------------------------------------

  def event("term_pick", params, socket) do
    t = socket.assigns.term
    t = %{t | target: params["target"] || t.target, shell: params["shell"] || t.shell}
    {:noreply, assign(socket, term: t)}
  end

  def event("term_open", %{"target" => target, "shell" => shell}, socket) do
    socket = assign(socket, term: %{socket.assigns.term | target: target, shell: shell})
    {:noreply, socket |> push_patch(to: ~p"/terminal") |> start()}
  end

  # Before the status a session has nothing to open on: the targets
  # would be guessed and the source's path unknown, and docker would
  # refuse an empty mount. The button says so and stays dark until then.
  def event("term_start", _, %{assigns: %{status: nil}} = socket), do: {:noreply, socket}
  def event("term_start", _, socket), do: {:noreply, start(socket)}

  def event("term_close", _, socket), do: {:noreply, close(socket)}

  def event("term_line", %{"line" => line}, socket) do
    t = socket.assigns.term

    if t.port do
      target = Enum.find(Terminal.targets(socket.assigns.status), &(&1.name == t.target))
      app = get_in(socket.assigns.status, ["project", "app"]) || "app"
      # rpc: each line is one expression handed to the release, through the bash that is open.
      text =
        if (t.shell == "rpc" and target) && target.release,
          do: "/app/bin/#{app} rpc \"$(cat <<'EOF_WB'\n#{line}\nEOF_WB\n)\"\n",
          else: line <> "\n"

      Port.command(t.port, text)
    end

    targets = Terminal.targets(socket.assigns.status)

    prompt =
      Terminal.prompt(
        Enum.find(targets, &(&1.name == t.target)) || hd(targets),
        t.shell,
        socket.assigns.status
      )

    escaped = line |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    {:noreply, push_event(socket, "term_out", %{line: prompt <> escaped, prompt: true})}
  end

  def start(socket) do
    status = socket.assigns.status
    t = close(socket).assigns.term
    targets = Terminal.targets(status)
    target = Enum.find(targets, &(&1.name == t.target)) || hd(targets)

    shell =
      if Enum.any?(Terminal.shells(target), &(elem(&1, 0) == t.shell)), do: t.shell, else: "bash"

    {_app, argv} = Terminal.argv(status, target, if(shell == "rpc", do: "bash", else: shell))

    port =
      Port.open({:spawn_executable, System.find_executable("docker")}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:line, 8192},
        args: argv
      ])

    socket
    |> assign(term: %{t | target: target.name, shell: shell, open: true, port: port})
    |> push_event("term_out", %{
      line:
        Terminal.command(status, target, shell) <>
          "  → " <>
          if(target.oneoff,
            do: "a one-off toolchain container with the source mounted (nothing runs)",
            else: "docker exec on " <> target.name
          ),
      dim: true,
      clear: true
    })
  end

  def close(%{assigns: %{term: %{port: nil}}} = socket),
    do: assign(socket, term: %{socket.assigns.term | open: false})

  def close(socket) do
    try do
      Port.close(socket.assigns.term.port)
    rescue
      _ -> :ok
    end

    assign(socket, term: %{socket.assigns.term | open: false, port: nil})
  end

  # --- what arrives ---------------------------------------------------------

  # A line of the session's output goes to the screen; the session ends
  # when the process in the container does.
  def info({port, {:data, {_, line}}}, %{assigns: %{term: %{port: port}}} = socket),
    do: {:noreply, push_event(socket, "term_out", %{line: Console.ANSI.to_html(line)})}

  def info({port, {:exit_status, code}}, %{assigns: %{term: %{port: port}} = a} = socket),
    do:
      {:noreply,
       socket
       |> assign(term: %{a.term | open: false, port: nil})
       |> push_event("term_out", %{line: "— session ended (exit #{code})", dim: true})}
end
