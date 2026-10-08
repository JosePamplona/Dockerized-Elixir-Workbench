defmodule ConsoleWeb.ConsoleLive do
  @moduledoc """
  The console: the workspace on the left, the screens on the right —
  Deploy, Jobs, Terminal, Logs, Cartridges, Project, Docker —
  and the jobs tray at the bottom. Everything it shows comes from the status,
  the catalog and `config.conf`; everything it does is `wb.sh` as a
  job. Where the reader is — the screen — lives in the URL.

  What each screen keeps off the page — which document the URL names,
  what it reads, what it answers — lives with the screen, under
  `ConsoleWeb.ConsoleLive.*`; this module mounts, routes, and hands
  each event, message and answer to the screen it belongs to.
  """
  use ConsoleWeb, :live_view

  alias Console.{Bench, Events, Jobs, Logs, Project, Terminals, Verbs, Workbench}
  alias ConsoleWeb.{Band, Box, Cartridges, Deploy, DockerScreen, GitScreen, Refs}
  alias ConsoleWeb.ConsoleLive.{Docker, Drawer, Git, Hand, Term}
  alias ConsoleWeb.Doors
  alias ConsoleWeb.Record
  import ConsoleWeb.{Board, Shelf, ProjectScreen, WorkbenchDrawer}
  import ConsoleWeb.Band, only: [state: 1, errands: 1]
  import ConsoleWeb.DockerScreen, only: [docker_screen: 1]
  import ConsoleWeb.LogsScreen, only: [logs_screen: 1]
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
    {"project", "Project"},
    {"shelf", "Cartridges"},
    # Last, and never unlit: the daemon is there before any project is.
    {"docker", "Docker"}
  ]
  @tab_names Enum.map(@tabs, &elem(&1, 0))

  # The mark, read from the file it lives in: one source, and
  # @external_resource recompiles this module when that file changes.
  # Inline and never an <img>: it is `fill="currentColor"`, and an SVG
  # loaded as an image is its own document, where that falls to black.

  @impl true
  def mount(_params, _session, socket) do
    listen(connected?(socket))

    # What the bench holds is what the page opens with: nothing is read
    # on a mount, and a reading in flight is the one this page waits for.
    status = Bench.status()
    catalog = Bench.catalog() || []
    ask_first(socket, status)

    socket =
      socket
      |> assign(
        tab: "deploy",
        status: status,
        rebind: Workbench.rebind(),
        off_disk: off_disk(status),
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
        read_deps: [],
        face: "front",
        ppaper: "record",
        back: "/deploy",
        pdeploy: nil,
        pcomposes: [],
        ppage: nil,
        mix_by: %{},
        preads: %{},
        wb: nil,
        trail: [],
        wbpaper: "readme",
        wbpart: "overlay",
        themes: Console.Themes.all(),
        theme_files: Application.get_env(:console, :theme_files, false),
        wbpage: nil,
        cfg_edits: %{},
        cfg_raw: false,
        stacks: Bench.stacks(),
        stacks_asking: Bench.reading?(:stacks),
        stacks_error: Bench.error(:stacks),
        installers: Bench.installers(),
        packages: Bench.packages(),
        packages_asking: Bench.reading?(:packages),
        packages_error: Bench.error(:packages),
        installers_asking: Bench.reading?(:installers),
        installers_error: Bench.error(:installers),
        nodes: Bench.nodes(),
        nodes_asking: Bench.reading?(:nodes),
        nodes_error: Bench.error(:nodes),
        term: Term.initial(),
        view: "covers",
        jobs: Jobs.list(),
        open_jobs: MapSet.new(),
        tray_open: false,
        tray_hidden: false,
        stop_ask: nil,
        stoppable: Jobs.stoppable?(),
        now: DateTime.utc_now(),
        error: Bench.error(:status) || Bench.error(:catalog),
        filter: nil,
        reading: (is_nil(status) or Bench.reading?(:status)) && :full,
        pick: %{target: nil, replicas: 4, balancer: true},
        restart_logs: false,
        folded: MapSet.new(),
        dk: DockerScreen.initial(recent_events(socket)),
        gt: GitScreen.initial()
      )

    socket = follow_logs(socket, status)

    {:ok, socket, layout: false}
  end

  # A connected page listens to the jobs, the logs, the bench and the daemon's events.
  defp listen(true) do
    Jobs.subscribe()
    Logs.subscribe()
    Bench.subscribe()
    Events.subscribe()
    Terminals.subscribe()
  end

  defp listen(false), do: :ok

  # Nothing known and nothing on its way — the bench's first reading
  # failed before this page came — asks again.
  defp ask_first(socket, status) do
    if connected?(socket) and is_nil(status) and not Bench.reading?(:status),
      do: Bench.refresh(:status, :full)
  end

  # What the daemon said lately, for the Events feed; nothing before the socket is up.
  defp recent_events(socket),
    do: if(connected?(socket), do: Enum.reverse(Events.recent()), else: [])

  # The logs follow the compose project, once there is one to follow.
  defp follow_logs(socket, status) do
    if connected?(socket) and status, do: Logs.follow(status["compose_project"])
    socket
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
         socket
         |> assign(tab: tab)
         |> Hand.take(params)
         |> take_paper(params)
         |> take_compose(params["compose"])
         |> Drawer.take(params)
         |> Docker.take(params)
         |> Git.take(params)
         |> take_shelf(params)
         |> assign(trail: if(params["box"], do: trail(params["from"]), else: []))
         |> sync_last_fold()
         |> keep_back()}
    end
  end

  # The screen's own place, as a path: the tab, and on Project the paper
  # and the commit open on it. A box or the workbench drawer opening
  # over the screen carries it along in the URL, and Put back and Close
  # come back to it — where before both went to the bare tab, and
  # pressing a cartridge on History left History (2026-09-15).
  defp keep_back(socket),
    do:
      assign(socket,
        back: "/#{socket.assigns.tab}#{screen_query(socket.assigns.tab, socket.assigns)}"
      )

  # What a box stands over, as a path: the screen, and the workbench's
  # drawer when it is open — the two can be on the page at once, the box
  # on top (2026-10-06). Until then a cartridge pressed in the
  # workbench's README took the drawer's place, and putting the box back
  # left the reader on the bare screen, the README and their place in it
  # gone. The drawer's own paper and part are not in this path: `paper`
  # is the box's manual's while a box is open, and the drawer keeps what
  # it was on (`Drawer.take/2`).
  defp under(%{wb: wb, back: back}) when is_binary(wb), do: Refs.over(back, "wb=#{wb}")
  defp under(%{back: back}), do: back

  # The trail of boxes left on the way to the one in hand, oldest first:
  # `from=ecto.manual.design,clustering.manual.readme`, each the box,
  # its screen and its paper. There is one box in hand, never two — its
  # form, its recipe and its face are one set — so a cartridge pressed
  # in another's paper takes its place, and until 2026-10-06 that was
  # the end of the first reading: there was no way back to it. The `‹`
  # beside the box's name goes back along this trail, one box at a
  # time, and the booklet puts the reader where they were (the Booklet
  # hook). Read off the address,
  # so the browser's back and a reload agree with it; whatever does not
  # read as a box, a screen and a paper is not on it.
  @trail_entry ~r/^[a-z0-9_]+\.(box|install|files|manual)\.[a-z]*$/
  defp trail(nil), do: []

  defp trail(from),
    do: from |> String.split(",") |> Enum.filter(&(&1 =~ @trail_entry)) |> Enum.take(-8)

  defp from([]), do: ""
  defp from(trail), do: "&from=" <> Enum.join(trail, ",")

  # The address of a box opened by `query` (`box=NAME…`) from here:
  # over what a box stands over, and, when another box is in hand, with
  # that one added to the trail. A link to the box in hand — another of
  # its screens, another of its papers — keeps the trail as it is.
  defp over_box(%{box: box, trail: trail} = assigns, query) do
    [_, name] = Regex.run(~r/^box=([^&]*)/, query)

    trail =
      if box && box["name"] != name,
        do: trail ++ ["#{box["name"]}.#{assigns.screen}.#{assigns.paper}"],
        else: trail

    Refs.over(under(assigns), query <> from(trail))
  end

  # One box back along the trail: the last one left, on the screen and
  # the paper it was left on; nil when the box was opened from no other.
  # The `‹` beside the box's name. Put back, Close and the scrim are not
  # this: they put the box away whole, trail and all, onto what it
  # stands over. For one day (2026-10-06) Put back was the step back,
  # and a reader five boxes deep had five presses between them and the
  # screen.
  defp back_one(%{trail: []}), do: nil

  defp back_one(%{trail: trail} = assigns) do
    [name, screen, paper] = trail |> List.last() |> String.split(".")
    rest = Enum.drop(trail, -1)

    Refs.over(
      under(assigns),
      "box=#{name}&screen=#{screen}" <>
        if(screen == "manual", do: "&paper=#{paper}", else: "") <> from(rest)
    )
  end

  # The box's own links are written over this: what it stands over,
  # with the trail, so turning a paper of the box in hand keeps the way back.
  defp box_back(%{trail: []} = assigns), do: under(assigns)

  defp box_back(%{trail: trail} = assigns),
    do: Refs.over(under(assigns), "from=" <> Enum.join(trail, ","))

  # Where a screen was left, as its query: on Project the paper and the
  # commit open on it, on Docker the document, on Cartridges the
  # ribbon's filter — what the socket already remembers of each screen.
  # The tab strip builds its links from it, so a tab pressed leads back
  # to where its screen was (2026-09-29): before, `/project` bare fell
  # to Birth and `/docker` to Containers, while the shelf kept its
  # filter only because it read none from the URL. A default the URL
  # need not say stays out of it.
  defp screen_query("project", %{ppaper: paper, gt: gt}) do
    "?paper=#{paper}" <>
      if(gt.pick && paper in ["pending", "history"], do: "&commit=#{gt.pick}", else: "")
  end

  defp screen_query("docker", %{dk: %{doc: doc}}) when doc != "containers", do: "?doc=#{doc}"
  defp screen_query("shelf", %{filter: filter}) when is_binary(filter), do: "?doc=#{filter}"
  defp screen_query(_tab, _assigns), do: ""

  # Whether `paper` in the URL is a manual's — the box's, or the
  # workbench's — and not the project's, which stays as it was then.
  defp manual?(params), do: params["screen"] == "manual" or params["wb"] == "manual"

  # The tray and the Jobs screen read the same last job: arriving at Jobs,
  # its row is unfolded or folded as the tray was left — put away or not.
  defp sync_last_fold(%{assigns: %{tab: "jobs", jobs: [last | _]}} = socket) do
    open = socket.assigns.open_jobs

    open =
      if socket.assigns.tray_open,
        do: MapSet.put(open, last.id),
        else: MapSet.delete(open, last.id)

    assign(socket, open_jobs: open)
  end

  defp sync_last_fold(socket), do: socket

  # The project's paper, from the query on /project — or, with a manual
  # open over the screen, the one already open, since `paper` in that
  # URL is the box's manual's or the workbench's.
  defp take_paper(%{assigns: %{tab: "project"}} = socket, params) do
    ws = socket.assigns.status && socket.assigns.status["workspace"]
    carried = Project.carried(socket.assigns.status)
    named = if manual?(params), do: socket.assigns.ppaper, else: params["paper"]
    paper = if named in carried, do: named, else: List.first(carried) || "readme"

    if manual?(params) and paper == socket.assigns.ppaper,
      do: socket,
      else: socket |> assign(ppaper: paper, ppage: Project.render(ws, paper)) |> ask_mix_by(paper)
  end

  defp take_paper(socket, _params), do: socket

  # Who put each package in mix.exs is read off git — the base boxes'
  # insert commits, the first commit — so it is asked apart from the page.
  defp ask_mix_by(socket, "mix") do
    status = socket.assigns.status
    start_async(socket, :mix_by, fn -> Project.brought_by(status) end)
  end

  defp ask_mix_by(socket, _paper), do: socket

  # The compose file open under its row on the Deploy tab: the one the
  # URL names, when it is baked; none otherwise — the reader opens one.
  defp take_compose(%{assigns: %{tab: "deploy"}} = socket, named) do
    composes = Console.Docker.composes(socket.assigns.status)
    open = Enum.find_value(composes, &(&1.key == named and &1.lines != nil and &1.key))
    assign(socket, pcomposes: composes, pdeploy: open)
  end

  defp take_compose(socket, _named), do: assign(socket, pcomposes: [], pdeploy: nil)

  # What the Deploy screen reads off the workspace's own files: the three
  # deployments as `Record` draws them (their compose files, for the
  # ports each publishes) and the stack the project was born on (its
  # `Dockerfile.local`). Read when a status arrives, which is when those
  # files can have changed — a bake, a new, an up — and not on every
  # render: they sat in the card's body, so every checkbox of the New
  # Project form read them again on its way through the server
  # (`born/1` alone measured 6.5 ms, 2026-09-27).
  defp off_disk(status) do
    %{
      rows: Record.deployments(status || %{}),
      born: status && status["exists"] == true && Console.Project.born(status["workspace"])
    }
  end

  # A knock: every open route called once, and what each answered kept
  # for the whole page — the rail's Services, Doors & Pages and the Record's
  # addresses share it. With the app down there is no route to call, and
  # the knock still goes: the round from :asking to its answer renders
  # the pages on disk again, which are read off the disk as they render.
  # Only when the reader presses the bell on either: never on a mount, a status or a clock — the calls land in the app's
  # logs, and a line the reader did not cause is noise there (the
  # automatic knock lasted a day, 2026-09-09). A status arriving wipes
  # what was heard: a job changed the world, and no chip may say what
  # was true before it.
  defp knock(socket) do
    page = Record.page(socket.assigns.status, socket.assigns.catalog)

    case page do
      nil ->
        assign(socket, preads: %{})

      page ->
        hrefs = if page.up, do: Record.hrefs(page), else: []

        socket
        |> assign(preads: :asking)
        |> start_async({:knock, :read}, fn -> Doors.read(hrefs) end)
    end
  end

  # Which reading of the shelf: /shelf?doc=base. Named in the URL by the
  # row; kept as it was when a link does not name it — a box opening
  # over the shelf, its screens — so the shelf behind the drawer stays
  # where the reader left it.
  defp take_shelf(%{assigns: %{tab: "shelf"}} = socket, %{"doc" => doc}) when is_binary(doc) do
    if doc in ConsoleWeb.Shelf.doc_names(), do: assign(socket, filter: doc), else: socket
  end

  defp take_shelf(socket, _params), do: socket

  defp leave_unlit(socket) do
    if unlit(socket.assigns.tab, socket.assigns),
      do: push_patch(socket, to: ~p"/deploy"),
      else: socket
  end

  # --- what arrives ---------------------------------------------------------

  @impl true
  def handle_info({:bench, :status, status}, socket) do
    poll_if_starting(status)
    refollow_logs(socket, status)

    # Another workspace — the config moved it — is another project's
    # papers and another git: what was read off the old one is read again.
    moved? = socket.assigns.status && socket.assigns.status["workspace"] != status["workspace"]

    socket =
      socket
      |> assign(
        status: status,
        off_disk: off_disk(status),
        reading: false,
        error: nil,
        restart_logs: false,
        rebind: Workbench.rebind()
      )
      |> leave_unlit()
      # The containers may have changed: the Docker screen reads again.
      |> Docker.read()
      # And the tree, after a commit or an insert: the Git screen too.
      |> Git.read(true)
      |> reread_paper(moved?)
      |> reask_diff(moved?)
      |> assign(preads: %{})
      # And the compose files under Deploy: a bake may have rewritten one.
      |> then(&take_compose(&1, &1.assigns.pdeploy))

    {:noreply, socket}
  end

  def handle_info({:bench, :packages, readings}, socket),
    do:
      {:noreply, assign(socket, packages: readings, packages_asking: false, packages_error: nil)}

  def handle_info({:bench, :error, :packages, why}, socket),
    do: {:noreply, assign(socket, packages_asking: false, packages_error: why)}

  def handle_info({:bench, key, _} = msg, socket) when key in [:stacks, :installers, :nodes],
    do: Drawer.info(msg, socket)

  def handle_info({:bench, :error, key, _} = msg, socket)
      when key in [:stacks, :installers, :nodes],
      do: Drawer.info(msg, socket)

  def handle_info({:bench, :catalog, catalog}, socket) do
    socket = assign(socket, catalog: catalog)
    # A box named in the URL before the catalog was here opens now.
    {:noreply,
     if(socket.assigns[:pending_box],
       do: Hand.take(socket, socket.assigns.pending_box),
       else: socket
     )}
  end

  def handle_info({:bench, :expand, _, _, _} = msg, socket), do: Hand.info(msg, socket)
  def handle_info({:bench, :error, {:expand, _, _}, _} = msg, socket), do: Hand.info(msg, socket)

  def handle_info({:bench, :error, _key, why}, socket),
    do: {:noreply, assign(socket, error: why, reading: false)}

  @impl true
  def handle_info({:job, job}, socket) do
    known = Enum.any?(socket.assigns.jobs, &(&1.id == job.id))

    jobs =
      if known,
        do: Enum.map(socket.assigns.jobs, &if(&1.id == job.id, do: job, else: &1)),
        else: [job | socket.assigns.jobs]

    # A new job brings the tray back if the reader had put it away.
    socket = if known, do: socket, else: assign(socket, tray_hidden: false)

    open = unfold(socket.assigns.open_jobs, job)

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
      if job.state in [:done, :failed],
        do: socket |> Docker.forget_disk(job.kind) |> reread(Verbs.reread(job.kind)),
        else: socket

    {:noreply, socket}
  end

  # A delete took its workspace's jobs with it.
  def handle_info({:jobs_dropped, ids}, socket),
    do:
      {:noreply,
       assign(socket,
         jobs: Enum.reject(socket.assigns.jobs, &(&1.id in ids)),
         open_jobs: MapSet.difference(socket.assigns.open_jobs, MapSet.new(ids)),
         stop_ask: if(socket.assigns.stop_ask in ids, do: nil, else: socket.assigns.stop_ask)
       )}

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

  # What the daemon says on its own, and the stats' stream open as a
  # Port, told apart by the port its screen holds.
  def handle_info({:event, _} = msg, socket), do: Docker.info(msg, socket)

  def handle_info({port, _} = msg, %{assigns: %{dk: %{port: port}}} = socket) when is_port(port),
    do: Docker.info(msg, socket)

  # The terminal's sessions: a line of the one this page looks at, and
  # the state of every one, for the marks.
  def handle_info({:term, _, _} = msg, socket), do: Term.info(msg, socket)
  def handle_info({:terminal, _, _} = msg, socket), do: Term.info(msg, socket)

  # A line of the logs goes to the client, which keeps and filters them;
  # a stream started over tells the client to fetch the buffer again.
  def handle_info({:log, line}, socket), do: {:noreply, push_event(socket, "log", line)}

  def handle_info({:logs, :restarted}, socket),
    do: {:noreply, push_event(socket, "logs_restarted", %{})}

  # The terminal's sessions that run, for the tab's dot: they live in
  # Console.Terminals and outlive the page, so the dot reads the same
  # from every screen and after a reload.
  defp live_sessions(%{sessions: sessions}),
    do: Enum.count(sessions, fn {_, s} -> s.state == :live end)

  # A container still starting will be healthy without any job saying
  # so: ask again in a moment, the fast way.
  defp poll_if_starting(status) do
    if Enum.any?(status["containers"] || [], &(&1["Health"] == "starting")),
      do: Process.send_after(self(), :poll, 3000)
  end

  # The logs follow the compose project, whichever deployment is up;
  # after a job that could have changed the containers the stream is
  # started again, since --follow only attaches to what is there.
  defp refollow_logs(socket, status) do
    if connected?(socket),
      do: Logs.follow(status["compose_project"], restart: socket.assigns.restart_logs)
  end

  # The project's paper, read again when it was never read or the workspace
  # moved — and Mix on every status, since a job that inserted a box
  # changed mix.exs and the table under it already follows the status.
  defp reread_paper(socket, moved?) do
    if socket.assigns.tab == "project" and
         (is_nil(socket.assigns.ppage) or moved? or socket.assigns.ppaper == "mix"),
       do: take_paper(socket, %{"paper" => socket.assigns.ppaper}),
       else: socket
  end

  # A Files screen opened before the status was here asks now.
  defp reask_diff(socket, moved?) do
    if socket.assigns.screen == "files" && socket.assigns.box &&
         (is_nil(socket.assigns.diff) or moved?),
       do: Hand.ask_diff(socket, socket.assigns.box),
       else: socket
  end

  @impl true

  def handle_async({:knock, :read}, {:ok, reads}, socket),
    do: {:noreply, assign(socket, preads: reads)}

  def handle_async({:knock, :read}, {:exit, _}, socket),
    do: {:noreply, assign(socket, preads: %{})}

  def handle_async(:mix_by, {:ok, by}, socket), do: {:noreply, assign(socket, mix_by: by)}
  def handle_async(:mix_by, {:exit, _why}, socket), do: {:noreply, socket}
  def handle_async({:diff, _} = key, result, socket), do: Hand.async(key, result, socket)
  def handle_async({:deps, _} = key, result, socket), do: Hand.async(key, result, socket)
  def handle_async({:dk, _} = key, result, socket), do: Docker.async(key, result, socket)
  def handle_async({:gt, _} = key, result, socket), do: Git.async(key, result, socket)

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
    do: {:noreply, push_patch(socket, to: over_box(socket.assigns, "box=#{name}"))}

  # Close takes away what is on top. A box opened over the workbench's
  # drawer — a cartridge pressed in its README — is put back, whatever
  # trail of boxes led to it, and the drawer is there as it was left;
  # closed again, the screen.
  def handle_event("close", _, socket),
    do:
      {:noreply,
       push_patch(socket,
         to: if(socket.assigns.box, do: under(socket.assigns), else: socket.assigns.back)
       )}

  # A link of a paper that opens a box: over the workbench's drawer when
  # the link is the drawer's, and, from another box, with that box left
  # on the trail to come back to.
  def handle_event("goto", %{"href" => "?box=" <> _ = href}, socket),
    do:
      {:noreply, push_patch(socket, to: over_box(socket.assigns, String.trim_leading(href, "?")))}

  def handle_event("goto", %{"href" => href}, socket),
    do: {:noreply, push_patch(socket, to: "/#{socket.assigns.tab}#{href}")}

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

  # The workbench's drawer: the config form and its two errands.
  def handle_event("cfg_" <> _ = event, params, socket), do: Drawer.event(event, params, socket)
  def handle_event("stacks_ask", params, socket), do: Drawer.event("stacks_ask", params, socket)

  def handle_event("installers_ask", params, socket),
    do: Drawer.event("installers_ask", params, socket)

  def handle_event("nodes_ask", params, socket), do: Drawer.event("nodes_ask", params, socket)

  # The Git screen, the Docker screen, the terminal: each one's events
  # go to the module that keeps its state.
  def handle_event("git_" <> _ = event, params, socket), do: Git.event(event, params, socket)
  def handle_event("dk_" <> _ = event, params, socket), do: Docker.event(event, params, socket)
  def handle_event("term_" <> _ = event, params, socket), do: Term.event(event, params, socket)

  # The bell of Services, Doors & Pages: every open route called once.
  def handle_event("knock", _params, socket), do: {:noreply, knock(socket)}

  # A container's own lines: the Logs screen, with that service alone
  # lit. The filter lives in the client — the hook holds the buffer — so
  # the server says which one and the screen does the rest.
  def handle_event("logs_of", %{"service" => service}, socket),
    do:
      {:noreply,
       socket |> push_patch(to: ~p"/logs") |> push_event("logs_only", %{service: service})}

  # The box in hand: its face, its options, and what it asks of wb.sh.
  def handle_event(event, params, socket) when event in ~w(flip options section insert eject),
    do: Hand.event(event, params, socket)

  # What hex says of the packages the box in hand brings. Asked for, as
  # every reading that costs the internet is (Console.Bench): the names
  # already read are answered from memory, and only the rest are fetched.
  def handle_event("packages_ask", %{"names" => names}, socket) do
    # A package from GitHub comes as `name=owner/repo`; what was read is
    # kept by name, and only what was not is asked.
    read = socket.assigns.packages

    wanted =
      names
      |> String.split(",", trim: true)
      |> Enum.reject(&Map.has_key?(read, hd(String.split(&1, "="))))

    Bench.refresh(:packages, wanted)
    {:noreply, assign(socket, packages_asking: true, packages_error: nil)}
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

  # Folding the last job folds the tray too: they are one fold of one job.
  def handle_event("fold", %{"id" => id}, socket) do
    open = socket.assigns.open_jobs
    open = if MapSet.member?(open, id), do: MapSet.delete(open, id), else: MapSet.put(open, id)
    last = List.first(socket.assigns.jobs)

    tray_open =
      if last && last.id == id,
        do: MapSet.member?(open, id),
        else: socket.assigns.tray_open

    {:noreply, assign(socket, open_jobs: open, tray_open: tray_open)}
  end

  def handle_event("fold_all", _, socket),
    do: {:noreply, assign(socket, open_jobs: MapSet.new(), tray_open: false)}

  # The tray's fold is the last job's, whichever that is: kept while the
  # tray is put away, and what the Jobs screen opens that job to. The rest
  # of the list stays folded as the reader left it.
  def handle_event("tray_fold", _, socket),
    do: {:noreply, assign(socket, tray_open: !socket.assigns.tray_open)}

  # Put away until the next job; its fold is kept.
  def handle_event("tray_hide", _, socket),
    do: {:noreply, assign(socket, tray_hidden: true)}

  # Clear done: what is running or waiting stays in view; the rest is
  # only this reader's view of the list, the queue keeps its history.
  def handle_event("jobs_clear", _, socket),
    do:
      {:noreply,
       assign(socket,
         jobs: Enum.filter(socket.assigns.jobs, &(&1.state in [:running, :queued, :pending]))
       )}

  def handle_event("pick", params, socket),
    do: {:noreply, assign(socket, pick: pick_from(params, socket.assigns.pick))}

  # The picker sent, and with it the verb of the button pressed: Up and
  # Build of the row picked, Bake of a row's own file. The line is
  # written HERE, out of what travelled — never off the button, which
  # was rendered with the form as it was and can be a change behind it.
  def handle_event("deploy_run", params, socket) do
    pick = pick_from(params, socket.assigns.pick)
    socket = assign(socket, pick: pick)
    line = Deploy.line(params["do"], pick)

    {:noreply,
     if(line, do: run(socket, String.replace_prefix(line, "./wb.sh ", "")), else: socket)}
  end

  # The picker as the reader left it: the target, the replicas, the
  # balancer. A change writes it, and a submit reads it again — the two
  # events carry the same fields.
  defp pick_from(params, pick) do
    %{
      target: params["target"] || pick.target,
      replicas:
        (params["replicas"] || "4")
        |> Integer.parse()
        |> then(fn
          {n, _} -> max(n, 1)
          :error -> 4
        end),
      balancer: params["balancer"] == "on"
    }
  end

  # The card's form as state: the base cartridges left out, the flags.

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
        else: "this workspace has no project — Deploy → Project creates one"
      )

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

  # The inserts and ejects of the box in hand, newest first: its runs,
  # drawn in the drawer as the rows the Jobs screen draws.
  defp box_jobs(jobs, box),
    do:
      Enum.filter(
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

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        tabs: @tabs,
        busy: Deploy.busy?(assigns.jobs, [:up, :stop, :down, :build, :restart])
      )

    ~H"""
    <header class="band">
      <div class="mark">
        <.link
          class="cell"
          patch={~p"/deploy"}
          aria-label="Deploy — the console’s first screen"
          title="Deploy — the console's first screen"
        ><.logo /></.link>
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
          <.mark name="ground" />
        </button>
        <.link
          class="cell"
          patch={Refs.over(@back, "wb=config")}
          aria-label="The workbench: its config, its manual, its changelog"
          title="The workbench: its config, its manual, its changelog"
        >
          <.mark name="workbench" />
        </.link>
      </div>
    </header>

    <%!-- The one thing that is true of the whole console at once: it was
          started for another workspace, or for a project by another
          name, so every mix and git of a job runs in a container of its
          own — slower, and nothing else. It said so in a note inside
          the rail's Workspace section until 2026-09-27, which is a
          local place for a global condition, and it was the one message
          that explains why every job suddenly takes minutes.

          Nothing is disabled with it. The console in this state works
          whole — Docker, Logs, Terminal, the papers, the shelf, the
          status — and what changed is where a job's mix runs. Greying
          out what still works would be the unlit rule backwards.

          It sits against the band, on the side the screen is: under it
          when the band is on top, over it when the reader put the band
          at the foot (`body.band-bottom`). --%>
    <Band.rebind :if={@rebind} rebind={@rebind} />

    <%!-- What colour each service is drawn in, for the hooks that paint in
         the browser (the logs): a role's, asked of ConsoleWeb.Services. --%>
    <div id="svc-colors" hidden data-colors={Jason.encode!(ConsoleWeb.Services.colors(@status))}>
    </div>
    <div class="app" id="app" phx-hook="Rail">
      <%!-- The rail's two squares, the way hexdocs folds its sidebar: in
            the rail's corner while the rail shows, in the screen's corner
            while it is away. Left puts the rail on the left, Right on the
            right, and each draws the frame it would set, the column
            solid; the one in force is pressed, and pressing it again
            puts the rail away. They are the Interface tab's Left, Right
            and Hidden, kept the same way; the Rail hook works them, and
            their pressed state and title are its alone: the server does
            not know the frame, so a patch of the page must not write
            them back (phx-update="ignore" on the pair — until 2026-09-15
            every patch pressed Left again, seen once the state had a
            look). The pair is one element so that it casts one shadow:
            two squares each with its own laid the second's over the
            first. --%>
      <div class="railsq" id="rail-squares" phx-update="ignore">
        <.square
          mark="rail"
          size="small"
          label="The rail on the left"
          id="rail-left"
          aria-pressed="true"
          title="put the rail away"
        />
        <.square
          mark="rail"
          size="small"
          label="The rail on the right"
          id="rail-right"
          aria-pressed="false"
          title="move the rail to the right"
        />
      </div>
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
          rebind={@rebind}
          catalog={@catalog}
          reads={@preads}
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
              patch={"/#{t}" <> screen_query(t, %{ppaper: @ppaper, gt: @gt, dk: @dk, filter: @filter})}
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
              <span
                :if={t == "terminal" and live_sessions(@term) > 0}
                class="live"
                title={
                  case live_sessions(@term) do
                    1 -> "a session is open"
                    n -> "#{n} sessions are open"
                  end
                }
              ></span>
              <span :if={t == "shelf" and @status} class="badge">{length(
                Cartridges.installed(@status)
              )} in</span>
              <span
                :if={t == "docker" and @dk.alarms > 0}
                class="badge bad"
                title="a container of this workspace died with a code, was killed for memory, or turned unhealthy — since you last looked at Events"
              >{@dk.alarms} died</span>
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
              composes={@pcomposes}
              deploy={@pdeploy}
              reading={@reading}
              folded={@folded}
              off_disk={@off_disk}
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

          <section :if={@tab == "project"} class="panel fill on" id="panel-project" role="tabpanel">
            <.project_screen
              carried={Project.carried(@status)}
              paper={@ppaper}
              page={@ppage}
              record={@ppaper == "record" && Record.page(@status, @catalog, @preads)}
              reads={@preads}
              birth={get_in(@status || %{}, ["project", "birth", "sha"])}
              status={@status}
              gt={@gt}
              jobs={@jobs}
              busy={@busy}
              reading={@reading}
              hex={@packages}
              hex_asking={@packages_asking}
              hex_error={@packages_error}
              by={@mix_by}
            />
          </section>

          <section :if={@tab == "docker"} class="panel fill on" id="panel-docker" role="tabpanel">
            <.docker_screen status={@status} dk={@dk} jobs={@jobs} />
          </section>

          <section class={["panel", "fill", @tab == "terminal" && "on"]} role="tabpanel">
            <.terminal status={@status} term={@term} />
          </section>

          <section class={["panel", "fill", @tab == "shelf" && "on"]} id="panel-shelf" role="tabpanel">
            <.shelf
              catalog={@catalog}
              status={@status}
              filter={@filter || ConsoleWeb.Shelf.first_doc(@status, @catalog)}
              view={@view}
              tab={@tab}
              reads={@preads}
            />
          </section>
        </div>

        <.tray
          jobs={@jobs}
          tab={@tab}
          open={@tray_open}
          hidden={@tray_hidden}
          asking={@stop_ask}
          stoppable={@stoppable}
        />
      </main>
    </div>

    <div class={["scrim", (@box || @wb) && "on"]} phx-click="close"></div>
    <.workbench_drawer
      :if={@wb}
      tab={@tab}
      back={@back}
      wb={@wb}
      paper={@wbpaper}
      part={@wbpart}
      themes={@themes}
      theme_files={@theme_files}
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
      nodes={@nodes}
      nodes_asking={@nodes_asking}
      nodes_error={@nodes_error}
      page={@wbpage}
      jobs={@jobs}
      under={@box != nil}
    />
    <Box.box
      :if={@box}
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
      back={box_back(%{wb: @wb, back: @back, trail: @trail})}
      put_back={under(%{wb: @wb, back: @back})}
      back_one={back_one(%{wb: @wb, back: @back, trail: @trail})}
      back_one_to={@trail |> List.last() |> then(&(&1 && hd(String.split(&1, "."))))}
      jobs={box_jobs(@jobs, @box)}
      open={@open_jobs}
      now={@now}
      asking={@stop_ask}
      stoppable={@stoppable}
      diff={@diff}
      read_deps={@read_deps}
      packages={@packages}
      packages_asking={@packages_asking}
      packages_error={@packages_error}
    />
    """
  end

  # A job you just asked for is a job you are watching: it comes unfolded.
  defp unfold(open, %{state: state, id: id}) when state in [:queued, :pending],
    do: MapSet.put(open, id)

  defp unfold(open, _job), do: open
end
