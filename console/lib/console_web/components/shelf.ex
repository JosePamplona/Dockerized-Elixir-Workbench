defmodule ConsoleWeb.Shelf do
  @moduledoc """
  The shelf: every cartridge as a box on a plank, or as a row. There is
  one kind of cartridge, so the only division is the box's *state*, and
  since 2026-09-10 that state is the ribbon and not three planks at
  once: inserted, on the shelf, not done, archived — one at a time. The ribbon
  read *all / collections / base / with a box* until then, which asked
  a question the box already answers: what a cartridge is rides on it
  as a fact (`base`, `inserts 4`, `not done`), in both views.

  *Inserted* is the one state with more to say, and its list is what
  the Record paper's second section was: a row per cartridge with where
  it came from, its edition, the parameters it was installed with and
  the addresses it opens — columns that only exist for a cartridge that
  is in. It moved here because this is where cartridges are read, and
  because the shelf already knows which are in.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Ribbon, only: [ribbon: 1]
  import ConsoleWeb.Square, only: [square: 1]
  alias ConsoleWeb.{Box, Cartridges, Record}

  # Archived last: the state nobody picks a cartridge from. It is a
  # state and not a filter taken off the shelf — the retired boxes are
  # counted where the others are, one click away, because their papers
  # are the log of why they were made and that reading is the reason
  # they stay.
  @docs [
    {"in", "Inserted"},
    {"shelf", "On the shelf"},
    {"pending", "Not done"},
    {"archived", "Archived"}
  ]
  def docs, do: @docs
  def doc_names, do: Enum.map(@docs, &elem(&1, 0))

  @doc """
  The state to open on: what the project carries, when it carries
  anything. Without a project there is nothing inserted to read, so the
  shelf opens on itself.
  """
  def first_doc(status, catalog) do
    if Enum.any?(catalog, &Cartridges.installed?(status, &1["name"])), do: "in", else: "shelf"
  end

  # Which of the catalog each state holds. A cartridge that is in is in,
  # whatever else it is — a project carrying a retired box is told the
  # truth about its own project first; of the rest, the retired are
  # archived, then the ones not built yet are not done, and the
  # others are on the shelf.
  defp state(status, e) do
    cond do
      Cartridges.installed?(status, e["name"]) -> "in"
      e["archived"] -> "archived"
      e["pending"] -> "pending"
      true -> "shelf"
    end
  end

  defp of_state(catalog, status, doc), do: Enum.filter(catalog, &(state(status, &1) == doc))

  attr :catalog, :list, required: true
  attr :status, :map, default: nil
  attr :filter, :string, required: true
  attr :view, :string, required: true
  attr :tab, :string, default: "shelf"
  attr :reads, :any, default: %{}, doc: "what the doors answered when called, by href"

  def shelf(assigns) do
    installed? = &Cartridges.installed?(assigns.status, &1["name"])
    visible = of_state(assigns.catalog, assigns.status, assigns.filter)

    assigns =
      assign(assigns,
        visible: visible,
        # The inserted read as the Record's rows — with what they were
        # installed with and what they open — and only in the list view:
        # the boxes are the boxes wherever they stand.
        rows:
          if(assigns.filter == "in" and assigns.view == "list",
            do: Record.cartridges(assigns.status || %{}, assigns.catalog, assigns.reads),
            else: []
          ),
        up: Cartridges.app_up?(assigns.status || %{}),
        with_box: Enum.count(assigns.catalog, & &1["covers"]["front"]),
        in_count: Enum.count(assigns.catalog, installed?)
      )

    ~H"""
    <div class="pdocs shelfp">
      <.ribbon
        label="The shelf: what is in, what is on it, what is not done, what is retired"
        selected={@filter}
        docked
        items={
          for {key, label} <- docs(),
              do: %{
                key: key,
                label: label,
                small: "#{length(of_state(@catalog, @status, key))}",
                href: "/#{@tab}?doc=#{key}"
              }
        }
      />
      <div class="dkdoc">
        <div class="toolbar">
          <span class="label">{@in_count} in the project · {@with_box} with a box</span>
          <span class="sep"></span>
          <div
            class="views"
            role="group"
            aria-label="How the shelf is laid out"
            id="shelf-views"
            phx-hook="ShelfView"
          >
            <button
              class="btn"
              type="button"
              phx-click="view"
              phx-value-view="covers"
              aria-pressed={to_string(@view == "covers")}
              title="The boxes, on the plank"
            >Covers</button>
            <button
              class="btn"
              type="button"
              phx-click="view"
              phx-value-view="list"
              aria-pressed={to_string(@view == "list")}
              title="A row for each cartridge, with what it is"
            >List</button>
          </div>
        </div>
        <div id="shelf">
          <div class="row">
            <.inserted
              :if={@rows != []}
              rows={@rows}
              up={@up}
              reads={@reads}
              tab={@tab}
              status={@status}
            />
            <%!-- On the shelf, Not done and Archived read in Inserted's table, its
                  columns included: the parameters the cartridge takes, with
                  their type, and the addresses it would open, shut. The
                  summary rides on the name's title. No bell: nothing of
                  these is in, so there is no door to call. --%>
            <div :if={@rows == [] and @view == "list" and @visible != []} class="tbl">
              <table class="wide carts">
                <tr>
                  <th></th>
                  <th>cartridge</th>
                  <th>facts</th>
                  <th>edition</th>
                  <th>installation parameters</th>
                  <th title="the services it would ask for and the routes it would open on the app's port, once inserted">
                    addresses
                  </th>
                  <th></th>
                </tr>
                <.list_row :for={e <- @visible} e={e} status={@status} tab={@tab} />
              </table>
            </div>
            <div :if={@view != "list"} class="boxes">
              <.box_el :for={e <- @visible} e={e} status={@status} tab={@tab} />
            </div>
            <div :if={@view != "list"} class="plank"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  What the project carries, in full: the cover, the mention, its facts
  and where it came from, its edition, the parameters it was installed
  with, and the addresses it opens — with the bell that calls them all
  once. The Record paper held this until 2026-09-10; only the reading
  moved, not a column.
  """
  attr :rows, :list, required: true
  attr :up, :boolean, default: false
  attr :reads, :any, default: %{}
  attr :tab, :string, default: "shelf"
  attr :status, :map, default: nil

  def inserted(assigns) do
    assigns =
      assign(assigns,
        knock: Record.knockable?(assigns.up, Enum.flat_map(assigns.rows, & &1.addresses))
      )

    ~H"""
    <%!-- A table, as the Docker screen's containers are: the rows were a
          grid of their own while each was a link that opened the box —
          an <a> cannot wrap a <tr> — and they are not links now: the
          mention opens the box, the doors and the verb are the row's
          own controls (2026-09-11). --%>
    <div class="tbl">
      <table class="wide carts">
        <tr>
          <th></th>
          <th>cartridge</th>
          <th>origin</th>
          <th>edition</th>
          <th>installation parameters</th>
          <th title="the ports the compose publishes for the cartridge's services, and the routes the project offers on the app's port">
            <span class="addr">
              addresses
              <.square
                :if={@knock}
                mark="bell"
                size="small"
                label="Knock on every door"
                class="knock"
                phx-click="knock"
                aria-busy={to_string(@reads == :asking)}
                title="knock: call every open route once and read every page off the disk again — the rail hears the same"
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
            </span>
          </th>
          <th></th>
        </tr>
        <tr :for={row <- @rows} class="in">
          <td class="th"><img src={"/covers/#{front(row.entry)}"} alt="" draggable="false" /></td>
          <td><.cart_ref name={row.c["name"]} installed={true} /></td>
          <td>
            <span class="fx">
              <.chip :for={f <- row.facts}>{f}</.chip>
              <.chip class={elem(row.origin, 1)} title={elem(row.origin, 2)}>
                {elem(row.origin, 0)}
              </.chip>
            </span>
          </td>
          <td class="vr" title={version_title(row.entry)}>{version(row.entry)}</td>
          <td class="wrap">
            <span class="argv">
              <span
                :for={
                  {{flag, value}, default?} <-
                    Enum.map(row.params, &{split_flag(elem(&1, 0)), elem(&1, 1)})
                }
                title={default? && "the default"}
              >{flag} <i :if={value} class="val">{value}</i></span>
            </span>
          </td>
          <td class="wrap">
            <span class="pairs"><.address :for={a <- row.addresses} a={a} /></span>
          </td>
          <%!-- The box's Eject, as a bare line: `eject NAME` travels on the
                click and the server parses it, the way every line that is
                only itself does. Unlit with the reason when the box's own
                would be — and a collection's, whose eject is its members',
                is the box's alone. --%>
          <td class="act">
            <.job_button
              label="Eject"
              class="danger"
              args={"eject #{row.c["name"]}"}
              title={eject_title(@status, row.c["name"])}
              why={eject_why(@status, row)}
            />
          </td>
        </tr>
      </table>
    </div>
    """
  end

  defp eject_why(status, row) do
    name = row.c["name"]

    cond do
      get_in(status, ["git", "clean"]) == false ->
        "the tree has changes git does not have — commit first"

      row.entry["collection"] ->
        "a collection leaves no commit of its own: its box ejects its cartridges, one revert each"

      is_nil(Cartridges.insert(status, name)) ->
        "in from birth, or by hand: no commit to revert"

      true ->
        case Box.eject_blockers(row.entry, status, [name]) do
          [] -> nil
          blockers -> Enum.join(blockers, "; ") <> " — eject those first"
        end
    end
  end

  defp eject_title(status, name) do
    case Cartridges.insert(status, name) do
      %{"sha" => sha, "subject" => subject} ->
        "git revert #{String.slice(sha, 0, 7)} — #{subject}"

      _ ->
        nil
    end
  end

  attr :a, :map, required: true

  defp address(assigns) do
    ~H"""
    <.door_ref
      label={@a.label}
      path={@a.path}
      href={@a.href}
      why={@a.why}
      kind={@a.kind}
      port={@a.kind == "route" && @a.port}
      svc={@a[:svc]}
      read={@a.read}
      client={@a[:client]}
      read_title={@a[:read_title]}
      build={@a[:build]}
      filed={@a[:filed]}
    />
    """
  end

  # `--endpoint /health` as the flag and what follows it: the flag reads
  # in ink, its value dimmed — the same notation as a flag and its type.
  defp split_flag(flag) do
    case String.split(flag, " ", parts: 2) do
      [f, v] -> {f, v}
      [f] -> {f, nil}
    end
  end

  defp version(%{"version" => %{"version" => v}}), do: "v" <> v
  defp version(_), do: "—"
  defp version_title(%{"version" => %{"date" => d}}), do: "#{d} in its CHANGELOG"
  defp version_title(_), do: "no CHANGELOG to read a version from"

  @doc "The cover a box shows: its front, or the placeholder for a box without one."
  def front(e),
    do:
      e["covers"]["front"] ||
        if(e["pending"], do: "empty_cover_placeholder.jpg", else: "cover_placeholder.png")

  @doc "The box's title: its name, spaced."
  def title(e), do: e["name"] |> String.replace(~r/(\d+)$/, " \\1") |> String.replace("_", " ")

  attr :e, :map, required: true
  attr :status, :map
  attr :tab, :string

  defp box_el(assigns) do
    installed = Cartridges.installed?(assigns.status, assigns.e["name"])

    assigns =
      assign(assigns,
        installed: installed,
        facts: Cartridges.facts(assigns.e),
        covered: assigns.e["covers"]["front"] != nil
      )

    ~H"""
    <.link
      class={["box", @e["pending"] && "pending", @e["archived"] && "archived", @installed && "in"]}
      patch={"/#{@tab}?box=#{@e["name"]}"}
      aria-label={"#{title(@e)}: pick up the box"}
    >
      <div class={["face", !@covered && "socket"]}>
        <img
          src={"/covers/#{front(@e)}"}
          alt={if @covered, do: "#{title(@e)} — box cover", else: ""}
          draggable="false"
        />
        <span :if={!@covered} class="name">{title(@e)}</span>
      </div>
      <div class="cap">
        <b>{@e["name"]}</b><span :if={@facts != []} class="st">{Enum.join(@facts, " · ")}</span>
      </div>
    </.link>
    """
  end

  defp list_row(assigns) do
    installed = Cartridges.installed?(assigns.status, assigns.e["name"])
    c = Cartridges.carried(assigns.status, assigns.e["name"])
    origin = if installed and c, do: Cartridges.origin(assigns.status, c)

    assigns =
      assign(assigns,
        installed: installed,
        origin: origin,
        facts: Cartridges.facts(assigns.e),
        offered: Record.offered(assigns.e)
      )

    ~H"""
    <%!-- A row of the Inserted table's shape, for a cartridge that is not
          in: the mention opens the box. --%>
    <tr class={[@installed && "in", @e["pending"] && "pending", @e["archived"] && "archived"]}>
      <td class="th"><img src={"/covers/#{front(@e)}"} alt="" draggable="false" /></td>
      <td title={@e["summary"] || Cartridges.not_done_said(@e)}>
        <.cart_ref name={@e["name"]} installed={@installed} />
      </td>
      <td>
        <span class="fx">
          <.chip :for={f <- @facts}>{f}</.chip>
          <.chip :if={@origin} class={elem(@origin, 1)} title={elem(@origin, 2)}>
            {elem(@origin, 0)}
          </.chip>
        </span>
      </td>
      <td
        class="vr"
        title={
          if @e["version"],
            do: "#{@e["version"]["date"]} in its CHANGELOG",
            else: "no CHANGELOG to read a version from"
        }
      >
        {if @e["version"], do: "v#{@e["version"]["version"]}", else: "—"}
      </td>
      <td class="wrap">
        <span class="argv">
          <span :for={{flag, type, title} <- @offered.params} title={title != "" && title}>
            {flag} <i class="val">{type}</i>
          </span>
        </span>
      </td>
      <td class="wrap">
        <span class="pairs"><.address :for={a <- @offered.addresses} a={a} /></span>
      </td>
      <%!-- Insert leads to the box's Installation screen, where the
            options are picked and the box's own Insert says what it runs,
            or why it cannot: the row sent the bare `add NAME` for a day
            (2026-09-10), and a verb with options to pick is pressed where
            they are. Never unlit: the screen reads for every box, and it
            is the screen that says "not built yet". --%>
      <td class="act">
        <.link
          class="btn primary"
          patch={"/#{@tab}?box=#{@e["name"]}&screen=install"}
          title={"#{title(@e)}: how it goes in — pick its options there, and insert it"}
        >
          Insert
        </.link>
      </td>
    </tr>
    """
  end
end
