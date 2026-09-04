defmodule ConsoleWeb.JobsScreen do
  @moduledoc """
  The Jobs screen — the wb.sh line, the list — and the tray that
  follows a job to the screens that start them. The lines of output
  are not rendered here: they reach the `JobLines` hook straight from
  `Console.Jobs`, in batches, already through `Console.ANSI` — so a
  job of two thousand lines never makes the page render two thousand
  lines two thousand times.

  What a job can still be asked — run again, drop it, stop it — is said
  at the FOOT of its own output, under the last line. That is where the
  reason it failed is, and where the reading ends; and a job that is
  running is read at the foot too, because the output follows itself
  down as it arrives. Not in the row: the row is one fold control edge
  to edge, and a second button beside it would take the caret off the
  right margin every other line closes at. A job's own words about
  itself live inside it.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs

  attr :jobs, :list, required: true
  attr :open, :any, required: true, doc: "the ids unfolded"
  attr :now, :any, required: true
  attr :words, :string, required: true, doc: "what Tab completes, as JSON"
  attr :asking, :any, default: nil, doc: "the id whose stop is being confirmed"
  attr :stoppable, :boolean, default: false, doc: "whether this machine can signal a run at all"

  def jobs_screen(assigns) do
    running = Enum.count(assigns.jobs, &(&1.state == :running))
    failed = Enum.count(assigns.jobs, &(&1.state == :failed))
    unfolded = Enum.count(assigns.jobs, &MapSet.member?(assigns.open, &1.id))
    assigns = assign(assigns, running: running, failed: failed, unfolded: unfolded)

    ~H"""
    <div class="logs jobsp">
      <form class="toolbar cli" phx-submit="cli">
        <span class="p">$ ./wb.sh</span>
        <input
          type="text"
          name="line"
          id="wb-cli"
          phx-hook="Cli"
          data-words={@words}
          autocomplete="off"
          placeholder="↑↓ history · Tab completes commands, cartridges and options from the catalog"
          aria-label="wb.sh command"
          spellcheck="false"
        />
        <span class="sep"></span>
        <button class="btn" type="button" phx-click="jobs_clear">Clear done</button>
      </form>
      <div :if={@jobs != []} class="logmeta">
        <span>{length(@jobs)} job{if length(@jobs) == 1, do: "", else: "s"} · {if @running > 0,
          do: "#{@running} running",
          else: "idle"}{if @failed > 0, do: " · #{@failed} failed"}</span>
        <span :if={@unfolded > 0}><button class="lk" phx-click="fold_all">{if @unfolded == 1,
          do: "collapse it",
          else: "collapse all"}</button></span>
        <span :if={@unfolded == 0}>click a job to unfold its output</span>
      </div>
      <div class="viewport light">
        <div class="lines" id="jobs" phx-hook="JobOut">
          <div :for={j <- @jobs} class={["job", MapSet.member?(@open, j.id) && "open"]} data-id={j.id}>
            <button
              class="fold jt"
              type="button"
              aria-expanded={to_string(MapSet.member?(@open, j.id))}
              phx-click="fold"
              phx-value-id={j.id}
            >
              <.chip class={job_class(j)}>{job_word(j)}</.chip>
              <span class="cmdline">{j.cmdline}</span>
              <span class="dur">{duration(j, @now)}</span>
            </button>
            <div class="out">
              <div class="dim">$ {j.cmdline}</div>
              <.job_lines id={"jl-" <> j.id} job={j.id} />
              <div :if={j.state == :pending} class="dim">
                waiting for your word: confirm it where it was asked, or here —
                <button class="lk" phx-click="confirm" phx-value-id={j.id}>run it</button>
                · <button class="lk" phx-click="cancel" phx-value-id={j.id}>drop it</button>
              </div>
              <div :if={j.state == :queued} class="dim">
                waiting its turn behind what is running — <button
                  class="lk"
                  phx-click="cancel"
                  phx-value-id={j.id}
                >drop it</button>, nothing of it has happened yet
              </div>
              <div :if={j.state == :running and @stoppable and @asking != j.id} class="dim">
                <button class="lk" phx-click="stop_ask" phx-value-id={j.id}>stop it</button>
              </div>
              <div :if={j.state == :running and @asking == j.id} class="dim">
                stop it where it is? what it has already done stays done, and a verb left half-way leaves no commit to revert —
                <button class="lk" phx-click="stop" phx-value-id={j.id}>stop it</button>
                · <button class="lk" phx-click="stop_keep">let it finish</button>
              </div>
              <div :if={j.state == :stopped} class="dim">
                stopped on your word — <button class="lk" phx-click="retry" phx-value-id={j.id}>run it again</button>, the same line, as a new job
              </div>
              <div :if={j.state == :failed} class="dim">
                it stopped here — <button class="lk" phx-click="retry" phx-value-id={j.id}>run it again</button>, the same line, as a new job
              </div>
            </div>
            <div
              :if={MapSet.member?(@open, j.id)}
              class="ograb"
              role="separator"
              aria-orientation="horizontal"
              tabindex="0"
              aria-label="How tall this output is — drag, or arrow keys; double-click for the default"
            >
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Where a job's lines land: the hook fills it — the backlog when it
  mounts, each batch as it comes — and the server's patches leave it
  alone. One per screen that shows the job; the ids tell them apart.
  """
  attr :id, :string, required: true
  attr :job, :string, required: true, doc: "the job's id"
  attr :class, :string, default: nil
  attr :rest, :global

  def job_lines(assigns) do
    ~H"""
    <div id={@id} class={@class} phx-hook="JobLines" phx-update="ignore" data-job={@job} {@rest}>
    </div>
    """
  end

  def job_class(%{state: :done}), do: "good"
  def job_class(%{state: :failed}), do: "bad"
  def job_class(%{state: :stopped}), do: "warn"
  def job_class(%{state: :running}), do: "warn busy"
  def job_class(%{state: :pending}), do: "warn"
  def job_class(_), do: "off"

  def job_word(%{state: :done, exit: e}), do: "exit #{e}"
  def job_word(%{state: :failed, exit: e}), do: "exit #{e}"
  def job_word(%{state: :stopped}), do: "stopped"
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

    assigns =
      assign(assigns, running: running, last: last, shown: tray_shown?(assigns.tab, assigns.jobs))

    ~H"""
    <div class="tray" id="tray" hidden={!@shown}>
      <.link class="bar" patch="/jobs">
        <h4>Jobs</h4>
        <.chip class={
          cond do
            @running > 0 -> "warn busy"
            @last && @last.state == :failed -> "bad"
            @last && @last.state == :pending -> "warn"
            @last -> "good"
            true -> "off"
          end
        }>
          {cond do
            @running > 0 -> "#{@running} running"
            @last && @last.state == :pending -> "waiting for your word"
            @last -> "#{length(@jobs)} done"
            true -> "idle"
          end}
        </.chip>
        <span class="last">{if @last,
          do: @last.cmdline,
          else:
            "Every command the console runs is a job: its output, its exit code, how long it took."}</span>
        <span class="caret">→ jobs</span>
      </.link>
    </div>
    """
  end
end
