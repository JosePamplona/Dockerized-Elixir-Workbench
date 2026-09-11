defmodule ConsoleWeb.JobsScreen do
  @moduledoc """
  The Jobs screen — the wb.sh line, the list — and the tray that
  follows a job to the screens that start them. The lines of output
  are not rendered here: they reach the `JobLines` hook straight from
  `Console.Jobs`, in batches, already through `Console.ANSI` — so a
  job of two thousand lines never makes the page render two thousand
  lines two thousand times.

  The tray follows a job to the screens that start them, and since
  2026-09-10 it is read there too: its bar is a fold, and the last
  job's output unfurls upward from it with the bar pinned to the
  window's foot — the screen above gives the height and scrolls, so
  the table you are about to act on is still under your eyes when the
  answer comes back. It is the same `job_out/1` the Jobs screen and a
  cartridge's box draw, with the tray's own fold: the tray reads
  whichever job is last, and the Jobs screen keeps its own list folded
  as its reader left it.

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
          <.job_row
            :for={j <- @jobs}
            j={j}
            open={MapSet.member?(@open, j.id)}
            now={@now}
            asking={@asking}
            stoppable={@stoppable}
          />
        </div>
      </div>
    </div>
    """
  end

  @doc """
  One job as a row: the fold control — chip, command line, duration —
  and under it the output with the job's own words about itself. The
  Jobs screen lists every job this way; a cartridge's box lists its own
  inserts and ejects the same way, so a job reads the same wherever it
  is met. `prefix` keeps the output pane's id apart when two screens
  show one job at once.
  """
  attr :j, :map, required: true
  attr :open, :boolean, required: true
  attr :now, :any, required: true
  attr :asking, :any, default: nil, doc: "the id whose stop is being confirmed"
  attr :stoppable, :boolean, default: false
  attr :prefix, :string, default: "jl-"

  def job_row(assigns) do
    ~H"""
    <div class={["job", @open && "open"]} data-tall={@j.id}>
      <button
        class="fold jt"
        type="button"
        aria-expanded={to_string(@open)}
        phx-click="fold"
        phx-value-id={@j.id}
      >
        <span class="n" title="the job's number: this console's jobs from 1, in the order asked">#{@j.n}</span>
        <.chip class={job_class(@j)}>{job_word(@j)}</.chip>
        <span class="cmdline">{@j.cmdline}</span>
        <span class="dur">{duration(@j, @now)}</span>
      </button>
      <.job_out j={@j} asking={@asking} stoppable={@stoppable} prefix={@prefix} />
      <div
        :if={@open}
        class="ograb"
        role="separator"
        aria-orientation="horizontal"
        tabindex="0"
        aria-label="How tall this output is — drag, or arrow keys; double-click for the default"
      >
      </div>
    </div>
    """
  end

  @doc """
  A job's output, and its own words about itself under the last line —
  what it can still be asked, and why it stopped. Wherever a job is
  read it is read this way: the Jobs screen under its row, a
  cartridge's box under its insert, the tray under its bar.
  """
  attr :j, :map, required: true
  attr :asking, :any, default: nil, doc: "the id whose stop is being confirmed"
  attr :stoppable, :boolean, default: false
  attr :prefix, :string, default: "jl-"

  def job_out(assigns) do
    ~H"""
    <div class="out">
      <div class="dim">$ {@j.cmdline}</div>
      <.job_lines id={@prefix <> @j.id} job={@j.id} />
      <div :if={@j.state == :pending} class="dim">
        waiting for your word: confirm it where it was asked, or here —
        <button class="lk" phx-click="confirm" phx-value-id={@j.id}>run it</button>
        · <button class="lk" phx-click="cancel" phx-value-id={@j.id}>drop it</button>
      </div>
      <div :if={@j.state == :queued} class="dim">
        waiting its turn behind what is running — <button
          class="lk"
          phx-click="cancel"
          phx-value-id={@j.id}
        >drop it</button>, nothing of it has happened yet
      </div>
      <div :if={@j.state == :running and @stoppable and @asking != @j.id} class="dim">
        <button class="lk" phx-click="stop_ask" phx-value-id={@j.id}>stop it</button>
      </div>
      <div :if={@j.state == :running and @asking == @j.id} class="dim">
        stop it where it is? what it has already done stays done, and a verb left half-way leaves no commit to revert —
        <button class="lk" phx-click="stop" phx-value-id={@j.id}>stop it</button>
        · <button class="lk" phx-click="stop_keep">let it finish</button>
      </div>
      <div :if={@j.state == :stopped} class="dim">
        stopped on your word — <button class="lk" phx-click="retry" phx-value-id={@j.id}>run it again</button>, the same line, as a new job
      </div>
      <div :if={@j.state == :failed} class="dim">
        it stopped here — <button class="lk" phx-click="retry" phx-value-id={@j.id}>run it again</button>, the same line, as a new job
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
  The tray is on every screen but Jobs, which is the tray in full, once
  anything has run — until the reader puts it away with its own button,
  and the next job brings it back. It kept to the screens that start
  jobs until 2026-09-11, and a job's answer went unseen on the others.
  """
  def tray_shown?(tab, jobs, hidden \\ false),
    do: tab != "jobs" and jobs != [] and not hidden

  attr :jobs, :list, required: true
  attr :tab, :string, required: true
  attr :open, :boolean, default: false, doc: "the last job's output, read under the bar"
  attr :hidden, :boolean, default: false, doc: "put away by the reader, until the next job"
  attr :asking, :any, default: nil, doc: "the id whose stop is being confirmed"
  attr :stoppable, :boolean, default: false

  def tray(assigns) do
    last = List.first(assigns.jobs)

    assigns =
      assign(assigns,
        last: last,
        shown: tray_shown?(assigns.tab, assigns.jobs, assigns.hidden)
      )

    ~H"""
    <div class={["tray", @open && @last && "open"]} id="tray" hidden={!@shown}>
      <%!-- The bar is the fold, edge to edge as a job's row is, and the
            one control beside it keeps the right margin every row closes
            at. The output grows upward from here: the tray is `flex:none`
            under a screen that is `flex:1`, so the screen gives the
            height and scrolls — nothing is covered. --%>
      <button
        class="bar"
        type="button"
        aria-expanded={to_string(@open && !is_nil(@last))}
        aria-controls="tray-out"
        title={
          if @last,
            do: "read what it said, here",
            else: "nothing has run yet"
        }
        phx-click={@last && "tray_fold"}
      >
        <%!-- The last job's own chip, as its row on the Jobs screen wears
              it: `exit 0`, `exit 2`, `running`. It counted the list (`3
              done`) until 2026-09-11, a different reading of the same job. --%>
        <span :if={@last} class="n" title="the job's number, to find it on the Jobs screen">#{@last.n}</span>
        <.chip :if={@last} class={job_class(@last)}>{job_word(@last)}</.chip>
        <.chip :if={!@last} class="off">idle</.chip>
        <span class="last">{if @last,
          do: @last.cmdline,
          else:
            "Every command the console runs is a job: its output, its exit code, how long it took."}</span>
      </button>
      <%!-- Put away, not folded: the bar goes until the next job starts.
            It was a link to Jobs until 2026-09-11, which the tab bar
            already is. --%>
      <button
        class="hide"
        type="button"
        phx-click="tray_hide"
        title="put the bar away — the next job brings it back; every job is on the Jobs tab"
      >
        ×<span class="sr">Put the jobs bar away</span>
      </button>
      <%!-- The grip is at the TOP here, and not under the output as it
            is everywhere else: the bar is pinned to the window's foot,
            so the edge that moves is the other one. `data-grip="up"`
            turns the drag over for it. --%>
      <div
        :if={@open && @last}
        class="job open"
        id="tray-out"
        data-tall="tray"
        data-grip="up"
        phx-hook="JobOut"
      >
        <div
          class="ograb"
          role="separator"
          aria-orientation="horizontal"
          tabindex="0"
          aria-label="How tall this output is — drag, or arrow keys; double-click for the default"
        >
        </div>
        <.job_out j={@last} asking={@asking} stoppable={@stoppable} prefix="tr-" />
      </div>
    </div>
    """
  end
end
