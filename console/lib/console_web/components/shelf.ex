defmodule ConsoleWeb.Shelf do
  @moduledoc """
  The shelf: every cartridge as a box on a plank, or as a row. The
  planks are a view, not a taxonomy — there is one kind of cartridge —
  so they group by the box's *state*: in the project, on the shelf,
  not done yet. What a box does rides on the box as a fact.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Ribbon, only: [ribbon: 1]
  alias ConsoleWeb.Cartridges

  @docs [{"all", "All"}, {"collection", "Collections"}, {"base", "Base"}, {"covered", "With a box"}]
  def docs, do: @docs
  def doc_names, do: Enum.map(@docs, &elem(&1, 0))

  # How many of the catalog each reading of the shelf holds.
  defp count(catalog, "all"), do: length(catalog)
  defp count(catalog, "collection"), do: Enum.count(catalog, & &1["collection"])
  defp count(catalog, "base"), do: Enum.count(catalog, & &1["base"])
  defp count(catalog, "covered"), do: Enum.count(catalog, & &1["covers"]["front"])

  attr :catalog, :list, required: true
  attr :status, :map, default: nil
  attr :filter, :string, required: true
  attr :view, :string, required: true
  attr :tab, :string, default: "shelf"

  def shelf(assigns) do
    visible =
      Enum.filter(assigns.catalog, fn e ->
        case assigns.filter do
          "collection" -> e["collection"]
          "base" -> e["base"]
          "covered" -> e["covers"]["front"] != nil
          _ -> true
        end
      end)

    installed? = &Cartridges.installed?(assigns.status, &1["name"])

    groups = [
      {"In the project", Enum.filter(visible, installed?)},
      {"On the shelf — pick one to insert", Enum.filter(visible, &(!installed?.(&1) and !&1["pending"]))},
      {"Not done yet", Enum.filter(visible, &(!installed?.(&1) and &1["pending"]))}
    ]

    with_box = Enum.count(assigns.catalog, & &1["covers"]["front"])
    assigns = assign(assigns, groups: groups, with_box: with_box, in_count: Enum.count(assigns.catalog, installed?))

    ~H"""
    <div class="pdocs shelfp">
      <.ribbon
        label="The shelf: all of it, or one kind"
        selected={@filter}
        docked
        items={for {key, label} <- docs(), do: %{key: key, label: label, small: "#{count(@catalog, key)}", href: "/#{@tab}?doc=#{key}"}}
      />
      <div class="dkdoc">
        <div class="toolbar">
          <span class="label">{@in_count} in the project · {@with_box} with a box</span>
          <span class="sep"></span>
          <div class="views" role="group" aria-label="How the shelf is laid out" id="shelf-views" phx-hook="ShelfView">
            <button class="btn" type="button" phx-click="view" phx-value-view="covers" aria-pressed={to_string(@view == "covers")} title="The boxes, on the plank">Covers</button>
            <button class="btn" type="button" phx-click="view" phx-value-view="list" aria-pressed={to_string(@view == "list")} title="A row for each cartridge, with what it is">List</button>
          </div>
        </div>
    <div id="shelf">
      <%= for {label, list} <- @groups, list != [] do %>
        <div class="row">
          <span class="label">{label}</span>
          <div :if={@view == "list"} class="list"><.list_row :for={e <- list} e={e} status={@status} tab={@tab} /></div>
          <div :if={@view != "list"} class="boxes"><.box_el :for={e <- list} e={e} status={@status} tab={@tab} /></div>
          <div :if={@view != "list"} class="plank"></div>
        </div>
      <% end %>
    </div>
      </div>
    </div>
    """
  end

  defp front(e), do: e["covers"]["front"] || if(e["pending"], do: "empty_cover_placeholder.jpg", else: "cover_placeholder.png")
  defp title(e), do: e["name"] |> String.replace(~r/(\d+)$/, " \\1") |> String.replace("_", " ")

  attr :e, :map, required: true
  attr :status, :map
  attr :tab, :string

  defp box_el(assigns) do
    installed = Cartridges.installed?(assigns.status, assigns.e["name"])
    assigns = assign(assigns, installed: installed, facts: Cartridges.facts(assigns.e), covered: assigns.e["covers"]["front"] != nil)

    ~H"""
    <.link class={["box", @e["pending"] && "pending", @installed && "in"]} patch={"/#{@tab}?box=#{@e["name"]}"} aria-label={"#{title(@e)}: pick up the box"}>
      <div class={["face", !@covered && "socket"]}>
        <img src={"/covers/#{front(@e)}"} alt={if @covered, do: "#{title(@e)} — box cover", else: ""} draggable="false" />
        <span :if={!@covered} class="name">{title(@e)}</span>
      </div>
      <div class="cap"><b>{@e["name"]}</b><span :if={@facts != []} class="st">{Enum.join(@facts, " · ")}</span></div>
    </.link>
    """
  end

  defp list_row(assigns) do
    installed = Cartridges.installed?(assigns.status, assigns.e["name"])
    c = Cartridges.carried(assigns.status, assigns.e["name"])
    origin = if installed and c, do: Cartridges.origin(assigns.status, c)
    assigns = assign(assigns, installed: installed, origin: origin, facts: Cartridges.facts(assigns.e))

    ~H"""
    <.link class={["lrow", @installed && "in", @e["pending"] && "pending"]} patch={"/#{@tab}?box=#{@e["name"]}"} aria-label={"#{title(@e)}: pick up the box"}>
      <span class="th"><img src={"/covers/#{front(@e)}"} alt="" draggable="false" /></span>
      <span class="nm"><span class={["cart-ref", @installed && "in"]}>{@e["name"]}</span></span>
      <span class="fx">
        <.chip :for={f <- @facts}>{f}</.chip>
        <.chip :if={@origin} class={elem(@origin, 1)} title={elem(@origin, 2)}>{elem(@origin, 0)}</.chip>
      </span>
      <span class="vr" title={if @e["version"], do: "#{@e["version"]["date"]} in its CHANGELOG", else: "no CHANGELOG to read a version from"}>{if @e["version"], do: "v#{@e["version"]["version"]}", else: "—"}</span>
      <span class="sm">{@e["summary"] || "Documented in the generated project, but its installer is not done yet."}</span>
    </.link>
    """
  end
end
