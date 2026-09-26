defmodule ConsoleWeb.Deploy do
  @moduledoc """
  The Deploy screen: the New Project card — where a project is created,
  out of config.conf and nothing else — the Deployments card,
  `ConsoleWeb.Deployments`: one row per deployment, picked on its row,
  each compose file baked or not, in sync or drifted, up, stopped or
  down, with Stop, Down and Bake on its row, the file itself in a box,
  and Up, Stop and Down under the table, and last the
  Danger box, whose only verb is the one that cannot be taken back.
  Every button is a `wb.sh` line handed to the `run` event; the two
  that cannot be taken back come back as a pending job, and the box
  that asked shows the question.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Square, only: [square: 1]
  import ConsoleWeb.Deployments, only: [deployments_sheet: 1]
  alias ConsoleWeb.{Cartridges, Record}

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
    running = assigns.status && assigns.status["deployment"]
    pick = assigns.pick.target || running || "dev"

    assigns =
      assign(assigns,
        running: running,
        pickname: pick,
        extra: if(pick == "scaled", do: scaled_extra(assigns.pick), else: ""),
        clustering: assigns.status && Cartridges.installed?(assigns.status, "clustering")
      )

    ~H"""
    <.new_card status={@status} catalog={@catalog} config={@config} jobs={@jobs} newp={@newp} />
    <.deployments_sheet
      rows={Record.deployments(@status || %{})}
      status={@status}
      busy={busy?(@jobs, [:up, :stop, :down, :build])}
      composes={@composes}
      deploy={@deploy}
      stale={@reading == :full}
      pick={@pick}
      scaled_extra={scaled_extra(@pick)}
      pickname={@pickname}
      running={@running}
      extra={@extra}
      clustering={@clustering}
    />
    <.danger status={@status} jobs={@jobs} />
    """
  end

  # The one verb that cannot be taken back, in a section of its own at
  # the tab's foot — away from Create, which shares no ground with it,
  # and away from the rows pressed every day. It had a box under
  # "Workspace" once, beside the database errand, and when the errand
  # went a heading over one button said only what the confirmation
  # already says; it comes back (2026-09-10) with what the Docker
  # screen gives its own removals — the line it is, and everything it
  # takes with it, before the hand is anywhere near it.
  attr :status, :map, default: nil
  attr :jobs, :list, default: []

  defp danger(assigns) do
    project? = assigns.status && assigns.status["exists"] == true

    assigns =
      assign(assigns,
        project?: project?,
        deleting: pending(assigns.jobs, :delete),
        name: (assigns.status || %{})["compose_project"]
      )

    ~H"""
    <section class="danger">
      <h3>Danger zone</h3>
      <%!-- The foot of the two boxes above: the line it is, taking the
            width, and the button at its right — Create's shape and Up's,
            because this is the third of the three verbs the tab has. The
            note goes under the line, in the line's own column, since what
            it says is what that line takes with it; the button holds the
            line's row and is centred on the line alone, so a note of any
            length leaves it where it is. --%>
      <div class="foot">
        <div class="cmd">./wb.sh delete</div>
        <p class="note">
          every file of {@name || "the project"} in the workspace, its containers, its images and its volumes — the database's data with them · asks first
        </p>
        <.job_button
          :if={!@deleting}
          label="Delete the project"
          class="primary danger"
          args="delete"
          why={!@project? && "the workspace is empty: nothing to delete"}
        />
        <span :if={@deleting} class="confirm on">Files, containers, images and volumes go.
        <button class="btn primary danger" phx-click="confirm" phx-value-id={@deleting.id}>Yes, delete</button><button
          class="btn"
          phx-click="cancel"
          phx-value-id={@deleting.id}
        >Keep it</button></span>
      </div>
    </section>
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
        project?: project?,
        born: born,
        busy: busy?(assigns.jobs, [:new]),
        cmd: new_command(assigns.catalog, assigns.newp),
        bases: Cartridges.base(assigns.catalog)
      )

    ~H"""
    <div class="newcard">
      <h3>
        New Project
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
        <.given label="workspace" value={@conf["WORKSPACE_PATH"]}>
          <:mark>
            <.chip
              :if={!@project?}
              class="off"
              title="nothing to read and nothing to lose: Create makes one"
            >
              empty
            </.chip>
            <.chip :if={@project?} class="good" title="creating overwrites every file in it">
              existing project
            </.chip>
          </:mark>
        </.given>
        <.given
          label="elixir"
          value={@conf["ELIXIR_VERSION"]}
          warn={born_arg(@born, "ELIXIR", "elixir", @conf["ELIXIR_VERSION"])}
        />
        <.given
          label="erlang"
          value={@conf["ERLANG_VERSION"]}
          warn={born_arg(@born, "OTP", "erlang", @conf["ERLANG_VERSION"])}
        />
        <.given
          label="debian"
          value={@conf["DEBIAN_VERSION"]}
          warn={born_arg(@born, "DEBIAN", "debian", @conf["DEBIAN_VERSION"])}
        />
        <.given
          label="installer"
          value={installer(@conf)}
          muted="the newest phx.new that runs on this stack"
        />
        <div class="frow">
          <label>mix phx.new</label>
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
              <%!-- A base cartridge's own phx.new flags: ecto's database and
                    ids, html's live. A switch is labelled with its flag and
                    checked when on, whatever its default; one on by default
                    carries an "off" before its box, since a form sends nothing
                    for an unchecked one, and the command says --no-live. --%>
              <span :if={e["options"] != []} class="subs">
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
                        :if={o["default"] == true}
                        type="hidden"
                        name={"gen[#{o["name"]}]"}
                        value="off"
                      />
                      <input
                        type="checkbox"
                        name={"gen[#{o["name"]}]"}
                        disabled={out}
                        checked={switch_on?(o, @newp.gen[o["name"]])}
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
        <.job_button
          :if={!@pending}
          label={if @busy, do: "Creating…", else: "Create project"}
          class="primary"
          form="new-project"
          args={String.replace_prefix(@cmd, "./wb.sh ", "")}
          why={@busy && "a job is running"}
        />
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

  slot :mark, doc: "a reading of this given itself, chipped after the value"

  defp given(assigns) do
    ~H"""
    <div class="frow">
      <label>{@label}</label>
      <span class="ro">
        <span :if={@value} title={@title}>{@value}</span><span :if={!@value} class="nothing">{@muted}</span>
        {render_slot(@mark)}
        <.chip :if={@warn} class="warn" title={List.last(@warn)}>{List.first(@warn)}</.chip>
        <.square
          mark="cog"
          size="small"
          label={"Change #{@label} in config.conf"}
          class="cog"
          patch="/deploy?wb=config"
          title="change it in config.conf, in the workbench drawer"
        />
      </span>
    </div>
    """
  end

  # The cog on every given: the row is read here and changed in one
  # place, config.conf — the same square the eye is, so a reader who has
  # met one has met both. It said "change in config" in words on every
  # row until 2026-09-10, six times down one card.

  # The installer, as one version when config names one; the sentence
  # otherwise, which is what a sentence is for. What this project was
  # born with is the Record's to say, not this card's: the card is
  # intention, and it used to answer with the project's own stamp here,
  # which was the state slipping into the form.
  defp installer(%{"PHX_NEW_VERSION" => v}) when v not in [nil, ""], do: "phx.new #{v}"
  defp installer(_conf), do: nil

  # The stack, only where the two have come apart — the one thing on this
  # card the reader has to be told rather than left to notice, because
  # creating again would move the project off the stack it was built on.
  # A chip and not a sentence: two versions in one row is a state, and
  # the house has a face for a state. One row each, as the Record's
  # Birth reads them (2026-09-10): the row that moved is the row that
  # says so, and the elixir it was born on no longer speaks for the
  # three.
  defp born_arg(born, key, label, now) when is_map(born) do
    case born[key] do
      b when is_binary(b) and b != now ->
        [
          "born on #{b}",
          "this project was built on #{label} #{b}; config.conf now names #{now || "another"}, and creating again would move it"
        ]

      _ ->
        nil
    end
  end

  defp born_arg(_, _, _, _), do: nil

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

    Enum.join(["./wb.sh", "new"] ++ gen ++ outs ++ base_flags(catalog, newp), " ")
  end

  # The base cartridges' own flags — ecto's database and ids, html's
  # --no-live — for each one that is in.
  defp base_flags(catalog, newp) do
    for e <- Cartridges.base(catalog),
        not base_out?(catalog, newp, e["name"]),
        flag <- option_flags(e, newp),
        do: flag
  end

  defp option_flags(e, newp),
    do: Enum.flat_map(e["options"] || [], &option_flag(&1, newp.gen[&1["name"]]))

  # One option as set on the card, against its default: a switch off by
  # default gives --flag when on, one on by default --no-flag when off.
  defp option_flag(o, v) do
    name = String.replace(o["name"], "_", "-")

    cond do
      o["type"] == "boolean" and o["default"] == true ->
        if v == "off", do: ["--no-#{name}"], else: []

      o["type"] == "boolean" ->
        if v == "on", do: ["--#{name}"], else: []

      v && v != o["default"] ->
        ["--#{name}", v]

      true ->
        []
    end
  end

  # Whether a switch reads as on: as the card set it, else its default.
  defp switch_on?(o, nil), do: o["default"] == true
  defp switch_on?(_o, v), do: v == "on"

  @doc "`--replicas N --no-balancer`, only when they differ from what `up` assumes."
  def scaled_extra(pick) do
    if(pick.replicas && pick.replicas != 4, do: " --replicas #{pick.replicas}", else: "") <>
      if(pick.balancer == false, do: " --no-balancer", else: "")
  end

  @doc """
  The line the picker's own buttons become: the verb of the button
  pressed, and the target and options as they travelled with the form.
  `nil` for anything else, so a button nobody wrote runs nothing.

  It lives here, and not on the button, because a button is rendered
  with the picker as it was and can be a change behind it — the
  hazard `ConsoleWeb.Refs.job_button/1` explains.
  """
  def line(verb, pick) do
    extra = fn name -> if(name == "scaled", do: scaled_extra(pick), else: "") end

    case String.split(verb || "", " ") do
      [verb, name] when verb in ~w(bake build) and name in ~w(dev prod scaled) ->
        cmdline(verb, name, extra.(name))

      ["up"] ->
        name = pick.target || "dev"
        cmdline("up", name, extra.(name))

      _ ->
        nil
    end
  end

  @doc """
  The command a deploy verb becomes. dev is the default deployment, so
  only the others name themselves; only the verbs that bake a file —
  up, build, bake — carry its options. Written once: the rail's buttons put this in
  their title, and a title that drifts from the command is worse than none.
  """
  def cmdline(verb, name, extra) do
    "./wb.sh #{verb}" <>
      if(name == "dev" and verb not in ["up", "build"], do: "", else: " --deploy #{name}") <>
      if(verb in ["up", "build", "bake"], do: extra, else: "")
  end
end
