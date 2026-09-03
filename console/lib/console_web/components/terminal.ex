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
    shell = if Enum.any?(shells, &(elem(&1, 0) == assigns.term.shell)), do: assigns.term.shell, else: "bash"
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
        <button :if={!@term.open} class="btn primary" type="button" phx-click="term_start">Open a session</button>
      </div>
      <div class="logmeta"><span>{@cmd}</span><span>{if @term.open, do: "session on #{@target.name} · #{@shell}", else: "no session · docker exec -i, line by line, no tty"}</span></div>
      <div class="viewport">
        <div class="lines screen" id="term-screen" phx-update="ignore"><span class="empty">No session. Open one: bash or iex on the app when it runs, or on a one-off toolchain container with the source.</span></div>
        <form :if={@term.open} class="in" phx-submit="term_line"><span class="p">{prompt(@target, @shell, @status)}</span><input type="text" name="line" id="term-input" autocomplete="off" spellcheck="false" placeholder="↑↓ history · Ctrl+L clears" /></form>
      </div>
    </div>
    """
  end

  @doc "Where a session can open: every running app container, or a one-off toolchain container."
  def targets(status) do
    cs = (status && status["containers"]) || []
    apps = for c <- cs, Regex.match?(~r/^app\d*$/, c["Service"]), c["State"] == "running" do
      release = not String.ends_with?(c["Image"], ":local")
      %{name: c["Service"], release: release, oneoff: false, title: if(release, do: "the release image", else: "the dev image")}
    end

    if apps == [], do: [%{name: "toolchain", release: false, oneoff: true, title: "a one-off toolchain container with the source mounted — nothing runs"}], else: apps
  end

  def shells(%{release: true}), do: [{"bash", "bash"}, {"rpc", "bin/app rpc"}]
  def shells(_), do: [{"bash", "bash"}, {"iex", "iex -S mix"}]

  defp svc_color(%{oneoff: true}), do: "var(--svc-network)"
  defp svc_color(_), do: "var(--svc-app)"

  def prompt(target, shell, status) do
    app = get_in(status, ["project", "app"]) || "app"
    cond do
      shell == "iex" -> "iex> "
      shell == "rpc" -> "#{app} rpc> "
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
      true -> "docker compose -p #{status["compose_project"]} exec -T #{if target.release, do: "", else: "-w /app/src "}#{target.name} #{if shell == "iex", do: "iex -S mix", else: "bash"}"
    end
  end

  @doc "The argv for the Port: docker, and what to run in the container."
  def argv(status, target, shell) do
    app = get_in(status, ["project", "app"]) || "app"
    cond do
      target.oneoff -> ["run", "-i", "--rm", "-v", "#{status["workspace"]}:/app/src", "-w", "/app/src", image(status), if(shell == "iex", do: "iex", else: "bash")] ++ if(shell == "iex", do: ["-S", "mix"], else: [])
      true -> ["compose", "--project-name", status["compose_project"], "exec", "-T"] ++ if(target.release, do: [], else: ["-w", "/app/src"]) ++ [target.name] ++ (case shell do "iex" -> ["iex", "-S", "mix"]; _ -> ["bash"] end)
    end
    |> then(&{app, &1})
  end

  # The workspace's dev image: its compose project with dashes, :local.
  defp image(status), do: String.replace(status["compose_project"] || "app", "_", "-") <> ":local"
end
