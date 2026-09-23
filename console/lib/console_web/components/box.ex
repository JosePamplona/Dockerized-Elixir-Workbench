defmodule ConsoleWeb.Box do
  @moduledoc """
  The box in hand: a drawer over the page with four screens — what the
  box is, the papers it carries, how it goes in, && what it wrote.
  Which box && which screen live in the URL (`?box=rest&screen=manual
  &paper=design`), so the browser's back is the trail back.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Ribbon, only: [ribbon: 1]
  alias ConsoleWeb.Cartridges
  alias ConsoleWeb.Packages
  alias ConsoleWeb.Record

  @screens [{"box", "Box"}, {"manual", "Manual"}, {"install", "Installation"}, {"files", "Files"}]

  attr :box, :map, required: true
  attr :status, :map, default: nil
  attr :catalog, :list, default: []
  attr :screen, :string, required: true
  attr :paper, :string, required: true
  attr :papers, :list, required: true, doc: "the keys of the papers the box carries"
  attr :page, :map, default: nil, doc: "the rendered paper"
  attr :args, :map, required: true, doc: "the form as filled: option name to value(s)"
  attr :recipe, :any, default: nil, doc: "a collection's plan from expand, :asking, || nil"
  attr :jobs, :list, default: [], doc: "the inserts and ejects of this box, newest first"
  attr :open, :any, default: MapSet.new(), doc: "the job ids unfolded"
  attr :now, :any, default: nil
  attr :asking, :any, default: nil
  attr :stoppable, :boolean, default: false
  attr :face, :string, default: "front"
  attr :tab, :string, default: "shelf"

  attr :back, :string,
    default: nil,
    doc: "the screen's own place, where Put back goes; the bare tab when not given"

  attr :diff, :any,
    default: nil,
    doc: "what the cartridge wrote (Console.Diffs), :loading, || nil"

  attr :packages, :map, default: %{}, doc: "what hex said of each package, by name"

  attr :read_deps, :any,
    default: [],
    doc: "what this box's insert commit put in mix.exs, read off git"

  attr :packages_asking, :boolean, default: false
  attr :packages_error, :any, default: nil

  def box(assigns) do
    c = Cartridges.carried(assigns.status, assigns.box["name"]) || assigns.box
    installed = Cartridges.installed?(assigns.status, assigns.box["name"])

    assigns =
      assign(assigns,
        c: c,
        installed: installed,
        screens: @screens,
        box: Map.put(assigns.box, :status_for_files, assigns.status)
      )

    ~H"""
    <aside class="drawer on" role="dialog" aria-modal="true" aria-label="The box in hand">
      <div class="top">
        <div class="who">
          <h3>{@box["name"]}</h3>
        </div>
        <.link class="btn" patch={@back || "/#{@tab}"}>Put back</.link>
        <.ribbon
          label="The box && what comes inside it"
          selected={@screen}
          items={
            for {key, label} <- @screens,
                do: %{
                  key: key,
                  label: label,
                  why: screen_unlit(key, @box, @installed, @papers),
                  href:
                    ConsoleWeb.Refs.over(
                      @back || "/#{@tab}",
                      "box=#{@box["name"]}&screen=#{key}#{if key == "manual", do: "&paper=#{@paper}"}"
                    )
                }
          }
        />
      </div>

      <.files :if={@screen == "files"} box={@box} status={@status} diff={@diff} />
      <.install
        :if={@screen == "install"}
        box={@box}
        c={@c}
        status={@status}
        catalog={@catalog}
        args={@args}
        recipe={@recipe}
        jobs={@jobs}
        open={@open}
        now={@now}
        asking={@asking}
        stoppable={@stoppable}
        installed={@installed}
      />
      <.manual
        :if={@screen == "manual"}
        box={@box}
        papers={@papers}
        paper={@paper}
        page={@page}
        tab={@tab}
        back={@back}
      />
      <.sheet
        :if={@screen == "box"}
        packages={@packages}
        read_deps={@read_deps}
        packages_asking={@packages_asking}
        packages_error={@packages_error}
        now={@now}
        box={@box}
        c={@c}
        status={@status}
        catalog={@catalog}
        args={@args}
        recipe={@recipe}
        installed={@installed}
        face={@face}
      />
    </aside>
    """
  end

  defp screen_unlit("files", box, _installed, _papers),
    do: files_unlit(box, box[:status_for_files])

  defp screen_unlit("manual", _box, _installed, []), do: "this box carries no papers"
  defp screen_unlit(_, _, _, _), do: nil

  @doc """
  Why the Files screen is dark: the box is not done, a collection's
  picks are not in, or the cartridge was not inserted by commit — what
  it wrote is read off its commits, one per insert, && there is none.
  """
  def files_unlit(box, status) do
    cond do
      box["pending"] ->
        "the box is designed; its installer is not done yet"

      box["collection"] ->
        if member_inserts(box, status) == [],
          do: "nothing to show until its picks are in the project",
          else: nil

      Cartridges.insert(status, box["name"]) ->
        nil

      composer = Cartridges.composer(status, box) ->
        "it came in with #{composer["name"]}'s insert: its files are in that commit"

      true ->
        "not inserted yet: what it wrote is read off its commit"
    end
  end

  @doc "A collection's members that are in by commit, newest first (the status's order)."
  def member_inserts(box, status) do
    names = box["members"] |> List.wrap() |> Enum.map(& &1["name"]) |> MapSet.new()
    Enum.filter(get_in(status, ["git", "inserts"]) || [], &MapSet.member?(names, &1["feature"]))
  end

  # --- Files: what the cartridge wrote ----------------------------------------

  defp files(assigns) do
    ~H"""
    <div class="install">
      <div class="impl">
        <p :if={@diff == :loading} class="note">
          reading the commit{if @box["collection"], do: "s"}…
        </p>
        <%= if is_map(@diff) do %>
          <span class="label">Summary</span>
          <div class="picks">
            <.pick
              :if={@box["collection"] && @diff[:contiguous] && length(@diff.picks) > 1}
              name={@box["name"]}
              here={true}
              sha=""
              date=""
              subject=""
              added={@diff.added}
              removed={@diff.removed}
              files={length(@diff.files)}
              title={@diff.range <> " — read off the range, not the column added up. The column is what each pick did; this is what the project was left with. A file several picks touch is one file, && a line one pick wrote && a later one took out was never there at the start nor at the end."}
            />
            <%= if @box["collection"] do %>
              <.pick
                :for={p <- @diff.picks}
                name={p.name}
                here={false}
                sha={p.sha}
                date={p.date}
                subject={p.subject}
                added={p.added}
                removed={p.removed}
                files={length(p.files)}
                status={@status}
              />
            <% else %>
              <.pick
                :for={p <- @diff.picks}
                name={@box["name"]}
                here={true}
                sha={p.sha}
                date={p.date}
                subject={p.subject}
                added={p.added}
                removed={p.removed}
                files={length(p.files)}
              />
            <% end %>
          </div>
          <%= cond do %>
            <% not @box["collection"] && length(@diff.picks) > 1 -> %>
              <%!-- One sheet per insert: the commits are apart in the log,
                    so no range reads them as one. --%>
              <%= for {p, k} <- Enum.with_index(@diff.picks) do %>
                <span class="label" title={p.subject}>
                  Files · {String.slice(p.sha, 0, 7)} {p.subject}
                </span>
                <div class={["files", length(p.files) > 12 && "many"]}>
                  <.file
                    :for={{f, i} <- Enum.with_index(p.files)}
                    f={f}
                    i={k * 1000 + i}
                    status={@status}
                  />
                </div>
              <% end %>
            <% @diff.files != [] -> %>
              <span class="label">Files</span>
              <div class={["files", length(@diff.files) > 12 && "many"]}>
                <.file :for={{f, i} <- Enum.with_index(@diff.files)} f={f} i={i} status={@status} />
              </div>
            <% @box["collection"] && not @diff.contiguous -> %>
              <p class="caveat">
                Their commits are not contiguous — a second pass, a pick born with phx.new or one ejected in between — so there is no honest range to read as one.
              </p>
            <% @box["collection"] -> %>
              <p class="caveat">
                The box leaves no commit of its own: what it did is what its picks did.
              </p>
            <% true -> %>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # The packages the box puts in the project's `mix.exs` — *packages*
  # and not *brings*, which is what the Specs above call the containers
  # it raises: two panels of one screen never share a word. Before it
  # is in, the
  # packages it may bring, off the manifest (`deps/1` with `:any`): a
  # reader sees what an insert would add without inserting. Once it is
  # in, the ones this project carries of it, each with what the box
  # brings, what `mix.exs` pins today and what `mix.lock` resolved — the
  # three differ on a project whose insert is older than the box, and the
  # difference is the row's own reading.
  attr :box, :map, required: true
  attr :c, :map, required: true
  attr :installed, :boolean, required: true
  attr :hex, :map, default: %{}, doc: "what hex said of each package, by name"
  attr :hex_asking, :boolean, default: false
  attr :hex_error, :any, default: nil
  attr :now, :any, default: nil

  attr :read_deps, :any,
    default: [],
    doc: "the packages this box's insert commit put in mix.exs, for a box that declares none"

  attr :mix, :list, default: [], doc: "every package the project carries, pinned and locked"

  defp packages(assigns) do
    carried = assigns.installed && assigns.c["deps"]
    declared = assigns.box["deps"] || []

    own = assigns.installed and declared == []

    carried =
      if carried in [nil, []] and assigns.installed,
        do: off_the_insert(assigns.read_deps, assigns.mix),
        else: carried

    rows = if(carried && carried != [], do: carried, else: nil)

    # A base cartridge that declares none and whose insert commit says
    # nothing was not inserted: the project was born with the flag, and
    # there is no commit to read. The panel says so rather than leaving
    # the reader to wonder whether the box costs nothing.
    nothing =
      cond do
        not own or rows != nil or assigns.read_deps == :loading -> nil
        assigns.read_deps == :born -> "born with the project: no insert commit to read them off"
        assigns.read_deps == [] -> "its insert commit put no package in mix.exs"
        true -> "what its insert commit added is not in mix.exs any more"
      end

    now = assigns.now || DateTime.utc_now()

    assigns =
      assign(assigns,
        nothing: nothing,
        rows: for(row <- rows || declared, do: Packages.row(row, assigns.hex, now, rows != nil))
      )

    ~H"""
    <Packages.table rows={@rows} nothing={@nothing} hex_asking={@hex_asking} hex_error={@hex_error} />
    """
  end

  # A base cartridge declares no package: its own arrive inside the
  # `phx.new` delta, at whatever version that installer writes. What it
  # brought is read off its insert commit instead (`Console.Diffs`) and
  # matched against the project's own list, so nothing is kept by hand
  # and a name the project no longer carries is not claimed. A project
  # born with the flag has no insert commit, so it has nothing here.
  defp off_the_insert(read, mix) when is_list(read) and read != [] do
    project = Map.new(mix, &{&1["name"], &1})

    for %{name: name} = dep <- read, project[name] do
      %{
        "name" => name,
        "declared" => dep.requirement,
        "pinned" => project[name]["pinned"],
        "locked" => project[name]["locked"],
        "git" => Packages.git_said(dep[:git]) || project[name]["git"],
        "read" => true,
        "from" => dep[:from]
      }
    end
  end

  defp off_the_insert(_read, _mix), do: []

  attr :name, :string, required: true
  attr :here, :boolean, default: false
  attr :sha, :string
  attr :date, :string
  attr :subject, :string
  attr :added, :integer
  attr :removed, :integer
  attr :files, :integer
  attr :title, :string, default: nil
  attr :status, :map, default: nil

  defp pick(assigns) do
    ~H"""
    <div class={["pick", @here && @sha == "" && "total"]}>
      <span class="p"><.cart_ref
        name={@name}
        installed={true}
        unlit={@here && "the box you have in hand"}
      /></span>
      <span class="sh">{String.slice(@sha || "", 0, 7)}</span>
      <span class="dt">{String.slice(@date || "", 0, 10)}</span>
      <span class="sj" title={@subject}>{@subject}</span>
      <span class="n" title={@title}><span class="a">+{@added}</span><span
        :if={@removed && @removed > 0}
        class="r"
      > −{@removed}</span></span>
      <span class="fc" title={@title}>{@files} file{if @files == 1, do: "", else: "s"}</span>
    </div>
    """
  end

  @doc "One file of a diff, folded: the sheet the box's Files screen and the Git screen share."
  attr :f, :map, required: true
  attr :i, :integer, required: true
  attr :status, :map, default: nil

  def file(assigns) do
    by = Map.get(assigns.f, :by, [])

    id = "f-#{assigns.i}"

    # The fold: the button that is the path carries it and the aria-expanded
    # the caret is drawn from; the row carries it too, so the counts and the
    # caret at its far end fold as well — LiveView fires the binding closest
    # to the click, so the path's stays the path's.
    toggle =
      Phoenix.LiveView.JS.toggle_attribute({"hidden", "hidden"}, to: "##{id}-b")
      |> Phoenix.LiveView.JS.toggle_class("open", to: "##{id}")
      |> Phoenix.LiveView.JS.toggle_attribute({"aria-expanded", "true", "false"},
        to: "##{id} .ft"
      )

    assigns =
      assign(assigns,
        by: by,
        shown: Enum.take(by, 3),
        rest: max(length(by) - 3, 0),
        id: id,
        toggle: toggle
      )

    ~H"""
    <div class="f" id={@id}>
      <div class="fh" phx-click={@toggle}>
        <button class="ft fold" type="button" aria-expanded="false" phx-click={@toggle}>
          <span class="p">{@f.path}</span>
        </button>
        <span :if={@f.born || @f.gone} class="mark">{if @f.born, do: "new", else: "gone"}</span>
        <%!-- A mention's click is its own: the empty binding stops it here, so
              the row does not fold under a cartridge the reader is opening. --%>
        <span :if={@shown != []} class="refs" phx-click={%Phoenix.LiveView.JS{}}>
          <.cart_ref :for={n <- @shown} name={n} installed={true} />
          <span :if={@rest > 0} class="more" title={"and " <> Enum.join(Enum.drop(@by, 3), ", ")}>+{@rest}</span>
        </span>
        <span class="n">
          <span :if={@f.binary}>binary</span>
          <span :if={!@f.binary} class="a">+{@f.added}</span><span
            :if={!@f.binary && @f.removed > 0}
            class="r"
          > −{@f.removed}</span>
        </span>
      </div>
      <div id={"#{@id}-b"} hidden>
        <p :if={@f.treatment == :omit} class="none">
          left out on purpose: its lines run past a thousand characters && nobody reads them
        </p>
        <div :if={@f.treatment == :image && not @f.gone} class="shot">
          <img src={"/blob/#{@f.tip}/#{@f.path}"} alt={@f.path} />
        </div>
        <pre
          :if={@f.treatment != :image && @f.treatment != :omit}
          class="src"
          id={"#{@id}-src"}
          data-lang={Console.Highlight.lang(@f.path)}
          style={"--gut:#{Console.Diffs.gutter(@f.rows)}ch"}
        >
          <div :if={String.downcase(Path.extname(@f.path)) == ".svg" && not @f.gone} class="switch">
            <button type="button" class="on" aria-pressed="true" phx-click={Phoenix.LiveView.JS.remove_class("drawn", to: "##{@id}-src") |> Phoenix.LiveView.JS.add_class("on", to: "##{@id}-src .switch button:first-child") |> Phoenix.LiveView.JS.remove_class("on", to: "##{@id}-src .switch button:last-child")}>code</button>
            <button type="button" aria-pressed="false" phx-click={Phoenix.LiveView.JS.add_class("drawn", to: "##{@id}-src") |> Phoenix.LiveView.JS.remove_class("on", to: "##{@id}-src .switch button:first-child") |> Phoenix.LiveView.JS.add_class("on", to: "##{@id}-src .switch button:last-child")}>drawing</button>
          </div>
          <div class="rows"><.row :for={r <- @f.rows} r={r} /></div>
          <div :if={String.downcase(Path.extname(@f.path)) == ".svg" && not @f.gone} class="shot drawing"><img class="drawn" src={"/blob/#{@f.tip}/#{@f.path}"} alt={@f.path} /></div>
        </pre>
      </div>
    </div>
    """
  end

  attr :r, :any, required: true

  defp row(assigns) do
    {cls, o, n, sign, html} = assigns.r
    assigns = assign(assigns, cls: cls, o: o, n: n, sign: sign, html: html)

    ~H"""
    <div class={[
      "dl",
      @cls == :add && "add",
      @cls == :del && "del",
      @cls == :hunk && "hunk",
      @cls == :meta && "meta"
    ]}>
      <span class="gut" style={"--d:#{digits(@o)}"}>{@o}</span><span
        class="gut"
        style={"--d:#{digits(@n)}"}
      >{@n}</span><span class="sg">{@sign}</span><span class="cd">{Phoenix.HTML.raw(@html)}</span>
    </div>
    """
  end

  # How many digits a line number has, for the sheet to centre it on a
  # whole pixel: a bitmap face's digit is an odd number of pixels wide,
  # so half the leftover of a cell is a half pixel every other count.
  defp digits(nil), do: 0
  defp digits(n), do: n |> Integer.digits() |> length()

  # --- Box: the face, the need, the specs -------------------------------------

  defp sheet(assigns) do
    ~H"""
    <div class="body">
      <div class={["hand", @box["archived"] && "archived"]}>
        <%!-- The box is turned by hand: a click on it, Enter or Space
              with it focused. Not a <button>: its two sides hold headings
              and paragraphs, which a button may not. The lozenge in the
              corner opens the viewer on the side that shows; it stops its
              click from turning the box. --%>
        <div
          class="face"
          id="d-face"
          role="button"
          tabindex="0"
          phx-hook="Face"
          phx-click="flip"
          phx-keydown="flip"
          phx-key="Enter"
          aria-label={if @face == "front", do: "Turn it over", else: "Turn it back"}
        >
          <div class={["card", @face == "back" && "back"]} id="d-card">
            <div class="side front">
              <img
                :if={@box["covers"]["front"]}
                src={"/covers/#{@box["covers"]["front"]}"}
                alt={"#{@box["name"]} — box cover"}
                draggable="false"
              />
              <img
                :if={is_nil(@box["covers"]["front"])}
                src={"/covers/#{if @box["pending"], do: "empty_cover_placeholder.jpg", else: "cover_placeholder.png"}"}
                alt=""
                draggable="false"
              />
              <div :if={is_nil(@box["covers"]["front"])} class="typeset">
                <h4>{@box["name"]}</h4><span class="nocover">{if @box["pending"],
                  do: "not done yet — a drawing, not a cartridge",
                  else: "no box yet — the socket stands in"}</span>
              </div>
            </div>
            <div class="side back">
              <img
                :if={@box["covers"]["back"]}
                src={"/covers/#{@box["covers"]["back"]}"}
                alt={"#{@box["name"]} — box back"}
                draggable="false"
              />
              <img
                :if={is_nil(@box["covers"]["back"])}
                src={"/covers/#{if @box["pending"], do: "empty_back_placeholder.jpg", else: "back_placeholder.jpg"}"}
                alt=""
                draggable="false"
              />
              <div :if={is_nil(@box["covers"]["back"])} class="typeset">
                <h4>{@box["summary"] || @box["name"]}</h4><p :if={@box["example"]}>
                  $ {@box["example"]}
                </p><span class="nocover">{if @box["pending"],
                  do: "not done yet — the drawing, through the sheet",
                  else: "typeset back — the composed back would go here"}</span>
              </div>
            </div>
          </div>
          <button class="expand" type="button" aria-label="See this side large">⤢ expand</button>
        </div>
      </div>
      <div class="sheet">
        <div class="head">
          <div class="kicker">
            <.chip
              :if={@box["pending"]}
              class="warn"
              title="the box is designed; its installer is not done yet"
            >
              not done
            </.chip>
            <%!-- Archived is a fact of the box and being in is a fact of
                  the project, so a retired box a project already carries
                  says both. It does not also say *on the shelf*: that
                  one is the plain absence of being in, and the ribbon
                  reads these four as one state each. The chip is
                  `off` and not `unlit` — it reports something true out
                  there, it is not a control the reader cannot use. --%>
            <.chip :if={@box["archived"]} class="off" title={@box["archived"]}>archived</.chip>
            <.chip :if={!@box["pending"] && @installed} class="good">inserted</.chip>
            <.chip :if={!@box["pending"] && !@box["archived"] && !@installed}>on the shelf</.chip>
            <.chip :if={@box["version"]}>v{@box["version"]["version"]}</.chip>
            <.chip :if={@box["collection"]}>collection</.chip>
            <.chip :if={@box["base"]} title="a phx.new capability: in from birth unless left out">
              base
            </.chip>
          </div>
          <h4>{title(@box)}</h4>
          <p>
            {@box["summary"] ||
              "Documented in the generated project, but its installer is not done yet."}
          </p>
          <div :if={@box["need"]} class="need">
            <p class="want">{ticked(@box["need"]["line"])}</p>
            <%= for {label, key} <- [{"Before", "before"}, {"After", "after"}, {"Not for", "not_for"}], @box["need"][key] do %>
              <div class="row">
                <span class="k">{label}</span><span class="v">{ticked(@box["need"][key])}</span>
              </div>
            <% end %>
          </div>
        </div>
        <div>
          <span class="label">Specs</span><.specs
            box={@box}
            c={@c}
            status={@status}
            catalog={@catalog}
            args={@args}
            recipe={@recipe}
            installed={@installed}
          />
          <.packages
            box={@box}
            c={@c}
            installed={@installed}
            hex={@packages}
            hex_asking={@packages_asking}
            hex_error={@packages_error}
            read_deps={@read_deps}
            mix={get_in(@status, ["project", "deps"]) || []}
            now={@now}
          />
        </div>
      </div>
    </div>
    """
  end

  defp title(e), do: e["name"] |> String.replace(~r/(\d+)$/, " \\1") |> String.replace("_", " ")

  # `code` in ticks, as the need writes it.
  defp ticked(text) do
    text
    |> String.split("`")
    |> Enum.with_index()
    |> Enum.map(fn {part, i} ->
      if rem(i, 2) == 1,
        do:
          Phoenix.HTML.raw([
            "<code>",
            Phoenix.HTML.html_escape(part) |> Phoenix.HTML.safe_to_string(),
            "</code>"
          ]),
        else: part
    end)
  end

  # Specs: what the cartridge is, as opposed to what you are about to do
  # with it. Three rows move with the options — a collection's recipe,
  # what a chosen value builds on, and the containers it raises — so the
  # panel says which switch moved it.
  defp specs(assigns) do
    asked = value_requires(assigns.box, assigns.args, assigns.status)
    members = members(assigns)
    up = Cartridges.app_up?(assigns.status)

    assigns =
      assign(assigns,
        asked: asked,
        members: members,
        up: up,
        brings: brings(assigns),
        console: assigns.box["console"] || %{},
        doors: doors(assigns)
      )

    ~H"""
    <div class="specs">
      <span :if={@box["task"]} class="k">Task</span>
      <span :if={@box["task"]} class="v"><span class="path">mix {@box["task"]}</span></span>
      <span class="k">Kind</span>
      <span class="v">
        <span class="w">{cond do
          @box["collection"] -> "collection"
          @box["base"] -> "base cartridge"
          true -> "cartridge"
        end}</span>
        <span class="note">{kind_note(@box)}</span>
      </span>
      <span :if={@box["requires"] != [] || @asked != []} class="k">Needs</span>
      <span :if={@box["requires"] != [] || @asked != []} class="v stack">
        <span :for={r <- @box["requires"]} class="req"><.cart_ref
          name={r}
          installed={Cartridges.satisfies?(@status, r, condition(@box, r))}
        /><span :if={condition(@box, r) != %{}} class="by">with {Cartridges.state_said(
          condition(@box, r)
        )}</span></span>
        <span :for={{why, names, conds} <- @asked} class="why"><span :for={n <- names} class="req"><.cart_ref
          name={n}
          installed={Cartridges.satisfies?(@status, n, conds[n] || %{})}
        /><span :if={conds[n]} class="by">with {Cartridges.state_said(conds[n])}</span></span><span class="by">by {why}</span></span>
      </span>
      <span :if={@box["collection"]} class="k">Inserts</span>
      <span :if={@box["collection"]} class="v stack">
        <span :if={@members == :asking} class="note">asking the project which of its picks are already in…</span>
        <%= if is_list(@members) do %>
          <span :for={m <- @members} class="why"><.cart_ref
            name={m["name"]}
            installed={Cartridges.installed?(@status, m["name"])}
          /><span :if={m["argv"] != []}>{Enum.join(m["argv"], " ")}</span></span>
        <% end %>
      </span>
      <span :if={@brings != []} class="k">Brings</span>
      <span :if={@brings != []} class="v stack">
        <span :for={{service, why} <- @brings} class={["req", why && "unlit"]} title={why}>
          <span class="svc" style={"--svc:#{ConsoleWeb.Services.role_color(service["role"])}"}>
            {service["service"]}
          </span>
          <span :if={service["listens"]} class="path">:{service["listens"]}</span>
          <span class="by">{Enum.join(service["deploys"] || [], " · ")}</span>
        </span>
      </span>
      <span :if={@doors != []} class="k">Opens</span>
      <span :if={@doors != []} class="v stack">
        <.door_ref
          :for={a <- @doors}
          label={a.label}
          path={a.path}
          href={a.href}
          why={a.why}
          kind={a.kind}
          read={a.read}
        />
      </span>
      <span :if={(@console["tabs"] || []) != []} class="k">Lights</span>
      <span :if={(@console["tabs"] || []) != []} class="v"><span
        :for={t <- @console["tabs"]}
        class="w"
      >{t}</span></span>
      <span :if={@box["afterwards"]} class="k">After</span>
      <span :if={@box["afterwards"]} class="v"><span class="after">{@box["afterwards"]}</span></span>
    </div>
    """
  end

  defp kind_note(e) do
    again =
      cond do
        e["pending"] -> nil
        e["collection"] -> "inserting it again inserts what is missing"
        is_list(e["adds"]) -> "inserting it again adds " <> flags_said(e["adds"])
        e["adds"] == "all" -> "inserting it again adds to what is in"
        true -> "inserting it again changes nothing"
      end

    [e["base"] && "a phx.new capability, in from birth unless left out", again]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  # The doors as the Record reads them once the box is in — the same
  # face, reason and reading as on its row — and shut until it is.
  defp doors(%{box: box, c: c, installed: installed, status: status}) do
    for d <- get_in(box, ["console", "doors"]) || [] do
      if installed and c do
        Record.door(status, c, d)
      else
        %{
          label: d["label"],
          path: Cartridges.fill_path(d["path"], box),
          kind: if(d["output"], do: "output", else: "route"),
          href: nil,
          why: "insert #{box["name"]} first",
          read: nil
        }
      end
    end
  end

  # A collection's recipe: what expand answered, the catalog's while it
  # is asked, minus nothing — the catalog's is what the defaults give.
  defp members(%{box: %{"collection" => true}, recipe: :asking}), do: :asking
  defp members(%{box: %{"collection" => true}, recipe: recipe}) when is_list(recipe), do: recipe
  defp members(%{box: box}), do: box["members"] || []

  # The containers the box raises: `[{service, why}]`, `why` the reason
  # it is unlit and `nil` when it is lit.
  #
  # Once it is in, the project says it — the carried cartridge's
  # `compose` is the real thing, engine and all, and nothing here has
  # to guess. On the shelf there is no project to ask, so the row reads
  # the manifest's menu (`offers`) and lights what the form is holding:
  # it moves with the switches, as Needs and Inserts do.
  #
  # Either way the rest of the menu stays, unlit. A cartridge that can
  # be run again to add more — `rerun: adds`, as db_admin is — lights
  # it by the form like a box on the shelf: those are containers the
  # reader can still have, and ticking the switch is how they ask. One
  # whose form is locked cannot be moved by any switch, so the reason
  # is not a switch but the state it went in with: ecto on sqlite has
  # no `database` container because SQLite is a file, and the row says
  # that rather than leaving the reader to wonder where it went.
  defp brings(assigns) do
    have = if assigns.installed, do: assigns.c["compose"] || [], else: []
    inside = MapSet.new(have, & &1["service"])
    locked = assigns.installed and (assigns.box["adds"] || "none") == "none"

    rest =
      for o <- assigns.box["offers"] || [], not MapSet.member?(inside, o["service"]), do: o

    for(service <- have, do: {service, nil}) ++
      for o <- rest do
        cond do
          locked -> {o, locked_out(o, assigns.box, assigns.c)}
          chosen?(o, assigns.args) -> {o, nil}
          true -> {o, unlit(o)}
        end
      end
  end

  # Why it is not there and no switch will bring it: the cartridge is
  # in and its form is locked, so what it went in with decided this.
  # Said as that state and not as the switch — `--database postgres`
  # would be a lie, since the reader cannot move it without ejecting
  # first — and narrowed to the options this container hangs on, so a
  # cartridge with many switches does not read out all of them.
  defp locked_out(offer, box, c) do
    decided = Map.take(c["state"] || %{}, for(w <- offer["with"] || [], do: w["option"]))

    if decided == %{},
      do: unlit(offer),
      else: "#{box["name"]} is in with #{Cartridges.state_said(decided)}"
  end

  # Whether the form as filled brings this one: a service that waits on
  # no choice always does, and one that waits needs any of its choices
  # to be the value the field holds (`--admin` holds several).
  defp chosen?(offer, args) do
    (offer["with"] || []) == [] or
      Enum.any?(offer["with"], &(&1["value"] in List.wrap(args[&1["option"]] || [])))
  end

  # Why it is not lit: the switches that would bring it, in the words
  # the reader would type.
  defp unlit(offer) do
    said =
      (offer["with"] || [])
      |> Enum.group_by(& &1["option"], & &1["value"])
      |> Enum.map_join(" · ", fn {option, values} ->
        "--#{String.replace(option, "_", "-")} #{Enum.join(values, ", ")}"
      end)

    if said == "", do: nil, else: "only with #{said}"
  end

  @doc "What each chosen value builds on: [{\"--flag value\", [names], conditions}]."
  def value_requires(box, args, _status),
    do: chosen_values(box, args) ++ switches_on(box, args)

  defp chosen_values(box, args) do
    for o <- box["options"] || [],
        o["choices"],
        v <- List.wrap(args[o["name"]] || []),
        c = Enum.find(choices(o), &(&1["value"] == v)),
        (c["requires"] || []) != [] do
      {"--#{String.replace(o["name"], "_", "-")} #{v}", c["requires"], c["conditions"] || %{}}
    end
  end

  # A switch turned on says it by its flag alone.
  defp switches_on(box, args) do
    for o <- box["options"] || [],
        o["type"] == "boolean",
        (o["requires"] || []) != [],
        args[o["name"]] == "on" do
      {"--#{String.replace(o["name"], "_", "-")}", o["requires"], o["conditions"] || %{}}
    end
  end

  def choices(%{"choices" => [%{"group" => _} | _] = groups}),
    do: Enum.flat_map(groups, & &1["values"])

  def choices(%{"choices" => values}), do: values

  # --- Installation -------------------------------------------------------------

  defp install(assigns) do
    insert = Cartridges.insert(assigns.status, assigns.box["name"])
    # What a second insert can still put in, the box's own word: "none"
    # — the form takes no more input at all —, "all", or the options it
    # still adds, the rest having been fixed when it went in. A field
    # nobody can move is a field that must not be offered: the job it
    # would send is one the installer refuses on arrival.
    adds = assigns.box["adds"] || "none"
    locked = assigns.installed && adds == "none"
    clean = is_nil(assigns.status) || get_in(assigns.status, ["git", "clean"]) != false
    missing = missing(assigns.box, assigns.args, assigns.status)
    left = if assigns.box["collection"], do: members_left(assigns), else: nil
    going = if assigns.box["collection"], do: ejectable(assigns), else: []

    blockers =
      eject_blockers(
        assigns.box,
        assigns.status,
        if(assigns.box["collection"],
          do: Enum.map(going, & &1["feature"]),
          else: [assigns.box["name"]]
        )
      )

    argv = line_argv(assigns.box, assigns.args, insert, locked)

    assigns =
      assign(assigns,
        insert: insert,
        locked: locked,
        clean: clean,
        missing: missing,
        left: left,
        going: going,
        blockers: blockers,
        argv: argv,
        # What it went in with, for the fields to start from — the ones
        # that are locked and the ones that can be run again (`rerun:
        # adds`), which went back to their defaults and so forgot.
        inserted_args: (insert && insert["argv"]) || [],
        from_insert: insert != nil,
        # Insertable while it is not in, and still while it is when
        # inserting again adds to what is there (`rerun: adds`).
        can_insert: !assigns.installed || adds != "none",
        adds: adds,
        full:
          assigns.installed && !assigns.box["collection"] &&
            nothing_to_add?(assigns.box, assigns.c || %{}, assigns.status, adds)
      )

    ~H"""
    <div class="install">
      <form
        class={["insert", @locked && "locked"]}
        id="insert-form"
        phx-change="options"
        phx-submit="insert"
      >
        <span class="label">Options</span>
        <div class="opts">
          <p :if={@box["options"] == []} class="nothing">This cartridge takes no options.</p>
          <.option
            :for={o <- @box["options"]}
            o={o}
            args={@args}
            status={@status}
            locked={@locked || (@installed && not addable?(@adds, o))}
            installed={@installed}
            c_state={@c["state"] || %{}}
            detected={(@c || %{})["detected"] || %{}}
            from_insert={@from_insert}
            inserted_args={@inserted_args}
            by_hand={@locked && @insert == nil}
          />
        </div>
        <%!-- One foot per verb, each with the line it is: a cartridge
              that is not in can be inserted, one that is in can be
              ejected, and the two that can be run again to add — `ash`
              and the `chiefs_setup` collection — have both at once, one
              under the other. A button that says `Already inserted` is
              not an action that cannot run but a state wearing a
              button's clothes; what is in is said by the mention's dot
              and by these notes. Unlit stays for the verbs that ARE conceivable
              here and cannot run now: a dirty tree, a cartridge missing,
              nothing to revert. --%>
        <div :if={@can_insert} class="foot">
          <div class="cmd">{insert_line(@box, @argv)}</div>
          <.job_button
            label={
              cond do
                @box["pending"] ->
                  "Not done yet"

                @box["archived"] ->
                  "Archived"

                @missing != [] ->
                  "Insert #{hd(@missing)} first"

                @left == :asking ->
                  "Asking…"

                is_list(@left) and @left == [] ->
                  "Every pick is in"

                is_list(@left) ->
                  "Insert #{length(@left)} cartridge#{if length(@left) == 1, do: "", else: "s"}"

                @installed ->
                  "Add to cartridge"

                true ->
                  "Insert cartridge"
              end
            }
            class="primary"
            form="insert-form"
            args={"add #{@box["name"]}#{if @argv != [], do: " " <> Enum.join(@argv, " ")}"}
            why={
              cond do
                @box["pending"] -> "no installer yet: nothing to run"
                # The installer still works; the console is not where it
                # is forced. The shell's flag is, and the command above
                # already carries it.
                @box["archived"] -> "#{@box["archived"]} — the line above inserts it anyway"
                not @clean -> "the tree has changes git does not have — commit first"
                @missing != [] -> "#{hd(@missing)} has to go in first"
                @left == :asking -> "reading what is in"
                is_list(@left) and @left == [] -> "every cartridge of this box is in"
                @full -> "every value this project allows is in: nothing left to add"
                true -> nil
              end
            }
          />
          <span class="note">{insert_note(assigns)}</span>
        </div>
        <div :if={@installed} class="foot">
          <div class="cmd">{eject_line(@box, @going)}</div>
          <.job_button
            label={if @box["collection"], do: "Eject #{length(@going)}", else: "Eject"}
            class="danger"
            event="eject"
            phx-value-name={@box["name"]}
            title={eject_title(@box, @insert, @going, @blockers)}
            why={
              cond do
                not @clean ->
                  "the tree has changes git does not have — commit first"

                @blockers != [] ->
                  Enum.join(@blockers, "; ") <> " — eject those first"

                @box["collection"] && @going == [] ->
                  "no cartridge of this box left a commit to revert"

                !@box["collection"] && is_nil(@insert) ->
                  eject_title(@box, @insert, @going, @blockers)

                true ->
                  nil
              end
            }
          />
          <span class="note">{eject_note(assigns)}</span>
        </div>
      </form>
      <%!-- The box's runs, each the row the Jobs screen draws: the same
            chip, the same fold, the same grip and the same words at the
            foot — one way to meet a job, wherever it is met. The unfold
            state is the Jobs screen's too: it is the same job. --%>
      <div class="runs">
        <div class="log-cap">
          <span class="label">Runs</span><span :if={@jobs != []} class="note">this box's inserts and ejects, newest first · they are in the Jobs tab too</span>
        </div>
        <p :if={@jobs == []} class="nothing">
          Nothing has run for this box yet: an insert's output lands here, and in the jobs tray.
        </p>
        <div :if={@jobs != []} class="lines jobs-list" id={"runs-" <> @box["name"]} phx-hook="JobOut">
          <ConsoleWeb.JobsScreen.job_row
            :for={j <- @jobs}
            j={j}
            open={MapSet.member?(@open, j.id)}
            now={@now}
            asking={@asking}
            stoppable={@stoppable}
            prefix="jbox-"
          />
        </div>
      </div>
    </div>
    """
  end

  # One option, whatever its shape: the key (its flag and what kind of
  # answer it takes) and the body, one line per control. A line reads
  # control · name · tags · — note in every shape: a switch is a list of
  # one with no name, a text is a line with a field. A tag sits on the
  # line of the control it shuts, whether the option asks for the
  # cartridge (credo's --githook) or one of its values does (db_admin's
  # pgadmin); the key never carries one. The option's doc is always the
  # last line of its answers.
  attr :o, :map, required: true
  attr :args, :map, required: true
  attr :status, :map
  attr :locked, :boolean
  attr :installed, :boolean
  attr :c_state, :map
  attr :from_insert, :boolean
  attr :inserted_args, :list
  attr :by_hand, :boolean, doc: "locked with no Insert commit to read the value off"
  attr :detected, :map, default: %{}, doc: "the defaults the project gives, off the status"

  defp option(assigns) do
    o = with_detected(assigns.o, assigns.detected)
    grouped = match?([%{"group" => _} | _], o["choices"])

    assigns =
      assign(assigns,
        o: o,
        flag: "--" <> String.replace(o["name"], "_", "-"),
        kind: kind(o),
        groups:
          if(grouped,
            do: o["choices"],
            else: [%{"group" => nil, "values" => o["choices"] || []}]
          )
      )

    ~H"""
    <div class="opt">
      <div class="key">
        <span class="flag">{@flag}</span>
        <span class="kind">{@kind}</span>
      </div>
      <div class="answers">
        <%= cond do %>
          <% @o["choices"] -> %>
            <%= for g <- @groups do %>
              <span :if={g["group"]} class="gl">{String.replace(to_string(g["group"]), "_", " ")}</span>
              <.choice
                :for={c <- g["values"]}
                o={@o}
                c={c}
                args={@args}
                status={@status}
                locked={@locked}
                installed={@installed}
                c_state={@c_state}
              />
            <% end %>
            <div :if={@o["open"]} class="line other">
              <input
                type="text"
                name={"other[#{@o["name"]}]"}
                value={@args["other:#{@o["name"]}"]}
                placeholder={
                  if @o["multiple"],
                    do: "other: name, name — anything the installer takes",
                    else: "other: another value"
                }
                disabled={@locked}
              />
            </div>
          <% @o["type"] == "boolean" -> %>
            <.switch {assigns} />
          <% true -> %>
            <div class="line txt">
              <input
                type={input_type(@o)}
                inputmode={input_mode(@o)}
                pattern={input_pattern(@o)}
                title={format_says(@o)}
                spellcheck={input_type(@o) == "url" && "false"}
                phx-hook={input_type(@o) == "url" && "UrlField"}
                id={"opt-#{@o["name"]}"}
                name={"opt[#{@o["name"]}]"}
                value={text_value(@o, @args, @c_state, @from_insert, @inserted_args)}
                placeholder={
                  if @by_hand, do: "inserted by hand: value unknown", else: placeholder(@o)
                }
                disabled={@locked}
              />
              <.tags need={[]} default={!@installed && text_default(@o)} status={@status} />
            </div>
        <% end %>
        <p :if={@o["doc"]} class="doc">{@o["doc"]}</p>
      </div>
    </div>
    """
  end

  # The shape the value has to have, where the manifest declares one
  # (`formats/0`): the field asks for it — a URL field is a URL field in
  # every browser — and the browser checks it before the installer does,
  # which refuses it all the same.
  defp input_type(%{"format" => "url"}), do: "url"
  defp input_type(_o), do: "text"

  defp input_mode(%{"format" => "integer" <> _}), do: "numeric"
  defp input_mode(_o), do: nil

  # `type="url"` alone takes any scheme (`ftp://…`): the pattern is the
  # rule the installer holds it to, http or https with something after.
  defp input_pattern(%{"format" => "url"}), do: "https?://.+"
  defp input_pattern(%{"format" => "version"}), do: "\\d+\\.\\d+\\.\\d+.*"
  defp input_pattern(%{"format" => "integer " <> _}), do: "\\d{1,3}"

  defp input_pattern(%{"format" => "dns_name"}),
    do: "[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*"

  defp input_pattern(%{"format" => "route"}), do: "/*([A-Za-z0-9._~-]+/*)*"
  defp input_pattern(_o), do: nil

  # What the shape is, in the words the installer refuses with.
  defp format_says(%{"format" => format}) when is_binary(format) do
    case format do
      "url" -> "a URL (https://example.com/page)"
      "version" -> "a version (1.2.3)"
      "dns_name" -> "a DNS name (app.default.svc.cluster.local)"
      "route" -> "a path (/health)"
      "integer " <> range -> "a whole number from #{String.replace(range, "..", " to ")}"
      other -> other
    end
  end

  defp format_says(_o), do: nil

  # What kind of answer the option takes, said under its flag: the one
  # place a list that also takes values of its own says so. A text with
  # a declared shape says the shape instead — `url`, not `text`.
  defp kind(o) do
    base =
      cond do
        o["choices"] && o["multiple"] -> "several"
        o["choices"] -> "one of"
        o["type"] == "boolean" -> "switch"
        is_binary(o["format"]) -> String.replace(o["format"], "_", " ")
        true -> "text"
      end

    cond do
      !o["open"] -> base
      o["multiple"] -> base <> " · or others"
      true -> base <> " · or another"
    end
  end

  # A default the installer reads off the project (`detected`) becomes
  # the option's default here when the status says it for this project
  # (`detect/1`), so the field, the choice's tag and the rest read it as
  # any other; `read` remembers where it came from.
  defp with_detected(%{"detected" => true} = o, detected) do
    case detected[o["name"]] do
      nil -> o
      value -> Map.merge(o, %{"default" => value, "read" => true})
    end
  end

  defp with_detected(o, _detected), do: o

  # A text's default, when it is one the manifest knows: one the
  # installer reads off the project is the placeholder's, and its tag
  # says where it comes from; unread, the placeholder alone says so.
  defp text_default(%{"read" => true}), do: "read off the project"
  defp text_default(%{"detected" => true}), do: nil

  defp text_default(o) do
    case o["default"] do
      default when default in [nil, "", []] -> nil
      default -> "default " <> (default |> List.wrap() |> Enum.join(","))
    end
  end

  # A switch that builds on a cartridge (credo's --githook on precommit)
  # is unlit while the project lacks it, and says why on its own line —
  # unless the project already carries it on, which the box then says
  # checked.
  defp switch(assigns) do
    o = assigns.o

    need = if assigns.c_state[o["name"]] == true, do: [], else: lacks(o, assigns.status)

    assigns =
      assign(assigns,
        need: need,
        default:
          !assigns.installed && is_boolean(o["default"]) &&
            "default #{if o["default"], do: "on", else: "off"}"
      )

    ~H"""
    <label class={["line sw", @need != [] && "lacks"]} for={"opt-#{@o["name"]}"}>
      <%!-- A form sends nothing for an unchecked box: the "off" before it
            is what says a switch was turned off, which matters for one on
            by default (html's --live). --%>
      <input type="hidden" name={"opt[#{@o["name"]}]"} value="off" disabled={@locked} />
      <input
        type="checkbox"
        id={"opt-#{@o["name"]}"}
        name={"opt[#{@o["name"]}]"}
        checked={@need == [] && checked?(@o, @args, @c_state, @from_insert, @inserted_args)}
        disabled={@locked || @need != []}
        title={@need != [] && builds_on(@need)}
      />
      <.tags need={@need} default={@default} status={@status} />
    </label>
    """
  end

  attr :o, :map, required: true
  attr :c, :map, required: true
  attr :args, :map, required: true
  attr :status, :map
  attr :locked, :boolean
  attr :installed, :boolean
  attr :c_state, :map

  defp choice(assigns) do
    o = assigns.o
    c = assigns.c

    need = lacks(c, assigns.status)
    st = assigns.c_state[o["name"]]
    has = has?(o, c, assigns.c_state)
    group_locked = st == true
    chosen = c["value"] in List.wrap(assigns.args[o["name"]] || [])

    assigns =
      assign(assigns,
        need: need,
        has: has,
        group_locked: group_locked,
        chosen: chosen,
        default: c["value"] in List.wrap(o["default"]) && !assigns.installed && "default"
      )

    ~H"""
    <label class={["line", @has && "has", @need != [] && "lacks"]}>
      <input
        type={if @o["multiple"], do: "checkbox", else: "radio"}
        name={if @o["multiple"], do: "opt[#{@o["name"]}][]", else: "opt[#{@o["name"]}]"}
        value={@c["value"]}
        checked={@has || @chosen}
        disabled={@has || @group_locked || @locked || @need != []}
        title={@need != [] && builds_on(@need)}
      />
      <span class="name">{@c["value"]}</span>
      <%!-- What the project has is said by the box checked and shut, as
            it is when the whole form is locked; a tag only says why a
            box is shut that is not checked. --%>
      <.tags need={if @has, do: [], else: @need} default={!@has && @default} status={@status} />
      <span :if={@c["doc"]} class="gloss">{@c["doc"]}</span>
    </label>
    """
  end

  # A line's tags: what it builds on and the project lacks, each as the
  # cartridge's own mention — a door to its box, so the form shows how
  # the cartridges hang together — with the state it asks beside it;
  # or, when nothing shuts it, its default. The mention's dot is the
  # cartridge's own state: ecto in on mysql is in, and what pgadmin
  # lacks is said by the `with` beside it. Never both: a shut control's
  # default is not an answer it can give.
  attr :need, :list, required: true
  attr :default, :any, required: true
  attr :status, :map

  defp tags(assigns) do
    ~H"""
    <span class="tags">
      <%= if @need != [] do %>
        <span class="tag lacks">needs</span>
        <span :for={{name, condition} <- @need} class="req"><.cart_ref
          name={name}
          installed={Cartridges.installed?(@status, name)}
        /><span :if={condition != %{}} class="by">with {Cartridges.state_said(condition)}</span></span>
      <% else %>
        <span :if={@default} class="tag def">{@default}</span>
      <% end %>
    </span>
    """
  end

  defp builds_on(need) do
    names =
      Enum.map_join(need, " and ", fn {name, condition} ->
        Cartridges.requirement(name, condition)
      end)

    "builds on #{names}, which this project lacks"
  end

  # What the value builds on and the project lacks, with the state it
  # asks: `{ecto, database mysql}` when ecto is in and on another
  # database, not a bare `ecto` the project already has.
  defp lacks(c, status) do
    for name <- c["requires"] || [],
        condition = get_in(c, ["conditions", name]) || %{},
        not Cartridges.satisfies?(status, name, condition),
        do: {name, condition}
  end

  defp has?(o, c, state) do
    st = state[o["name"]]
    st == c["value"] || (is_list(st) && c["value"] in st)
  end

  # A cartridge that is in and adds on a second run has nothing left to
  # add when every option is a closed list and each of its values is
  # either in or builds on what the project lacks — db_admin with every
  # admin its database allows. An open field or a switch can always say
  # something new, so a box with one never counts as full.
  defp nothing_to_add?(box, c, status, adds) do
    options = for o <- box["options"] || [], addable?(adds, o), do: o
    state = c["state"] || %{}

    options != [] and
      Enum.all?(options, fn o ->
        o["choices"] && !o["open"] &&
          Enum.all?(choices(o), &(has?(o, &1, state) or lacks(&1, status) != []))
      end)
  end

  @doc """
  Whether an option can still be moved on a box that is in: what the
  box says a second insert adds (`adds/0`), which is "all", "none" or
  the names of the options it still puts in.
  """
  def addable?("all", _o), do: true
  def addable?("none", _o), do: false
  def addable?(names, o) when is_list(names), do: o["name"] in names
  def addable?(_adds, _o), do: false

  # What the reader has just said wins; then what the project reports of
  # the cartridge (`state/1`) — a base cartridge in from birth has no
  # Insert commit, and its --binary-id read unchecked with the project
  # saying true; then what it went in with, whether the field is locked
  # or open; then the default. The choices read the state already.
  defp checked?(o, args, state, from_insert, inserted) do
    cond do
      Map.has_key?(args, o["name"]) ->
        args[o["name"]] == "on"

      is_boolean(state[o["name"]]) ->
        state[o["name"]]

      from_insert ->
        ("--" <> String.replace(o["name"], "_", "-")) in inserted ||
          (o["default"] == true &&
             ("--no-" <> String.replace(o["name"], "_", "-")) not in inserted)

      true ->
        o["default"] == true
    end
  end

  # The default is shown, never filled in: an empty field is the
  # default (`text_argv/3` leaves the flag out), and one the reader typed
  # reads as theirs. A default the installer reads off the project
  # (`detected`) is the value the status read for this project; when it
  # read none — no project, or nothing there — the field says where it
  # would come from. Without a default it says its type.
  defp placeholder(%{"detected" => true} = o) when not is_map_key(o, "read"),
    do: "read off the project"

  defp placeholder(o) do
    case o["default"] do
      # Nothing to show: what it takes, the declared shape where there
      # is one (`url`) and the bare type where there is not.
      default when default in [nil, "", []] -> o["format"] || o["type"]
      default -> default |> List.wrap() |> Enum.join(",")
    end
  end

  defp text_value(o, args, state, from_insert, inserted) do
    flag = "--" <> String.replace(o["name"], "_", "-")

    cond do
      Map.has_key?(args, o["name"]) ->
        args[o["name"]]

      state[o["name"]] not in [nil, "", []] ->
        state[o["name"]] |> List.wrap() |> Enum.join(",")

      from_insert ->
        case Enum.drop_while(inserted, &(&1 != flag)) do
          [_, v | _] -> v
          _ -> nil
        end

      true ->
        nil
    end
  end

  @doc "The installer's argv from the form as filled."
  def argv(box, args), do: Enum.flat_map(box["options"] || [], &option_argv(&1, args))

  @doc """
  The options the box's line shows: what the open form says, and for a
  cartridge that is in and cannot be run again, what it went in with —
  its insert's own argv. The line read the form's live values in both
  cases until 2026-09-10, and those are empty while the form is locked,
  so the box said `add ecto` of a cartridge inserted with `--database
  postgres`. With nothing to read — inserted by a hand that left no
  commit, or born with the project — the line is the bare verb, which
  is all that is known.
  """
  def line_argv(box, args, insert, locked)
  def line_argv(_box, _args, %{"argv" => argv}, true), do: argv
  def line_argv(box, args, _insert, _locked), do: argv(box, args)

  # One option's flags: nothing when the form says what the default says.
  defp option_argv(o, args) do
    flag = "--" <> String.replace(o["name"], "_", "-")

    cond do
      o["choices"] -> choice_argv(o, flag, args)
      o["type"] == "boolean" -> boolean_argv(o, flag, args)
      true -> text_argv(o, flag, args)
    end
  end

  # The choices picked, and the ones typed under Other.
  defp choice_argv(o, flag, args) do
    picked = List.wrap(args[o["name"]] || [])
    other = (args["other:#{o["name"]}"] || "") |> String.split(~r/[,\s]+/, trim: true)
    v = picked ++ other

    if o["multiple"],
      do: if(v == [], do: [], else: [flag, Enum.join(v, ",")]),
      else: one_choice_argv(v, o["default"], flag)
  end

  defp one_choice_argv([], _default, _flag), do: []
  defp one_choice_argv([x | _], default, flag), do: if(x == default, do: [], else: [flag, x])

  # A switch: --flag when turned on against its default, --no-flag when off.
  defp boolean_argv(o, flag, args) do
    on =
      if Map.has_key?(args, o["name"]),
        do: args[o["name"]] == "on",
        else: o["default"] == true

    if on == (o["default"] == true),
      do: [],
      else: [if(on, do: flag, else: "--no-" <> String.replace(o["name"], "_", "-"))]
  end

  # A value: quoted when it has spaces, left out when it is the default.
  defp text_argv(o, flag, args) do
    v = String.trim(args[o["name"]] || to_string(o["default"] || ""))

    if v == "" || v == to_string(o["default"] || ""),
      do: [],
      else: [flag, if(v =~ ~r/\s/, do: inspect(v), else: v)]
  end

  # Everything the insert as asked builds on && the project lacks, each
  # said with the state it asks for ("ecto with database postgres").
  defp missing(box, args, status) do
    own = for n <- box["requires"] || [], do: {n, condition(box, n)}

    asked =
      for {_why, names, conds} <- value_requires(box, args, status),
          n <- names,
          do: {n, conds[n] || %{}}

    (own ++ asked)
    |> Enum.uniq()
    |> Enum.reject(fn {n, cond} -> Cartridges.satisfies?(status, n, cond) end)
    |> Enum.map(fn {n, cond} -> Cartridges.requirement(n, cond) end)
  end

  # The state a requirement of the box asks for, off the catalog's `conditions`.
  defp condition(box, name), do: get_in(box, ["conditions", name]) || %{}

  defp members_left(%{recipe: :asking}), do: :asking
  defp members_left(%{recipe: recipe}) when is_list(recipe), do: recipe

  defp members_left(%{box: box, status: status}),
    do: Enum.reject(box["members"] || [], &Cartridges.installed?(status, &1["name"]))

  # A collection's members in by commit, newest first — the order git can take them out in.
  defp ejectable(%{box: box, status: status, recipe: recipe}) do
    names =
      if(is_list(recipe), do: recipe, else: box["members"] || [])
      |> Enum.map(& &1["name"])
      |> MapSet.new()

    names =
      MapSet.union(names, box["members"] |> List.wrap() |> Enum.map(& &1["name"]) |> MapSet.new())

    Enum.filter(get_in(status, ["git", "inserts"]) || [], &MapSet.member?(names, &1["feature"]))
  end

  # What would be left standing on nothing: one level, not the transitive walk.
  @doc """
  What stops an eject: the cartridges in the project that build on one
  of those going, each named with what it builds on. The shelf's rows
  ask the same before lighting their Eject.
  """
  def eject_blockers(box, status, going) do
    out = MapSet.new(going)

    for c <- Cartridges.installed(status),
        c["name"] != box["name"],
        !MapSet.member?(out, c["name"]),
        on = Enum.filter(c["requires"] || [], &MapSet.member?(out, &1)),
        on != [] do
      "#{c["name"]} builds on #{Enum.join(on, " && ")}"
    end
  end

  defp eject_title(box, insert, going, blockers) do
    cond do
      blockers != [] ->
        Enum.join(blockers, "; ") <> " — eject those first"

      box["collection"] && going == [] ->
        "none of its cartridges has an insert commit: nothing to revert"

      box["collection"] ->
        Enum.map_join(going, " && ", &"./wb.sh eject #{&1["feature"]}")

      insert ->
        "git revert #{String.slice(insert["sha"], 0, 7)} — #{insert["subject"]}"

      true ->
        "Inserted by hand: no commit to revert"
    end
  end

  # The line the insert is, built here and not in the template: the
  # box wraps what it is given (`white-space: pre-wrap`, so a long
  # option breaks instead of scrolling out of sight), which means the
  # markup's own newlines and indentation would be part of the command
  # as it reads.
  defp insert_line(box, argv) do
    Enum.join(
      ["./wb.sh add", if(box["archived"], do: "--archived"), box["name"] | argv]
      |> Enum.reject(&is_nil/1),
      " "
    )
  end

  # The line the eject is: a collection's is one revert per cartridge,
  # newest first, and it was only ever in the button's title.
  defp eject_line(%{"collection" => true}, going) when going != [],
    do: Enum.map_join(going, " && ", &"./wb.sh eject #{&1["feature"]}")

  defp eject_line(box, _going), do: "./wb.sh eject #{box["name"]}"

  # A note each, for the verb it stands under.
  defp insert_note(a) do
    cond do
      a.box["archived"] ->
        "retired: not offered for new projects — its papers stay for the reading"

      not a.clean ->
        "the tree has changes git does not have — commit first"

      is_list(a.left) and a.left != [] ->
        "one commit per cartridge — what is in already is skipped"

      a.full ->
        "every value this project allows is in: nothing left to add"

      a.installed && is_list(a.box["adds"]) ->
        "what it went in with is fixed; #{flags_said(a.box["adds"])} are the pieces it still adds"

      a.installed && a.box["adds"] == "all" ->
        "every option is a piece: what is in stays, what you add is queued"

      !a.installed && a.missing != [] ->
        "builds on #{Enum.join(a.missing, " && ")}, not in the project yet"

      true ->
        ""
    end
  end

  # Option names as the form writes them: --md-report && --githook.
  defp flags_said(names),
    do: Enum.map_join(names, " && ", &"--#{String.replace(&1, "_", "-")}")

  defp eject_note(a) do
    cond do
      a.blockers != [] ->
        Enum.join(a.blockers, "; ") <> ": eject those first"

      a.box["collection"] && a.going != [] ->
        "takes its #{length(a.going)} cartridge#{if length(a.going) == 1, do: "", else: "s"} out, newest first — one revert each"

      a.box["collection"] ->
        "the box leaves no commit of its own, && none of its cartridges has one either"

      a.locked && a.insert ->
        "inserted once, with these options (from its commit); eject to change them"

      a.locked ->
        elem(Cartridges.origin(a.status, a.c), 2)

      true ->
        ""
    end
  end

  # --- Manual -------------------------------------------------------------------

  defp manual(assigns) do
    ~H"""
    <div class="papers">
      <.ribbon
        label="The papers the box carries"
        selected={@paper}
        docked
        items={
          for {key, label, file} <- Console.Papers.papers(),
              do: %{
                key: key,
                label: label,
                small: if(key in @papers, do: file, else: "—"),
                why: key not in @papers && "this box carries no #{file}",
                href:
                  ConsoleWeb.Refs.over(
                    @back || "/#{@tab}",
                    "box=#{@box["name"]}&screen=manual&paper=#{key}"
                  )
              }
        }
      />
      <div
        :if={@page}
        class={["booklet", @page.toc == [] && "notoc"]}
        id="d-booklet"
        phx-hook="Booklet"
      >
        <article class="md">{Phoenix.HTML.raw(@page.html)}</article>
        <nav :if={@page.toc != []} class="toc" aria-label="In this document">
          <a class="doctitle" href="#top">{@page.title}</a>
          <a :for={{id, text} <- @page.toc} href={"##{id}"}>{text}</a>
        </nav>
      </div>
    </div>
    """
  end
end
