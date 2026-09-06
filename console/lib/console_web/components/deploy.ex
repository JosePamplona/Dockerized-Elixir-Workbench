defmodule ConsoleWeb.Deploy do
  @moduledoc """
  The Deploy screen: the Project card — where a project is created,
  and the one that is here deleted — and the Deployment card. Every
  button is a `wb.sh` line handed to the `run` event; the two that
  cannot be taken back come back as a pending job, and the card that
  asked shows the question.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  alias ConsoleWeb.Cartridges

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

  def deploy(assigns) do
    ~H"""
    <.new_card status={@status} catalog={@catalog} config={@config} jobs={@jobs} newp={@newp} />
    <.deployment status={@status} catalog={@catalog} jobs={@jobs} pick={@pick} />
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
    # What the project in this workspace was actually made with, off its
    # own Dockerfile.local. The card's rows say what the *next* creation
    # would use, which is config.conf and nothing else; this is the other
    # half of the sentence, and it only appears when it says something —
    # the installer always does, because config.conf usually leaves it
    # open, and the stack only when the two have come apart, which is
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
      </h3>
      <form class="form" id="new-project" phx-change="new_form">
        <.given label="project name" value={@conf["PROJECT_NAME"]} />
        <.given label="workspace" value={@conf["WORKSPACE_PATH"]} />
        <.given
          label="stack"
          value={"elixir #{@conf["ELIXIR_VERSION"]} · erlang #{@conf["ERLANG_VERSION"]} · #{@conf["DEBIAN_VERSION"]}"}
          warn={born_stack(@born, @conf)}
        />
        <.given
          label="installer"
          value={installer(@conf, @born)}
          muted="the newest phx_new that runs on this stack"
          title={installer_title(@conf, @born)}
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
        <button
          :if={!@pending}
          class="btn primary"
          disabled={@busy}
          phx-click="run"
          phx-value-args={String.replace_prefix(@cmd, "./wb.sh ", "")}
        >{if @busy, do: "Creating…", else: "Create project"}</button>
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

  # The installer, as one version whenever there is one to name: config
  # names it, or the project in this workspace was born with it and its
  # own Dockerfile still says so. Only when neither knows does the row
  # fall back to the sentence, which is what a sentence is for.
  defp installer(%{"PHX_NEW_VERSION" => v}, _born) when v not in [nil, ""], do: "phx_new #{v}"
  defp installer(_conf, %{"PHX_NEW" => v}) when v not in [nil, ""], do: "phx_new #{v}"
  defp installer(_conf, _born), do: nil

  # Which of the two it is goes in the title, since the version alone
  # cannot say: it is this project's, and creating another would go and
  # ask hex again.
  defp installer_title(%{"PHX_NEW_VERSION" => v}, _born) when v not in [nil, ""], do: nil

  defp installer_title(_conf, %{"PHX_NEW" => v}) when v not in [nil, ""],
    do:
      "the installer this project was born with, stamped in its own Dockerfile.local — config.conf names none, so creating again takes the newest phx_new that runs on this stack"

  defp installer_title(_conf, _born), do: nil

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
          <span class="sep"></span>
          <button
            class="btn"
            disabled={@busy or @alive == 0}
            title={
              if @alive == 0,
                do: "nothing is running",
                else:
                  "stops the #{@alive} running container#{if @alive == 1, do: "", else: "s"}, keeping them"
            }
            phx-click="run"
            phx-value-args={
              String.replace_prefix(cmdline("stop", @running || "dev", ""), "./wb.sh ", "")
            }
          >Stop</button>
          <button
            class="btn"
            disabled={@busy or @left == 0}
            title={
              if @left == 0,
                do: "there are no containers to remove",
                else:
                  "removes the #{@left} container#{if @left == 1, do: "", else: "s"} of the project, running or not"
            }
            phx-click="run"
            phx-value-args={
              String.replace_prefix(cmdline("down", @running || "dev", ""), "./wb.sh ", "")
            }
          >Down</button>
          <span class="note">{cond do
            @noproject -> "the workspace is empty: create a project first"
            @running -> "on #{@running}"
            @left > 0 -> "on what is left of the project"
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
