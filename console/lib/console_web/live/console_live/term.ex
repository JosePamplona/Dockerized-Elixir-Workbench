defmodule ConsoleWeb.ConsoleLive.Term do
  @moduledoc """
  The terminal's state, off the page: the target and the shell the
  reader is looking at, and what every session is — since the sessions
  themselves live in `Console.Terminals`, one process per container and
  shell, and outlive this page. The page attaches to the one it looks
  at, hands the screen its trail, and forwards each line that arrives;
  picking another container or shell detaches and attaches again, so
  the screen reads what that session has.
  """
  use ConsoleWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_patch: 2]

  alias Console.Terminals
  alias ConsoleWeb.Terminal

  @doc "What the page opens with: nothing picked, and every session there is."
  def initial, do: %{target: nil, shell: nil, sessions: Terminals.list(), attached: nil}

  # --- what the reader does ---------------------------------------------------

  # A target picked opens on the shell with a session on it — the
  # reason to press the container is the session it carries — or on its
  # first shell, the one the row's button opens with; the shell alone
  # changes the shell. The screen follows through the hook: it sees the
  # key change and asks.
  def event("term_pick", %{"target" => target}, socket) do
    t = socket.assigns.term
    live = for {{^target, sh}, %{state: :live}} <- t.sessions, do: sh
    t = %{t | target: target, shell: if(t.shell in live, do: t.shell, else: List.first(live))}
    {:noreply, assign(socket, term: t)}
  end

  def event("term_pick", %{"shell" => shell}, socket),
    do: {:noreply, assign(socket, term: %{socket.assigns.term | shell: shell})}

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
    {_targets, target, shell} = Terminal.resolve(socket.assigns.status, socket.assigns.term)
    prompt = Terminal.prompt(target, shell, socket.assigns.status)
    escaped = line |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    Terminals.send_line({target.name, shell}, line, prompt <> escaped)
    {:noreply, socket}
  end

  # Ctrl+L cleared the screen; the trail follows, so coming back reads the same.
  def event("term_clear", _, socket) do
    Terminals.clear(key(socket))
    {:noreply, socket}
  end

  # The hook asks for the screen of the session it looks at: once
  # mounted, and whenever the key on the screen changes — a pick, or a
  # status that took the container away and left the first one.
  def event("term_look", _, socket),
    do: {:noreply, socket |> assign(term: %{socket.assigns.term | attached: nil}) |> look()}

  def start(socket) do
    status = socket.assigns.status
    {_targets, target, shell} = Terminal.resolve(status, socket.assigns.term)
    {app, argv} = Terminal.argv(status, target, if(shell == "rpc", do: "bash", else: shell))

    head =
      Terminal.command(status, target, shell) <>
        "  → " <>
        if(target.oneoff,
          do: "a one-off toolchain container with the source mounted (nothing runs)",
          else: "docker exec on " <> target.name
        )

    {:ok, _} =
      Terminals.open({target.name, shell},
        argv: argv,
        target: target,
        shell: shell,
        app: app,
        head: head
      )

    socket
    |> assign(
      term: %{
        socket.assigns.term
        | target: target.name,
          shell: shell,
          attached: nil,
          sessions: Terminals.list()
      }
    )
    |> look()
  end

  def close(socket) do
    Terminals.close(key(socket))

    socket
    |> assign(term: %{socket.assigns.term | attached: nil, sessions: Terminals.list()})
    |> look()
  end

  # --- what arrives ---------------------------------------------------------

  # A line of the session this page looks at goes to the screen; lines
  # of the others are theirs to keep.
  def info({:term, key, {:line, html, cls}}, %{assigns: %{term: %{attached: key}}} = socket),
    do: {:noreply, push_event(socket, "term_out", %{line: html, cls: cls})}

  def info({:term, _, _}, socket), do: {:noreply, socket}

  # A session changed state, this page's or another's: the marks on
  # the buttons follow; one opened or closed under this screen — from
  # another page, or this one — is attached again, or left.
  def info({:terminal, key, state}, socket) do
    t = socket.assigns.term

    sessions =
      case state do
        :live -> Terminals.list()
        :closed -> Map.delete(t.sessions, key)
        ended -> Map.replace_lazy(t.sessions, key, &%{&1 | state: ended})
      end

    socket = assign(socket, term: %{t | sessions: sessions})

    if state in [:live, :closed] and t.attached == key,
      do: {:noreply, socket |> assign(term: %{socket.assigns.term | attached: nil}) |> look()},
      else: {:noreply, socket}
  end

  # --- the screen -------------------------------------------------------------

  # Looks at the current key: attaches to its session when it is not the
  # one attached, and hands the screen what the session holds — or
  # nothing, when the key holds no session.
  defp look(socket) do
    t = socket.assigns.term
    key = key(socket)

    if t.attached == key do
      socket
    else
      if t.attached, do: Terminals.detach(t.attached)

      socket
      |> assign(term: %{t | attached: key})
      |> push_event("term_screen", %{lines: trail(key)})
    end
  end

  defp trail(key) do
    case Terminals.attach(key) do
      {:ok, %{lines: lines}} -> Enum.map(lines, fn {html, cls} -> %{line: html, cls: cls} end)
      :none -> []
    end
  end

  defp key(socket) do
    {_targets, target, shell} = Terminal.resolve(socket.assigns.status, socket.assigns.term)
    {target.name, shell}
  end
end
