defmodule ConsoleWeb.ConsoleLive do
  @moduledoc """
  The console: the workspace on the left, the screens on the right —
  Deploy, Jobs, Terminal, Logs, Cartridges, Project, Cluster — and the
  jobs tray at the bottom. Everything it shows comes from the status,
  the catalog and `config.conf`; everything it does is `wb.sh` as a
  job. Where the reader is — the screen — lives in the URL.
  """
  use ConsoleWeb, :live_view

  alias Console.{Bench, Jobs, Logs, Verbs, Workbench}
  alias Console.{Diffs, Papers, Project}
  alias ConsoleWeb.{Box, Cartridges, Deploy, Terminal}
  import ConsoleWeb.{Board, Shelf, ProjectScreen, WorkbenchDrawer, Cluster}
  import ConsoleWeb.Terminal, only: [terminal: 1]
  import ConsoleWeb.JobsScreen, only: [jobs_screen: 1, tray: 1]

  # The order is the order of the work: what you deploy, what ran, what it
  # printed, and only then the shell you open when the three are not
  # enough. Logs is read a hundred times for every session opened.
  @tabs [
    {"deploy", "Deploy"},
    {"jobs", "Jobs"},
    {"logs", "Logs"},
    {"terminal", "Terminal"},
    {"shelf", "Cartridges"},
    {"project", "Project"},
    {"cluster", "Cluster"}
  ]
  @tab_names Enum.map(@tabs, &elem(&1, 0))

  # The mark, read from the file it lives in: one source, and
  # @external_resource recompiles this module when that file changes.
  # Inline and never an <img>: it is `fill="currentColor"`, and an SVG
  # loaded as an image is its own document, where that falls to black.
  @mark_path Path.join(__DIR__, "../../../priv/static/images/logo.svg")
  @external_resource @mark_path
  @mark File.read!(@mark_path) |> String.trim()
  defp mark, do: Phoenix.HTML.raw(@mark)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Jobs.subscribe()
      Logs.subscribe()
      Bench.subscribe()
    end

    # What the bench holds is what the page opens with: nothing is read
    # on a mount, and a reading in flight is the one this page waits for.
    status = Bench.status()
    catalog = Bench.catalog() || []
    # Nothing known and nothing on its way — the bench's first reading
    # failed before this page came — asks again.
    if connected?(socket) and is_nil(status) and not Bench.reading?(:status),
      do: Bench.refresh(:status, :full)

    socket =
      socket
      |> assign(
        tab: "deploy",
        status: status,
        catalog: catalog,
        config: Workbench.config(),
        version: Workbench.version(),
        box: nil,
        screen: "box",
        paper: "readme",
        papers: [],
        page: nil,
        args: %{},
        recipe: nil,
        diff: nil,
        face: "front",
        ppaper: "readme",
        ppage: nil,
        wb: nil,
        wbpaper: "readme",
        wbpage: nil,
        cfg_edits: %{},
        cfg_raw: false,
        stacks: Bench.stacks(),
        stacks_asking: Bench.reading?(:stacks),
        stacks_error: Bench.error(:stacks),
        installers: Bench.installers(),
        installers_asking: Bench.reading?(:installers),
        installers_error: Bench.error(:installers),
        probes: %{},
        term: %{target: nil, shell: "bash", open: false, port: nil},
        view: "covers",
        jobs: Jobs.list(),
        open_jobs: MapSet.new(),
        stop_ask: nil,
        stoppable: Jobs.stoppable?(),
        now: DateTime.utc_now(),
        error: Bench.error(:status) || Bench.error(:catalog),
        filter: "all",
        reading: (is_nil(status) or Bench.reading?(:status)) && :full,
        pick: %{target: nil, replicas: 4, balancer: true},
        newp: %{out: MapSet.new(), gen: %{}},
        setup_env: "dev",
        restart_logs: false,
        folded: MapSet.new()
      )

    socket =
      if connected?(socket) and status,
        do: Logs.follow(status["compose_project"]) && socket,
        else: socket

    {:ok, socket, layout: false}
  end

  # The screen is the URL: /deploy, /jobs… An unlit one falls back to
  # Deploy, the console's first screen, which is never unlit — judged
  # once the status is here, since before it every screen that needs a
  # project would read as unlit.
  @impl true
  def handle_params(params, _uri, socket) do
    tab = params["tab"] || "deploy"

    cond do
      tab not in @tab_names ->
        {:noreply, push_patch(socket, to: ~p"/deploy")}

      socket.assigns.status && unlit(tab, socket.assigns) ->
        {:noreply, push_patch(socket, to: ~p"/deploy")}

      true ->
        {:noreply,
         socket |> assign(tab: tab) |> take_box(params) |> take_paper(params) |> take_wb(params)}
    end
  end

  # The project's paper, from the query on /project.
  defp take_paper(%{assigns: %{tab: "project"}} = socket, params) do
    ws = socket.assigns.status && socket.assigns.status["workspace"]
    carried = Project.carried(ws)

    paper =
      if params["paper"] in carried, do: params["paper"], else: List.first(carried) || "readme"

    assign(socket, ppaper: paper, ppage: Project.render(ws, paper))
  end

  defp take_paper(socket, _params), do: socket

  # The workbench's drawer, over whatever screen: ?wb=config|manual|ui,
  # and under Manual which paper — the same shape as a box's
  # ?screen=manual&paper=readme, because it is the same thing.
  # The papers used to be flat tabs of their own. A link that still names
  # one — a bookmark, or the README's own "see the CHANGELOG" — is the
  # paper it asks for, under Manual.
  defp take_wb(socket, %{"wb" => key} = params) when key in ~w(readme changelog),
    do: take_wb(socket, %{params | "wb" => "manual"} |> Map.put("paper", key))

  defp take_wb(socket, %{"wb" => key} = params) when key in ~w(config manual ui) do
    papers = Papers.workbench_papers() |> Enum.map(&elem(&1, 0))
    paper = if params["paper"] in papers, do: params["paper"], else: hd(papers)

    assign(socket,
      wb: key,
      wbpaper: paper,
      wbpage: if(key == "manual", do: Papers.render_workbench(paper))
    )
  end

  defp take_wb(socket, _params), do: assign(socket, wb: nil, wbpage: nil)

  # The box in hand, and which of its screens, from the query: a box
  # named anywhere opens over whatever screen the reader is on, and the
  # browser's back is the trail back. A collection asks the project
  # what its recipe leaves to insert (expand: seconds) when it is picked
  # up, never again per keystroke.
  defp take_box(socket, %{"box" => name} = params) do
    box = Enum.find(socket.assigns.catalog, &(&1["name"] == name))
    same = socket.assigns.box && socket.assigns.box["name"] == name

    cond do
      is_nil(box) and socket.assigns.catalog == [] ->
        assign(socket, pending_box: params)

      is_nil(box) ->
        socket |> assign(box: nil) |> push_patch(to: "/#{socket.assigns.tab}")

      true ->
        screen =
          if params["screen"] in ~w(box install files manual), do: params["screen"], else: "box"

        papers = Papers.carried(name)

        paper =
          if params["paper"] in papers, do: params["paper"], else: List.first(papers) || "readme"

        page = if screen == "manual", do: Papers.render(name, paper)

        socket =
          if same,
            do: socket,
            else: socket |> assign(args: %{}, face: "front", recipe: nil) |> ask_recipe(box, %{})

        socket =
          assign(socket,
            box: box,
            screen: screen,
            papers: papers,
            paper: paper,
            page: page,
            pending_box: nil
          )

        if screen == "files", do: ask_diff(socket, box), else: socket
    end
  end

  defp take_box(socket, _params), do: assign(socket, box: nil, page: nil, pending_box: nil)

  # What the cartridge wrote, read off the workspace's git in the
  # background: a collection reads every pick's commit and the range.
  defp ask_diff(socket, box) do
    status = socket.assigns.status
    ws = status && status["workspace"]

    cond do
      is_nil(ws) or Box.files_unlit(box, status) ->
        assign(socket, diff: nil)

      box["collection"] ->
        inserts = Box.member_inserts(box, status)

        socket
        |> assign(diff: :loading)
        |> start_async({:diff, box["name"]}, fn -> Diffs.collection(ws, inserts) end)

      true ->
        insert = Cartridges.insert(status, box["name"])

        socket
        |> assign(diff: :loading)
        |> start_async({:diff, box["name"]}, fn -> Diffs.cartridge(ws, insert) end)
    end
  end

  defp ask_recipe(socket, %{"collection" => true} = box, args) do
    case Bench.expand(box["name"], Box.argv(box, args)) do
      {:ok, plan} -> assign(socket, recipe: plan)
      :asking -> assign(socket, recipe: :asking)
    end
  end

  defp ask_recipe(socket, _box, _args), do: socket

  defp leave_unlit(socket) do
    if unlit(socket.assigns.tab, socket.assigns),
      do: push_patch(socket, to: ~p"/deploy"),
      else: socket
  end

  # --- what arrives ---------------------------------------------------------

  @impl true
  def handle_info({:bench, :status, status}, socket) do
    # A container still starting will be healthy without any job saying
    # so: ask again in a moment, the fast way.
    if Enum.any?(status["containers"] || [], &(&1["Health"] == "starting")),
      do: Process.send_after(self(), :poll, 3000)

    # The logs follow the compose project, whichever deployment is up;
    # after a job that could have changed the containers the stream is
    # started again, since --follow only attaches to what is there.
    if connected?(socket),
      do: Logs.follow(status["compose_project"], restart: socket.assigns.restart_logs)

    # Another workspace — the config moved it — is another project's
    # papers and another git: what was read off the old one is read again.
    moved? = socket.assigns.status && socket.assigns.status["workspace"] != status["workspace"]

    socket =
      socket
      |> assign(status: status, reading: false, error: nil, restart_logs: false)
      |> leave_unlit()

    socket =
      if socket.assigns.tab == "project" and (is_nil(socket.assigns.ppage) or moved?),
        do: take_paper(socket, %{"paper" => socket.assigns.ppaper}),
        else: socket

    # A Files screen opened before the status was here asks now.
    socket =
      if socket.assigns.screen == "files" && socket.assigns.box &&
           (is_nil(socket.assigns.diff) or moved?),
         do: ask_diff(socket, socket.assigns.box),
         else: socket

    {:noreply, socket}
  end

  # The stacks and the installers, asked for by pressing the button
  # beside their field.
  def handle_info({:bench, :stacks, tags}, socket),
    do: {:noreply, assign(socket, stacks: tags, stacks_asking: false, stacks_error: nil)}

  def handle_info({:bench, :error, :stacks, why}, socket),
    do: {:noreply, assign(socket, stacks_asking: false, stacks_error: why)}

  def handle_info({:bench, :installers, releases}, socket),
    do:
      {:noreply,
       assign(socket, installers: releases, installers_asking: false, installers_error: nil)}

  def handle_info({:bench, :error, :installers, why}, socket),
    do: {:noreply, assign(socket, installers_asking: false, installers_error: why)}

  def handle_info({:bench, :catalog, catalog}, socket) do
    socket = assign(socket, catalog: catalog)
    # A box named in the URL before the catalog was here opens now.
    {:noreply,
     if(socket.assigns[:pending_box],
       do: take_box(socket, socket.assigns.pending_box),
       else: socket
     )}
  end

  # The recipe expand answered, if it is still the box in hand with these options.
  def handle_info({:bench, :expand, name, argv, plan}, socket) do
    box = socket.assigns.box

    if box && box["name"] == name && Box.argv(box, socket.assigns.args) == argv,
      do: {:noreply, assign(socket, recipe: plan)},
      else: {:noreply, socket}
  end

  def handle_info({:bench, :error, {:expand, _, _}, _why}, socket),
    do: {:noreply, assign(socket, recipe: nil)}

  def handle_info({:bench, :error, _key, why}, socket),
    do: {:noreply, assign(socket, error: why, reading: false)}

  @impl true
  def handle_info({:job, job}, socket) do
    jobs =
      if Enum.any?(socket.assigns.jobs, &(&1.id == job.id)),
        do: Enum.map(socket.assigns.jobs, &if(&1.id == job.id, do: job, else: &1)),
        else: [job | socket.assigns.jobs]

    # A job you just asked for is a job you are watching: it comes unfolded.
    open =
      if job.state in [:queued, :pending] and not MapSet.member?(socket.assigns.open_jobs, job.id),
        do: MapSet.put(socket.assigns.open_jobs, job.id),
        else: socket.assigns.open_jobs

    # The question goes away with what it was about.
    asking =
      if socket.assigns.stop_ask == job.id and job.state != :running,
        do: nil,
        else: socket.assigns.stop_ask

    socket =
      assign(socket, jobs: jobs, open_jobs: open, stop_ask: asking, now: DateTime.utc_now())

    if job.state == :running, do: Process.send_after(self(), :tick, 1000)
    # The workspace changed when a job ended: read again what the verb
    # could have changed — the fast status after an up or a down, the
    # cartridges too after an insert, everything after new or delete.
    socket =
      if job.state in [:done, :failed], do: reread(socket, Verbs.reread(job.kind)), else: socket

    {:noreply, socket}
  end

  # A job's output never touches the assigns: a batch of lines goes to
  # the hook that holds that job's output, on whichever screen shows it.
  def handle_info({:job_lines, id, from, lines}, socket),
    do: {:noreply, push_event(socket, "job_lines", %{id: id, from: from, lines: lines})}

  # The durations of the running jobs move while they run.
  def handle_info(:tick, socket) do
    if Enum.any?(socket.assigns.jobs, &(&1.state == :running)),
      do: Process.send_after(self(), :tick, 1000)

    {:noreply, assign(socket, now: DateTime.utc_now())}
  end

  def handle_info(:poll, socket), do: {:noreply, read_status(socket, :fast)}

  # A line of the session's output goes to the screen; the session ends
  # when the process in the container does.
  def handle_info({port, {:data, {_, line}}}, %{assigns: %{term: %{port: port}}} = socket),
    do: {:noreply, push_event(socket, "term_out", %{line: Console.ANSI.to_html(line)})}

  def handle_info({port, {:exit_status, code}}, %{assigns: %{term: %{port: port}} = a} = socket),
    do:
      {:noreply,
       socket
       |> assign(term: %{a.term | open: false, port: nil})
       |> push_event("term_out", %{line: "— session ended (exit #{code})", dim: true})}

  # A line of the logs goes to the client, which keeps and filters them;
  # a stream started over tells the client to fetch the buffer again.
  def handle_info({:log, line}, socket), do: {:noreply, push_event(socket, "log", line)}

  def handle_info({:logs, :restarted}, socket),
    do: {:noreply, push_event(socket, "logs_restarted", %{})}

  @impl true
  def handle_async({:probe, key}, {:ok, lines}, socket),
    do: {:noreply, assign(socket, probes: Map.put(socket.assigns.probes, key, lines))}

  def handle_async({:probe, key}, {:exit, why}, socket),
    do:
      {:noreply,
       assign(socket, probes: Map.put(socket.assigns.probes, key, ["failed: " <> inspect(why)]))}

  def handle_async({:diff, name}, {:ok, diff}, socket) do
    if socket.assigns.box && socket.assigns.box["name"] == name,
      do: {:noreply, assign(socket, diff: diff)},
      else: {:noreply, socket}
  end

  def handle_async({:diff, _}, {:exit, why}, socket),
    do:
      {:noreply, assign(socket, diff: nil, error: "the diff could not be read: " <> inspect(why))}

  defp reread(socket, :none), do: socket

  # The config was written. What it says is what the status reads —
  # which workspace, which compose project, which ports — so the board
  # is never left describing the file as it was. A workspace moved is
  # another workbench altogether: everything again, and the resident of
  # the old one dropped. Anything else the fast reading covers.
  defp reread(socket, :config) do
    was = workspace_path(socket.assigns.config)
    config = Workbench.config()
    socket = assign(socket, config: config, cfg_edits: %{})
    if workspace_path(config) == was, do: reread(socket, :fast), else: reread(socket, :all)
  end

  defp reread(socket, :fast), do: socket |> assign(restart_logs: true) |> read_status(:fast)
  defp reread(socket, :full), do: read_status(socket, :full)

  defp reread(socket, :all) do
    Bench.refresh(:catalog)
    Bench.refresh(:status, :all)
    socket |> assign(config: Workbench.config(), restart_logs: true, reading: :full)
  end

  defp workspace_path(config), do: Console.Config.values(config)["WORKSPACE_PATH"]

  # The board is read again by the bench, once for every page; what is
  # on it stays until the new one arrives.
  defp read_status(socket, mode) do
    Bench.refresh(:status, mode)
    assign(socket, reading: mode)
  end

  # The pulse on the Logs tab means what the one on Jobs means: something
  # is happening on that screen right now. For jobs that is a job
  # running; for logs it is a container of the project running, because
  # a container is what writes a line. It used to be the client's own
  # `follow` flag, which starts true and stays true whether or not
  # anything is up — so the dot pulsed over an empty stream, and said a
  # second time what the Following button on the screen already says.
  defp streaming?(nil), do: false
  defp streaming?(status), do: Enum.any?(status["containers"] || [], &(&1["State"] == "running"))

  defp project?(nil), do: false
  defp project?(status), do: status["exists"] == true

  # --- what the reader does ---------------------------------------------------

  @impl true
  def handle_event("refresh", _, socket), do: {:noreply, read_status(socket, :full)}
  # The hook, once mounted, asks for what the stream already holds.
  def handle_event("logs_backlog", _, socket), do: {:reply, %{lines: Logs.backlog()}, socket}

  # What a job wrote before its hook was there to hear it.
  def handle_event("job_backlog", %{"id" => id}, socket) do
    {from, lines} = Jobs.lines(id)
    {:reply, %{from: from, lines: lines}, socket}
  end

  def handle_event("filter", %{"filter" => f}, socket), do: {:noreply, assign(socket, filter: f)}

  def handle_event("open", %{"name" => name}, socket),
    do: {:noreply, push_patch(socket, to: "/#{socket.assigns.tab}?box=#{name}")}

  def handle_event("close", _, socket),
    do:
      {:noreply,
       push_patch(socket,
         to:
           "/#{socket.assigns.tab}" <>
             if(socket.assigns.wb && socket.assigns.box,
               do: "?box=#{socket.assigns.box["name"]}",
               else: ""
             )
       )}

  def handle_event("goto", %{"href" => href}, socket),
    do: {:noreply, push_patch(socket, to: "/#{socket.assigns.tab}#{href}")}

  def handle_event("flip", _, socket),
    do:
      {:noreply,
       assign(socket, face: if(socket.assigns.face == "front", do: "back", else: "front"))}

  def handle_event("view", %{"view" => v}, socket) when v in ~w(covers list),
    do: {:noreply, assign(socket, view: v)}

  # A section of the rail, folded away or opened again. The state is the
  # server's — a class the client puts on a section is wiped by the next
  # status — and the browser only remembers it, which is what the Folds
  # hook does with what comes back here.
  def handle_event("fold_section", %{"key" => key}, socket) do
    folded = socket.assigns.folded

    folded =
      if MapSet.member?(folded, key),
        do: MapSet.delete(folded, key),
        else: MapSet.put(folded, key)

    {:noreply,
     socket |> assign(folded: folded) |> push_event("folds", %{keys: MapSet.to_list(folded)})}
  end

  # What the browser remembered, handed back when the page mounts.
  def handle_event("folds_restore", %{"keys" => keys}, socket) when is_list(keys),
    do: {:noreply, assign(socket, folded: MapSet.new(Enum.filter(keys, &is_binary/1)))}

  # --- the workbench's config, as a form ---
  def handle_event("cfg_change", params, socket) do
    values = Console.Config.values(socket.assigns.config)
    edits = params["cfg"] || %{}

    # The stack sets the three versions at once — but only when the stack
    # is what was touched. The whole form travels on every change, so the
    # stack's own value came along when the reader moved one of the three
    # and overwrote it with the tag the stack still showed: picking an
    # Erlang put the old Erlang straight back, and nothing on the row
    # ever moved. `_target` is which field fired, and it is the answer.
    edits =
      with ["stack"] <- params["_target"],
           tag when is_binary(tag) and tag != "" <- params["stack"],
           [%{e: e, o: o, d: d}] <- ConsoleWeb.WorkbenchDrawer.parse_tag(tag) do
        edits
        |> Map.put("ELIXIR_VERSION", e)
        |> Map.put("ERLANG_VERSION", o)
        |> Map.put("DEBIAN_VERSION", d)
      else
        _ -> edits
      end

    edits = for {k, v} <- edits, Map.has_key?(values, k), v != values[k], into: %{}, do: {k, v}
    {:noreply, assign(socket, cfg_edits: edits)}
  end

  # The one place in the console where a page reaches the internet, and
  # it only does it here: five pages of Docker Hub's API, because the
  # reader pressed the button that says so.
  def handle_event("stacks_ask", _, socket) do
    Bench.refresh(:stacks)
    {:noreply, assign(socket, stacks_asking: true, stacks_error: nil)}
  end

  def handle_event("installers_ask", _, socket) do
    Bench.refresh(:installers)
    {:noreply, assign(socket, installers_asking: true, installers_error: nil)}
  end

  def handle_event("cfg_reload", _, socket), do: {:noreply, assign(socket, cfg_edits: %{})}

  def handle_event("cfg_raw", _, socket),
    do: {:noreply, assign(socket, cfg_raw: not socket.assigns.cfg_raw)}

  def handle_event("cfg_save", _, socket) do
    if socket.assigns.cfg_edits != %{} do
      Jobs.run({:config, nil}, [
        "config",
        "set" | Enum.map(socket.assigns.cfg_edits, fn {k, v} -> "#{k}=#{v}" end)
      ])
    end

    {:noreply, socket}
  end

  # --- the cluster's probes, run by the console ---
  def handle_event("probe", %{"key" => key}, socket) when key in ~w(answers peers) do
    status = socket.assigns.status
    key = String.to_existing_atom(key)

    fun =
      case key do
        :answers ->
          fn -> Console.Cluster.answers(status["ports"]["app"]) end

        :peers ->
          first =
            status["containers"]
            |> Enum.filter(&Regex.match?(~r/^app\d+$/, &1["Service"]))
            |> Enum.map(& &1["Service"])
            |> Enum.sort()
            |> List.first()

          fn ->
            Console.Cluster.peers(
              status["compose_project"],
              first,
              get_in(status, ["project", "app"]) || "app"
            )
          end
      end

    {:noreply,
     socket
     |> assign(probes: Map.put(socket.assigns.probes, key, :asking))
     |> start_async({:probe, key}, fun)}
  end

  # --- the terminal ---
  def handle_event("term_pick", params, socket) do
    t = socket.assigns.term
    t = %{t | target: params["target"] || t.target, shell: params["shell"] || t.shell}
    {:noreply, assign(socket, term: t)}
  end

  # A container's own lines: the Logs screen, with that service alone
  # lit. The filter lives in the client — the hook holds the buffer — so
  # the server says which one and the screen does the rest.
  def handle_event("logs_of", %{"service" => service}, socket),
    do:
      {:noreply,
       socket |> push_patch(to: ~p"/logs") |> push_event("logs_only", %{service: service})}

  def handle_event("term_open", %{"target" => target, "shell" => shell}, socket) do
    socket = assign(socket, term: %{socket.assigns.term | target: target, shell: shell})
    {:noreply, socket |> push_patch(to: ~p"/terminal") |> start_term()}
  end

  # Before the status a session has nothing to open on: the targets
  # would be guessed and the source's path unknown, and docker would
  # refuse an empty mount. The button says so and stays dark until then.
  def handle_event("term_start", _, %{assigns: %{status: nil}} = socket), do: {:noreply, socket}
  def handle_event("term_start", _, socket), do: {:noreply, start_term(socket)}

  def handle_event("term_close", _, socket), do: {:noreply, close_term(socket)}

  def handle_event("term_line", %{"line" => line}, socket) do
    t = socket.assigns.term

    if t.port do
      target = Enum.find(Terminal.targets(socket.assigns.status), &(&1.name == t.target))
      app = get_in(socket.assigns.status, ["project", "app"]) || "app"
      # rpc: each line is one expression handed to the release, through the bash that is open.
      text =
        if (t.shell == "rpc" and target) && target.release,
          do: "/app/bin/#{app} rpc \"$(cat <<'EOF_WB'\n#{line}\nEOF_WB\n)\"\n",
          else: line <> "\n"

      Port.command(t.port, text)
    end

    targets = Terminal.targets(socket.assigns.status)

    prompt =
      Terminal.prompt(
        Enum.find(targets, &(&1.name == t.target)) || hd(targets),
        t.shell,
        socket.assigns.status
      )

    escaped = line |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    {:noreply, push_event(socket, "term_out", %{line: prompt <> escaped, prompt: true})}
  end

  # The form as filled, kept as option name to value; a collection's
  # recipe is asked again when a choice moved, since that is what
  # chooses its members.
  def handle_event("options", params, socket) do
    args =
      Map.merge(
        params["opt"] || %{},
        Map.new(params["other"] || %{}, fn {k, v} -> {"other:" <> k, v} end)
      )

    box = socket.assigns.box
    moved = box["collection"] and Box.argv(box, args) != Box.argv(box, socket.assigns.args)
    socket = assign(socket, args: args)
    {:noreply, if(moved, do: ask_recipe(socket, box, args), else: socket)}
  end

  # A line to run — from a button or from the command line: a verb the
  # console knows (Console.Verbs), never a free-form argv. The two verbs
  # that cannot be taken back wait as pending until confirmed.
  def handle_event("run", %{"args" => line}, socket), do: {:noreply, run(socket, line)}
  def handle_event("cli", %{"line" => line}, socket), do: {:noreply, run(socket, line)}

  def handle_event("confirm", %{"id" => id}, socket) do
    Jobs.confirm(id)
    {:noreply, socket}
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    Jobs.cancel(id)
    {:noreply, socket}
  end

  # Again is a NEW job with the same kind and the same argv, never the
  # old one revived: what failed keeps its output and its exit code,
  # because that is the record of what happened. And it asks for the
  # word again if the verb asks for one — a retry of a `delete` is
  # still a delete.
  def handle_event("stop_ask", %{"id" => id}, socket),
    do: {:noreply, assign(socket, stop_ask: id)}

  def handle_event("stop_keep", _, socket), do: {:noreply, assign(socket, stop_ask: nil)}

  # The answer to the question, and the question closes either way: if
  # the signal did not go out the job is still running and says so on
  # its own, and there is nothing else to tell.
  def handle_event("stop", %{"id" => id}, socket) do
    Jobs.stop(id)
    {:noreply, assign(socket, stop_ask: nil)}
  end

  def handle_event("retry", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.jobs, &(&1.id == id and &1.state in [:failed, :stopped])) do
      nil ->
        {:noreply, socket}

      j ->
        Jobs.run(j.kind, j.args, confirm: Verbs.confirm?(j.kind, project?(socket.assigns.status)))
        {:noreply, assign(socket, error: nil)}
    end
  end

  def handle_event("fold", %{"id" => id}, socket) do
    open = socket.assigns.open_jobs
    open = if MapSet.member?(open, id), do: MapSet.delete(open, id), else: MapSet.put(open, id)
    {:noreply, assign(socket, open_jobs: open)}
  end

  def handle_event("fold_all", _, socket), do: {:noreply, assign(socket, open_jobs: MapSet.new())}

  # Clear done: what is running or waiting stays in view; the rest is
  # only this reader's view of the list, the queue keeps its history.
  def handle_event("jobs_clear", _, socket),
    do:
      {:noreply,
       assign(socket,
         jobs: Enum.filter(socket.assigns.jobs, &(&1.state in [:running, :queued, :pending]))
       )}

  def handle_event("pick", params, socket) do
    pick = %{
      target: params["target"] || socket.assigns.pick.target,
      replicas:
        (params["replicas"] || "4")
        |> Integer.parse()
        |> then(fn
          {n, _} -> max(n, 1)
          :error -> 4
        end),
      balancer: params["balancer"] == "on"
    }

    {:noreply, assign(socket, pick: pick)}
  end

  def handle_event("setup_env", %{"env" => env}, socket) when env in ~w(dev prod),
    do: {:noreply, assign(socket, setup_env: env)}

  def handle_event("new_form", params, socket) do
    ins = params["in"] || %{}

    out =
      for e <- Cartridges.base(socket.assigns.catalog),
          ins[e["name"]] != "on",
          into: MapSet.new(),
          do: e["name"]

    {:noreply, assign(socket, newp: %{out: out, gen: params["gen"] || %{}})}
  end

  def handle_event("insert", _params, socket) do
    box = socket.assigns.box
    Jobs.run({:insert, box["name"]}, ["add", box["name"] | Box.argv(box, socket.assigns.args)])
    {:noreply, socket}
  end

  # A collection leaves no commit of its own: its Eject is its members',
  # newest first — one job each, in the queue's order. One that refuses
  # (files changed since, a dependent) leaves the tree clean, and the
  # next either goes or refuses on its own.
  def handle_event("eject", %{"name" => name}, socket) do
    box = socket.assigns.box

    if box && box["collection"] do
      names =
        if(is_list(socket.assigns.recipe), do: socket.assigns.recipe, else: []) ++
          (box["members"] || [])

      names = names |> Enum.map(& &1["name"]) |> MapSet.new()

      for i <- get_in(socket.assigns.status, ["git", "inserts"]) || [],
          MapSet.member?(names, i["feature"]),
          do: Jobs.run({:eject, i["feature"]}, ["eject", i["feature"]])
    else
      Jobs.run({:eject, name}, ["eject", name])
    end

    {:noreply, socket}
  end

  defp start_term(socket) do
    status = socket.assigns.status
    t = close_term(socket).assigns.term
    targets = Terminal.targets(status)
    target = Enum.find(targets, &(&1.name == t.target)) || hd(targets)

    shell =
      if Enum.any?(Terminal.shells(target), &(elem(&1, 0) == t.shell)), do: t.shell, else: "bash"

    {_app, argv} = Terminal.argv(status, target, if(shell == "rpc", do: "bash", else: shell))

    port =
      Port.open({:spawn_executable, System.find_executable("docker")}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:line, 8192},
        args: argv
      ])

    socket
    |> assign(term: %{t | target: target.name, shell: shell, open: true, port: port})
    |> push_event("term_out", %{
      line:
        Terminal.command(status, target, shell) <>
          "  → " <>
          if(target.oneoff,
            do: "a one-off toolchain container with the source mounted (nothing runs)",
            else: "docker exec on " <> target.name
          ),
      dim: true,
      clear: true
    })
  end

  defp close_term(%{assigns: %{term: %{port: nil}}} = socket),
    do: assign(socket, term: %{socket.assigns.term | open: false})

  defp close_term(socket) do
    try do
      Port.close(socket.assigns.term.port)
    rescue
      _ -> :ok
    end

    assign(socket, term: %{socket.assigns.term | open: false, port: nil})
  end

  defp run(socket, line) do
    case Verbs.parse(line) do
      {:ok, kind, args} ->
        Jobs.run(kind, args, confirm: Verbs.confirm?(kind, project?(socket.assigns.status)))
        assign(socket, error: nil)

      {:error, why} ->
        assign(socket, error: why)
    end
  end

  # --- the page -------------------------------------------------------------

  # Why a screen is dark: never hidden, marked, with the reason. Deploy,
  # Jobs and Cartridges are always lit.
  defp unlit("project", %{status: status}),
    do:
      if(project?(status),
        do: nil,
        else: "this workspace has no project — Deploy → New project starts one"
      )

  defp unlit("cluster", %{status: status, catalog: catalog}) do
    lit =
      Cartridges.contributions(status, catalog, "tabs")
      |> Enum.any?(fn {_, t} -> t == "cluster" end)

    lights =
      catalog
      |> Enum.filter(&("cluster" in (get_in(&1, ["console", "tabs"]) || [])))
      |> Enum.map(& &1["name"])

    if lit,
      do: nil,
      else:
        "no cartridge lights this screen yet — #{Enum.join(lights, " or ")} does: insert it from Cartridges"
  end

  defp unlit("terminal", %{status: status}),
    do:
      if(project?(status),
        do: nil,
        else: "this workspace has no project — a shell needs one, or its source"
      )

  defp unlit("logs", %{status: status}),
    do:
      if(project?(status),
        do: nil,
        else: "this workspace has no project — its containers' logs come with one"
      )

  defp unlit(_, _), do: nil

  # The last insert or eject of the box in hand: its output lands in the drawer.
  defp box_job(jobs, box),
    do:
      Enum.find(
        jobs,
        &(elem(&1.kind, 0) in [:insert, :eject] and elem(&1.kind, 1) == box["name"])
      )

  # What Tab completes on the wb.sh line: the verbs, the cartridges,
  # each one's options — from the catalog, as JSON for the hook.
  defp words(catalog) do
    Jason.encode!(%{
      commands: Verbs.verbs(),
      cartridges: Enum.map(catalog, & &1["name"]),
      options:
        Map.new(catalog, fn e ->
          {e["name"],
           Enum.map(e["options"] || [], &("--" <> String.replace(&1["name"], "_", "-")))}
        end),
      deploy: ~w(--deploy --replicas --no-balancer),
      targets: ~w(dev prod scaled)
    })
  end

  # The Logs screen is the hook's: the lines never pass through the
  # server's render — two thousand of them and a search box would
  # re-render across the socket on every keystroke — so the whole
  # screen is built once and left alone (phx-update="ignore").
  @doc """
  What the console is doing, in the band's middle: a dot and a word.

  One place, always in front — the tray is per screen and the rail can be
  hidden. It is the chip's grammar minus the plate, the same move the
  probe made on the door: nobody presses this, so it has no box. Mono in
  lower case, because everything here is read off the machine.

  The order is the order of what matters: your word first, since it is the
  only one the console cannot resolve alone; then what is running; then
  what is being read; then nothing, which still says so. The lost socket
  is not here at all — it is written in CSS, on the class LiveView puts on
  the page when the socket goes, because a server that cannot be reached
  cannot be the one to tell you.
  """
  attr :jobs, :list, required: true
  attr :reading, :any, required: true
  attr :errands, :list, default: [], doc: "what the console is fetching from outside, by name"

  def state(assigns) do
    assigns = assign(assigns, state: state_of(assigns.jobs, assigns.reading, assigns.errands))

    ~H"""
    <div class={["state", elem(@state, 0)]} aria-live="polite">
      <span class="w"><i class="dot"></i><span class="word">{elem(@state, 1)}</span></span>
    </div>
    """
  end

  defp state_of(jobs, reading, errands) do
    running = Enum.filter(jobs, &(&1.state == :running))

    cond do
      Enum.any?(jobs, &(&1.state == :pending)) -> {"warn", "waiting for your word"}
      running != [] -> running_word(running)
      # An errand out of the machine is said before the readings of it:
      # it is the one the reader pressed a button for, and the only thing
      # the console does that leaves the host at all. Saying it here is
      # what the band is for — the button spinning is what the hand sees,
      # this is what the room sees.
      errands != [] -> {"busy", "asking " <> Enum.join(errands, " and ") <> "…"}
      reading == :full -> {"busy", "reading the cartridges…"}
      reading -> {"busy", "reading…"}
      true -> {"idle", "idle"}
    end
  end

  # The two fields that go out to the internet, by the name of who they
  # are asking — the same word their button's title uses.
  defp errands(assigns) do
    for {asking, who} <- [
          {assigns.stacks_asking, "docker hub"},
          {assigns.installers_asking, "hex"}
        ],
        asking,
        do: who
  end

  defp running_word([job]), do: {"busy", said(job.kind)}
  defp running_word(jobs), do: {"busy", "#{length(jobs)} jobs"}

  # A job in the band's words: the verb, and what it is about. `up dev`,
  # `add rest`, `delete` — the cmdline's own first two words, which is
  # what the reader typed or pressed, and never the whole line: the band
  # is not the tray.
  defp said({verb, nil}), do: to_string(verb)
  defp said({verb, what}), do: "#{verb} #{what}"

  defp logs_screen(assigns) do
    ~H"""
    <div class="logs" id="logs" phx-hook="Logs" phx-update="ignore">
      <div class="toolbar">
        <span id="svc-chips" style="display:inline-flex;gap:6px;flex-wrap:wrap"></span>
        <span class="sep"></span>
        <select id="level" aria-label="Level">
          <option value="error">Errors only</option>
          <option value="warn">Warnings and up</option>
          <option value="info">Info and up</option>
          <option value="debug" selected>All levels</option>
        </select>
        <input type="search" id="q" placeholder="Search the lines…" aria-label="Search" />
        <span class="sep"></span>
        <button class="btn" id="follow" type="button" aria-pressed="true">Following</button>
        <button class="btn" id="ts" type="button" aria-pressed="true">Timestamps</button>
        <button class="btn" id="clear" type="button">Clear</button>
      </div>
      <div class="logmeta">
        <span id="log-count"></span><span>docker compose logs --follow · the last 500 lines when the stream starts, then live · capped at 2 000 lines in the page</span>
      </div>
      <div class="viewport">
        <div class="lines" id="lines" aria-live="off"></div>
        <button class="newpill" id="newpill" type="button">↓ new lines</button>
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, tabs: @tabs, busy: Deploy.busy?(assigns.jobs, [:up, :stop, :down, :build]))

    ~H"""
    <header class="band">
      <div class="mark">
        <.link
          class="cell"
          patch={~p"/deploy"}
          aria-label="Deploy — the console’s first screen"
          title="Deploy — the console's first screen"
        >{mark()}</.link>
        <h1>
          Dockerized Elixir Workbench
          <small>Console <span :if={@version} class="v">v{@version}</span></small>
        </h1>
      </div>
      <.state jobs={@jobs} reading={@reading} errands={errands(assigns)} />
      <div class="right">
        <span id="clock" phx-hook="Clock" phx-update="ignore"></span>
        <button
          class="cell"
          id="ground-toggle"
          phx-hook="Ground"
          phx-update="ignore"
          aria-label="The ground: light or dark"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2" />
            <path d="M12 3a9 9 0 010 18z" fill="currentColor" />
          </svg>
        </button>
        <.link
          class="cell"
          patch={"/#{@tab}?wb=config"}
          aria-label="The workbench: its config, its manual, its changelog"
          title="The workbench: its config, its manual, its changelog"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path
              d="M 10.21 6.06 L 10.26 2.86 L 13.74 2.86 L 13.79 6.06 A 6.20 6.20 0 0 1 16.24 7.48 L 16.24 7.48 L 19.04 5.92 L 20.78 8.94 L 18.04 10.58 A 6.20 6.20 0 0 1 18.04 13.42 L 18.04 13.42 L 20.78 15.06 L 19.04 18.08 L 16.24 16.52 A 6.20 6.20 0 0 1 13.79 17.94 L 13.79 17.94 L 13.74 21.14 L 10.26 21.14 L 10.21 17.94 A 6.20 6.20 0 0 1 7.76 16.52 L 7.76 16.52 L 4.96 18.08 L 3.22 15.06 L 5.96 13.42 A 6.20 6.20 0 0 1 5.96 10.58 L 5.96 10.58 L 3.22 8.94 L 4.96 5.92 L 7.76 7.48 A 6.20 6.20 0 0 1 10.21 6.06 Z M 16 12 A 4 4 0 1 1 8 12 A 4 4 0 1 1 16 12 Z"
              fill="currentColor"
              fill-rule="evenodd"
              stroke="currentColor"
              stroke-width="2"
              stroke-linejoin="round"
            />
          </svg>
        </.link>
      </div>
    </header>

    <div class="app" id="app" phx-hook="Rail">
      <div
        class="grip"
        id="rail-grip"
        role="separator"
        aria-orientation="vertical"
        tabindex="0"
        aria-label="The rail's width — drag, or arrow keys"
      >
      </div>
      <aside
        class="console"
        id="rail"
        phx-hook="Folds"
        aria-label="The console: the configured workspace"
      >
        <.board
          status={@status}
          catalog={@catalog}
          reading={@reading}
          busy={@busy}
          error={@error}
          folded={@folded}
        />
      </aside>

      <main class="screen">
        <div class="tabs" role="tablist" aria-label="Screens">
          <%= for {t, label} <- @tabs do %>
            <% why = unlit(t, assigns) %>
            <.link
              :if={!why}
              class="tab"
              role="tab"
              patch={"/#{t}"}
              aria-selected={to_string(@tab == t)}
            >
              {label}
              <span
                :if={t == "jobs" and Enum.any?(@jobs, &(&1.state == :running))}
                class="live"
                title="a job is running"
              ></span>
              <span :if={t == "jobs" and Enum.any?(@jobs, &(&1.state == :failed))} class="badge bad">{Enum.count(
                @jobs,
                &(&1.state == :failed)
              )} failed</span>
              <span
                :if={t == "logs" and streaming?(@status)}
                class="live"
                title="the project's containers are running: lines are coming"
              ></span>
              <span :if={t == "logs"} id="logs-badge" class="badge bad" hidden phx-update="ignore"></span>
              <span :if={t == "shelf" and @status} class="badge">{length(
                Cartridges.installed(@status)
              )} in</span>
            </.link>
            <button
              :if={why}
              class="tab unlit"
              role="tab"
              aria-disabled="true"
              aria-selected="false"
              title={why}
            >{label}</button>
          <% end %>
        </div>

        <div class="scroller">
          <section class={["panel", @tab == "deploy" && "on"]} role="tabpanel">
            <Deploy.deploy
              status={@status}
              catalog={@catalog}
              config={@config}
              jobs={@jobs}
              pick={@pick}
              newp={@newp}
              setup_env={@setup_env}
            />
          </section>

          <section class={["panel", "fill", @tab == "jobs" && "on"]} role="tabpanel">
            <.jobs_screen
              jobs={@jobs}
              open={@open_jobs}
              now={@now}
              words={words(@catalog)}
              asking={@stop_ask}
              stoppable={@stoppable}
            />
          </section>

          <section class={["panel", "fill", @tab == "logs" && "on"]} role="tabpanel">
            <.logs_screen />
          </section>

          <section :if={@tab == "project"} class="panel fill on" role="tabpanel">
            <.project_screen
              carried={Project.carried(@status && @status["workspace"])}
              paper={@ppaper}
              page={@ppage}
            />
          </section>

          <section :if={@tab == "cluster"} class="panel on" role="tabpanel">
            <.cluster status={@status} probes={@probes} pick={@pick} />
          </section>

          <section class={["panel", "fill", @tab == "terminal" && "on"]} role="tabpanel">
            <.terminal status={@status} term={@term} />
          </section>

          <section class={["panel", @tab == "shelf" && "on"]} role="tabpanel">
            <.shelf catalog={@catalog} status={@status} filter={@filter} view={@view} tab={@tab} />
          </section>
        </div>

        <.tray jobs={@jobs} tab={@tab} />
      </main>
    </div>

    <div class={["scrim", (@box || @wb) && "on"]} phx-click="close"></div>
    <.workbench_drawer
      :if={@wb}
      tab={@tab}
      wb={@wb}
      paper={@wbpaper}
      version={@version}
      config={@config}
      edits={@cfg_edits}
      raw={@cfg_raw}
      stacks={@stacks}
      asking={@stacks_asking}
      stacks_error={@stacks_error}
      installers={@installers}
      installers_asking={@installers_asking}
      installers_error={@installers_error}
      page={@wbpage}
      jobs={@jobs}
    />
    <Box.box
      :if={@box && !@wb}
      box={@box}
      status={@status}
      catalog={@catalog}
      screen={@screen}
      paper={@paper}
      papers={@papers}
      page={@page}
      args={@args}
      recipe={@recipe}
      face={@face}
      tab={@tab}
      job={box_job(@jobs, @box)}
      diff={@diff}
    />
    """
  end
end
