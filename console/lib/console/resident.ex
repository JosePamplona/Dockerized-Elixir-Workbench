defmodule Console.Resident do
  @moduledoc """
  The resident: one BEAM with the workspace's project loaded, kept for
  as long as the console runs, answering the two questions only the
  project can — what it carries (`status`), what inserting a box would
  run (`expand`) — in milliseconds instead of a Mix boot each. It is
  `mix workbench.serve`, on a `Port`: one question per line in, one
  `answer> ` line out.

  Where it runs: inside the console's own container, as a process
  beside the console — the image is the toolchain, the same the
  workspace's dev image is an alias of, and `./wb.sh console` mounts
  the workspace at `/app/src` with the app's volumes over it
  (`WORKSPACE_MOUNT`), so the resident compiles from the app's own
  source path into the app's own `_build` and finds what it compiled.
  That mount was made for the workspace config.conf named when the
  console started; named another since, the mount is not this
  workspace's — the same three checks `wb.sh` makes, `toolchain_here` —
  and the resident runs in one long-lived container on the workspace's
  dev image instead, with its volumes, as it does on a host running the
  console by hand. Slower to start, and right.

  It is started on the first question, restarted when it dies, and
  dropped when the workspace changes — `new`, `delete`, or config.conf
  naming another path: the next question starts a fresh one on the
  project that is there.
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
    state = state |> follow_workspace() |> ensure_started()

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

  # A resident of another workspace — config.conf moved on — is dropped;
  # the one that follows starts on the workspace named now.
  defp follow_workspace(%{port: port, workspace: ws} = state) when port != nil do
    if ws == Workbench.workspace(), do: state, else: close(state)
  end

  defp follow_workspace(state), do: state

  # Here, when this container mounts this very workspace at /app/src;
  # else a container on the workspace's dev image, with the two mounts
  # the project's mix.exs expects and the app's volumes over _build and
  # deps, so nothing compiles through the bind mount there either.
  defp command(ws) do
    dir = Workbench.dir()
    project = Workbench.project(ws)
    # deps.get and deps.compile first: the package's own dependencies
    # are only fetched, and compiled, with the workbench mounted, which
    # the app service never has. Incremental: a second once done.
    mix = ["do", "deps.get,", "deps.compile,", "workbench.serve"]

    if mounted_here?(ws, project) do
      # The workspace as the app service sees it: /app/src, the volumes
      # over its _build and deps (WORKSPACE_MOUNT, set by `./wb.sh
      # console`). Mix keys its manifests on the source path, so from
      # there what the app compiled is what the resident finds, and
      # adds to; from the host path it would compile the project again.
      # The two variables are UNSET for this run — they are the
      # console's own, set in its image so its build lives under
      # /app/console, and inherited they would send the workspace's
      # compilation there.
      env = [
        {~c"WORKBENCH_PATH", String.to_charlist(dir)},
        {~c"MIX_ENV", ~c"dev"},
        {~c"MIX_BUILD_ROOT", false},
        {~c"MIX_DEPS_PATH", false}
      ]

      {System.find_executable("mix"), mix, [cd: System.fetch_env!("WORKSPACE_MOUNT"), env: env]}
    else
      {System.find_executable("docker"),
       ["run", "-i", "--rm", "--name", "#{project.name}_workbench_serve_#{:os.getpid()}",
        "-v", "#{ws}:/app/src", "-v", "#{dir}:/app/workbench:ro",
        "-v", "#{project.name}_build:/app/src/_build", "-v", "#{project.name}_deps:/app/src/deps",
        "-w", "/app/src", project.image, "mix" | mix], []}
    end
  end

  # The three things `./wb.sh console` says about its mount, against the
  # workspace config.conf names now — as `toolchain_here` in wb.sh.
  defp mounted_here?(ws, project) do
    System.get_env("WORKSPACE_MOUNT") != nil and
      System.get_env("WORKSPACE_MOUNT_PATH") == ws and
      System.get_env("WORKSPACE_MOUNT_PROJECT") == project.name
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
