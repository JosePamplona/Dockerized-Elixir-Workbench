defmodule ConsoleWeb.JobsScreen do
  @moduledoc """
  The Jobs screen — the wb.sh line, the list — and the tray that
  follows a job to the screens that start them. Every line of output
  comes through `Console.ANSI`, escaped, its colours kept as spans.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs

  attr :jobs, :list, required: true
  attr :open, :any, required: true, doc: "the ids unfolded"
  attr :now, :any, required: true
  attr :words, :string, required: true, doc: "what Tab completes, as JSON"

  def jobs_screen(assigns) do
    running = Enum.count(assigns.jobs, &(&1.state == :running))
    failed = Enum.count(assigns.jobs, &(&1.state == :failed))
    unfolded = Enum.count(assigns.jobs, &MapSet.member?(assigns.open, &1.id))
    assigns = assign(assigns, running: running, failed: failed, unfolded: unfolded)

    ~H"""
    <div class="logs jobsp">
      <form class="toolbar cli" phx-submit="cli">
        <span class="p">$ ./wb.sh</span>
        <input type="text" name="line" id="wb-cli" phx-hook="Cli" data-words={@words} autocomplete="off" placeholder="new, add, up, status, help… · ↑↓ history · Tab completes commands, cartridges and options from the catalog" aria-label="wb.sh command" spellcheck="false" />
        <span class="sep"></span>
        <button class="btn" type="button" phx-click="jobs_clear">Clear done</button>
      </form>
      <div :if={@jobs != []} class="logmeta">
        <span>{length(@jobs)} job{if length(@jobs) == 1, do: "", else: "s"} · {if @running > 0, do: "#{@running} running", else: "idle"}{if @failed > 0, do: " · #{@failed} failed"}</span>
        <span :if={@unfolded > 0}><button class="lk" phx-click="fold_all">{if @unfolded == 1, do: "collapse it", else: "collapse all"}</button></span>
        <span :if={@unfolded == 0}>click a job to unfold its output</span>
      </div>
      <div class="viewport light">
        <div class="lines" id="jobs">
          <div :for={j <- @jobs} class={["job", MapSet.member?(@open, j.id) && "open"]} phx-click="fold" phx-value-id={j.id}>
            <.chip class={job_class(j)}>{job_word(j)}</.chip>
            <span class="cmdline">{j.cmdline}</span>
            <span class="dur">{duration(j, @now)}</span>
            <span class="caret">{if MapSet.member?(@open, j.id), do: "▾", else: "▸"}</span>
            <div class="out">
              <div :if={j.state == :pending} class="dim">waiting for your word: confirm it where it was asked, or here — <button class="lk" phx-click="confirm" phx-value-id={j.id}>run it</button> · <button class="lk" phx-click="cancel" phx-value-id={j.id}>drop it</button></div>
              <div class="dim">$ {j.cmdline}</div>
              <div :for={line <- Enum.reverse(j.lines)}>{Phoenix.HTML.raw(Console.ANSI.to_html(line))}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def job_class(%{state: :done}), do: "good"
  def job_class(%{state: :failed}), do: "bad"
  def job_class(%{state: :running}), do: "warn busy"
  def job_class(%{state: :pending}), do: "warn"
  def job_class(_), do: "off"

  def job_word(%{state: :done, exit: e}), do: "exit #{e}"
  def job_word(%{state: :failed, exit: e}), do: "exit #{e}"
  def job_word(%{state: s}), do: to_string(s)

  defp duration(%{started_at: nil}, _now), do: ""

  defp duration(j, now) do
    ms = DateTime.diff(j.finished_at || now, j.started_at, :millisecond)
    :erlang.float_to_binary(ms / 1000, decimals: 1) <> "s"
  end

  @doc """
  The screens that start jobs are where the tray is the answer coming
  back; everywhere else it stays away, unless a job is still running.
  """
  def tray_shown?(tab, jobs) do
    running = Enum.any?(jobs, &(&1.state in [:running, :pending]))
    tab != "jobs" and jobs != [] and (running or tab in ~w(deploy shelf cluster))
  end

  attr :jobs, :list, required: true
  attr :tab, :string, required: true

  def tray(assigns) do
    running = Enum.count(assigns.jobs, &(&1.state == :running))
    last = List.first(assigns.jobs)
    assigns = assign(assigns, running: running, last: last, shown: tray_shown?(assigns.tab, assigns.jobs))

    ~H"""
    <div class="tray" id="tray" hidden={!@shown}>
      <.link class="bar" patch="/jobs">
        <h4>Jobs</h4>
        <.chip class={cond do @running > 0 -> "warn busy"; @last && @last.state == :failed -> "bad"; @last && @last.state == :pending -> "warn"; @last -> "good"; true -> "off" end}>{cond do @running > 0 -> "#{@running} running"; @last && @last.state == :pending -> "waiting for your word"; @last -> "#{length(@jobs)} done"; true -> "idle" end}</.chip>
        <span class="last">{if @last, do: @last.cmdline, else: "Every command the console runs is a job: its output, its exit code, how long it took."}</span>
        <span class="caret">→ jobs</span>
      </.link>
    </div>
    """
  end
end
