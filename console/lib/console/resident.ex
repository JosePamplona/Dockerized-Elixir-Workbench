defmodule Console.Resident do
  @moduledoc """
  The resident: one BEAM with the workspace's project loaded, kept for
  as long as the console runs, answering the two questions only the
  project can — what it carries (`status`), what inserting a box would
  run (`expand`) — in milliseconds instead of a Mix boot each. It is
  `mix workbench.serve`, on a `Port`: one question per line in, one
  `answer> ` line out.

  Where it runs: inside the console's own container, as a process
  beside the console (the image is the toolchain, the same the
  workspace's dev image is an alias of, so they share the workspace's
  `_build`); on a host running the console by hand, in one long-lived
  toolchain container instead, since the project's path dependency on
  the package resolves at `/app/workbench`.

  It is started on the first question, restarted when it dies, and
  dropped when the workspace changes (`new`, `delete`): the next
  question starts a fresh one on the new project.
  """
  use GenServer

  alias Console.Workbench

  @boot_timeout 240_000
  @ask_timeout 120_000

  defstruct port: nil, buffer: "", waiting: :queue.new(), current: nil, ready: false, workspace: nil

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Asks the project: `%{\"ask\" => \"status\"}`, `%{\"ask\" => \"expand\", \"name\" => …, \"argv\" => […]}`."
  def ask(request), do: GenServer.call(__MODULE__, {:ask, request}, @boot_timeout + @ask_timeout)

  @doc "Drops the resident: the next question starts one on the workspace as it is now."
  def reset, do: GenServer.cast(__MODULE__, :reset)

  @impl true
  def init(_), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_call({:ask, request}, from, state) do
    state = ensure_started(state)

    if state.port do
      state = %{state | waiting: :queue.in({request, from}, state.waiting)}
      {:noreply, next(state)}
    else
      {:reply, {:error, "no workspace to ask: config.conf names none, or it holds no project"}, state}
    end
  end

  @impl true
  def handle_cast(:reset, state), do: {:noreply, close(state)}

  @impl true
  def handle_info({port, {:data, {:noeol, chunk}}}, %{port: port} = state), do: {:noreply, %{state | buffer: state.buffer <> chunk}}

  def handle_info({port, {:data, {:eol, chunk}}}, %{port: port} = state) do
    line = state.buffer <> chunk
    state = %{state | buffer: ""}

    cond do
      String.starts_with?(line, "answer> ") ->
        {:noreply, answered(state, String.replace_prefix(line, "answer> ", ""))}

      String.starts_with?(line, "serve> ready") ->
        {:noreply, next(%{state | ready: true})}

      true ->
        # Mix's own lines — compiling what an insert changed — are noise here.
        {:noreply, state}
    end
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    why = "the resident ended (exit #{code})"
    if state.current, do: GenServer.reply(elem(state.current, 1), {:error, why})
    for {_, from} <- :queue.to_list(state.waiting), do: GenServer.reply(from, {:error, why})
    {:noreply, %__MODULE__{}}
  end

  def handle_info(_, state), do: {:noreply, state}

  # One question at a time: the resident answers in order.
  defp next(%{ready: true, current: nil} = state) do
    case :queue.out(state.waiting) do
      {{:value, {request, from}}, waiting} ->
        Port.command(state.port, Jason.encode!(request) <> "\n")
        %{state | waiting: waiting, current: {request, from}}

      {:empty, _} ->
        state
    end
  end

  defp next(state), do: state

  defp answered(%{current: {_request, from}} = state, json) do
    reply =
      case Jason.decode(json) do
        {:ok, %{"answer" => answer}} -> {:ok, answer}
        {:ok, %{"error" => why}} -> {:error, why}
        _ -> {:error, "not an answer: " <> String.slice(json, 0, 200)}
      end

    GenServer.reply(from, reply)
    next(%{state | current: nil})
  end

  defp answered(state, _json), do: state

  defp ensure_started(%{port: nil} = state) do
    ws = Workbench.workspace()

    if ws && File.regular?(Path.join(ws, "mix.exs")) do
      {exe, args, opts} = command(ws)
      port = Port.open({:spawn_executable, exe}, [:binary, :exit_status, :stderr_to_stdout, {:line, 65536}, args: args] ++ opts)
      %{state | port: port, workspace: ws, ready: false}
    else
      state
    end
  end

  defp ensure_started(state), do: state

  # Inside the console's container the workbench is at its host path and
  # WORKBENCH_PATH says so to the project's mix.exs; on a host, a toolchain
  # container with the two mounts the project expects.
  defp command(ws) do
    dir = Workbench.dir()
    # deps.get and deps.compile first: the package's own dependencies
    # are only fetched, and compiled, with the workbench mounted, which
    # the app service never has. Incremental: a second once done.
    mix = ["do", "deps.get,", "deps.compile,", "workbench.serve"]

    if System.get_env("WORKBENCH_DIR") do
      # The project compiles into the workspace's own volumes, mounted
      # beside the console's (WORKSPACE_BUILD, WORKSPACE_DEPS): what the
      # app service compiled is what the resident finds.
      env =
        [{~c"WORKBENCH_PATH", String.to_charlist(dir)}, {~c"MIX_ENV", ~c"dev"}] ++
          for {var, key} <- [{"WORKSPACE_BUILD", ~c"MIX_BUILD_ROOT"}, {"WORKSPACE_DEPS", ~c"MIX_DEPS_PATH"}],
              value = System.get_env(var),
              do: {key, String.to_charlist(value)}

      {System.find_executable("mix"), mix, [cd: ws, env: env]}
    else
      image = Workbench.local_image()

      {System.find_executable("docker"),
       ["run", "-i", "--rm", "--name", "#{image |> String.replace(":", "_")}_workbench_serve_#{:os.getpid()}",
        "-v", "#{ws}:/app/src", "-v", "#{dir}:/app/workbench:ro", "-w", "/app/src", image, "mix" | mix], []}
    end
  end

  defp close(%{port: nil} = state), do: state

  defp close(state) do
    try do
      Port.close(state.port)
    rescue
      _ -> :ok
    end

    for {_, from} <- :queue.to_list(state.waiting), do: GenServer.reply(from, {:error, "the resident was dropped"})
    if state.current, do: GenServer.reply(elem(state.current, 1), {:error, "the resident was dropped"})
    %__MODULE__{}
  end
end
