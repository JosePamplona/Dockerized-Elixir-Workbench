defmodule ConsoleWeb.Terminal do
  @moduledoc """
  A shell on the app container, or on a one-off toolchain container with
  the source when nothing runs — line-oriented: an input, a screen, the
  history and Tab in the client. `docker exec -i` and `docker run -i`
  on a Port; no tty. bash and `iex -S mix` both read lines that way;
  a release replica gets bash and `rpc` — `bin/<app> rpc` on each line,
  since its remote shell stops the node when its input ends.
  """
  use Phoenix.Component

  attr :status, :map, default: nil
  attr :term, :map, required: true

  def terminal(assigns) do
    targets = targets(assigns.status)
    target = Enum.find(targets, &(&1.name == assigns.term.target)) || List.first(targets)
    shells = shells(target)
    shell = if Enum.any?(shells, &(elem(&1, 0) == assigns.term.shell)), do: assigns.term.shell, else: default_shell(target)
    assigns = assign(assigns, targets: targets, target: target, shells: shells, shell: shell, cmd: command(assigns.status, target, shell))

    ~H"""
    <div class="logs term" id="term" phx-hook="Term" data-open={to_string(@term.open)}>
      <div class="toolbar">
        <span style="display:inline-flex;gap:6px;flex-wrap:wrap">
          <button :for={t <- @targets} class="btn svc" type="button" style={"--svc:#{svc_color(t)}"} aria-pressed={to_string(t.name == @target.name)} disabled={@term.open and t.name != @target.name} title={t.title} phx-click="term_pick" phx-value-target={t.name}>{t.name}</button>
        </span>
        <span class="sep"></span>
        <span style="display:inline-flex;gap:6px;flex-wrap:wrap">
          <button :for={{v, label} <- @shells} class="btn" type="button" aria-pressed={to_string(@shell == v)} disabled={@term.open and @shell != v} title={label} phx-click="term_pick" phx-value-shell={v}>{label}</button>
        </span>
        <span class="sep"></span>
        <button :if={@term.open} class="btn" type="button" phx-click="term_close">Close session</button>
        <button :if={!@term.open} class="btn primary" type="button" phx-click="term_start" disabled={is_nil(@status)} title={if is_nil(@status), do: "reading the workspace — a session needs to know what runs, and where the source is", else: nil}>Open a session</button>
      </div>
      <div class="logmeta"><span>{@cmd}</span><span>{cond do @term.open -> "session on #{@target.name} · #{@shell}"; is_nil(@status) -> "reading the workspace…"; true -> "no session · docker exec -i, line by line, no tty" end}</span></div>
      <div class="viewport">
        <div class="lines screen" id="term-screen" phx-update="ignore"><span class="nothing">No session. Open one: bash or iex on the app when it runs, or on a one-off toolchain container with the source.</span></div>
        <form :if={@term.open} class="in" phx-submit="term_line"><span class="p">{prompt(@target, @shell, @status)}</span><input type="text" name="line" id="term-input" autocomplete="off" spellcheck="false" placeholder="↑↓ history · Ctrl+L clears" /></form>
      </div>
    </div>
    """
  end

  @doc """
  Where a session can open: every running app container, the database and
  pgAdmin beside them, or a one-off toolchain container when nothing runs.

  The workspace's other container is `network` — the pause image, ~700 KB
  that own the ports and sleep — and it is not here: it carries no shell
  at all. That is the one case the house's rule hides rather than marks:
  `.unlit` is for what the reader could have, and this is not applicable
  and never will be.
  """
  def targets(status) do
    cs = (status && status["containers"]) || []

    apps = for c <- cs, Regex.match?(~r/^app\d*$/, c["Service"]), c["State"] == "running" do
      release = not String.ends_with?(c["Image"], ":local")
      %{name: c["Service"], kind: :app, release: release, oneoff: false, title: if(release, do: "the release image", else: "the dev image")}
    end

    apps = if apps == [], do: [%{name: "toolchain", kind: :toolchain, release: false, oneoff: true, title: "a one-off toolchain container with the source mounted — nothing runs"}], else: apps

    # The services beside the app, in the order the compose declares them.
    beside = for c <- cs, c["Service"] in ~w(database pgadmin), c["State"] == "running" do
      %{name: c["Service"], kind: String.to_existing_atom(c["Service"]), release: false, oneoff: false,
        title: if(c["Service"] == "database", do: "the workspace's postgres", else: "the pgAdmin container")}
    end

    apps ++ beside
  end

  @doc """
  What a session on this target can be. The database's first shell is
  `psql` and not bash, because the reason to open the database is the
  database and not its filesystem; pgAdmin's image is Alpine and carries
  `sh` alone, which is why its one shell is not a choice.
  """
  def shells(%{kind: :database}), do: [{"psql", "psql"}, {"bash", "bash"}]
  def shells(%{kind: :pgadmin}), do: [{"sh", "sh"}]
  def shells(%{release: true}), do: [{"bash", "bash"}, {"rpc", "bin/app rpc"}]
  def shells(_), do: [{"bash", "bash"}, {"iex", "iex -S mix"}]

  @doc "The shell a target opens with when none is chosen: the first it offers."
  def default_shell(target), do: target |> shells() |> hd() |> elem(0)

  defp svc_color(%{kind: :toolchain}), do: "var(--svc-network)"
  defp svc_color(%{kind: kind}), do: "var(--svc-#{kind})"

  def prompt(target, shell, status) do
    app = get_in(status, ["project", "app"]) || "app"
    cond do
      shell == "iex" -> "iex> "
      shell == "rpc" -> "#{app} rpc> "
      shell == "psql" -> "postgres=# "
      target.kind == :pgadmin -> "pgadmin@#{target.name}:/$ "
      target.kind == :database -> "postgres@#{target.name}:/$ "
      target.release -> "nobody@#{target.name}:/app$ "
      true -> "elixir@#{target.name}:/app/src$ "
    end
  end

  @doc "The docker command the session runs, in words."
  def command(status, target, shell) do
    cond do
      is_nil(status) -> ""
      target.oneoff -> "docker run -i --rm -v #{status["workspace"]}:/app/src -w /app/src #{image(status)} #{if shell == "iex", do: "iex -S mix", else: "bash"}"
      shell == "rpc" -> "docker compose -p #{status["compose_project"]} exec -T #{target.name} /app/bin/#{get_in(status, ["project", "app"]) || "app"} rpc …"
      true -> "docker compose -p #{status["compose_project"]} exec -T #{workdir(target)}#{target.name} #{Enum.join(run(shell), " ")}"
    end
  end

  # A pipe is no terminal, and iex, mix, hex and git would go plain on
  # it: this asks them for colour anyway — Elixir by the option the VM
  # reads before anything else, git by the config it takes from the
  # environment — and the page turns it into spans (Console.ANSI), the
  # same way the jobs get theirs through wb.sh's WB_ANSI. ls and grep
  # have no such switch; they take --color=always on the line.
  @colour [
    "-e", "ELIXIR_ERL_OPTIONS=-elixir ansi_enabled true",
    "-e", "TERM=xterm-256color",
    "-e", "GIT_CONFIG_COUNT=1",
    "-e", "GIT_CONFIG_KEY_0=color.ui",
    "-e", "GIT_CONFIG_VALUE_0=always"
  ]

  @doc "The argv for the Port: docker, and what to run in the container."
  def argv(status, target, shell) do
    app = get_in(status, ["project", "app"]) || "app"

    cond do
      target.oneoff -> ["run", "-i", "--rm" | @colour] ++ ["-v", "#{status["workspace"]}:/app/src", "-w", "/app/src", image(status), if(shell == "iex", do: "iex", else: "bash")] ++ if(shell == "iex", do: ["-S", "mix"], else: [])
      true -> ["compose", "--project-name", status["compose_project"], "exec", "-T" | @colour] ++ workdir_args(target) ++ [target.name] ++ run(shell)
    end
    |> then(&{app, &1})
  end

  # Only the dev app is entered where its source is mounted: a release
  # has none, and neither postgres nor pgAdmin has ever heard of /app/src.
  defp workdir_args(%{kind: :app, release: false}), do: ["-w", "/app/src"]
  defp workdir_args(_), do: []
  defp workdir(target), do: if(workdir_args(target) == [], do: "", else: "-w /app/src ")

  # What each shell is, as a command line. `psql` takes the user the
  # compose gives postgres; the rest are the shell and nothing else.
  defp run("iex"), do: ["iex", "-S", "mix"]
  defp run("psql"), do: ["psql", "-U", "postgres"]
  defp run("sh"), do: ["sh"]
  defp run(_), do: ["bash"]

  # The workspace's dev image: its compose project with dashes, :local.
  defp image(status), do: String.replace(status["compose_project"] || "app", "_", "-") <> ":local"
end
