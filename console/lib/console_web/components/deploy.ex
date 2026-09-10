defmodule ConsoleWeb.Deploy do
  @moduledoc """
  The Deploy screen: the Project card — where a project is created,
  and the one that is here deleted — the Deployment card, where a
  target is picked and brought up, and under them the deployments as
  they are, `ConsoleWeb.Deployments`: each compose file baked or not,
  in sync or drifted, up, stopped or down, with Stop, Down and Bake on
  its row and the file itself in a box. Every button is a `wb.sh` line
  handed to the `run` event; the two that cannot be taken back come
  back as a pending job, and the card that asked shows the question.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Deployments, only: [deployments_sheet: 1]
  alias ConsoleWeb.{Cartridges, Record}

  @targets %{
    "dev" =>
      "The dev toolchain image with the source mounted. Recompiles on boot; iex -S mix on the container.",
    "prod" =>
      "The release image, built from the project's Dockerfile on each up. No source, no Mix. A one-shot migrate runs first, and the app waits for it.",
    "scaled" =>
      "N production replicas behind an nginx balancer, on a bridge network. A BEAM cluster if clustering is inserted."
  }

  # Generation-only flags of phx.new. --database and --binary-id are
  # phx.new flags too, but only Ecto reads them: they are the ecto
  # cartridge's options, offered with its box.
  @gen_flags [{"adapter", ["bandit", "cowboy"]}]

  attr :status, :map, default: nil
  attr :catalog, :list, default: []
  attr :config, :map, required: true
  attr :jobs, :list, default: []
  attr :pick, :map, required: true, doc: "target, replicas, balancer"
  attr :newp, :map, required: true, doc: "out: names left out, gen: the flags"
  attr :composes, :list, default: [], doc: "the compose files, for the deployments sheet"
  attr :deploy, :any, default: nil, doc: "which compose file the deployments sheet shows"
  attr :reading, :any, default: false, doc: "a status in flight: :fast, :full, or false"

  def deploy(assigns) do
    ~H"""
    <.new_card status={@status} catalog={@catalog} config={@config} jobs={@jobs} newp={@newp} />
    <.deployment status={@status} catalog={@catalog} jobs={@jobs} pick={@pick} />
    <.deployments_sheet
      rows={Record.deployments(@status || %{})}
      status={@status}
      busy={busy?(@jobs, [:up, :stop, :down, :build])}
      composes={@composes}
      deploy={@deploy}
      stale={@reading == :full}
    />
    """
  end

  @doc "The pending job of a verb, if one waits."
  def pending(jobs, verb),
    do: Enum.find(jobs, &(&1.state == :pending and elem(&1.kind, 0) == verb))

  @doc "Whether a job of these verbs is running or queued."
  def busy?(jobs, verbs),
    do: Enum.any?(jobs, &(&1.state in [:running, :queued] and elem(&1.kind, 0) in verbs))

  # --- the project card ------------------------------------------------------

  defp new_card(assigns) do
    conf = Console.Config.values(assigns.config)
    pending = pending(assigns.jobs, :new)
    deleting = pending(assigns.jobs, :delete)
    project? = assigns.status && assigns.status["exists"] == true
    # The card's rows say what the *next* creation would use, which is
    # config.conf and nothing else: intention. What the project here is
    # has a paper of its own, the Record, and the card only links to it.
    # One crossing stays: the stack the project was built on, off its own
    # Dockerfile.local, and only when the two have come apart — which is
    # exactly when creating again would move the project off it.
    born = project? && Console.Project.born(assigns.status["workspace"])

    assigns =
      assign(assigns,
        conf: conf,
        pending: pending,
        deleting: deleting,
        project?: project?,
        born: born,
        busy: busy?(assigns.jobs, [:new]),
        cmd: new_command(assigns.catalog, assigns.newp),
        bases: Cartridges.base(assigns.catalog)
      )

    ~H"""
    <div class="newcard">
      <h3>
        Project
        <.chip :if={!@project?}>the workspace is empty</.chip>
        <.chip :if={@project?} class="bad" title="creating overwrites every file in it">
          a project exists here
        </.chip>
        <.link
          :if={@project?}
          class="lk"
          patch="/project?paper=record"
          title="the Record: what this project is — its birth, its cartridges"
        >
          what it is
        </.link>
      </h3>
      <form class="form" id="new-project" phx-change="new_form" phx-submit="new_submit">
        <.given label="project name" value={@conf["PROJECT_NAME"]} />
        <.given label="workspace" value={@conf["WORKSPACE_PATH"]} />
        <.given
          label="stack"
          value={"elixir #{@conf["ELIXIR_VERSION"]} · erlang #{@conf["ERLANG_VERSION"]} · #{@conf["DEBIAN_VERSION"]}"}
          warn={born_stack(@born, @conf)}
        />
        <.given
          label="installer"
          value={installer(@conf)}
          muted="the newest phx_new that runs on this stack"
        />
        <div class="frow">
          <label>phx.new</label>
          <div class="flags">
            <label :for={{k, values} <- gen_flags()}>
              --{k}
              <select name={"gen[#{k}]"}>
                <option :for={v <- values} value={v} selected={(@newp.gen[k] || hd(values)) == v}>
                  {v}
                </option>
              </select>
            </label>
          </div>
        </div>
        <div class="frow">
          <label title="In from birth; leave one out and insert it later from the shelf">base cartridges</label>
          <div class="flags bases">
            <%= for e <- @bases do %>
              <% out = base_out?(@catalog, @newp, e["name"]) %>
              <% forced = Enum.any?(e["requires"] || [], &base_out?(@catalog, @newp, &1)) %>
              <%!-- A cartridge that phx.new only generates with another is
                    not the reader's to leave in: it is disabled with the
                    reason in its title, which is `.unlit` and not a
                    fourth opacity written here. --%>
              <label class={[out && "out", forced && "unlit"]}>
                <input
                  type="checkbox"
                  name={"in[#{e["name"]}]"}
                  checked={!out}
                  disabled={forced}
                  title={
                    if forced,
                      do:
                        "goes with #{Enum.join(e["requires"], " and ")}: phx.new generates it only with them",
                      else: "in from birth; uncheck to leave it out"
                  }
                />
                <.cart_ref name={e["name"]} />
              </label>
              <span :if={e["name"] == "ecto" and e["options"] != []} class="subs">
                <%= for o <- e["options"] do %>
                  <% flag = "--" <> String.replace(o["name"], "_", "-") %>
                  <label class={["sub", out && "out"]}>
                    <%= if o["choices"] do %>
                      {flag}
                      <select name={"gen[#{o["name"]}]"} disabled={out} title={o["doc"]}>
                        <option
                          :for={c <- choices(o)}
                          value={c["value"]}
                          selected={(@newp.gen[o["name"]] || o["default"]) == c["value"]}
                          title={c["doc"]}
                        >
                          {c["value"]}
                        </option>
                      </select>
                    <% else %>
                      <input
                        type="checkbox"
                        name={"gen[#{o["name"]}]"}
                        disabled={out}
                        checked={@newp.gen[o["name"]] == "on"}
                        title={o["doc"]}
                      /> {flag}
                    <% end %>
                  </label>
                <% end %>
              </span>
            <% end %>
          </div>
        </div>
      </form>
      <div class="foot">
        <div class="cmds">
          <div class="cmd">{@cmd}</div>
        </div>
        <span :if={@pending} class="confirm on">A project already exists in this workspace: every file in it goes.
        <button class="btn danger" phx-click="confirm" phx-value-id={@pending.id}>Yes, overwrite</button><button
          class="btn"
          phx-click="cancel"
          phx-value-id={@pending.id}
        >Keep it</button></span>
        <%!-- The form's submit, not a click carrying the command: the
              command was rendered onto this button, and a change and a
              click in the same instant sent the command as it was before
              the change — a --database chosen, a bare `new` run. Submitted,
              the form travels whole and the server builds the line from it. --%>
        <button :if={!@pending} class="btn primary" type="submit" form="new-project" disabled={@busy}>
          {if @busy, do: "Creating…", else: "Create project"}
        </button>
        <%!-- The reverse of Create, on the same card: what the one makes,
              the other takes away — files, containers, images and volumes.
              It had a box of its own under "Workspace", beside the database
              errand; the errand went, and a heading over one button named
              only what the confirmation already says. Unlit on an empty
              workspace, never hidden. --%>
        <button
          :if={!@deleting}
          class={["btn danger", !@project? && "unlit"]}
          aria-disabled={!@project? && "true"}
          title={!@project? && "the workspace is empty: nothing to delete"}
          phx-click={@project? && "run"}
          phx-value-args="delete"
        >Delete the project</button>
        <span :if={@deleting} class="confirm on">Files, containers, images and volumes go.
        <button class="btn danger" phx-click="confirm" phx-value-id={@deleting.id}>Yes, delete</button><button
          class="btn"
          phx-click="cancel"
          phx-value-id={@deleting.id}
        >Keep it</button></span>
      </div>
    </div>
    """
  end

  # The givens the card reads and never sets: one origin, config.conf —
  # and the drawer that edits it, which is where the link goes. It was an
  # unlit span saying the drawer "comes later"; the drawer came, and the
  # style the link wants was already sitting in the stylesheet, unused.
  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :muted, :string, default: nil

  attr :title, :string,
    default: nil,
    doc: "where the value comes from, when it is not config.conf's own"

  attr :warn, :list,
    default: nil,
    doc: "[word, title]: the project here was made with something else"

  defp given(assigns) do
    ~H"""
    <div class="frow">
      <label>{@label}</label>
      <span class="ro">
        <span :if={@value} title={@title}>{@value}</span><span :if={!@value} class="nothing">{@muted}</span>
        <.chip :if={@warn} class="warn" title={List.last(@warn)}>{List.first(@warn)}</.chip>
        <.link patch="/deploy?wb=config" title="config.conf, in the workbench drawer">change in config</.link>
      </span>
    </div>
    """
  end

  # The installer, as one version when config names one; the sentence
  # otherwise, which is what a sentence is for. What this project was
  # born with is the Record's to say, not this card's: the card is
  # intention, and it used to answer with the project's own stamp here,
  # which was the state slipping into the form.
  defp installer(%{"PHX_NEW_VERSION" => v}) when v not in [nil, ""], do: "phx_new #{v}"
  defp installer(_conf), do: nil

  # The stack, only when the two have come apart — the one thing on this
  # card the reader has to be told rather than left to notice, because
  # creating again would move the project off the stack it was built on.
  # A chip and not a sentence: two versions in one row is a state, and
  # the house has a face for a state.
  defp born_stack(%{"ELIXIR" => e, "OTP" => o, "DEBIAN" => d}, conf)
       when is_binary(e) and is_binary(o) and is_binary(d) do
    if {e, o, d} == {conf["ELIXIR_VERSION"], conf["ERLANG_VERSION"], conf["DEBIAN_VERSION"]},
      do: nil,
      else: [
        "born on elixir #{e}",
        "this project was built on elixir #{e} · erlang #{o} · #{d}; config.conf now names another stack, and creating again would move it"
      ]
  end

  defp born_stack(_, _), do: nil

  def gen_flags, do: @gen_flags

  defp choices(%{"choices" => [%{"group" => _} | _] = groups}),
    do: Enum.flat_map(groups, & &1["values"])

  defp choices(%{"choices" => values}), do: values

  # A base cartridge left out takes with it the ones that build on it.
  def base_out?(catalog, newp, name) do
    e = Enum.find(catalog, &(&1["name"] == name)) || %{}
    name in newp.out or Enum.any?(e["requires"] || [], &base_out?(catalog, newp, &1))
  end

  @doc "`./wb.sh new` with the flags the card has set."
  def new_command(catalog, newp) do
    gen =
      Enum.flat_map(@gen_flags, fn {k, values} ->
        v = newp.gen[k]
        if v && v != hd(values), do: ["--#{k}", v], else: []
      end)

    outs =
      for e <- Cartridges.base(catalog),
          base_out?(catalog, newp, e["name"]),
          do: "--no-#{e["name"]}"

    Enum.join(["./wb.sh", "new"] ++ gen ++ outs ++ ecto_flags(catalog, newp), " ")
  end

  # Ecto's own flags — the database, binary ids — while Ecto is in.
  defp ecto_flags(catalog, newp) do
    case Enum.find(catalog, &(&1["name"] == "ecto")) do
      nil -> []
      e -> if base_out?(catalog, newp, "ecto"), do: [], else: option_flags(e, newp)
    end
  end

  defp option_flags(e, newp),
    do: Enum.flat_map(e["options"] || [], &option_flag(&1, newp.gen[&1["name"]]))

  # One option as set on the card, against its default.
  defp option_flag(o, v) do
    flag = "--" <> String.replace(o["name"], "_", "-")

    cond do
      o["type"] == "boolean" -> if v == "on", do: [flag], else: []
      v && v != o["default"] -> [flag, v]
      true -> []
    end
  end

  # --- the deployment card ---------------------------------------------------

  defp deployment(assigns) do
    running = assigns.status && assigns.status["deployment"]
    pick = assigns.pick.target || running || "dev"
    busy = busy?(assigns.jobs, [:up, :stop, :down, :build])
    noproject = is_nil(assigns.status) or assigns.status["exists"] != true
    extra = if pick == "scaled", do: scaled_extra(assigns.pick), else: ""
    clustering = assigns.status && Cartridges.installed?(assigns.status, "clustering")
    # Stop and Down used to be gated on `deployment`, which is only ever
    # a name while an *app* container runs. So the moment the app was not
    # running — it crashed, it failed to compile, or you had just pressed
    # Stop — the workspace's other containers were still there and both
    # buttons were dead: Stop was a one-way door. They ask the containers
    # now, which is the thing they act on. Down takes what exists away
    # (`compose down --remove-orphans`, and the three composes share the
    # project name, so it reaches whatever deployment left them); Stop
    # only has work while something still runs.
    cs = (assigns.status && assigns.status["containers"]) || []
    left = Enum.count(cs)
    alive = Enum.count(cs, &(&1["State"] == "running"))

    assigns =
      assign(assigns,
        running: running,
        pickname: pick,
        busy: busy,
        noproject: noproject,
        extra: extra,
        clustering: clustering,
        targets: @targets,
        left: left,
        alive: alive
      )

    ~H"""
    <div class="targets">
      <div class="deployment">
        <h3>Deployment</h3>
        <div class="now">
          <.chip class={
            cond do
              @busy -> "warn busy"
              @running -> "good"
              @left > 0 -> "warn"
              true -> "off"
            end
          }>
            {cond do
              @busy -> "working"
              @running -> "#{@running} is running"
              @left > 0 -> "#{@left} container#{if @left == 1, do: "", else: "s"} left"
              true -> "nothing is up"
            end}
          </.chip>
          <span class="note">{cond do
            @running ->
              "one deployment at a time: the composes share the project name, so Up replaces it"

            @left > 0 ->
              "no deployment is up, but the project's containers are still there: Down removes them"

            true ->
              "pick a target and bring it up"
          end}</span>
        </div>
        <form class="pick" id="deploy-pick" phx-change="pick">
          <label :for={name <- ~w(dev prod scaled)} class={name == @pickname && "on"}>
            <div>
              <input type="radio" name="target" value={name} checked={name == @pickname} />
              <b>{name}</b>
            </div>
            <.chip :if={name == "scaled" and !@clustering} class="warn">
              no clustering: replicas run isolated
            </.chip>
            <p>{@targets[name]}</p>
            <div :if={name == "scaled"} class="opts">
              --replicas <input type="number" name="replicas" min="1" value={@pick.replicas} />
              <label><input type="checkbox" name="balancer" checked={@pick.balancer} /> balancer</label>
            </div>
          </label>
        </form>
        <div class="acts">
          <button
            class="btn primary"
            disabled={@busy or @noproject or @running == @pickname}
            phx-click="run"
            phx-value-args={"up --deploy #{@pickname}#{@extra}"}
          >{if @running && @running != @pickname,
            do: "Replace #{@running} with #{@pickname}",
            else: "Up #{@pickname}"}</button>
          <button
            class="btn"
            disabled={@busy or @noproject}
            phx-click="run"
            phx-value-args={"build --deploy #{@pickname}#{@extra}"}
          >Build {@pickname}</button>
          <span class="note">{cond do
            @noproject -> "the workspace is empty: create a project first"
            @running -> "#{@running} is up: its row under the card stops it, or takes it down"
            @left > 0 -> "what is left of the project comes down from its row under the card"
            true -> "nothing is up"
          end}</span>
        </div>
        <div class="cmd">./wb.sh up --deploy {@pickname}{@extra}</div>
      </div>
    </div>
    """
  end

  @doc "`--replicas N --no-balancer`, only when they differ from what `up` assumes."
  def scaled_extra(pick) do
    if(pick.replicas && pick.replicas != 4, do: " --replicas #{pick.replicas}", else: "") <>
      if(pick.balancer == false, do: " --no-balancer", else: "")
  end

  @doc """
  The command a deploy verb becomes. dev is the default deployment, so
  only the others name themselves; only the verbs that bring something
  up carry its options. Written once: the rail's buttons put this in
  their title, and a title that drifts from the command is worse than none.
  """
  def cmdline(verb, name, extra) do
    "./wb.sh #{verb}" <>
      if(name == "dev" and verb not in ["up", "build"], do: "", else: " --deploy #{name}") <>
      if(verb in ["up", "build"], do: extra, else: "")
  end
end
