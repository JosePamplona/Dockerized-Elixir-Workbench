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
    <div class="toolbar">
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
      <code :if={@dk.daemon} class="code-box daemon"><span
        :for={{k, v} <- @dk.daemon}
        class="ln"
      ><span class="k">{k}</span>{v}</span></code>
    </div>
    """
  end

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
          </th><th class="num">cpu</th><th class="num">memory</th><th></th><th></th>
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
                <div
                  class="port"
                  style={service_color(c.service) && "--addr-port:#{service_color(c.service)}"}
                >
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
            <td class="act shell"><.shell c={c} mine={mine} /></td>
          </tr>
        <% end %>
      </table>
    </div>
    <.card :if={@dk.card} card={@dk.card} live={@dk.live[@dk.card.name]} />
    <p :if={@dk.pick && is_nil(@dk.card)} class="note">Reading {@dk.pick}…</p>
    """
  end

  # A shell on the containers that can hold one — the same rule as the board's.
  attr :c, :map, required: true
  attr :mine, :boolean, required: true

  defp shell(assigns) do
    shellable =
      assigns.mine and not assigns.c.console? and
        Regex.match?(
          ~r/^(app\d*|database|pgadmin|adminer|prometheus|grafana)$/,
          assigns.c.service
        )

    down = assigns.c.state != "running"
    # The Terminal's own rule: psql on the database, sh on the Alpine and
    # busybox images (pgAdmin, Adminer, Grafana, Prometheus), bash elsewhere.
    shell =
      case assigns.c.service do
        "database" -> "psql"
        s when s in ~w(pgadmin adminer prometheus grafana) -> "sh"
        _ -> "bash"
      end

    assigns = assign(assigns, shellable: shellable, down: down, shell: shell)

    ~H"""
    <button
      :if={@shellable}
      class={["btn mini", @down && "unlit"]}
      type="button"
      aria-disabled={@down && "true"}
      title={
        if @down,
          do: "#{@c.service} is not running: a session needs a container",
          else: "a #{@shell} session on #{@c.service}, in the Terminal"
      }
      phx-click={!@down && "term_open"}
      phx-value-target={@c.service}
      phx-value-shell={@shell}
    >
      {@shell}
    </button>
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

    why =
      cond do
        assigns.c.console? ->
          "the console: ./wb.sh console starts it again, from the host"

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
        cmd: "./wb.sh restart --deploy #{assigns.deployment || "dev"} #{assigns.c.service}"
      )

    ~H"""
    <button
      class={["btn mini", @why && "unlit"]}
      type="button"
      aria-disabled={@why && "true"}
      title={
        @why || @cmd <> " — the same service, the same image, up again; the deployment stays whole"
      }
      phx-click={!@why && "dk_restart"}
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

  # `Up 39 minutes (healthy)` says the health twice; `Exited (1) 36 hours ago` says it once.
  defp since(%{state: "running", status: s}),
    do: Regex.replace(~r/^Up /, Regex.replace(~r/ \(.*\)$/, s || "", ""), "")

  defp since(%{status: s}), do: s

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
            <th>image</th><th class="dim">id</th><th class="num">size</th><th class="dim">created</th>
          </tr>
          <tr :for={i <- @dk.images.images} class={!i.mine? && "theirs"}>
            <td class="k mono"><span :for={n <- i.names} class="nm">{n}</span></td>
            <td class="dim">{i.id}</td>
            <td class="num">{i.size}</td>
            <td class="dim">{i.age}</td>
          </tr>
        </table>
      </div>
      <p :if={@dk.images.images == []} class="note">No images in this scope.</p>
      <div class="acts">
        <.prune_button
          what="images"
          label={"Remove the #{@dk.images.dangling} untagged"}
          off={@dk.images.dangling == 0 && "no untagged images: nothing to remove"}
          jobs={@jobs}
        />
        <span class="note">wb.sh prune --images · the layers a prod bake leaves behind<span :if={
          @dk.images.dangling > 0
        }> · {@dk.images.dangling_size}</span>
        · asks first</span>
      </div>
      <p class="note">
        An image with several names is one image: the app's <code>:local</code>
        is the toolchain's, tagged for each workspace.
      </p>
    <% end %>
    """
  end

  attr :what, :string, required: true
  attr :label, :string, required: true
  attr :off, :any, default: nil
  attr :jobs, :list, required: true

  defp prune_button(assigns) do
    busy =
      Enum.any?(
        assigns.jobs,
        &(&1.state in [:running, :queued, :pending] and elem(&1.kind, 0) == :prune)
      )

    why = assigns.off || (busy && "a prune is already asked")
    assigns = assign(assigns, why: why)

    ~H"""
    <.job_button
      label={@label}
      why={@why}
      event="dk_prune"
      title="asks for your word first, in Jobs"
      phx-value-what={@what}
    />
    """
  end

  # --- Volumes, and the disk ------------------------------------------------------

  attr :dk, :map, required: true
  attr :status, :map, default: nil
  attr :jobs, :list, required: true

  defp volumes_doc(assigns) do
    up = assigns.status && assigns.status["deployment"]

    assigns =
      assign(assigns,
        up: up,
        project: assigns.status && assigns.status["exists"] && assigns.status["compose_project"]
      )

    ~H"""
    <.toolbar dk={@dk} />
    <p :if={is_nil(@dk.volumes)} class="note">Reading the daemon…</p>
    <%= if @dk.volumes do %>
      <div class="tbl">
        <table class="wide">
          <tr>
            <th>volume</th><th class="num">size</th><th>mounted by</th><th class="dim">project</th>
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
          </tr>
        </table>
      </div>
      <p :if={@dk.volumes == []} class="note">No volumes in this scope.</p>
      <div class="acts">
        <.prune_button
          what="build"
          label="Remove the build volumes"
          off={
            cond do
              is_nil(@project) -> "this workspace has no project: no build volumes"
              @up -> "#{@up} is up and the app mounts them: Deploy → Down first"
              true -> nil
            end
          }
          jobs={@jobs}
        />
        <span class="note">wb.sh prune --build · {(@project || "the workspace") <> "_build and _deps"} · the next up compiles from scratch · asks first</span>
      </div>
      <h3 class="cap">Disk</h3>
      <p :if={is_nil(@dk.df)} class="note">Measuring the disk: docker system df takes seconds…</p>
      <div :if={@dk.df} class="tbl">
        <table class="wide">
          <tr>
            <th></th><th class="num">total</th><th></th><th class="num">takes</th><th class="num">
              reclaimable
            </th>
          </tr>
          <tr :for={r <- @dk.df}>
            <td class="k">{r.type}</td><td class="num">{r.total}</td><td class="dim">
              {r.active} in use
            </td><td class="num">{r.size}</td><td class="num">{r.reclaimable}</td>
          </tr>
        </table>
      </div>
      <div class="acts">
        <.prune_button what="" label="Remove what other workspaces left" jobs={@jobs} />
        <span class="note">wb.sh prune · the stopped containers, networks and volumes of the other workspaces of this workbench, a dead database's data included · never this workspace's deployment, the console, nor anything else on the daemon · asks first</span>
      </div>
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
      The workspace's app and the services beside it — database, pgadmin, adminer, prometheus, grafana — are not on any network of their own: they share the pod's — the
      <code>network</code>
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
          <span class="s" style={"--svc:" <> svc_color(e)}>{who(e)}</span>
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

  defp svc_color(%{type: "container", service: s})
       when s in ~w(app database pgadmin prometheus grafana network balancer migrate),
       do: "var(--svc-#{s})"

  defp svc_color(%{type: "container", service: "app" <> _}), do: "var(--svc-app)"
  defp svc_color(_), do: "var(--term-dim)"

  # A service's colour off the tokens, for its ports' squares; one
  # without a colour of its own keeps the port's blue — nil, and no
  # style: `--addr-port: var(--addr-port)` is a cycle, and paints nothing.
  defp service_color(s) when s in ~w(database pgadmin adminer network balancer migrate),
    do: "var(--svc-#{s})"

  defp service_color("app" <> _), do: "var(--svc-app)"
  defp service_color(_), do: nil
end
