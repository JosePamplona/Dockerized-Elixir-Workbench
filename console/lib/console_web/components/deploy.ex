defmodule ConsoleWeb.Deploy do
  @moduledoc """
  The Deploy screen: the New project card, the Deployment card, the
  database, the workspace. Every button is a `wb.sh` line handed to
  the `run` event; the two that cannot be taken back come back as a
  pending job, and the card that asked shows the question.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  alias ConsoleWeb.Cartridges

  @targets %{
    "dev" => "The dev toolchain image with the source mounted. Recompiles on boot; iex -S mix on the container.",
    "prod" => "The release image, built from the project's Dockerfile on each up. No source, no Mix.",
    "scaled" => "N production replicas behind an nginx balancer, on a bridge network. A BEAM cluster if clustering is inserted."
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
  attr :setup_env, :string, default: "dev"

  def deploy(assigns) do
    ~H"""
    <.new_card status={@status} catalog={@catalog} config={@config} jobs={@jobs} newp={@newp} />
    <.deployment status={@status} catalog={@catalog} jobs={@jobs} pick={@pick} />
    <div class="zone">
      <h3>Database</h3>
      <form class="pick" role="radiogroup" aria-label="The environment to set the database up for" phx-change="setup_env">
        <label :for={env <- ~w(dev prod)}><div><input type="radio" name="env" value={env} checked={@setup_env == env} /> <b>{env}</b></div></label>
      </form>
      <div class="acts">
        <button class={["btn", is_nil(@status) || !@status["exists"] && "unlit"]} aria-disabled={(is_nil(@status) || !@status["exists"]) && "true"} title={(is_nil(@status) || !@status["exists"]) && "the workspace is empty: create a project first"} phx-click={@status && @status["exists"] && "run"} phx-value-args={"setup --env #{@setup_env}"}>Setup the database</button>
        <span class="note">drops it, creates it, seeds it</span>
      </div>
    </div>
    <div class="dangerzone">
      <h3>Workspace</h3>
      <div class="acts">
        <% pending = pending(@jobs, :delete) %>
        <button :if={!pending} class={["btn danger", is_nil(@status) || !@status["exists"] && "unlit"]} aria-disabled={(is_nil(@status) || !@status["exists"]) && "true"} title={(is_nil(@status) || !@status["exists"]) && "the workspace is empty: nothing to delete"} phx-click={@status && @status["exists"] && "run"} phx-value-args="delete">Delete the project</button>
        <span :if={pending} class="confirm on">Files, containers, images and volumes go. <button class="btn danger" phx-click="confirm" phx-value-id={pending.id}>Yes, delete</button><button class="btn" phx-click="cancel" phx-value-id={pending.id}>Keep it</button></span>
      </div>
    </div>
    """
  end

  @doc "The pending job of a verb, if one waits."
  def pending(jobs, verb), do: Enum.find(jobs, &(&1.state == :pending and elem(&1.kind, 0) == verb))

  @doc "Whether a job of these verbs is running or queued."
  def busy?(jobs, verbs), do: Enum.any?(jobs, &(&1.state in [:running, :queued] and elem(&1.kind, 0) in verbs))

  # --- the new project card --------------------------------------------------

  defp new_card(assigns) do
    conf = Console.Config.values(assigns.config)
    pending = pending(assigns.jobs, :new)
    project? = assigns.status && assigns.status["exists"] == true
    assigns = assign(assigns, conf: conf, pending: pending, project?: project?, busy: busy?(assigns.jobs, [:new]), cmd: new_command(assigns.catalog, assigns.newp), bases: Cartridges.base(assigns.catalog))

    ~H"""
    <div class="newcard">
      <h3>New project
        <.chip :if={!@project?}>the workspace is empty</.chip>
        <.chip :if={@project?} class="bad" title="creating overwrites every file in it">a project exists here</.chip>
      </h3>
      <form class="form" phx-change="new_form">
        <.given label="project name" value={@conf["PROJECT_NAME"]} />
        <.given label="workspace" value={@conf["WORKSPACE_PATH"]} />
        <.given label="stack" value={"elixir #{@conf["ELIXIR_VERSION"]} · erlang #{@conf["ERLANG_VERSION"]} · #{@conf["DEBIAN_VERSION"]}"} />
        <.given label="installer" value={if @conf["PHX_NEW_VERSION"] in [nil, ""], do: nil, else: "phx_new #{@conf["PHX_NEW_VERSION"]}"} muted="the newest phx_new that runs on this stack" />
        <div class="frow">
          <label>phx.new</label>
          <div class="flags">
            <label :for={{k, values} <- gen_flags()}>--{k}
              <select name={"gen[#{k}]"}>
                <option :for={v <- values} value={v} selected={(@newp.gen[k] || hd(values)) == v}>{v}</option>
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
              <label class={out && "out"}>
                <input type="checkbox" name={"in[#{e["name"]}]"} checked={!out} disabled={forced} title={if forced, do: "goes with #{Enum.join(e["requires"], " and ")}: phx.new generates it only with them", else: "in from birth; uncheck to leave it out"} />
                <.cart_ref name={e["name"]} />
              </label>
              <span :if={e["name"] == "ecto" and e["options"] != []} class="subs">
                <%= for o <- e["options"] do %>
                  <% flag = "--" <> String.replace(o["name"], "_", "-") %>
                  <label class={["sub", out && "out"]}>
                    <%= if o["choices"] do %>
                      {flag}
                      <select name={"gen[#{o["name"]}]"} disabled={out} title={o["doc"]}>
                        <option :for={c <- choices(o)} value={c["value"]} selected={(@newp.gen[o["name"]] || o["default"]) == c["value"]} title={c["doc"]}>{c["value"]}</option>
                      </select>
                    <% else %>
                      <input type="checkbox" name={"gen[#{o["name"]}]"} disabled={out} checked={@newp.gen[o["name"]] == "on"} title={o["doc"]} /> {flag}
                    <% end %>
                  </label>
                <% end %>
              </span>
            <% end %>
          </div>
        </div>
      </form>
      <div class="foot">
        <div class="cmds"><div class="cmd">{@cmd}</div></div>
        <span :if={@pending} class="confirm on">A project already exists in this workspace: every file in it goes. <button class="btn danger" phx-click="confirm" phx-value-id={@pending.id}>Yes, overwrite</button><button class="btn" phx-click="cancel" phx-value-id={@pending.id}>Keep it</button></span>
        <button :if={!@pending} class="btn primary" disabled={@busy} phx-click="run" phx-value-args={String.replace_prefix(@cmd, "./wb.sh ", "")}>{if @busy, do: "Creating…", else: "Create project"}</button>
      </div>
    </div>
    """
  end

  # The givens the card reads and never sets: one origin, config.conf.
  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :muted, :string, default: nil

  defp given(assigns) do
    ~H"""
    <div class="frow">
      <label>{@label}</label>
      <span class="ro">
        <span :if={@value}>{@value}</span><span :if={!@value} class="muted">{@muted}</span>
        <span class="unlit" title="the workbench drawer, where config.conf is edited, comes later" aria-disabled="true">change in config</span>
      </span>
    </div>
    """
  end

  def gen_flags, do: @gen_flags

  defp choices(%{"choices" => [%{"group" => _} | _] = groups}), do: Enum.flat_map(groups, & &1["values"])
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

    outs = for e <- Cartridges.base(catalog), base_out?(catalog, newp, e["name"]), do: "--no-#{e["name"]}"

    ecto =
      case Enum.find(catalog, &(&1["name"] == "ecto")) do
        nil -> []
        e ->
          if base_out?(catalog, newp, "ecto") do
            []
          else
            Enum.flat_map(e["options"] || [], fn o ->
              v = newp.gen[o["name"]]
              flag = "--" <> String.replace(o["name"], "_", "-")

              cond do
                o["type"] == "boolean" -> if v == "on", do: [flag], else: []
                v && v != o["default"] -> [flag, v]
                true -> []
              end
            end)
          end
      end

    Enum.join(["./wb.sh", "new"] ++ gen ++ outs ++ ecto, " ")
  end

  # --- the deployment card ---------------------------------------------------

  defp deployment(assigns) do
    running = assigns.status && assigns.status["deployment"]
    pick = assigns.pick.target || running || "dev"
    busy = busy?(assigns.jobs, [:up, :stop, :down, :build])
    noproject = is_nil(assigns.status) or assigns.status["exists"] != true
    extra = if pick == "scaled", do: scaled_extra(assigns.pick), else: ""
    clustering = assigns.status && Cartridges.installed?(assigns.status, "clustering")
    assigns = assign(assigns, running: running, pickname: pick, busy: busy, noproject: noproject, extra: extra, clustering: clustering, targets: @targets)

    ~H"""
    <div class="targets">
      <div class="deployment">
        <h3>Deployment</h3>
        <div class="now">
          <.chip class={cond do @busy -> "warn busy"; @running -> "good"; true -> "off" end}>{cond do @busy -> "working"; @running -> "#{@running} is running"; true -> "nothing is up" end}</.chip>
          <span class="note">{if @running, do: "one deployment at a time: the composes share the project name, so Up replaces it", else: "pick a target and bring it up"}</span>
        </div>
        <form class="pick" phx-change="pick">
          <label :for={name <- ~w(dev prod scaled)} class={name == @pickname && "on"}>
            <div><input type="radio" name="target" value={name} checked={name == @pickname} /> <b>{name}</b></div>
            <.chip :if={name == "scaled" and !@clustering} class="warn">no clustering: replicas run isolated</.chip>
            <p>{@targets[name]}</p>
            <div :if={name == "scaled"} class="opts">
              --replicas <input type="number" name="replicas" min="1" value={@pick.replicas} />
              <label><input type="checkbox" name="balancer" checked={@pick.balancer} /> balancer</label>
            </div>
          </label>
        </form>
        <div class="acts">
          <button class="btn primary" disabled={@busy or @noproject or @running == @pickname} phx-click="run" phx-value-args={"up --deploy #{@pickname}#{@extra}"}>{if @running && @running != @pickname, do: "Replace #{@running} with #{@pickname}", else: "Up #{@pickname}"}</button>
          <button class="btn" disabled={@busy or @noproject} phx-click="run" phx-value-args={"build --deploy #{@pickname}#{@extra}"}>Build {@pickname}</button>
          <span class="sep"></span>
          <button class="btn" disabled={@busy or !@running} phx-click="run" phx-value-args={String.replace_prefix(cmdline("stop", @running || "dev", ""), "./wb.sh ", "")}>Stop</button>
          <button class="btn" disabled={@busy or !@running} phx-click="run" phx-value-args={String.replace_prefix(cmdline("down", @running || "dev", ""), "./wb.sh ", "")}>Down</button>
          <span class="note">{cond do @noproject -> "the workspace is empty: create a project first"; @running -> "on #{@running}"; true -> "nothing is up" end}</span>
        </div>
        <div class="cmd">./wb.sh up --deploy {@pickname}{@extra}</div>
      </div>
    </div>
    """
  end

  @doc "`--replicas N --no-balancer`, only when they differ from what `up` assumes."
  def scaled_extra(pick) do
    (if pick.replicas && pick.replicas != 4, do: " --replicas #{pick.replicas}", else: "") <>
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
