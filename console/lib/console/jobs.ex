defmodule Console.Jobs do
  @moduledoc """
  Every command the console runs is a job: `wb.sh` under `--yes`, its
  output line by line, its exit code, how long it took. Jobs run one at
  a time, in the order they were asked — the workbench's commands are
  not meant to overlap on one workspace — and every change is broadcast
  on the `"jobs"` PubSub topic as `{:job, job}`.
  """
  use GenServer

  alias Console.Workbench

  @topic "jobs"
  @max_lines 2000

  defstruct [:id, :args, :cmdline, :state, :exit, :started_at, :finished_at, lines: []]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Queues `wb.sh --yes ARGS`; returns the job's id."
  def run(args) when is_list(args), do: GenServer.call(__MODULE__, {:run, args})

  @doc "Every job, newest first."
  def list, do: GenServer.call(__MODULE__, :list)

  def subscribe, do: Phoenix.PubSub.subscribe(Console.PubSub, @topic)

  @impl true
  def init(_), do: {:ok, %{jobs: [], queue: :queue.new(), running: nil, port: nil}}

  @impl true
  def handle_call({:run, args}, _from, state) do
    job = %__MODULE__{
      id: System.unique_integer([:positive, :monotonic]) |> Integer.to_string(36),
      args: args,
      cmdline: Enum.join(["./wb.sh", "--yes" | args], " "),
      state: :queued
    }

    state = %{state | jobs: [job | state.jobs], queue: :queue.in(job.id, state.queue)}
    broadcast(job)
    {:reply, job.id, maybe_start(state)}
  end

  def handle_call(:list, _from, state), do: {:reply, state.jobs, state}

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    {:noreply, update_running(state, &%{&1 | lines: Enum.take([Workbench.strip(line) | &1.lines], @max_lines)})}
  end

  def handle_info({port, {:data, {:noeol, line}}}, %{port: port} = state) do
    {:noreply, update_running(state, &%{&1 | lines: Enum.take([Workbench.strip(line) | &1.lines], @max_lines)})}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    state =
      update_running(state, &%{&1 | state: if(code == 0, do: :done, else: :failed), exit: code, finished_at: DateTime.utc_now()})

    {:noreply, maybe_start(%{state | running: nil, port: nil})}
  end

  def handle_info(_, state), do: {:noreply, state}

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
        update_running(state, &%{&1 | state: :running, started_at: DateTime.utc_now()})

      {:empty, _} ->
        state
    end
  end

  defp maybe_start(state), do: state

  defp update_running(%{running: id} = state, fun) do
    jobs =
      Enum.map(state.jobs, fn
        %{id: ^id} = job -> job |> fun.() |> tap(&broadcast/1)
        job -> job
      end)

    %{state | jobs: jobs}
  end

  defp broadcast(job), do: Phoenix.PubSub.broadcast(Console.PubSub, @topic, {:job, job})
end
