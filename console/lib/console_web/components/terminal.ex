defmodule ConsoleWeb.Terminal do
  @moduledoc """
  A shell on the app container, or on a one-off container of the
  workbench's image with the source when nothing runs — line-oriented: an input, a screen, the
  history and Tab in the client. `docker exec -i` and `docker run -i`
  on a Port; no tty. bash reads lines that way, and so does iex: on the
  app container `iex --remsh <app>`, attached to the named node that
  serves the port (its Dockerfile.local's CMD boots it so), never a
  second VM with a mailbox and a Repo of its own; on the one-off, where
  nothing runs, `iex -S mix`. A release replica gets bash and `rpc` —
  `bin/<app> rpc` on each line, since its remote shell stops the node
  when its input ends; the remsh does the same, which is why a session
  on it is closed by a signal (see `Console.Terminals.Session`).
  """
  use Phoenix.Component

  alias ConsoleWeb.Services

  attr :status, :map, default: nil
  attr :term, :map, required: true

  def terminal(assigns) do
    {targets, target, shell} = resolve(assigns.status, assigns.term)
    sessions = assigns.term.sessions
    state = get_in(sessions, [{target.name, shell}, :state])

    assigns =
      assign(assigns,
        targets: targets,
        target: target,
        shells: shells(target),
        shell: shell,
        state: state,
        open: state == :live,
        live: Enum.count(sessions, fn {_, s} -> s.state == :live end),
        cmd: command(assigns.status, target, shell)
      )

    ~H"""
    <div
      class="logs term"
      id="term"
      phx-hook="Term"
      data-open={to_string(@open)}
      data-key={"#{@target.name} #{@shell}"}
    >
      <div class="logmeta">
        <span>{@cmd}</span><span>{cond do
          @open ->
            "session on #{@target.name} · #{@shell}#{others(@live - 1)}"

          match?({:ended, _}, @state) ->
            "session ended (exit #{elem(@state, 1)}) on #{@target.name} · #{@shell}#{others(@live)}"

          is_nil(@status) ->
            "reading the workspace…"

          true ->
            "no session#{others(@live)} · docker exec -i, line by line, no tty"
        end}</span>
      </div>
      <div class="viewport">
        <%!-- The containers on top, alone: where a session opens. Each one
              wears its sessions — live, or ended with its trail — and none
              is dark while another has one: a session is its own process,
              and the row switches the screen between them (2026-09-12). --%>
        <div class="toolbar controls top" aria-label="Where a session opens">
          <button
            :for={t <- @targets}
            class="btn svc"
            type="button"
            style={"--svc:#{svc_color(@status, t)}"}
            aria-pressed={to_string(t.name == @target.name)}
            data-session={mark(@term.sessions, t.name)}
            title={t.title <> sessions_on(@term.sessions, t.name)}
            phx-click="term_pick"
            phx-value-target={t.name}
          >{t.name}</button>
        </div>
        <div class="lines screen" id="term-screen" phx-update="ignore"></div>
        <form :if={@open} class="in" phx-submit="term_line">
          <span class="p">{prompt(@target, @shell, @status)}</span><input
            type="text"
            name="line"
            id="term-input"
            data-key={"#{@target.name} #{@shell}"}
            autocomplete="off"
            spellcheck="false"
            placeholder="↑↓ history · Ctrl+C interrupts · Ctrl+L clears"
          />
        </form>
        <%!-- The rest of the controls under the command line: with what,
              and the opening (2026-09-12). --%>
        <div class="toolbar controls">
          <span style="display:inline-flex;gap:6px;flex-wrap:wrap">
            <button
              :for={{v, label} <- @shells}
              class="btn"
              type="button"
              aria-pressed={to_string(@shell == v)}
              data-session={mark(@term.sessions, @target.name, v)}
              title={label <> sessions_on(@term.sessions, @target.name, v)}
              phx-click="term_pick"
              phx-value-shell={v}
            >{label}</button>
          </span>
          <span class="sep"></span>
          <button :if={@open} class="btn" type="button" phx-click="term_close">Close session</button>
          <button
            :if={!@open and match?({:ended, _}, @state)}
            class="btn"
            type="button"
            phx-click="term_close"
            title="forget this session's trail"
          >Discard</button>
          <button
            :if={!@open}
            class="btn primary"
            type="button"
            phx-click="term_start"
            disabled={is_nil(@status)}
            title={
              if is_nil(@status),
                do:
                  "reading the workspace — a session needs to know what runs, and where the source is",
                else: nil
            }
          >Open a session</button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Where a session can open: every running app container, the database and
  pgAdmin beside them, or a one-off container of the workbench's image
  when nothing runs: the image `wb.sh` runs the project's mix on, which
  exists from `new` on, before the app's own dev image is ever built.

  The workspace's other container is `pod` — the pause image, ~700 kB
  that own the ports and sleep — and it is not here: it carries no shell
  at all. That is the one case the house's rule hides rather than marks:
  `.unlit` is for what the reader could have, and this is not applicable
  and never will be.
  """
  def targets(status) do
    cs = (status && status["containers"]) || []

    apps =
      for c <- cs, Regex.match?(~r/^app\d*$/, c["Service"]), c["State"] == "running" do
        release = not String.ends_with?(c["Image"], ":local")

        %{
          name: c["Service"],
          kind: :app,
          release: release,
          oneoff: false,
          title: if(release, do: "the release image", else: "the dev image")
        }
      end

    apps =
      if apps == [],
        do: [
          %{
            name: "workbench",
            kind: :workbench,
            release: false,
            oneoff: true,
            title:
              "a one-off container of the workbench's image, with the source and its build volumes — nothing runs"
          }
        ],
        else: apps

    # The services beside the app that can be entered, in the compose's
    # own order: which, with what, and under which name, their
    # cartridges say (ConsoleWeb.Services).
    beside =
      for c <- Enum.sort_by(cs, &Services.position(status, &1["Service"])),
          c["State"] == "running",
          shells = Services.shells(status, c["Service"]),
          shells != [] do
        %{
          name: c["Service"],
          kind: :service,
          shells: shells,
          release: false,
          oneoff: false,
          title: Services.get(status, c["Service"])["title"] || "the #{c["Service"]} container"
        }
      end

    apps ++ beside
  end

  @doc """
  The targets with the sessions' own: a session on a container that has
  since left the status — the one-off workbench once the app runs, a
  replica stopped — is still a process with a screen, and its button
  stays until it is closed or discarded.
  """
  def targets(status, sessions) do
    known = targets(status)
    names = MapSet.new(known, & &1.name)

    extra =
      for {{name, _}, %{target: t}} <- Enum.sort(sessions),
          name not in names,
          uniq: true,
          do: %{t | title: t.title <> " — no longer in the status"}

    known ++ extra
  end

  @doc """
  What the page looks at, resolved: the targets, the one picked or the
  first, and the shell picked when that target offers it, else its
  first. The component and the page's events read the same answer.
  """
  def resolve(status, term) do
    targets = targets(status, term.sessions || %{})
    target = Enum.find(targets, &(&1.name == term.target)) || List.first(targets)

    shell =
      if Enum.any?(shells(target), &(elem(&1, 0) == term.shell)),
        do: term.shell,
        else: default_shell(target)

    {targets, target, shell}
  end

  # The mark a button wears: `live` when a session runs there, `ended`
  # when one is over with its trail, nothing otherwise. A target's mark
  # reads across its shells; a live one wins.
  defp mark(sessions, name, shell \\ nil) do
    states =
      for {{n, s}, %{state: st}} <- sessions, n == name, is_nil(shell) or s == shell, do: st

    cond do
      :live in states -> "live"
      states != [] -> "ended"
      true -> nil
    end
  end

  defp sessions_on(sessions, name, shell \\ nil) do
    for {{n, s}, %{state: st}} <- Enum.sort(sessions), n == name, is_nil(shell) or s == shell do
      case st do
        :live -> " · #{s} open"
        {:ended, code} -> " · #{s} ended (exit #{code})"
      end
    end
    |> Enum.join()
  end

  defp others(0), do: ""
  defp others(1), do: " · 1 other open"
  defp others(n), do: " · #{n} others open"

  @doc """
  What a session on this target can be. A cartridge's service offers
  what its cartridge says — the database its own client before bash,
  because the reason to open the database is the database and not its
  filesystem; an Alpine or busybox image `sh` alone, which is why its
  one shell is not a choice. The app's are the console's own to know.
  """
  def shells(%{kind: :service, shells: shells}), do: for({label, _} <- shells, do: {label, label})

  def shells(%{release: true}), do: [{"bash", "bash"}, {"rpc", "bin/app rpc"}]
  def shells(%{oneoff: true}), do: [{"bash", "bash"}, {"iex", "iex -S mix"}]
  def shells(_), do: [{"bash", "bash"}, {"iex", "iex --remsh"}]

  @doc "The shell a target opens with when none is chosen: the first it offers."
  def default_shell(target), do: target |> shells() |> hd() |> elem(0)

  defp svc_color(_status, %{kind: :workbench}), do: "var(--svc-network)"
  defp svc_color(status, %{name: name}), do: Services.color(status, name)

  def prompt(target, shell, status) do
    app = get_in(status, ["project", "app"]) || "app"

    cond do
      shell == "iex" ->
        "iex> "

      shell == "rpc" ->
        "#{app} rpc> "

      target.oneoff ->
        "elixir@#{target.name}:/app/src$ "

      # Who and where a session is, the container says (the status's
      # `homes`); the dev app is entered where its source is mounted.
      true ->
        Services.prompt(status, target.name, shell, List.last(workdir_args(target)))
    end
  end

  @doc "The docker command the session runs, in words."
  def command(status, target, shell) do
    cond do
      is_nil(status) ->
        ""

      target.oneoff ->
        "docker run -i --rm -v #{status["workspace"]}:/app/src -v …_build -v …deps -w /app/src #{image(status)} #{if shell == "iex", do: "iex -S mix", else: "bash"}"

      shell == "rpc" ->
        "docker compose -p #{status["compose_project"]} exec -T #{target.name} /app/bin/#{get_in(status, ["project", "app"]) || "app"} rpc …"

      true ->
        app = get_in(status, ["project", "app"]) || "app"

        "docker compose -p #{status["compose_project"]} exec -T #{workdir(target)}#{target.name} #{Enum.join(run(shell, app, target), " ")}"
    end
  end

  # A pipe is no terminal, and iex, mix, hex and git would go plain on
  # it: this asks them for colour anyway — Elixir by the option the VM
  # reads before anything else, git by the config it takes from the
  # environment — and the page turns it into spans (Console.ANSI), the
  # same way the jobs get theirs through wb.sh's WB_ANSI. ls and grep
  # have no such switch; they take --color=always on the line.
  @colour [
    "-e",
    "ELIXIR_ERL_OPTIONS=-elixir ansi_enabled true",
    "-e",
    "TERM=xterm-256color",
    "-e",
    "GIT_CONFIG_COUNT=1",
    "-e",
    "GIT_CONFIG_KEY_0=color.ui",
    "-e",
    "GIT_CONFIG_VALUE_0=always"
  ]

  @doc """
  The argv for the Port — docker, and what to run in the container — and
  how to run something else in that same container, for Ctrl+C:
  `{app, argv, exec}`. The one-off gets a name of its own so it can be
  reached; the rest are the compose's services. What runs is wrapped
  (`announced/1`) so the session learns the PID it has in there.
  """
  def argv(status, target, shell) do
    app = get_in(status, ["project", "app"]) || "app"

    if target.oneoff do
      name =
        "#{status["compose_project"] || "app"}_workbench_term_#{System.unique_integer([:positive])}"

      cmd = if shell == "iex", do: ["iex", "-S", "mix"], else: ["bash"]

      {app,
       ["run", "-i", "--rm", "--name", name | @colour] ++
         oneoff_mounts(status) ++ ["-w", "/app/src", image(status) | announced(cmd)],
       ["exec", "-i", name]}
    else
      compose = ["compose", "--project-name", status["compose_project"]]

      {app,
       compose ++
         ["exec", "-T" | @colour] ++
         workdir_args(target) ++ [target.name | announced(coloured(run(shell, app, target), app))],
       compose ++ ["exec", "-T", target.name]}
    end
  end

  @doc """
  A command run through `sh`, which prints the PID it is about to hand
  the command — `exec` keeps it — on a line the session reads and never
  shows. A pipe has no terminal to turn Ctrl+C into a signal, so the
  console signals by PID, and in a container the PID is only known from
  inside.
  """
  def announced(cmd),
    do: ["sh", "-c", ~S(printf '\033]wb-pid;%s\007\n' "$$"; exec "$@"), "sh" | cmd]

  # Only the dev app is entered where its source is mounted: a release
  # has none, and neither postgres nor pgAdmin has ever heard of /app/src.
  defp workdir_args(%{kind: :app, release: false}), do: ["-w", "/app/src"]
  defp workdir_args(_), do: []
  defp workdir(target), do: if(workdir_args(target) == [], do: "", else: "-w /app/src ")

  # IEx colours its results where it evaluates them, which for a remsh
  # is the app's node — booted with no terminal, so its IEx has them
  # off, whatever the env of this exec says to the local one. Before
  # attaching, the app's node is told to colour, IEx's own setting and
  # nothing else on it (not `ansi_enabled`, which would colour its
  # Logger lines too), through an rpc that leaves no VM behind. Then
  # `exec` hands the announced PID to iex.
  defp coloured(["iex" | _] = cmd, app) do
    [
      "sh",
      "-c",
      ~s|elixir --sname "wb_cfg_$$" --rpc-eval #{app} 'IEx.configure(colors: [enabled: true])' >/dev/null 2>&1; exec "$@"|,
      "sh" | cmd
    ]
  end

  defp coloured(cmd, _app), do: cmd

  # What each shell is, as a command line. iex attaches to the app's
  # node, `<app>@<hostname>`: a short name without a host is completed
  # with the container's own, which is where the server is. A
  # cartridge's service runs what its cartridge says the shell is
  # (psql with the user the compose gives postgres); the rest are bash.
  defp run("iex", app, _target), do: ["iex", "--remsh", app]

  defp run(shell, _app, %{kind: :service, shells: shells}),
    do: Enum.find_value(shells, ["sh"], fn {label, argv} -> label == shell && argv end)

  defp run(_, _, _), do: ["bash"]

  # The mounts `wb.sh` gives its own runs on the project: the source, the
  # workbench (the project's mix.exs takes its package from there), and
  # over _build and deps the workbench's build volume and the deps the
  # app shares — so nothing compiles through the bind mount, and nothing
  # into the app's build.
  defp oneoff_mounts(status) do
    project = status["compose_project"] || "app"

    [
      "-v",
      "#{status["workspace"]}:/app/src",
      "-v",
      "#{Console.Workbench.dir()}:/app/workbench:ro",
      "-v",
      "#{project}_workbench_build:/app/src/_build",
      "-v",
      "#{project}_deps:/app/src/deps"
    ]
  end

  # The workbench's image for this workspace, as `wb.sh` names it.
  defp image(status), do: Console.Workbench.image(status["workspace"])
end
