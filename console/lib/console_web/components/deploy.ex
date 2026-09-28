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
  import ConsoleWeb.Folds, only: [card_head: 1, fold_class: 2]
  import ConsoleWeb.Deployments, only: [deployments_sheet: 1]
  alias ConsoleWeb.Cartridges

  # Generation-only flags of phx.new. --database and --binary-id are
  # phx.new flags too, but only Ecto reads them: they are the ecto
  # cartridge's options, offered with its box.
  @gen_flags [{"adapter", ["bandit", "cowboy"]}]

  # The name a project gets when the card is left alone and config.conf
  # names none. The file's `PROJECT_NAME` is the ordinary default —
  # `newp.default` — and it is the name the console started its
  # toolchain for, so leaving the field alone is what keeps the two
  # together.
  @default_name "Lorem Ipsum"

  @doc "The generation-only flags of phx.new, for the card that offers them."
  def gen_flags, do: @gen_flags

  @doc "`--replicas N --no-balancer`, only when they differ from what a bake assumes at birth."
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
        cmdline("up", pick.target || "dev", "")

      _ ->
        nil
    end
  end

  @doc """
  The command a deploy verb becomes. dev is the default deployment, so
  only the others name themselves; only the verb that writes a file —
  bake — carries the scaled shape (2026-09-27; up and build baked the
  file on their way and took it too, and left the tree dirty: they
  deploy and build what is baked now). Written once: the rail's
  buttons put this in their title, and a title that drifts from the
  command is worse than none.
  """
  def cmdline(verb, name, extra) do
    "./wb.sh #{verb}" <>
      if(name == "dev" and verb not in ["up", "build"], do: "", else: " --deploy #{name}") <>
      if(verb == "bake", do: extra, else: "")
  end

  attr :status, :map, default: nil
  attr :catalog, :list, default: []
  attr :config, :map, required: true
  attr :jobs, :list, default: []
  attr :pick, :map, required: true, doc: "target, replicas, balancer"
  attr :composes, :list, default: [], doc: "the compose files, for the deployments sheet"
  attr :deploy, :any, default: nil, doc: "which compose file the deployments sheet shows"
  attr :reading, :any, default: false, doc: "a status in flight: :fast, :full, or false"
  attr :folded, :any, default: nil, doc: "the section keys folded away, a MapSet"

  attr :off_disk, :map,
    required: true,
    doc: "what was read off the workspace's files when the status arrived: rows, born"

  def deploy(assigns) do
    running = assigns.status && assigns.status["deployment"]
    pick = assigns.pick.target || running || "dev"

    assigns =
      assign(assigns,
        running: running,
        pickname: pick,
        clustering: assigns.status && Cartridges.installed?(assigns.status, "clustering")
      )

    ~H"""
    <.live_component
      module={ConsoleWeb.NewProject}
      id="new-project"
      status={@status}
      catalog={@catalog}
      config={@config}
      jobs={@jobs}
      folded={@folded}
      born={@off_disk.born}
    />
    <.deployments_sheet
      rows={@off_disk.rows}
      status={@status}
      busy={busy?(@jobs, [:up, :stop, :down, :build])}
      composes={@composes}
      deploy={@deploy}
      stale={@reading == :full}
      pick={@pick}
      scaled_extra={scaled_extra(@pick)}
      pickname={@pickname}
      running={@running}
      clustering={@clustering}
      folded={@folded}
    />
    <.danger status={@status} jobs={@jobs} folded={@folded} />
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
  attr :folded, :any, default: nil

  defp danger(assigns) do
    project? = assigns.status && assigns.status["exists"] == true

    assigns =
      assign(assigns,
        project?: project?,
        deleting: pending(assigns.jobs, :delete),
        name: (assigns.status || %{})["compose_project"]
      )

    ~H"""
    <section class={["danger", fold_class(@folded, "danger")]}>
      <.card_head key="danger" name="Danger" folded={@folded} />
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

  # The givens the card reads and never sets: one origin, config.conf —
  # and the drawer that edits it, which is where the link goes. It was an
  # unlit span saying the drawer "comes later"; the drawer came, and the
  # style the link wants was already sitting in the stylesheet, unused.

  # The cog on every given: the row is read here and changed in one
  # place, config.conf — the same square the eye is, so a reader who has
  # met one has met both. It said "change in config" in words on every
  # row until 2026-09-10, six times down one card.

  # The installer, as one version when config names one; the sentence
  # otherwise, which is what a sentence is for. What this project was
  # A base cartridge left out takes with it the ones that build on it.
  def base_out?(catalog, newp, name) do
    e = Enum.find(catalog, &(&1["name"] == name)) || %{}
    name in newp.out or Enum.any?(e["requires"] || [], &base_out?(catalog, newp, &1))
  end

  @doc "The name a project gets when neither the card nor config.conf names one."
  def default_name, do: @default_name

  @doc """
  The card as it opens: config.conf's `PROJECT_NAME` in the field and
  behind it, since that is the name the console started its toolchain
  for. `default` is what an emptied field falls back to.
  """
  def newp_fresh(config) do
    name = Console.Config.values(config)["PROJECT_NAME"] || @default_name
    %{out: MapSet.new(), gen: %{}, name: name, default: name}
  end

  @doc """
  `./wb.sh new` as the card would run it, as a list of arguments — which
  is what runs, since a name has a space in it and the console's parser
  splits a line on spaces. `new_command/2` writes the same thing for the
  reader, with the name in quotes.
  """
  def new_args(catalog, newp) do
    fallback = (newp[:default] || "") |> String.trim() |> nonempty(@default_name)
    name = (newp[:name] || "") |> String.trim() |> nonempty(fallback)
    ["new", "--name", name] ++ new_flags(catalog, newp)
  end

  defp nonempty("", fallback), do: fallback
  defp nonempty(value, _fallback), do: value

  @doc "`./wb.sh new` with the flags the card has set, as the reader reads it."
  def new_command(catalog, newp) do
    ["new", "--name", name | flags] = new_args(catalog, newp)
    # A name with a space in it wears quotes here, so the line the reader
    # copies is the line a shell would take.
    said = if String.contains?(name, " "), do: ~s("#{name}"), else: name
    Enum.join(["./wb.sh", "new", "--name", said | flags], " ")
  end

  defp new_flags(catalog, newp) do
    gen =
      Enum.flat_map(@gen_flags, fn {k, values} ->
        v = newp.gen[k]
        if v && v != hd(values), do: ["--#{k}", v], else: []
      end)

    outs =
      for e <- Cartridges.base(catalog),
          base_out?(catalog, newp, e["name"]),
          do: "--no-#{e["name"]}"

    gen ++ outs ++ base_flags(catalog, newp)
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
end
