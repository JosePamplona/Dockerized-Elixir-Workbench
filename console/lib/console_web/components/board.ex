defmodule ConsoleWeb.Board do
  @moduledoc """
  The rail: the configured workspace, as the status says it — the name
  and the path, then what answers (Services & Doors), what is baked and
  up (Deployments, Containers), what is in it (Cartridges), and last
  Git, which is what has happened to it rather than what it is
  (2026-09-10).
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Square, only: [square: 1]
  alias ConsoleWeb.{Cartridges, Record}

  attr :status, :map, default: nil

  attr :rebind, :map,
    default: nil,
    doc: "the mount this console was started for, when config.conf names another workspace"

  attr :catalog, :list, default: []
  attr :folded, :any, default: nil, doc: "the section keys folded away, a MapSet"
  attr :reads, :any, default: %{}, doc: "what the doors answered when called, by href, or :asking"

  attr :reading, :any,
    default: false,
    doc: "a reading in flight: :fast, :full, or false — the empty board's own word"

  attr :busy, :boolean, default: false, doc: "a deploy job is in flight"
  attr :error, :string, default: nil

  def board(assigns) do
    ~H"""
    <section :if={is_nil(@status)} class="ws">
      <span class="label">Workspace</span>
      <p class="name">{if @reading, do: "reading…", else: "unread"}</p>
      <p :if={@error} class="note">{@error}</p>
      <p :if={!@error} class="note">
        ./wb.sh status --json — a container start and a Mix boot: seconds, more on a busy host.
      </p>
    </section>
    <%= if @status do %>
      <.workspace status={@status} rebind={@rebind} />
      <.services_doors status={@status} catalog={@catalog} folded={@folded} reads={@reads} />
      <.deployments status={@status} busy={@busy} folded={@folded} stale={@reading == :full} />
      <.containers status={@status} busy={@busy} folded={@folded} />
      <.inserted status={@status} catalog={@catalog} folded={@folded} stale={@reading == :full} />
      <.git status={@status} folded={@folded} />
      <p :if={@error} class="note">{@error}</p>
    <% end %>
    """
  end

  # Every section below the workspace has the same head — its name, and a
  # summary of what it holds — and that summary is what makes folding
  # cheap: a folded section still says `4 of 4 running`, `2 open by
  # cartridges`, `6 cartridges · 2 the workbench can eject`. The rail
  # keeps its table of contents whether or not the tables are open.
  #
  # The fold lives on the server. A class put on the section by the
  # client is wiped by the next status: these sections re-render often,
  # and LiveView restores what its own template says. What the browser
  # keeps is only the memory of it, in localStorage, the way it keeps the
  # ground and the rail's width — the Folds hook hands it back on mount.
  attr :key, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, default: nil
  attr :folded, :any, default: nil
  slot :inner_block, doc: "a control at the head's right edge, beside the fold"

  defp head(assigns) do
    ~H"""
    <%!-- The fold is a small square at the head's edge, its chevron
          turned by aria-expanded, and the control a screen reader gets.
          The head itself carries the same phx-click for the pointer, so
          the name and the empty stretch fold too: LiveView fires only
          the binding closest to the click, so the knock's square and the
          fold's keep their own. It was the name as a .fold with a caret,
          and then a hit layer over the head, until 2026-09-12 — the
          layer sat over the bell whatever its z-index said. --%>
    <h2 phx-click="fold_section" phx-value-key={@key}>
      <span class="name">{@name}<span :if={@label} class="label">{@label}</span></span>
      {render_slot(@inner_block)}
      <.square
        mark="chevron"
        size="small"
        class="foldsq"
        label={"#{@name}: fold, or open"}
        aria-expanded={to_string(not folded?(@folded, @key))}
        phx-click="fold_section"
        phx-value-key={@key}
      />
    </h2>
    """
  end

  defp folded?(nil, _key), do: false
  defp folded?(folded, key), do: MapSet.member?(folded, key)

  # A reading in flight used to be said here too, with a busy chip beside
  # the label. It is said in the band now — one place, always in front —
  # and two places saying the same thing is the thing the house keeps
  # learning not to do. The empty board keeps its own word, which is not
  # the same sentence: with nothing on it, "reading…" IS the board.
  # The console is bound to the workspace it was started for: its
  # container mounts it, and the volumes of that project, and cannot
  # mount another. Named another since, config.conf is obeyed — every
  # verb reads it — but each mix and git of a job goes to a container
  # of its own, the way the host runs them. Said here, with the way
  # out: `console` as a job, which starts the console again for the
  # workspace named now, on the same address.
  attr :status, :map, required: true
  attr :rebind, :map, default: nil

  defp workspace(assigns) do
    ~H"""
    <section class="ws">
      <span class="label">Workspace</span>
      <p class="name">{@status["compose_project"] || "no project"}</p>
      <div class="path mono">{@status["workspace"]}</div>
      <p :if={@rebind} class="note">
        This console was started for <span class="mono">{@rebind.project}</span>
        at <span class="mono">{@rebind.workspace}</span>.
        Until it starts again for this workspace, every mix and git of a job runs in a container of its own.
        <button
          class="btn mini"
          phx-click="run"
          phx-value-args="console up"
          title="./wb.sh console up — the console comes up again for this workspace, on the same address; this page reconnects on its own"
        >
          Start again
        </button>
      </p>
    </section>
    """
  end

  # Every address the workspace answers to, in one place: the services
  # of the deployment that is up (dev's file when none is) as ports with
  # what docker compose ps says of each, then every door the inserted
  # cartridges open on the app's port, with the mention of who opened
  # it. The faces are the Record's; a door here carries no reading, the
  # rail calls nothing. Neither fits beside its row's other columns at
  # 380px, which is why they are gathered here and not in Cartridges and
  # Deployments (tried on 2026-09-09).
  attr :status, :map, required: true
  attr :catalog, :list, default: []
  attr :folded, :any, default: nil
  attr :reads, :any, default: %{}

  defp services_doors(assigns) do
    rows = Record.deployments(assigns.status)
    up = assigns.status["deployment"]
    deployment = Enum.find(rows, &(&1.deploy == (up || "dev"))) || %{services: []}
    entry = fn c -> Enum.find(assigns.catalog, &(&1["name"] == c["name"])) || c end

    doors =
      for c <- Cartridges.installed(assigns.status),
          a <- Record.addresses(assigns.status, c, entry.(c), assigns.reads),
          a.kind in ["route", "output"],
          do: {c, a}

    assigns =
      assign(assigns,
        # A row is a door on the host: a port the compose publishes, or a
        # route. A port inside the pod (`database :5432`), the pod itself,
        # the one-shot `migrate`, are on Containers and on the Deployments
        # sheet, which is the whole map, solid and hollow; the rail is the
        # bell. Since 2026-09-16; the inside ports had a hollow row here.
        services: Enum.filter(deployment.services, &(&1.kind == "port")),
        deployment: up || "dev",
        up: up != nil,
        knock: Record.knockable?(up != nil, Enum.map(doors, &elem(&1, 1))),
        doors: doors,
        sum:
          (fn n ->
             "#{n} service#{if n == 1, do: "", else: "s"} · #{length(doors)} door#{if length(doors) == 1, do: "", else: "s"}"
           end).(Enum.count(deployment.services, &(&1.kind == "port")))
      )

    ~H"""
    <section class={folded?(@folded, "doors") && "folded"}>
      <.head key="doors" name="Services & Doors" label={@sum} folded={@folded}>
        <.square
          :if={@knock}
          mark="bell"
          size="small"
          label="Knock on every door"
          class="knock"
          phx-click="knock"
          aria-busy={to_string(@reads == :asking)}
          title="knock: call every open route once and read every page off the disk again — the Record hears the same"
        />
        <.square
          :if={!@knock}
          mark="bell"
          size="small"
          label="Knock on every door"
          class="knock unlit"
          aria-disabled="true"
          title="nothing is up and no page is kept: deploy, and knock — every door is called once and answers in a chip"
        />
      </.head>
      <div class="urls">
        <.door_ref
          :for={a <- @services}
          label={a.label}
          path={a.path}
          href={a.href}
          why={a.why}
          kind={a.kind}
          read={a.read}
        />
        <.door_ref
          :for={{c, a} <- @doors}
          label={a.label}
          path={a.path}
          href={a.href}
          why={a.why}
          kind={a.kind}
          port={a.port}
          who={c["name"]}
          read={a.read}
          build={a[:build]}
        />
      </div>
    </section>
    """
  end

  # The three deployments as the Record draws them — baked, up —
  # with the row's one action beside. The services go in Services & Doors:
  # a port face does not fit in a sixth column of a 380px rail.
  # What comes off the project — in sync or not, the cartridges in —
  # is the last full reading's until the next lands: while one is in
  # flight it is dimmed, with the reason, not asserted.
  @stale_why "reading the project again: this is the last reading's, until the new one lands"

  # Every head on the rail says what the section has — "3 services · 2
  # doors", "3 of 4 running", "clean", "8 in". This one said "topology",
  # which is what the section IS and not what it holds, so it was the
  # one head a reader had to open to learn anything (2026-09-10).
  defp deployments_sum(rows, up) do
    baked = Enum.count(rows, & &1.baked)

    cond do
      baked == 0 -> "none baked"
      up -> "#{baked} baked · #{up} up"
      true -> "#{baked} baked · nothing up"
    end
  end

  defp deployments(assigns) do
    rows = Record.deployments(assigns.status)

    assigns =
      assign(assigns,
        rows: rows,
        sum: deployments_sum(rows, assigns.status["deployment"]),
        why: @stale_why,
        not_baked:
          if(assigns.status["exists"] == true,
            do: "Bake, or Up, writes it",
            else: "the workspace is empty: Deploy → Project creates one"
          )
      )

    ~H"""
    <section class={folded?(@folded, "deployments") && "folded"}>
      <.head key="deployments" name="Deployments" label={@sum} folded={@folded} />
      <table class="rows" id="deployments">
        <tr class="hd">
          <th></th>
          <th title="the deployment's compose file: baked, out of sync with the project, or not baked yet">
            compose file
          </th>
          <th>status</th>
          <th></th>
        </tr>
        <%= for d <- @rows do %>
          <tr>
            <td class="k">{d.deploy}</td>
            <td class={["st", @stale && "stale"]} title={@stale && @why}>
              <.chip :if={!d.baked} class="off" title={@not_baked}>
                not baked
              </.chip>
              <.chip
                :if={d.baked && d.in_sync == false}
                class="warn"
                title="the file no longer says what the cartridges ask for: bake writes it again"
              >
                out of sync
              </.chip>
              <.chip :if={d.baked && d.in_sync != false} class="good">baked</.chip>
            </td>
            <td>
              <.chip :if={d.status == "up"} class="good">up</.chip>
              <.chip
                :if={d.status == "stopped"}
                class="off"
                title="its containers are there, stopped: Up brings them back fast"
              >
                stopped
              </.chip>
              <.chip :if={d.status == "down"} class="off" title="no containers: Up creates them">
                down
              </.chip>
            </td>
            <td class="act">
              <.bake_button name={d.deploy} status={@status} busy={@busy} baked={d.baked} />
              <.deploy_button
                verb="down"
                name={d.deploy}
                status={@status}
                busy={@busy}
                baked={d.baked}
                present={d.present}
              />
              <.deploy_button
                :if={@status["deployment"] == d.deploy}
                verb="stop"
                name={d.deploy}
                status={@status}
                busy={@busy}
              />
              <.deploy_button
                :if={@status["deployment"] != d.deploy}
                verb="up"
                name={d.deploy}
                status={@status}
                busy={@busy}
                baked={d.baked}
              />
            </td>
          </tr>
        <% end %>
      </table>
    </section>
    """
  end

  # Bake: the file written again for the project as it is now, keeping
  # its ports, as one commit — `bake` for dev, `bake --deploy` for prod
  # and scaled (it was `build --deploy` for those two until 2026-09-10,
  # the only road wb.sh had to their files, and it built the release
  # image on the way). Always there: a file in sync can be baked again,
  # and one not baked yet is what this makes.
  attr :name, :string, required: true
  attr :status, :map, required: true
  attr :busy, :boolean, default: false
  attr :baked, :boolean, default: false

  attr :extra, :string,
    default: "",
    doc: "scaled's --replicas and --no-balancer, when they differ"

  attr :form, :string,
    default: nil,
    doc: "the picker it stands in, when it stands in one: pressed, it sends the form"

  def bake_button(assigns) do
    cmd = ConsoleWeb.Deploy.cmdline("bake", assigns.name, assigns.extra)

    why =
      cond do
        assigns.status["exists"] != true -> "the workspace is empty: Deploy → Project creates one"
        assigns.busy -> "a job is running"
        true -> nil
      end

    title =
      why ||
        cmd <>
          " — writes the #{assigns.name} compose #{if assigns.baked, do: "again ", else: ""}for the project as it is now, keeping its ports, as one commit" <>
          if(assigns.name == "dev",
            do: "; the dev Dockerfile too, when the seed moved",
            else: ""
          )

    assigns = assign(assigns, why: why, title: title, cmd: cmd)

    ~H"""
    <.job_button
      label="Bake"
      class="mini"
      args={String.replace_prefix(@cmd, "./wb.sh ", "")}
      title={@title}
      why={@why}
      form={@form}
      name={@form && "do"}
      value={@form && "bake #{@name}"}
    />
    """
  end

  # Build: the row's image, built without deploying — the dev image off
  # the project's Dockerfile.local, which `up` never rebuilds (the next
  # up recreates the containers with it), or the release image prod and
  # scaled share, which `up --deploy` builds again on its own way up.
  # Built here, nothing goes down: a build that fails leaves the
  # deployment that is up as it was. It stood in the foot beside Up
  # until 2026-09-10 and went to the CLI; back on 2026-09-11, on the
  # row, beside Bake — the file, then the image, then the status. The
  # flags `docker compose build` takes, --no-cache and the rest, stay
  # the CLI's: a button sends the line it says and nothing more.
  attr :name, :string, required: true
  attr :status, :map, required: true
  attr :busy, :boolean, default: false

  attr :extra, :string,
    default: "",
    doc: "scaled's --replicas and --no-balancer, when they differ"

  attr :form, :string,
    default: nil,
    doc: "the picker it stands in, when it stands in one: pressed, it sends the form"

  def build_button(assigns) do
    cmd = ConsoleWeb.Deploy.cmdline("build", assigns.name, assigns.extra)

    why =
      cond do
        assigns.status["exists"] != true -> "the workspace is empty: Deploy → Project creates one"
        assigns.busy -> "a job is running"
        true -> nil
      end

    title =
      why ||
        cmd <>
          if(assigns.name == "dev",
            do:
              " — builds the dev image again from the project's Dockerfile.local, without deploying: the next Up recreates the containers with it",
            else:
              " — builds the release image #{if assigns.name == "scaled", do: "every replica shares", else: "the prod deployment runs"}, without deploying; nothing goes down, and the file is baked on the way"
          ) <>
          " · --no-cache and the other docker compose build flags are the CLI's"

    assigns = assign(assigns, why: why, title: title, cmd: cmd)

    ~H"""
    <.job_button
      label="Build"
      class="mini"
      args={String.replace_prefix(@cmd, "./wb.sh ", "")}
      title={@title}
      why={@why}
      form={@form}
      name={@form && "do"}
      value={@form && "build #{@name}"}
    />
    """
  end

  # The row's one action, in the row's own words. Another deployment up
  # is the ordinary case: Up replaces it, and the title says so. The
  # other way is Stop, not Down: the containers stay for a fast Up
  # again; `down`, which removes them, stays a command of the shell.
  #
  # A verb the row cannot do now is unlit with the reason, not hidden
  # (2026-09-10): the three slots stay put down the table, and a row
  # says what it could do, not only what it can. Up and Stop share one
  # slot — the same question, and the row's state answers which.
  attr :verb, :string, required: true, values: ~w(up stop down)
  attr :present, :boolean, default: true, doc: "the deployment has containers: what down removes"
  attr :baked, :boolean, default: true, doc: "its compose file is in the workspace"
  attr :name, :string, required: true
  attr :status, :map, required: true
  attr :busy, :boolean, default: false

  def deploy_button(assigns) do
    running = assigns.status["deployment"]
    cmd = ConsoleWeb.Deploy.cmdline(assigns.verb, assigns.name, "")

    why =
      cond do
        assigns.status["exists"] != true ->
          "the workspace is empty: Deploy → Project creates one"

        assigns.busy ->
          "a job is running"

        not assigns.baked ->
          "not baked: Bake writes its compose file first"

        assigns.verb == "down" and not assigns.present ->
          "nothing to take down: no containers of this deployment"

        assigns.verb == "stop" and running != assigns.name ->
          "not up: nothing to stop"

        true ->
          nil
      end

    replaces = assigns.verb == "up" && running && running != assigns.name

    title =
      why ||
        cmd <>
          cond do
            replaces ->
              " — #{running} is running and goes down: one deployment at a time"

            assigns.verb == "stop" ->
              " — stops its containers and keeps them, for a fast Up again"

            assigns.verb == "down" ->
              " — removes its containers and network; the volumes stay"

            true ->
              ""
          end

    assigns = assign(assigns, why: why, title: title, cmd: cmd)

    ~H"""
    <.job_button
      label={%{"up" => "Up", "stop" => "Stop", "down" => "Down"}[@verb]}
      class="mini"
      args={String.replace_prefix(@cmd, "./wb.sh ", "")}
      title={@title}
      why={@why}
    />
    """
  end

  # Each container's way in, its log lines. No new power: the Logs
  # screen already does it, and this is the row saying which of them is
  # about *this* container — which is what was missing the day Docker
  # Desktop stopped being the place to look. A shell is opened from the
  # Terminal, whose row of containers this one no longer doubles
  # (2026-09-16). Nothing here starts,
  # stops or builds anything: a deployment goes up and down whole, and a
  # button that left half of one up would make the status say `dev` for
  # something that is not dev. The one act on a single container is the
  # Docker screen's restart, here too since 2026-09-15: the same
  # service, the same image, up again, and the deployment stays whole.
  defp containers(assigns) do
    cs = assigns.status["containers"] || []
    running = Enum.count(cs, &(&1["State"] == "running"))

    assigns =
      assign(assigns,
        cs: cs,
        sum: if(cs == [], do: "none", else: "#{running} of #{length(cs)} running")
      )

    ~H"""
    <section class={folded?(@folded, "containers") && "folded"}>
      <.head key="containers" name="Containers" label={@sum} folded={@folded} />
      <table class="rows acts" id="containers">
        <tr :for={c <- @cs}>
          <td class="k" title={c["Image"]}>
            {c["Service"]}<span class="hint">{short_image(c["Image"])}</span>
          </td>
          <td class="st">
            <.chip class={elem(Cartridges.container_reading(c), 1)} title={c["Status"]}>
              {elem(Cartridges.container_reading(c), 0)}
            </.chip>
          </td>
          <td class="act">
            <button
              class="btn mini"
              type="button"
              title={"the log lines this container writes, alone — #{c["Service"]}"}
              phx-click="logs_of"
              phx-value-service={c["Service"]}
            >Logs</button>
            <.restart_button c={c} deployment={@status["deployment"]} busy={@busy} />
          </td>
        </tr>
      </table>
    </section>
    """
  end

  # Restart, the Docker screen's one act on a single container, as the
  # row's second button, in the style of Logs: `./wb.sh restart
  # --deploy DEPLOY SERVICE`. Unlit, with the reason, while the container is not running
  # (Up brings the deployment up whole), while a job on the deployment
  # runs, and on the pause container, whose network namespace the others
  # share: restarted alone it would come back with a new one and leave
  # them on the old.
  attr :c, :map, required: true
  attr :deployment, :any, default: nil
  attr :busy, :boolean, default: false

  defp restart_button(assigns) do
    why =
      cond do
        assigns.c["Service"] == "pod" ->
          "the pause container holds the pod's network: restarted alone, the others would be left on the old one"

        assigns.c["State"] != "running" ->
          "#{assigns.c["Service"]} is not running: Deploy → Up brings the deployment up whole"

        assigns.busy ->
          "a job on the deployment is running"

        true ->
          nil
      end

    assigns =
      assign(assigns,
        why: why,
        cmd: "./wb.sh restart --deploy #{assigns.deployment || "dev"} #{assigns.c["Service"]}"
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
      phx-value-service={@c["Service"]}
    >
      Restart
    </button>
    """
  end

  # The image without its registry and namespace: `registry.k8s.io/pause`
  # and `dpage/pgadmin4` are where it was fetched from, and the column is
  # 121px wide. What is left is the name and the tag — which is the half
  # that says something — and the whole reference is in the cell's title.
  defp short_image(nil), do: ""
  defp short_image(image), do: image |> String.split("/") |> List.last()

  defp git(assigns) do
    ~H"""
    <section class={folded?(@folded, "git") && "folded"}>
      <.head key="git" name="Git" label={git_sum(@status["git"])} folded={@folded} />
      <div class="git">
        <%= if @status["git"]["repo"] do %>
          <div class="row">
            <span class="k">tree</span><.chip class={
              if @status["git"]["clean"], do: "good", else: "warn"
            }>
              {if @status["git"]["clean"], do: "clean", else: "dirty"}
            </.chip>
          </div>
          <div class="row">
            <span class="k">head</span><span class="head"><.head_ref head={@status["git"]["head"]} /></span>
          </div>
          <div class="row">
            <span class="k">signs as</span><span title={@status["git"]["identity"]}>{String.replace(
              @status["git"]["identity"] || "",
              ~r/ <.*/,
              ""
            )}</span>
          </div>
          <.link
            :if={not @status["git"]["clean"]}
            class="btn"
            patch="/project?paper=pending"
            title="the Changes paper: what a commit would take, and the commit with a title"
          >Commit changes</.link>
        <% end %>
      </div>
    </section>
    """
  end

  defp git_sum(%{"repo" => false}), do: "no repository"
  defp git_sum(g), do: if(g["clean"], do: "clean", else: "changes git does not have")

  # The cartridges in the project, on the Record's columns: the mention,
  # the origin, the edition. The addresses each opens are not here — at
  # 380px a door does not fit beside three columns — but in Services &
  # Doors above, with the mention beside each.
  defp inserted(assigns) do
    ins = Cartridges.installed(assigns.status)
    revertible = Enum.count(ins, &Cartridges.insert(assigns.status, &1["name"]))

    sum =
      if ins == [],
        do: "none",
        else: "#{length(ins)} in · #{revertible} the workbench can eject"

    assigns = assign(assigns, ins: ins, sum: sum, why: @stale_why)

    ~H"""
    <section class={folded?(@folded, "inserted") && "folded"}>
      <.head key="inserted" name="Cartridges" label={@sum} folded={@folded} />
      <table class={["rows", @stale && "stale"]} id="slots" title={@stale && @why}>
        <%= for c <- @ins do %>
          <tr>
            <td>
              <.cart_ref
                name={c["name"]}
                installed={true}
                version={c["version"] && c["version"]["version"]}
              />
            </td>
            <td class="og">
              <.chip :for={f <- Cartridges.facts(c)}>{f}</.chip>
              <.origin status={@status} c={c} />
            </td>
            <td
              class="muted ver"
              title={
                if c["version"],
                  do: "#{c["version"]["date"]} in its CHANGELOG",
                  else: "no CHANGELOG to read a version from"
              }
            >
              {if c["version"], do: "v#{c["version"]["version"]}", else: "unversioned"}
            </td>
          </tr>
        <% end %>
      </table>
    </section>
    """
  end

  # The origin, and for a cartridge that came by commit the commit itself
  # beside it: the mention opens History on the insert, its diff shown.
  defp origin(assigns) do
    {word, cls, why} = Cartridges.origin(assigns.status, assigns.c)
    insert = Cartridges.insert(assigns.status, assigns.c["name"])
    assigns = assign(assigns, word: word, cls: cls, why: why, insert: insert)

    ~H"""
    <.chip class={@cls} title={@why}>{@word}</.chip>
    <.commit_ref
      :if={@insert}
      sha={@insert["sha"]}
      subject={@insert["subject"]}
      date={@insert["date"]}
    />
    """
  end

  # HEAD as `wb.sh status` writes it, `SHA subject`: the sha a mention, the subject beside.
  attr :head, :any, default: nil

  defp head_ref(%{head: head} = assigns) when is_binary(head) and head != "" do
    [sha | subject] = String.split(head, " ", parts: 2)
    assigns = assign(assigns, sha: sha, subject: List.first(subject) || "")

    ~H"""
    <.commit_ref sha={@sha} subject={@subject} /> {@subject}
    """
  end

  defp head_ref(assigns), do: ~H"no commits yet"
end
