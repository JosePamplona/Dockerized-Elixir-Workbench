defmodule ConsoleWeb.DockerScreen do
  @moduledoc """
  The Docker screen: what the daemon holds, in five documents under the
  row of tabs the Project screen has — Containers, Images, Volumes,
  Networks, Events. Deploys, the compose files, was the sixth until
  2026-09-09: the files are the workspace's, and they read under the
  Record's deployments now. Settled on 2026-09-05 in a decision page,
  `console/docker-en-la-consola.html`, retired once the answer was in
  (it stays in the history): the table across the top of Containers and the card of
  the container picked *under* it, never beside it, because the width
  is for the columns and the card wants it whole for the env and the
  mounts; the console itself a row like the others, marked; Events with
  the badge Jobs has, red, counting what died badly since the reader
  last looked.

  Nothing here starts or stops a single container. The board says why
  (`ConsoleWeb.Board.containers/1`): a deployment goes up and down
  whole. The one act on one container is Restart — the same service,
  the same image, up again, the deployment left whole — and the three
  ways of pruning are `wb.sh prune`, always confirmed. Stop and Start
  of one are not unlit, they are absent: `.unlit` is for what the
  reader could have, and this is the unit, not a state.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Ribbon, only: [ribbon: 1]

  @docs [
    {"containers", "Containers"},
    {"images", "Images"},
    {"volumes", "Volumes"},
    {"networks", "Networks"},
    {"events", "Events"}
  ]

  def docs, do: @docs
  def doc_names, do: Enum.map(@docs, &elem(&1, 0))

  @doc "The screen's state as the page opens: on Containers, this workspace, stats on."
  def initial(events),
    do: %{
      doc: "containers",
      scope: "workspace",
      stats: true,
      pick: nil,
      rows: nil,
      card: nil,
      live: %{},
      images: nil,
      volumes: nil,
      sizes: nil,
      networks: nil,
      df: nil,
      events: events,
      alarms: 0,
      port: nil,
      daemon: nil
    }

  @doc """
  Whether an event is one to count on the badge: a container of this
  workspace that died with a code, was killed for memory, or turned
  unhealthy. A `down` is four `die exit 0`, and those are not alarms.
  """
  def alarm?(%{type: "container"} = e, project) do
    mine = e.name == "workbench_console" or (not is_nil(project) and e.project == project)

    mine and
      ((e.action == "die" and e.exit not in [nil, "0"]) or e.action == "oom" or
         (e.action == "health_status" and e.detail == "unhealthy"))
  end

  def alarm?(_, _), do: false

  attr :status, :map, default: nil

  attr :dk, :map,
    required: true,
    doc: "the screen's state: which document, the scope, what was read"

  attr :jobs, :list, required: true

  def docker_screen(assigns) do
    ~H"""
    <div class="pdocs docker">
      <.ribbon
        label="What the daemon holds"
        selected={@dk.doc}
        docked
        items={
          for {key, label} <- docs(),
              do: %{
                key: key,
                label: label,
                small: doc_sum(key, @dk),
                href: "/docker?doc=#{key}",
                badge: key == "events" and @dk.alarms > 0 and "#{@dk.alarms} died",
                badge_class: "bad",
                badge_title:
                  "died with a code, killed for memory, or unhealthy, since you last looked"
              }
        }
      />
      <div class="dkdoc">
        <.containers_doc :if={@dk.doc == "containers"} dk={@dk} status={@status} jobs={@jobs} />
        <.images_doc :if={@dk.doc == "images"} dk={@dk} jobs={@jobs} />
        <.volumes_doc :if={@dk.doc == "volumes"} dk={@dk} status={@status} jobs={@jobs} />
        <.networks_doc :if={@dk.doc == "networks"} dk={@dk} />
        <.events_doc :if={@dk.doc == "events"} dk={@dk} status={@status} />
      </div>
    </div>
    """
  end

  # What each tab says of itself, off what was read; nothing before it was.
  defp doc_sum("containers", %{rows: rows}) when is_list(rows),
    do: "#{Enum.count(rows, &(&1.state == "running"))} of #{length(rows)} running"

  defp doc_sum("images", %{images: %{images: is, dangling: d}}),
    do: "#{length(is)}" <> if(d > 0, do: " · #{d} untagged", else: "")

  defp doc_sum("volumes", %{volumes: vs}) when is_list(vs), do: "#{length(vs)}"
  defp doc_sum("networks", %{networks: ns}) when is_list(ns), do: "#{length(ns)}"
  defp doc_sum("events", %{events: es}), do: "#{length(es)}"

  defp doc_sum(_, _), do: nil

  # --- the toolbar every document shares ----------------------------------------

  attr :dk, :map, required: true
  attr :stats, :boolean, default: false
  slot :inner_block

  defp toolbar(assigns) do
    ~H"""
    <%!-- The daemon's box, with its controls in a strip under it, the way
          the Logs screen and a job's output carry theirs (2026-09-16):
          the lines the daemon says of itself and of its disk, and beneath
          them the scope and, on Containers, Stats. Headed "Specs", as the
          Mix paper heads what def project says. --%>
    <div class="log-cap"><span class="label">Specs</span></div>
    <div class="viewport daemon">
      <code :if={@dk.daemon} class="code-box daemon"><span
        :for={{k, v} <- daemon_lines(@dk)}
        class="ln"
      ><span class="k">{k}</span>{v}</span></code>
      <p :if={!@dk.daemon} class="nothing">Reading the daemon…</p>
      <div class="toolbar controls">
        <span class="label">Scope</span>
        <button
          class="btn"
          type="button"
          phx-click="dk_scope"
          phx-value-scope="workspace"
          aria-pressed={to_string(@dk.scope == "workspace")}
          title="this workspace's compose project, and the console"
        >This workspace</button>
        <button
          class="btn"
          type="button"
          phx-click="dk_scope"
          phx-value-scope="daemon"
          aria-pressed={to_string(@dk.scope == "daemon")}
          title="everything on the daemon: the leftovers of the workspaces before this one included"
        >The daemon</button>
        <%= if @stats do %>
          <span class="sep"></span>
          <button
            class="btn"
            type="button"
            phx-click="dk_stats"
            aria-pressed={to_string(@dk.stats)}
            title="docker stats, streamed only while this document is open"
          >Stats</button>
        <% end %>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # The daemon's lines with the disk's after `storage`, where the root
  # is named: one a kind — images, containers, volumes, build cache —
  # with the count, the size, how many are in use and what is
  # reclaimable, as `system df` says; one line saying it is being
  # measured until it is. It was a table under Volumes until 2026-09-16,
  # and the disk is the daemon's, not the volumes'.
  defp daemon_lines(%{daemon: daemon, df: df}) do
    Enum.flat_map(daemon, fn
      {"storage", _} = kv -> [kv | disk_lines(df)]
      kv -> [kv]
    end)
  end

  defp disk_lines(nil), do: [{"disk", "measuring: docker system df takes seconds…"}]

  defp disk_lines(df),
    do:
      for(
        r <- df,
        do:
          {disk_kind(r.type),
           "#{r.total} · #{r.size} · #{r.active} in use · #{r.reclaimable} reclaimable"}
      )

  defp disk_kind("Local Volumes"), do: "volumes"
  defp disk_kind(type), do: String.downcase(type)

  # --- Containers -----------------------------------------------------------------

  attr :dk, :map, required: true
  attr :status, :map, default: nil
  attr :jobs, :list, required: true

  defp containers_doc(assigns) do
    assigns =
      assign(assigns,
        project: assigns.status && assigns.status["compose_project"],
        deployment: assigns.status && assigns.status["deployment"]
      )

    ~H"""
    <.toolbar dk={@dk} stats={true} />
    <p :if={is_nil(@dk.rows)} class="note">Reading the daemon…</p>
    <p :if={@dk.rows == []} class="note">No containers in this scope.</p>
    <div :if={@dk.rows not in [nil, []]} class="tbl">
      <table class="wide">
        <tr>
          <th>service</th><th>state</th><th>since</th><th class="dim num">restarts</th><th title="published on the host by the container that owns the network namespace — the pod's, for the workspace; a port may not answer to a browser">
            ports
          </th><th class="num">cpu</th><th class="num">memory</th><th></th>
        </tr>
        <%= for c <- @dk.rows do %>
          <% mine = Console.Docker.mine?(c, @project) %>
          <% live = @dk.live[c.name] %>
          <tr
            class={[@dk.pick == c.name && "on", c.state != "running" && "dead", not mine && "theirs"]}
            phx-click="dk_pick"
            phx-value-name={c.name}
            title={"#{c.name}: the card"}
          >
            <td class="k" title={c.image}>
              {if c.console?, do: "the console", else: c.service}
              <span :if={not mine} class="of">{c.project}</span>
              <span class="hint">{c.image |> String.split("/") |> List.last()}</span>
            </td>
            <td>
              <.chip class={elem(reading(c), 1)}>{elem(reading(c), 0)}</.chip>
            </td>
            <td class="dim">{since(c)}</td>
            <td class="num dim" title={"restart policy: #{c.policy}"}>{c.restarts}</td>
            <td class="ports">
              <%!-- The port's square wears its service's colour, as the Logs
                    pills and the events do: one colour for one service
                    everywhere. --%>
              <%= for p <- c.ports, [host, inside] = String.split(p, "→") do %>
                <div class="port">
                  <.door_ref
                    label={inside}
                    path={"localhost:#{host}"}
                    href={"http://localhost:#{host}"}
                    kind="port"
                  />
                </div>
              <% end %>
            </td>
            <td class="num cpu">{(live && live.cpu) || ""}</td>
            <td class="num mem" title={live && "#{live.mem} of #{live.limit} · #{live.pids} pids"}>
              {(live && live.mem) || ""}
            </td>
            <td class="act">
              <% logs_why =
                cond do
                  c.console? ->
                    "the console's own lines are not the project's: ./wb.sh console logs, from the host"

                  not mine ->
                    "of another workspace: this console follows only its own"

                  true ->
                    nil
                end %>
              <button
                class={["btn mini", logs_why && "unlit"]}
                type="button"
                aria-disabled={logs_why && "true"}
                phx-click={!logs_why && "logs_of"}
                phx-value-service={c.service}
                title={logs_why || "the log lines this container writes, alone — #{c.service}"}
              >Logs</button>
              <.restart c={c} mine={mine} deployment={@deployment} jobs={@jobs} />
            </td>
          </tr>
        <% end %>
      </table>
    </div>
    <.card :if={@dk.card} card={@dk.card} live={@dk.live[@dk.card.name]} />
    <p :if={@dk.pick && is_nil(@dk.card)} class="note">Reading {@dk.pick}…</p>
    """
  end

  # Restart: the one act on a single container that leaves the deployment whole.
  attr :c, :map, required: true
  attr :mine, :boolean, required: true
  attr :deployment, :any, default: nil
  attr :jobs, :list, required: true

  defp restart(assigns) do
    busy =
      Enum.any?(
        assigns.jobs,
        &(&1.state in [:running, :queued] and
            elem(&1.kind, 0) in [:up, :stop, :down, :build, :restart])
      )

    # The console restarts itself: `docker restart` on its own container
    # keeps the image, the mounts, the env and the port, and this page
    # reconnects when it is back. A new image or another workspace is
    # a recreate — ./wb.sh console up, from the host — and the console says
    # so where it applies (rebind). Since 2026-09-16; it was refused.
    why =
      cond do
        assigns.c.console? ->
          nil

        not assigns.mine ->
          "of another workspace: this console drives only its own"

        assigns.c.state != "running" ->
          "#{assigns.c.service} is not running: Deploy → Up brings the deployment up whole"

        busy ->
          "a job on the deployment is running"

        true ->
          nil
      end

    assigns =
      assign(assigns,
        why: why,
        title:
          cond do
            why ->
              why

            assigns.c.console? ->
              "docker restart #{assigns.c.name} — the console restarts itself, and this page reconnects in seconds; a new image or another workspace wants ./wb.sh console up, from the host"

            true ->
              "./wb.sh restart --deploy #{assigns.deployment || "dev"} #{assigns.c.service} — the same service, the same image, up again; the deployment stays whole"
          end
      )

    ~H"""
    <button
      class={["btn mini", @why && "unlit"]}
      type="button"
      aria-disabled={@why && "true"}
      title={@title}
      phx-click={!@why && if(@c.console?, do: "dk_restart_console", else: "dk_restart")}
      phx-value-service={@c.service}
    >
      Restart
    </button>
    """
  end

  # The container's face, as the rail's Containers reads it: one word
  # and one colour for the same state everywhere — healthy or running
  # good, starting busy, unhealthy bad, exited 0 an absence, exited
  # otherwise with its code, created, paused and restarting a warning.
  # This screen had a reading of its own that called a running
  # unhealthy container busy and an exit code nothing.
  defp reading(c),
    do:
      ConsoleWeb.Cartridges.container_reading(%{
        "State" => c.state,
        "Health" => c.health,
        "ExitCode" => c.exit
      })

  @doc """
  The since column: Docker's status line with only its time left.
  Docker writes every status the same way — a state word, a parenthesis
  when there is one, the time: `Up 4 hours (healthy)`, `Exited (0) 7
  minutes ago`, `Restarting (1) 5 seconds ago`, `Created` — and the
  state and the exit code are the state column's already, the health
  its dot's. So the word and both parentheses go: `4 hours`, `7 minutes
  ago`, `5 seconds ago`, nothing for a container that never ran. The
  `ago` stays: how long it has been up and how long since it stopped
  are different times, and the word is what tells them apart.
  """
  def since(%{status: s}),
    do:
      (s || "")
      |> String.replace(~r/^\S+( \(\d+\))? ?/, "")
      |> String.replace(~r/ ?\([^)]*\)$/, "")

  # --- the card -------------------------------------------------------------------

  attr :card, :map, required: true
  attr :live, :any, default: nil

  defp card(assigns) do
    ~H"""
    <div class="ficha" id={"card-" <> @card.name}>
      <header>
        <h3>{@card.name}</h3>
        <.chip class={elem(reading(@card), 1)}>{elem(reading(@card), 0)}</.chip>
        <span class="note">{@card.image}<span :if={@card.started}> · started {stamp(@card.started)}</span><span :if={
          @card.finished
        }> · ended {stamp(@card.finished)} with {@card.exit}</span>
        · {@card.restarts} restarts<span :if={@card.oom}> · killed for memory</span></span>
      </header>
      <div class="grid">
        <div>
          <p class="cap">Process</p>
          <dl>
            <dt>command</dt><dd>{@card.command}</dd>
            <dt>user</dt><dd>
              {@card.user || "root"}<span :if={@card.workdir} class="m"> in {@card.workdir}</span>
            </dd>
            <dt>restart</dt><dd>{@card.policy}</dd>
            <dt>network</dt><dd>
              {@card.network}<span :for={{n, ip} <- @card.addresses} class="m"> · {n} {ip}</span><span
                :if={@card.addresses == []}
                class="m"
              > · no address of its own</span>
            </dd>
            <dt>ports</dt><dd>
              {if @card.ports == [], do: "none published", else: Enum.join(@card.ports, " · ")}
            </dd>
            <dt>limits</dt><dd><span class="m">{limits(@card)}</span></dd>
            <dt :if={@card.pid}>pid</dt><dd :if={@card.pid}>
              {@card.pid}<span :if={@live} class="m"> · {@live.pids} processes · cpu {@live.cpu} · {@live.mem} of {@live.limit} · net {@live.net} · disk {@live.block}</span>
            </dd>
          </dl>
        </div>
        <div>
          <p class="cap">Healthcheck</p>
          <dl :if={@card.healthcheck}>
            <dt>test</dt><dd>{@card.healthcheck.test}</dd>
            <dt>every</dt><dd>
              {@card.healthcheck.interval}<span class="m"> · timeout {@card.healthcheck.timeout} · {@card.healthcheck.start} of grace · {@card.healthcheck.retries} failures</span>
            </dd>
            <dt>probes</dt><dd>
              <span :for={p <- @card.probes} class={p.exit != 0 && "bad"}>
                {clock(p.at)} {probe_word(p)}
                <span :if={p.ms} class="m">{p.ms} ms</span> ·
              </span>
              <span :if={@card.probes == []} class="m">none yet</span>
            </dd>
          </dl>
          <p :if={is_nil(@card.healthcheck)} class="note">
            No healthcheck: running is all the daemon knows of it.
          </p>
        </div>
        <div>
          <p class="cap">Mounts</p>
          <dl>
            <%= for m <- @card.mounts do %>
              <dt>{m.type}</dt><dd>{short_path(m.from)} → {m.to}<span class="m">{m.mode}</span></dd>
            <% end %>
          </dl>
          <p :if={@card.mounts == []} class="note">Nothing mounted.</p>
        </div>
        <div class="full">
          <p class="cap">Env</p>
          <pre class="env"><.env_line :for={line <- @card.env} line={line} /></pre>
        </div>
      </div>
    </div>
    """
  end

  attr :line, :string, required: true

  defp env_line(assigns) do
    assigns =
      assign(assigns,
        parts:
          case Regex.run(~r/^(\w+=)(.*)$/, assigns.line) do
            [_, k, v] -> [{"k", k}, {if(String.contains?(v, "•"), do: "m"), v}]
            _ -> [{nil, assigns.line}]
          end
      )

    # One element per line and no whitespace of its own inside it: the
    # pre keeps every space it is given (see the Project screen's env).
    ~H"""
    <div class="ln"><span :for={{cls, text} <- @parts} class={cls}>{text}</span></div>
    """
  end

  defp limits(%{memory: m, cpus: c}) when m in [nil, 0] and c in [nil, 0],
    do: "none: the machine's memory and cpu"

  defp limits(%{memory: m, cpus: c}),
    do:
      Enum.join(
        Enum.reject(
          [
            m not in [nil, 0] && Console.Docker.human(m),
            c not in [nil, 0] && "#{c / 1_000_000_000} cpus"
          ],
          &(!&1)
        ),
        " · "
      )

  # A bind's host path is long and the workbench's: the workspace's tail says which.
  defp short_path(path) do
    case String.split(path || "", "/_workspaces/") do
      [_, tail] -> "_workspaces/" <> tail
      _ -> path
    end
  end

  defp stamp(t) do
    case DateTime.from_iso8601(t) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
      _ -> t
    end
  end

  # A probe's verdict, in the card's words.
  defp probe_word(%{exit: 0}), do: "ok"
  defp probe_word(p), do: "exit #{p.exit}"

  defp clock(t) do
    case DateTime.from_iso8601(t || "") do
      {:ok, dt, _} -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> t
    end
  end

  # --- Images ---------------------------------------------------------------------

  attr :dk, :map, required: true
  attr :jobs, :list, required: true

  defp images_doc(assigns) do
    ~H"""
    <.toolbar dk={@dk} />
    <p :if={is_nil(@dk.images)} class="note">Reading the daemon…</p>
    <%= if @dk.images do %>
      <div class="tbl">
        <table class="wide">
          <tr>
            <th>image</th><th class="dim">id</th><th class="num">size</th><th class="dim">created</th><th>
            </th>
          </tr>
          <tr :for={i <- @dk.images.images} class={!i.mine? && "theirs"}>
            <td class="k mono">
              <%!-- A name links to its repository where the registry has a
                    page for it — Docker Hub's two shapes, Microsoft's —
                    and stays a name for a local image or a registry
                    with no page (Console.Docker.repo_url/1). --%>
              <%= for n <- i.names do %>
                <a
                  :if={Console.Docker.repo_url(n)}
                  class="nm"
                  href={Console.Docker.repo_url(n)}
                  target="_blank"
                  rel="noopener"
                  title="the image's page at its registry"
                >{n}</a>
                <span :if={!Console.Docker.repo_url(n)} class="nm">{n}</span>
              <% end %>
            </td>
            <td class="dim">{i.id}</td>
            <td class="num">{i.size}</td>
            <td class="dim">{i.age}</td>
            <td class="act">
              <.remove_button names={i.names} used_by={i.used_by} word="used by" jobs={@jobs} />
            </td>
          </tr>
        </table>
      </div>
      <p :if={@dk.images.images == []} class="note">No images in this scope.</p>
      <p :if={@dk.images.dangling > 0} class="note">
        {@dk.images.dangling} untagged image{if @dk.images.dangling == 1, do: "", else: "s"}, {@dk.images.dangling_size}: the layers a prod bake leaves behind.
        <code>./wb.sh prune --images</code>
        removes them.
      </p>
      <p class="note">
        An image with several names is one image, and Remove takes every name: the layers go with the last. The app's
        <code>:local</code>
        and the workbench's own share their first layers on disk.
      </p>
    <% end %>
    """
  end

  # Remove, on an image's or a volume's row: `./wb.sh prune NAME…`,
  # every name an image wears, confirmed in Jobs. Unlit while a
  # container uses it — the console's own among them, on the
  # workbench's image and its build volume — naming the containers,
  # since docker would refuse it too; and while a removal is already
  # asked. A volume's title says what the image's need not: the data
  # does not come back. Since 2026-09-16.
  attr :names, :list, required: true
  attr :used_by, :list, required: true
  attr :word, :string, required: true, doc: "how the users hold it: used by, mounted by"
  attr :jobs, :list, required: true

  defp remove_button(assigns) do
    busy =
      Enum.any?(
        assigns.jobs,
        &(&1.state in [:running, :queued, :pending] and elem(&1.kind, 0) in [:prune, :remove])
      )

    why =
      cond do
        assigns.used_by != [] -> "#{assigns.word} #{Enum.join(assigns.used_by, ", ")}"
        busy -> "a removal is already asked"
        true -> nil
      end

    assigns =
      assign(assigns,
        why: why,
        line: Enum.join(assigns.names, " "),
        data:
          if(assigns.word == "mounted by",
            do: "its data goes with it, and does not come back; ",
            else: ""
          )
      )

    ~H"""
    <.job_button
      label="Remove"
      class="mini"
      why={@why}
      event="dk_remove"
      title={"./wb.sh prune #{@line} — #{@data}asks for your word first, in Jobs"}
      phx-value-names={@line}
    />
    """
  end

  # --- Volumes, and the disk ------------------------------------------------------

  attr :dk, :map, required: true
  attr :status, :map, default: nil
  attr :jobs, :list, required: true

  defp volumes_doc(assigns) do
    assigns =
      assign(assigns,
        project: assigns.status && assigns.status["exists"] && assigns.status["compose_project"]
      )

    ~H"""
    <.toolbar dk={@dk} />
    <p :if={is_nil(@dk.volumes)} class="note">Reading the daemon…</p>
    <%= if @dk.volumes do %>
      <div class="tbl">
        <table class="wide">
          <tr>
            <th>volume</th><th class="num">size</th><th>mounted by</th><th class="dim">project</th><th>
            </th>
          </tr>
          <tr :for={v <- @dk.volumes} class={!v.mine? && "theirs"}>
            <td class="k mono">
              {if v.anonymous, do: String.slice(v.name, 0, 12) <> "…", else: v.name}<span
                :if={v.anonymous}
                class="of"
              >anonymous</span>
            </td>
            <td
              class="num dim"
              title={is_nil(@dk.sizes) && "measuring: docker system df -v takes seconds"}
            >
              {size_of(@dk.sizes, v.name)}
            </td>
            <td>{if v.used_by == [], do: "nobody", else: Enum.join(v.used_by, ", ")}</td>
            <td class="dim">{v.project || "—"}</td>
            <td class="act">
              <.remove_button names={[v.name]} used_by={v.used_by} word="mounted by" jobs={@jobs} />
            </td>
          </tr>
        </table>
      </div>
      <p :if={@dk.volumes == []} class="note">No volumes in this scope.</p>
      <p :if={@project} class="note">
        <code>./wb.sh prune --build</code>
        removes {@project}_build and {@project}_deps, the build volumes: the next up compiles from scratch.
      </p>
      <p class="note">
        <code>./wb.sh prune</code>
        removes what the other workspaces of this workbench left: their stopped containers, networks and volumes, a dead database's data included; never this workspace's deployment, the console, nor anything else on the daemon.
      </p>
    <% end %>
    """
  end

  defp size_of(nil, _), do: "…"
  defp size_of(sizes, name), do: if(sizes[name] in [nil, "N/A"], do: "—", else: sizes[name])

  # --- Networks -------------------------------------------------------------------

  attr :dk, :map, required: true

  defp networks_doc(assigns) do
    ~H"""
    <.toolbar dk={@dk} />
    <p :if={is_nil(@dk.networks)} class="note">Reading the daemon…</p>
    <div :if={@dk.networks} class="tbl">
      <table class="wide">
        <tr>
          <th>network</th><th class="dim">driver</th><th class="dim">subnet</th><th>on it</th>
        </tr>
        <tr :for={n <- @dk.networks} class={!n.mine? && "theirs"}>
          <td class="k mono">{n.name}</td>
          <td class="dim">{n.driver}</td>
          <td class="dim">{n.subnet}</td>
          <td class="wrap">{if n.on == [], do: "nobody", else: Enum.join(n.on, ", ")}</td>
        </tr>
      </table>
    </div>
    <p :if={@dk.networks} class="note">
      The workspace's app and the services its cartridges bring beside it are not on any network of their own: they share the pod's — the
      <code>pod</code>
      container's — and reach each other on localhost.
    </p>
    """
  end

  # --- Events ---------------------------------------------------------------------

  attr :dk, :map, required: true
  attr :status, :map, default: nil

  defp events_doc(assigns) do
    project = assigns.status && assigns.status["compose_project"]

    events =
      assigns.dk.events
      |> Enum.filter(
        &(assigns.dk.scope == "daemon" or &1.name == "workbench_console" or
            (not is_nil(project) and &1.project == project))
      )
      |> Enum.reverse()

    assigns = assign(assigns, events: events, project: project)

    ~H"""
    <.toolbar dk={@dk}>
      <span class="sep"></span>
      <span class="note">every die, oom or health_status of this workspace reads the status again: what the rail could not know</span>
    </.toolbar>
    <div class="logmeta">
      <span>docker events · since the console started · the healthchecks' exec_* dropped at the source · the last 500 kept</span>
      <span>{length(@events)} lines</span>
    </div>
    <div class="viewport">
      <div class="lines" id="dk-events">
        <div :for={e <- @events} class={["ln", event_class(e)]}>
          <span class="t">{clock(e.ts && DateTime.to_iso8601(e.ts))}</span>
          <span class="s" style={"--svc:" <> svc_color(@status, e)}>{who(e)}</span>
          <span class="m">{e.type} {e.action}<span :if={e.detail}>: {e.detail}</span><span :if={
            e.exit
          }> · exit {e.exit}</span><span :if={e.signal}> · signal {e.signal}</span><span :if={
            e.type != "container" and e.name
          }>{e.name}</span></span>
        </div>
        <div :if={@events == []} class="ln dim">
          <span class="t"></span><span class="s"></span><span class="m">Nothing yet: what Docker does on its own lands here as it happens.</span>
        </div>
      </div>
    </div>
    """
  end

  defp event_class(%{type: "container", action: "die", exit: exit}) when exit not in [nil, "0"],
    do: "error"

  defp event_class(%{type: "container", action: "oom"}), do: "error"

  defp event_class(%{type: "container", action: "health_status", detail: "unhealthy"}),
    do: "error"

  defp event_class(%{type: "container", action: "kill"}), do: "warn"
  defp event_class(%{type: "container"}), do: nil
  defp event_class(_), do: "dim"

  defp who(%{type: "container", service: s}) when is_binary(s), do: s
  defp who(%{type: "container", name: n}) when is_binary(n), do: n
  defp who(_), do: "daemon"

  # A container of a compose service wears its role's colour, asked of
  # who knows what the service is (ConsoleWeb.Services); the daemon's
  # own lines, and a container of no service, go dim.
  defp svc_color(status, %{type: "container", service: s}) when is_binary(s),
    do: ConsoleWeb.Services.color(status, s)

  defp svc_color(_status, _), do: "var(--term-dim)"
end
