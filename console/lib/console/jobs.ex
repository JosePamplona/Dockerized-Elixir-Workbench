defmodule Console.Jobs do
  @moduledoc """
  Every command the console runs is a job: `wb.sh` under `--yes`, its
  output line by line, its exit code, how long it took. Jobs run one at
  a time, in the order they were asked — the workbench's commands are
  not meant to overlap on one workspace — and every change is broadcast
  on the `"jobs"` PubSub topic as `{:job, job}`.

  A job carries its *kind* (`Console.Verbs.kind/0`): what it is about,
  so the page can route its output back to where it was asked and know
  what to read again when it ends. A job asked with `confirm: true`
  waits as `:pending` until `confirm/1` — or `cancel/1` — and never
  runs on its own: `wb.sh` under `--yes` asks nothing, so the two verbs
  that cannot be taken back are gated here, on the server.
  """
  use GenServer

  alias Console.Workbench

  @topic "jobs"
  @max_lines 2000

  defstruct [:id, :kind, :args, :cmdline, :state, :exit, :started_at, :finished_at, lines: []]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Queues `wb.sh --yes ARGS` as a job of KIND; returns the job's id.
  With `confirm: true` the job is `:pending` until confirmed.
  """
  def run(kind, args, opts \\ []) when is_list(args), do: GenServer.call(__MODULE__, {:run, kind, args, opts})

  @doc "Lets a pending job run."
  def confirm(id), do: GenServer.call(__MODULE__, {:confirm, id})

  @doc "Drops a pending job."
  def cancel(id), do: GenServer.call(__MODULE__, {:cancel, id})

  @doc "Every job, newest first."
  def list, do: GenServer.call(__MODULE__, :list)

  @doc "Whether a job is running or waiting to."
  def busy?, do: GenServer.call(__MODULE__, :busy?)

  def subscribe, do: Phoenix.PubSub.subscribe(Console.PubSub, @topic)

  @impl true
  def init(_), do: {:ok, %{jobs: [], queue: :queue.new(), running: nil, port: nil}}

  @impl true
  def handle_call({:run, kind, args, opts}, _from, state) do
    job = %__MODULE__{
      id: System.unique_integer([:positive, :monotonic]) |> Integer.to_string(36),
      kind: kind,
      args: args,
      cmdline: Enum.join(["./wb.sh", "--yes" | args], " "),
      state: if(opts[:confirm], do: :pending, else: :queued)
    }

    state = %{state | jobs: [job | state.jobs]}
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

  def handle_call({:cancel, id}, _from, state) do
    case Enum.find(state.jobs, &(&1.id == id and &1.state == :pending)) do
      nil -> {:reply, :error, state}
      _ -> {:reply, :ok, update(state, id, &%{&1 | state: :cancelled, finished_at: DateTime.utc_now()})}
    end
  end

  def handle_call(:list, _from, state), do: {:reply, state.jobs, state}

  def handle_call(:busy?, _from, state),
    do: {:reply, state.running != nil or not :queue.is_empty(state.queue), state}

  @impl true
  # The lines are kept as they come, escapes included: the workbench
  # colours its output on purpose, and the page turns them into spans
  # (Console.ANSI). Newest first; the page reverses them.
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    {:noreply, update(state, state.running, &%{&1 | lines: Enum.take([line | &1.lines], @max_lines)})}
  end

  def handle_info({port, {:data, {:noeol, line}}}, %{port: port} = state) do
    {:noreply, update(state, state.running, &%{&1 | lines: Enum.take([line | &1.lines], @max_lines)})}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    state =
      update(state, state.running, &%{&1 | state: if(code == 0, do: :done, else: :failed), exit: code, finished_at: DateTime.utc_now()})

    {:noreply, maybe_start(%{state | running: nil, port: nil})}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp enqueue(state, id), do: maybe_start(%{state | queue: :queue.in(id, state.queue)})

  defp maybe_start(%{running: nil} = state) do
    case :queue.out(state.queue) do
      {{:value, id}, queue} ->
        job = Enum.find(state.jobs, &(&1.id == id))

        port =
          Port.open({:spawn_executable, Path.join(Workbench.dir(), "wb.sh")}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            {:line, 4096},
            args: ["--yes" | job.args],
            cd: Workbench.dir(),
            env: [{~c"TERM", ~c"dumb"}]
          ])

        state = %{state | queue: queue, running: id, port: port}
        update(state, id, &%{&1 | state: :running, started_at: DateTime.utc_now()})

      {:empty, _} ->
        state
    end
  end

  defp maybe_start(state), do: state

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
