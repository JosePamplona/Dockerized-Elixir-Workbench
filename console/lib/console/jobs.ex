defmodule Console.Jobs do
  @moduledoc """
  Every command the console runs is a job: `wb.sh` under `--yes`, its
  output line by line, its exit code, how long it took. Jobs run one at
  a time, in the order they were asked — the workbench's commands are
  not meant to overlap on one workspace — and every change of state is
  broadcast on the `"jobs"` PubSub topic as `{:job, job}`.

  A job carries its *kind* (`Console.Verbs.kind/0`): what it is about,
  so the page can route its output back to where it was asked and know
  what to read again when it ends. A job asked with `confirm: true`
  waits as `:pending` until `confirm/1` — or `cancel/1` — and never
  runs on its own: `wb.sh` under `--yes` asks nothing, so the two verbs
  that cannot be taken back are gated here, on the server.

  A job can also be taken back after it was asked. `cancel/1` drops one
  that has not started — waiting for a word, or waiting its turn — and
  costs nothing, because nothing has happened yet. `stop/1` signals the
  one that is running, and that one is not free: `wb.sh` is stopped
  wherever it had got to, and half of a verb is not half a workspace —
  a cartridge whose files are written but whose commit was never made
  has nothing for `eject` to revert. The console asks before it, and
  says so; here the only thing said is that a stopped job ends as
  `:stopped` and not as `:failed`.

  The output never rides on the job. It used to: every line the port
  wrote put the job — all of its lines — on the topic, and every page
  rendered every line of every job again, so a `new` of two thousand
  lines cost the page two million renders and the reader's clicks
  queued behind them. Now the lines are held here, as they come,
  escapes included — the workbench colours its output on purpose —
  and go out as `{:job_lines, id, from, html}`: a batch every
  50 ms at most, already turned into spans (`Console.ANSI`), with
  the index of its first line, so a page that holds the first `from`
  lines appends the rest. A page that opens a job asks `lines/1` for
  what it missed. The state changes still go as `{:job, job}`; the
  last lines of a job go out before its exit does.
  """
  use GenServer

  alias Console.Workbench

  @topic "jobs"
  @max_lines 2000
  @batch_ms 50
  @grace_ms 5_000

  # `id` names the job — the DOM, the topic, the queue; `n` is what the
  # reader counts by: this console's jobs from 1, in the order asked. The
  # id is the BEAM's unique integer, which skips and goes to letters.
  defstruct [:id, :n, :kind, :args, :cmdline, :state, :exit, :started_at, :finished_at]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Queues `wb.sh --yes ARGS` as a job of KIND; returns the job's id.
  With `confirm: true` the job is `:pending` until confirmed.
  """
  def run(kind, args, opts \\ []) when is_list(args),
    do: GenServer.call(__MODULE__, {:run, kind, args, opts})

  @doc "Lets a pending job run."
  def confirm(id), do: GenServer.call(__MODULE__, {:confirm, id})

  @doc "Drops a job that has not started: waiting for a word, or in the queue."
  def cancel(id), do: GenServer.call(__MODULE__, {:cancel, id})

  @doc """
  Signals the job that is running, and everything it started. Returns
  `:error` when it is not the running one, or when this machine has no
  `setsid` and there is no session to signal (see the note above).
  """
  def stop(id), do: GenServer.call(__MODULE__, {:stop, id})

  @doc "Whether a running job can be stopped at all here."
  def stoppable?, do: GenServer.call(__MODULE__, :stoppable?)

  @doc "Every job, newest first."
  def list, do: GenServer.call(__MODULE__, :list)

  @doc """
  A job's output so far as HTML lines, the last #{@max_lines} at most:
  `{from, lines}`, where `from` is the index of the first one kept.
  """
  def lines(id), do: GenServer.call(__MODULE__, {:lines, id})

  @doc "Whether a job is running or waiting to."
  def busy?, do: GenServer.call(__MODULE__, :busy?)

  def subscribe, do: Phoenix.PubSub.subscribe(Console.PubSub, @topic)

  @impl true
  def init(_) do
    {:ok,
     %{
       jobs: [],
       next: 1,
       queue: :queue.new(),
       running: nil,
       port: nil,
       out: %{},
       tail: "",
       pending: [],
       flush: nil,
       stopping: nil,
       hard: nil,
       setsid: System.find_executable("setsid")
     }}
  end

  @impl true
  def handle_call({:run, kind, args, opts}, _from, state) do
    job = %__MODULE__{
      id: System.unique_integer([:positive, :monotonic]) |> Integer.to_string(36),
      n: state.next,
      kind: kind,
      args: args,
      cmdline: Enum.join(["./wb.sh", "--yes" | args], " "),
      state: if(opts[:confirm], do: :pending, else: :queued)
    }

    state = %{state | jobs: [job | state.jobs], next: state.next + 1}
    broadcast(job)

    if job.state == :queued,
      do: {:reply, job.id, enqueue(state, job.id)},
      else: {:reply, job.id, state}
  end

  def handle_call({:confirm, id}, _from, state) do
    case Enum.find(state.jobs, &(&1.id == id and &1.state == :pending)) do
      nil -> {:reply, :error, state}
      _ -> {:reply, :ok, state |> update(id, &%{&1 | state: :queued}) |> enqueue(id)}
    end
  end

  # A queued job is dropped where it stands and left in the queue:
  # `maybe_start` skips whatever is no longer `:queued` when it gets
  # there. Rebuilding the queue to take one id out of the middle would
  # be the same answer with more moving parts.
  def handle_call({:cancel, id}, _from, state) do
    case Enum.find(state.jobs, &(&1.id == id and &1.state in [:pending, :queued])) do
      nil ->
        {:reply, :error, state}

      _ ->
        {:reply, :ok,
         update(state, id, &%{&1 | state: :cancelled, finished_at: DateTime.utc_now()})}
    end
  end

  def handle_call({:stop, id}, _from, %{running: id} = state) when not is_nil(id) do
    case signal(state, "TERM") do
      :ok ->
        {:reply, :ok,
         %{state | stopping: id, hard: Process.send_after(self(), {:hard, id}, @grace_ms)}}

      :error ->
        {:reply, :error, state}
    end
  end

  def handle_call({:stop, _id}, _from, state), do: {:reply, :error, state}

  def handle_call(:stoppable?, _from, state), do: {:reply, state.setsid != nil, state}

  def handle_call(:list, _from, state), do: {:reply, state.jobs, state}

  def handle_call({:lines, id}, _from, state) do
    {total, kept} = state.out[id] || {0, []}

    {:reply, {total - length(kept), kept |> Enum.reverse() |> Enum.map(&Console.ANSI.to_html/1)},
     state}
  end

  def handle_call(:busy?, _from, state),
    do: {:reply, state.running != nil or not :queue.is_empty(state.queue), state}

  # The port cuts a line at 4096 bytes, in the middle of a character as
  # easily as not, and mix's spinner writes one line of frames with \r
  # and no newline for as long as it compiles. The pieces are joined
  # until the newline; of a line of frames, what a terminal shows — the
  # last — is kept; and a byte no character claims is dropped rather
  # than handed to the socket, which refused the whole page for one
  # (ash, 2026-09-11: `invalid byte 0xE2`, the third of a braille dot).
  @impl true
  def handle_info({port, {:data, {eol, chunk}}}, %{port: port} = state) do
    tail = last_frame(state.tail <> chunk)

    case eol do
      :eol -> {:noreply, take(%{state | tail: ""}, scrub(tail))}
      :noeol -> {:noreply, %{state | tail: tail}}
    end
  end

  def handle_info(:flush, state), do: {:noreply, flush(%{state | flush: nil})}

  # The grace is over and it is still there: no more asking.
  def handle_info({:hard, id}, %{running: id, stopping: id} = state) do
    signal(state, "KILL")
    {:noreply, %{state | hard: nil}}
  end

  def handle_info({:hard, _}, state), do: {:noreply, state}

  # What was stopped ends as `:stopped`, never as `:failed`: the number
  # a signal leaves behind is not the command's word on what it did.
  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    ended =
      cond do
        state.stopping == state.running -> :stopped
        code == 0 -> :done
        true -> :failed
      end

    # A last line with no newline after it is a line still.
    state = if state.tail == "", do: state, else: take(%{state | tail: ""}, scrub(state.tail))

    state =
      state
      |> flush()
      |> update(state.running, &%{&1 | state: ended, exit: code, finished_at: DateTime.utc_now()})

    if state.hard, do: Process.cancel_timer(state.hard)
    {:noreply, maybe_start(%{state | running: nil, port: nil, stopping: nil, hard: nil})}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Of a line drawn over itself with \r, the frame that is left on the
  # screen; a CRLF is a newline.
  defp last_frame(line),
    do: line |> String.trim_trailing("\r") |> String.split("\r") |> List.last()

  # The line with every byte that is not UTF-8 taken out.
  defp scrub(line) do
    if String.valid?(line),
      do: line,
      else: line |> String.chunk(:valid) |> Enum.filter(&String.valid?/1) |> Enum.join()
  end

  # A line is kept, newest first, and waits for the batch; the first
  # line of a batch sets its clock.
  defp take(state, line) do
    {total, kept} = state.out[state.running] || {0, []}
    out = Map.put(state.out, state.running, {total + 1, Enum.take([line | kept], @max_lines)})
    flush = state.flush || Process.send_after(self(), :flush, @batch_ms)
    %{state | out: out, pending: [line | state.pending], flush: flush}
  end

  defp flush(%{pending: []} = state), do: cancel_flush(state)

  defp flush(state) do
    {total, _} = state.out[state.running]
    lines = Enum.reverse(state.pending)

    Phoenix.PubSub.broadcast(
      Console.PubSub,
      @topic,
      {:job_lines, state.running, total - length(lines), Enum.map(lines, &Console.ANSI.to_html/1)}
    )

    cancel_flush(%{state | pending: []})
  end

  defp cancel_flush(%{flush: nil} = state), do: state

  defp cancel_flush(state) do
    Process.cancel_timer(state.flush)
    %{state | flush: nil}
  end

  defp enqueue(state, id), do: maybe_start(%{state | queue: :queue.in(id, state.queue)})

  defp maybe_start(%{running: nil} = state) do
    case :queue.out(state.queue) do
      {{:value, id}, queue} ->
        case Enum.find(state.jobs, &(&1.id == id)) do
          # Dropped while it waited: the queue kept the id, nothing else did.
          %{state: s} = job when s == :queued ->
            state = %{state | queue: queue, running: id, port: open(state, job)}
            update(state, id, &%{&1 | state: :running, started_at: DateTime.utc_now()})

          _ ->
            maybe_start(%{state | queue: queue})
        end

      {:empty, _} ->
        state
    end
  end

  defp maybe_start(state), do: state

  # `setsid -w` and not `wb.sh` straight: the run gets a session of its
  # own, and `-w` waits for it, so the job still ends with the command's
  # own exit status. That session is the whole reason a stop can work —
  # see `signal/2`. Where there is no setsid the command runs as it
  # always did and only the stop is missing.
  defp open(state, job) do
    opts = [
      :binary,
      :exit_status,
      :stderr_to_stdout,
      {:line, 4096},
      cd: Workbench.dir(),
      # A pipe is no terminal, and the tools under wb.sh would go plain:
      # WB_ANSI asks them for colour anyway (the page turns it into
      # spans), and TERM names one so nothing decides on its own.
      env: [{~c"WB_ANSI", ~c"always"}, {~c"TERM", ~c"xterm-256color"}]
    ]

    wb = Path.join(Workbench.dir(), "wb.sh")

    case state.setsid do
      nil ->
        Port.open({:spawn_executable, wb}, [{:args, ["--yes" | job.args]} | opts])

      setsid ->
        Port.open({:spawn_executable, setsid}, [{:args, ["-w", wb, "--yes" | job.args]} | opts])
    end
  end

  # The GROUP, not the process. `wb.sh` is not the leaf of anything —
  # docker, mix and git hang under it — and a signal to the shell alone
  # leaves running exactly what was meant to stop. The port holds the
  # `setsid -w` that waits; the leader of the new session is its child,
  # and a session leader's pid is its group's, so `kill -SIG -PID` on
  # that number reaches the whole run.
  #
  # The child is read from /proc and not from `ps`: procps is not in a
  # slim image, /proc always is. And the signal goes through `sh`, whose
  # `kill` is a builtin, for the same reason.
  defp signal(%{setsid: nil}, _sig), do: :error

  defp signal(state, sig) do
    with {:os_pid, pid} <- Port.info(state.port, :os_pid),
         {:ok, raw} <- File.read("/proc/#{pid}/task/#{pid}/children"),
         [leader | _] <- String.split(raw, ~r/\s+/, trim: true) do
      System.cmd("sh", ["-c", "kill -#{sig} -#{leader}"], stderr_to_stdout: true)
      :ok
    else
      _ -> :error
    end
  end

  defp update(state, id, fun) do
    jobs =
      Enum.map(state.jobs, fn
        %{id: ^id} = job -> job |> fun.() |> tap(&broadcast/1)
        job -> job
      end)

    %{state | jobs: jobs}
  end

  defp broadcast(job), do: Phoenix.PubSub.broadcast(Console.PubSub, @topic, {:job, job})
end
