defmodule ConsoleWeb.Board do
  @moduledoc "The rail: the configured workspace, as the status says it."
  use Phoenix.Component
  import ConsoleWeb.Refs
  alias ConsoleWeb.{Cartridges, Record, Terminal}

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
      <.git status={@status} folded={@folded} />
      <.deployments status={@status} busy={@busy} folded={@folded} />
      <.containers status={@status} folded={@folded} />
      <.inserted status={@status} catalog={@catalog} folded={@folded} />
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
    <h2>
      <button
        class="fold"
        type="button"
        aria-expanded={to_string(not folded?(@folded, @key))}
        phx-click="fold_section"
        phx-value-key={@key}
      >
        {@name}<span :if={@label} class="label">{@label}</span>
      </button>
      {render_slot(@inner_block)}
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
          phx-value-args="console"
          title="./wb.sh console — the console comes up again for this workspace, on the same address; this page reconnects on its own"
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
          a.kind == "route",
          do: {c, a}

    assigns =
      assign(assigns,
        services: deployment.services,
        deployment: up || "dev",
        up: up != nil,
        doors: doors,
        sum:
          "#{length(deployment.services)} service#{if length(deployment.services) == 1, do: "", else: "s"} · #{length(doors)} door#{if length(doors) == 1, do: "", else: "s"}"
      )

    ~H"""
    <section class={folded?(@folded, "doors") && "folded"}>
      <.head key="doors" name="Services & Doors" label={@sum} folded={@folded}>
        <button
          :if={@up}
          class="go knock"
          type="button"
          phx-click="knock"
          aria-busy={to_string(@reads == :asking)}
          title="knock: call every door once and read what each answers — the Record hears the same"
        >
          <.bell /><span class="sr">Knock on every door</span>
        </button>
        <button
          :if={!@up}
          class="go knock unlit"
          type="button"
          aria-disabled="true"
          title="nothing is up: deploy, and knock — every door is called once and answers in a chip"
        >
          <.bell /><span class="sr">Knock on every door</span>
        </button>
      </.head>
      <div class="urls">
        <p :if={@services == [] and @doors == []} class="nothing">
          Nothing answers yet: deploy, and cartridges open doors here — docs, dashboard, mailbox, swagger…
        </p>
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
        />
      </div>
    </section>
    """
  end

  # The bell: a knock on every door, the reader's own act.
  def bell(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" aria-hidden="true"><path
      d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20a2 2 0 0 0 4 0"
      fill="none"
      stroke="currentColor"
      stroke-width="2.2"
      stroke-linecap="round"
      stroke-linejoin="round"
    /></svg>
    """
  end

  # The three deployments as the Record draws them — baked, up —
  # with the row's one action beside. The services go in Services & Doors:
  # a port face does not fit in a sixth column of a 380px rail.
  defp deployments(assigns) do
    assigns = assign(assigns, rows: Record.deployments(assigns.status))

    ~H"""
    <section class={folded?(@folded, "deployments") && "folded"}>
      <.head key="deployments" name="Deployments" label="docker compose" folded={@folded} />
      <table class="rows" id="deployments">
        <tr class="hd">
          <th></th>
          <th title="the deployment's compose file: baked, out of sync with the project, or not baked yet">
            file
          </th>
          <th>status</th>
          <th></th>
        </tr>
        <%= for d <- @rows do %>
          <tr>
            <td class="k">{d.deploy}</td>
            <td class="st">
              <.chip :if={!d.baked} class="off" title={"up --deploy #{d.deploy} bakes it"}>
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
              <.deploy_button
                :if={@status["deployment"] == d.deploy}
                verb="stop"
                name={d.deploy}
                status={@status}
                busy={@busy}
              />
              <.deploy_button
                :if={@status["deployment"] != d.deploy and d.baked}
                verb="up"
                name={d.deploy}
                status={@status}
                busy={@busy}
              />
              <.deploy_button
                :if={d.baked}
                verb="down"
                name={d.deploy}
                status={@status}
                busy={@busy}
                present={d.present}
              />
              <.bake_button name={d.deploy} status={@status} busy={@busy} baked={d.baked} />
            </td>
          </tr>
        <% end %>
      </table>
    </section>
    """
  end

  # Bake: the file written again for the project as it is now — `bake`
  # for dev, which keeps its ports; `build --deploy` for prod and scaled,
  # which is where wb.sh bakes those two, and builds the release image
  # they share on the way. Always there: a file in sync can be baked
  # again, and one not baked yet is what this makes.
  attr :name, :string, required: true
  attr :status, :map, required: true
  attr :busy, :boolean, default: false
  attr :baked, :boolean, default: false

  def bake_button(assigns) do
    verb = if assigns.name == "dev", do: "bake", else: "build"
    cmd = ConsoleWeb.Deploy.cmdline(verb, assigns.name, "")

    why =
      cond do
        assigns.status["exists"] != true -> "the workspace is empty: Deploy → Project creates one"
        assigns.busy -> "a job is running"
        true -> nil
      end

    title =
      why ||
        cmd <>
          cond do
            assigns.name == "dev" ->
              " — writes docker-compose.yml again for the project as it is now, keeping its ports"

            assigns.baked ->
              " — writes the #{assigns.name} compose again and builds the release image"

            true ->
              " — writes the #{assigns.name} compose and builds the release image"
          end

    assigns = assign(assigns, why: why, title: title, cmd: cmd)

    ~H"""
    <button
      class={["btn mini", @why && "unlit"]}
      aria-disabled={@why && "true"}
      title={@title}
      phx-click={!@why && "run"}
      phx-value-args={String.replace_prefix(@cmd, "./wb.sh ", "")}
    >
      Bake
    </button>
    """
  end

  # The row's one action, in the row's own words. Only two things stop
  # it — nothing to deploy into, a job in flight. Another deployment up
  # is the ordinary case: Up replaces it, and the title says so. The
  # other way is Stop, not Down: the containers stay for a fast Up
  # again; `down`, which removes them, stays a command of the shell.
  attr :verb, :string, required: true, values: ~w(up stop down)
  attr :present, :boolean, default: true, doc: "the deployment has containers: what down removes"
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

        assigns.verb == "down" and not assigns.present ->
          "nothing to take down: no containers of this deployment"

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
    <button
      class={["btn mini", @why && "unlit"]}
      aria-disabled={@why && "true"}
      title={@title}
      phx-click={!@why && "run"}
      phx-value-args={String.replace_prefix(@cmd, "./wb.sh ", "")}
    >
      {%{"up" => "Up", "stop" => "Stop", "down" => "Down"}[@verb]}
    </button>
    """
  end

  # Each container's two ways in. Neither is a new power: the Logs screen
  # and the Terminal already do both, and this is the row saying which of
  # them is about *this* container — which is what was missing the day
  # Docker Desktop stopped being the place to look. Nothing here starts,
  # stops or builds anything: a deployment goes up and down whole, and a
  # button that left half of one up would make the status say `dev` for
  # something that is not dev.
  defp containers(assigns) do
    cs = assigns.status["containers"] || []
    running = Enum.count(cs, &(&1["State"] == "running"))
    targets = Map.new(Terminal.targets(assigns.status), &{&1.name, &1})
    # Containers with no deployment above them: the app is gone and the
    # rest of the project is still standing. The board says so rather
    # than leaving three rows of `down` over a table of things that are
    # not — and it says where the way out is.
    left = cs != [] and is_nil(assigns.status["deployment"])

    assigns =
      assign(assigns,
        cs: cs,
        targets: targets,
        left: left,
        sum: if(cs == [], do: "none", else: "#{running} of #{length(cs)} running")
      )

    ~H"""
    <section class={folded?(@folded, "containers") && "folded"}>
      <.head key="containers" name="Containers" label={@sum} folded={@folded} />
      <table class="rows acts" id="containers">
        <tr :if={@cs == []}>
          <td class="nothing">
            {if @status["exists"],
              do: "No containers: the project is down. Deploy → Up.",
              else: "The workspace is empty: Deploy → Project."}
          </td>
        </tr>
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
            <.shell_button c={c} target={@targets[c["Service"]]} />
          </td>
        </tr>
      </table>
      <p :if={@left} class="note">
        No deployment is up and these are still here: Deploy → Down removes them.
      </p>
    </section>
    """
  end

  # A shell, on the containers that can hold one. Which is the house's
  # rule read carefully in both directions: a container that is down
  # stays here, unlit, because bringing it up is something the reader can
  # do — but `network` is the pause image and carries no shell at all, so
  # it is not marked, it is absent. Hiding is for what is not applicable
  # and never will be, and that is this and nothing else on the board.
  defp shell_button(assigns) do
    down = assigns.c["State"] != "running"
    shell = if assigns.target, do: Terminal.default_shell(assigns.target)
    assigns = assign(assigns, down: down, shell: shell)

    ~H"""
    <button
      :if={shellable?(@c)}
      class={["btn mini", @down && "unlit"]}
      type="button"
      aria-disabled={@down && "true"}
      title={
        if @down,
          do: "#{@c["Service"]} is not running: a session needs a container",
          else: "a #{@shell} session on #{@c["Service"]}, in the Terminal"
      }
      phx-click={!@down && "term_open"}
      phx-value-target={@c["Service"]}
      phx-value-shell={@shell}
    >
      {@shell || "shell"}
    </button>
    """
  end

  # The pause container owns the workspace's network namespace and its
  # ports, and sleeps: ~700 kB with no shell in them.
  defp shellable?(c), do: c["Service"] != "network"

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
            <span class="k">head</span><span>{@status["git"]["head"] || "no commits yet"}</span>
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
            title="the Pending paper: what is pending, and the commit with a title"
          >Commit pending changes</.link>
        <% else %>
          <p class="nothing">phx.new initialises the repository; new makes the first commit.</p>
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

    assigns = assign(assigns, ins: ins, sum: sum)

    ~H"""
    <section class={folded?(@folded, "inserted") && "folded"}>
      <.head key="inserted" name="Cartridges" label={@sum} folded={@folded} />
      <table class="rows" id="slots">
        <tr :if={@ins == []}>
          <td class="nothing">Nothing inserted yet: the shelf is in Cartridges.</td>
        </tr>
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

  defp origin(assigns) do
    {word, cls, why} = Cartridges.origin(assigns.status, assigns.c)
    assigns = assign(assigns, word: word, cls: cls, why: why)

    ~H"""
    <.chip class={@cls} title={@why}>{@word}</.chip>
    """
  end
end
