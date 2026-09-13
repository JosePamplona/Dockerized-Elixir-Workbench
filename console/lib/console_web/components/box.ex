defmodule ConsoleWeb.Box do
  @moduledoc """
  The box in hand: a drawer over the page with four screens — what the
  box is, how it goes in, what it wrote, && the papers it carries.
  Which box && which screen live in the URL (`?box=rest&screen=manual
  &paper=design`), so the browser's back is the trail back.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Ribbon, only: [ribbon: 1]
  alias ConsoleWeb.Cartridges

  @screens [{"box", "Box"}, {"install", "Installation"}, {"files", "Files"}, {"manual", "Manual"}]

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

  attr :diff, :any,
    default: nil,
    doc: "what the cartridge wrote (Console.Diffs), :loading, || nil"

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
        <.link class="btn" patch={"/#{@tab}"}>Put back</.link>
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
                    "/#{@tab}?box=#{@box["name"]}&screen=#{key}#{if key == "manual", do: "&paper=#{@paper}"}"
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
      />
      <.sheet
        :if={@screen == "box"}
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
  it wrote is read off its commit, && there is none.
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
                name={@box["name"]}
                here={true}
                sha={@diff.sha}
                date={@diff.date}
                subject={@diff.subject}
                added={@diff.added}
                removed={@diff.removed}
                files={length(@diff.files)}
              />
            <% end %>
          </div>
          <%= cond do %>
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
      <div class="hand">
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
            <.chip :if={!@box["pending"] && @installed} class="good">inserted</.chip>
            <.chip :if={!@box["pending"] && !@installed}>on the shelf</.chip>
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
  # with it. Two rows move with the options — a collection's recipe, and
  # what a chosen value builds on — so the panel says which switch moved it.
  defp specs(assigns) do
    asked = value_requires(assigns.box, assigns.args, assigns.status)
    members = members(assigns)
    up = Cartridges.app_up?(assigns.status)

    assigns =
      assign(assigns,
        asked: asked,
        members: members,
        up: up,
        console: assigns.box["console"] || %{}
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
      <span :if={@box["requires"] != [] || @asked != []} class="v">
        <.cart_ref
          :for={r <- @box["requires"]}
          name={r}
          installed={Cartridges.installed?(@status, r)}
        />
        <span :for={{why, names} <- @asked} class="why"><.cart_ref
          :for={n <- names}
          name={n}
          installed={Cartridges.installed?(@status, n)}
        /><span class="by">by {why}</span></span>
      </span>
      <span :if={@box["collection"]} class="k">Inserts</span>
      <span :if={@box["collection"]} class="v">
        <span :if={@members == :asking} class="note">asking the project which of its picks are already in…</span>
        <%= if is_list(@members) do %>
          <span :for={m <- @members} class="why"><.cart_ref
            name={m["name"]}
            installed={Cartridges.installed?(@status, m["name"])}
          /><span :if={m["argv"] != []}>{Enum.join(m["argv"], " ")}</span></span>
        <% end %>
      </span>
      <span :if={(@console["doors"] || []) != []} class="k">Opens</span>
      <span :if={(@console["doors"] || []) != []} class="v">
        <.door_ref
          :for={d <- @console["doors"]}
          label={d["label"]}
          path={Cartridges.fill_path(d["path"], @c)}
          href={"http://localhost:#{@status && @status["ports"]["app"]}#{Cartridges.fill_path(d["path"], @c)}"}
          why={door_shut(@box, @c, @status, d, @installed, @up)}
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
        e["rerun"] == "adds" -> "inserting it again adds to what is in"
        true -> "inserting it again changes nothing"
      end

    [e["base"] && "a phx.new capability, in from birth unless left out", again]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  defp door_shut(box, c, status, d, installed, up) do
    cond do
      !installed ->
        "insert #{box["name"]} first"

      !Cartridges.holds?(status, c, d) ->
        if d["when"]["with"],
          do: "only with --with #{d["when"]["with"]}",
          else: "only with #{d["when"]["cartridge"]} inserted"

      !up ->
        "the app is down"

      true ->
        nil
    end
  end

  # A collection's recipe: what expand answered, the catalog's while it
  # is asked, minus nothing — the catalog's is what the defaults give.
  defp members(%{box: %{"collection" => true}, recipe: :asking}), do: :asking
  defp members(%{box: %{"collection" => true}, recipe: recipe}) when is_list(recipe), do: recipe
  defp members(%{box: box}), do: box["members"] || []

  @doc "What each chosen value builds on: [{\"--flag value\", [names]}]."
  def value_requires(box, args, _status) do
    for o <- box["options"] || [],
        o["choices"],
        v <- List.wrap(args[o["name"]] || []),
        c = Enum.find(choices(o), &(&1["value"] == v)),
        (c["requires"] || []) != [] do
      {"--#{String.replace(o["name"], "_", "-")} #{v}", c["requires"]}
    end
  end

  def choices(%{"choices" => [%{"group" => _} | _] = groups}),
    do: Enum.flat_map(groups, & &1["values"])

  def choices(%{"choices" => values}), do: values

  # --- Installation -------------------------------------------------------------

  defp install(assigns) do
    insert = Cartridges.insert(assigns.status, assigns.box["name"])
    locked = assigns.installed && assigns.box["rerun"] != "adds"
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
        can_insert: !assigns.installed || assigns.box["rerun"] == "adds"
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
        <div>
          <p :if={@box["options"] == []} class="nothing">This cartridge takes no options.</p>
          <%= for o <- @box["options"] do %>
            <% flag = "--" <> String.replace(o["name"], "_", "-") %>
            <%= if o["choices"] do %>
              <div class="field stack">
                <label>{flag}<span :if={o["multiple"]}> (several)</span></label>
                <div>
                  <% grouped = match?([%{"group" => _} | _], o["choices"]) %>
                  <div class={[grouped && "groups", !grouped && "choices"]}>
                    <%= for g <- (if grouped, do: o["choices"], else: [%{"group" => nil, "values" => o["choices"]}]) do %>
                      <div :if={grouped} class="g">
                        <span class="gl">{String.replace(to_string(g["group"]), "_", " ")}</span>
                        <div class="choices">
                          <.choice
                            :for={c <- g["values"]}
                            o={o}
                            c={c}
                            flag={flag}
                            args={@args}
                            status={@status}
                            locked={@locked}
                            installed={@installed}
                            c_state={@c["state"] || %{}}
                          />
                        </div>
                      </div>
                      <.choice
                        :for={c <- g["values"]}
                        :if={!grouped}
                        o={o}
                        c={c}
                        flag={flag}
                        args={@args}
                        status={@status}
                        locked={@locked}
                        installed={@installed}
                        c_state={@c["state"] || %{}}
                      />
                    <% end %>
                  </div>
                  <div :if={o["open"]} class="other">
                    other:
                    <input
                      type="text"
                      name={"other[#{o["name"]}]"}
                      value={@args["other:#{o["name"]}"]}
                      placeholder={
                        if o["multiple"],
                          do: "name, name — anything the installer takes",
                          else: "another value"
                      }
                      disabled={@locked}
                    />
                  </div>
                  <p :if={o["doc"]} class="doc">{o["doc"]}</p>
                </div>
              </div>
            <% else %>
              <div class="field">
                <label for={"opt-#{o["name"]}"}>{flag}</label>
                <input
                  :if={o["type"] == "boolean"}
                  type="checkbox"
                  id={"opt-#{o["name"]}"}
                  name={"opt[#{o["name"]}]"}
                  checked={checked?(o, @args, @c["state"] || %{}, @from_insert, @inserted_args)}
                  disabled={@locked}
                />
                <input
                  :if={o["type"] != "boolean"}
                  type="text"
                  id={"opt-#{o["name"]}"}
                  name={"opt[#{o["name"]}]"}
                  value={text_value(o, @args, @c["state"] || %{}, @from_insert, @inserted_args)}
                  placeholder={
                    if @locked && @insert == nil,
                      do: "inserted by hand: value unknown",
                      else: o["type"]
                  }
                  disabled={@locked}
                />
                <p :if={o["doc"]} class="doc">{o["doc"]}</p>
              </div>
            <% end %>
          <% end %>
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
          <div class="cmd">
            ./wb.sh add {@box["name"]}{if @argv != [], do: " " <> Enum.join(@argv, " ")}
          </div>
          <.job_button
            label={
              cond do
                @box["pending"] ->
                  "Not done yet"

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
                not @clean -> "the tree has changes git does not have — commit first"
                @missing != [] -> "#{hd(@missing)} has to go in first"
                @left == :asking -> "reading what is in"
                is_list(@left) and @left == [] -> "every cartridge of this box is in"
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

  attr :o, :map, required: true
  attr :c, :map, required: true
  attr :flag, :string, required: true
  attr :args, :map, required: true
  attr :status, :map
  attr :locked, :boolean
  attr :installed, :boolean
  attr :c_state, :map

  defp choice(assigns) do
    o = assigns.o
    c = assigns.c
    need = Enum.reject(c["requires"] || [], &Cartridges.installed?(assigns.status, &1))
    st = assigns.c_state[o["name"]]
    has = st == c["value"] || (is_list(st) && c["value"] in st)
    group_locked = st == true
    chosen = c["value"] in List.wrap(assigns.args[o["name"]] || [])

    assigns =
      assign(assigns,
        need: need,
        has: has,
        group_locked: group_locked,
        chosen: chosen,
        default: !o["multiple"] && c["value"] == o["default"] && !assigns.installed
      )

    ~H"""
    <label class={[@has && "has", @need != [] && "need"]}>
      <input
        type={if @o["multiple"], do: "checkbox", else: "radio"}
        name={if @o["multiple"], do: "opt[#{@o["name"]}][]", else: "opt[#{@o["name"]}]"}
        value={@c["value"]}
        checked={@has || @chosen}
        disabled={@has || @group_locked || @locked || @need != []}
        title={@need != [] && "builds on #{Enum.join(@need, " && ")}, not in the project yet"}
      />
      <%!-- `in` marks what the project has where the reader can still
            add beside it (rerun: adds); locked, everything checked is in,
            and the word said nothing. --%>
      <span>{@c["value"]}<span :if={@has && !@locked} class="in">in</span><span
        :if={!@has && @need != []}
        class="in need"
      >needs {Enum.join(@need, " + ")}</span><span
        :if={!@has && @need == [] && @default}
        class="in def"
      >default</span></span>
      <span class="doc">{@c["doc"]}</span>
    </label>
    """
  end

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
          _ -> o["default"]
        end

      true ->
        o["default"]
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

  # Everything the insert as asked builds on && the project lacks.
  defp missing(box, args, status) do
    ((box["requires"] || []) ++ Enum.flat_map(value_requires(box, args, status), &elem(&1, 1)))
    |> Enum.uniq()
    |> Enum.reject(&Cartridges.installed?(status, &1))
  end

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

  # The line the eject is: a collection's is one revert per cartridge,
  # newest first, and it was only ever in the button's title.
  defp eject_line(%{"collection" => true}, going) when going != [],
    do: Enum.map_join(going, " && ", &"./wb.sh eject #{&1["feature"]}")

  defp eject_line(box, _going), do: "./wb.sh eject #{box["name"]}"

  # A note each, for the verb it stands under.
  defp insert_note(a) do
    cond do
      not a.clean ->
        "the tree has changes git does not have — commit first"

      is_list(a.left) and a.left != [] ->
        "one commit per cartridge — what is in already is skipped"

      a.installed && a.box["rerun"] == "adds" ->
        "every option is a package: what is in stays, what you add is queued"

      !a.installed && a.missing != [] ->
        "builds on #{Enum.join(a.missing, " && ")}, not in the project yet"

      true ->
        ""
    end
  end

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
                href: "/#{@tab}?box=#{@box["name"]}&screen=manual&paper=#{key}"
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
