defmodule ConsoleWeb.Packages do
  @moduledoc """
  The table of packages, one way wherever the console lists what a
  project puts in its `mix.exs`: a box's Packages panel, the ones that
  box brings, and the project's Mix paper, every one it carries. Each
  row says the package, what the project's `mix.exs` pins, what
  `mix.lock` resolved, and — when somebody pressed for it — what hex
  says of it. The `cartridge` column is what the cartridge that brought
  the package asks for, and the mix.exs column is marked where the
  project pins something else. The Mix paper adds the package's
  `options`, as mix.exs writes them, and last `brought by`:
  which cartridge put it there, or that none did.

  A package from git is its repository (`ConsoleWeb.Refs.pkg_ref/1`
  with `git`): its tag in the place a version goes. The same button
  asks GitHub what hex answers for the rest — the latest release and
  its day (`Console.GitHub`) — and downloads stand unlit with the
  reason, since GitHub counts none of a repository. A git host other
  than GitHub has nobody to ask: its three columns say so.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs, only: [pkg_ref: 1, cart_ref: 1]
  import ConsoleWeb.Square, only: [square: 1]

  attr :rows, :list, required: true, doc: "row/4 of each package"
  attr :cartridge, :boolean, default: true, doc: "the column of what the box asks for"

  attr :brought, :boolean, default: false, doc: "the last column: who put each package there"

  attr :options, :map, default: nil, doc: "each package's options, as mix.exs writes them"
  attr :nothing, :string, default: nil, doc: "what an empty panel says"
  attr :hex_asking, :boolean, default: false
  attr :hex_error, :any, default: nil
  attr :class, :any, default: nil

  def table(assigns) do
    assigns =
      assign(assigns,
        # Hex is asked of what it has, GitHub of its repositories — as
        # `name=owner/repo` — and a git host elsewhere of nothing.
        names: for(r <- assigns.rows, name = asked_as(r), do: name),
        footnote: assigns.cartridge && footnote(assigns.rows)
      )

    ~H"""
    <div :if={@rows != [] or @nothing} class={["packages", @class]}>
      <div class="log-cap">
        <span class="label">Packages</span>
        <span :if={@nothing && @rows == []} class="note unlit">{@nothing}</span>
        <%!-- What hex says of a package is a reading of the ecosystem,
              not of the project: it costs the internet, so it happens
              because somebody pressed for it, never on its own. The
              same square the configuration's two fields carry for the
              same kind of reading — the Docker tags and the phx_new
              releases — so one gesture means one thing everywhere. --%>
        <.square
          :if={@rows != []}
          mark="reload"
          size="small"
          label="Ask hex and GitHub for these packages"
          class="ask"
          phx-click="packages_ask"
          phx-value-names={Enum.join(@names, ",")}
          disabled={@hex_asking}
          aria-busy={to_string(@hex_asking)}
          title={
            if @hex_asking,
              do: "asking hex…",
              else:
                "ask hex.pm for each package — GitHub for one from a repository there: its latest release, when it was published, and how much hex has served it"
          }
        />
        <span :if={@hex_error} class="note bad">{@hex_error}</span>
      </div>

      <div :if={@rows != []} class="scroll">
        <table class="rows pkgs">
          <thead>
            <tr>
              <th title="the package the project's mix.exs carries — its name opens its page on hex.pm, or its repository">
                package
              </th>
              <th
                :if={@options}
                class="opts"
                title="what mix.exs says of it besides the version: only, runtime, override…"
              >
                options
              </th>
              <th
                :if={@cartridge}
                title="the version the cartridge that brought it asks for: the requirement its installer writes"
              >
                cartridge
              </th>
              <th title="the version the project's mix.exs asks for today">mix.exs</th>
              <th title="the version the project actually runs, as mix.lock resolved it — it opens that version's documentation">
                locked
              </th>
              <th title="the newest stable release — on hex.pm, or on GitHub for a package from there — whatever this project runs">
                latest
              </th>
              <th title="when that newest release was published: the reading that says whether the package is alive">
                released
              </th>
              <th title="how many times hex.pm has served it, all versions — GitHub counts none">
                downloads
              </th>
              <th
                :if={@brought}
                class="by"
                title="the cartridge that put it in mix.exs — or where it came from, when none did"
              >
                brought by
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={r <- @rows}>
              <td><.pkg_ref name={r.name} git={r.git} /></td>
              <td :if={@options} class="opts">{@options[r.name]}</td>
              <td
                :if={@cartridge}
                class="asks"
                title={
                  r.read? &&
                    "read off this box's insert commit: it declares no package of its own — what it brings arrives inside the phx.new delta, generated at the phx.new the project stamped then"
                }
              >
                {r.brings}<span :if={r.read?} class="fn">*</span>
                <span
                  :if={!r.brings}
                  class="unlit"
                  title="no cartridge brought it: nothing asks for a version"
                >–</span>
              </td>
              <td
                class={["asks", r.carried? && r.brings && r.pinned != r.brings && "warn"]}
                title={pinned_says(r)}
              >
                <span :if={!r.carried?} class="unlit">–</span>
                <span :if={r.carried?}>{r.pinned || "—"}</span>
              </td>
              <td class="v" title={if(!r.carried?, do: "the box is not in: no lock resolved it yet")}>
                <span :if={!r.carried?} class="unlit">–</span>
                <.pkg_ref
                  :if={r.carried? && r.locked}
                  name={r.name}
                  version={r.locked}
                  git={r.git}
                  mark={false}
                />
                <span :if={r.carried? && !r.locked}>—</span>
              </td>
              <td
                class={["v", r.latest && r.latest == r.locked && "good"]}
                title={latest_says(r)}
              >
                <span :if={!r.asked?} class="unlit">–</span>
                <span :if={r.why} class="bad" title={r.why}>not read</span>
                {r.latest}
              </td>
              <td class="v" title={r.off}>
                {r.ago}<span :if={!r.asked?} class="unlit">–</span>
              </td>
              <td class="v" title={r.no_downloads}>
                {r.downloads}<span :if={!r.asked? or r.no_downloads} class="unlit">–</span>
              </td>
              <td :if={@brought} class="by"><.brought by={r.by} /></td>
            </tr>
          </tbody>
        </table>
      </div>
      <p :if={@footnote} class="fn-note"><span class="fn">*</span>{@footnote}</p>
    </div>
    """
  end

  attr :by, :any, required: true

  # Who put a package in mix.exs: the boxes, each a mention that opens
  # it; or where it came from when no box did — said, not left blank.
  defp brought(%{by: {:boxes, names}} = assigns) do
    assigns = assign(assigns, names: names)

    ~H"""
    <span class="refs"><.cart_ref :for={n <- @names} name={n} installed={true} /></span>
    """
  end

  defp brought(%{by: :born} = assigns) do
    ~H"""
    <span class="refs"><span
      class="nothing"
      title="in mix.exs since the first commit: phx.new generated it, or the workbench put its own dependency there — no cartridge brought it"
    >born with it</span></span>
    """
  end

  defp brought(%{by: :hand} = assigns) do
    ~H"""
    <span class="refs"><span
      class="nothing"
      title="neither the first commit nor any cartridge put it in mix.exs: it was added by hand"
    >by hand</span></span>
    """
  end

  defp brought(assigns) do
    ~H"""
    <span class="refs"><span class="unlit" title="being read off git">–</span></span>
    """
  end

  # What the mix.exs column says of itself: against the cartridge's own
  # pin where a cartridge brought it, plainly what the file asks for
  # where none did.
  defp pinned_says(%{carried?: false}), do: "the box is not in: nothing pins it yet"

  defp pinned_says(%{pinned: pinned, brings: brings}) when is_binary(brings) and pinned != brings,
    do:
      "the project pins #{pinned || "nothing"}, where the cartridge brings #{brings} — an insert older than the cartridge"

  defp pinned_says(_row), do: "what mix.exs asks for"

  # What the mark in the cartridge column means, said once under the
  # table: the rows read off an insert commit, and the phx.new that
  # generated what the commit wrote — one version, or the few when
  # inserts made at different ones share the panel.
  defp footnote(rows) do
    case for(r <- rows, r.read?, do: r.from) do
      [] ->
        nil

      froms ->
        at =
          case froms |> Enum.reject(&is_nil/1) |> Enum.uniq() do
            [] -> "phx.new"
            versions -> "phx.new " <> Enum.join(versions, ", ")
          end

        "The box does not install this package itself: it comes with #{at}, " <>
          "and the version is the one that installer writes."
    end
  end

  # hex's newest release, said against what the project runs: the same
  # number in two columns is a question a reader should not have to ask.
  defp latest_says(%{off: why}) when is_binary(why), do: why
  defp latest_says(%{latest: nil}), do: nil

  defp latest_says(%{latest: latest, locked: locked} = r) when latest == locked,
    do: "#{newest(r)} — and the one this project runs"

  defp latest_says(%{latest: _latest, locked: locked} = r) when is_binary(locked),
    do: "#{newest(r)}; this project runs #{locked}"

  defp latest_says(r), do: newest(r)

  defp newest(%{git: %{}}), do: "GitHub's latest release"
  defp newest(_r), do: "hex.pm's newest release"

  # What the button sends for a row: the name for hex, `name=owner/repo`
  # for a repository on GitHub, nothing for a git host elsewhere.
  defp asked_as(%{git: nil, name: name}), do: name

  defp asked_as(%{git: %{"repo" => repo}, name: name}) when is_binary(repo),
    do: name <> "=" <> repo

  defp asked_as(_r), do: nil

  @doc """
  One package as the table reads it, off a reading the status or a box
  gives (string keys): what the box brings, what the project does with
  it, and what hex said if anybody asked. `carried?` is whether the
  project carries it — a box not yet in lists what it would bring.
  """
  def row(row, hex, now, carried?) do
    said = hex[row["name"]] || %{}
    git = git_said(row["git"])

    %{
      name: row["name"],
      git: git,
      off: git && is_nil(git["repo"]) && "from git, not on GitHub: nobody to ask of its releases",
      no_downloads:
        git && "GitHub counts no downloads of a repository — only of files attached to a release",
      by: row["by"],
      brings: brings(row, git),
      read?: row["read"] == true,
      from: row["from"],
      pinned: row["pinned"],
      locked: row["locked"],
      latest: said[:latest],
      ago: said[:released_at] && Console.Hex.ago(said[:released_at], now),
      downloads: said[:downloads] && downloads_said(said[:downloads]),
      why: said[:error],
      asked?: said != %{},
      carried?: carried?
    }
  end

  @doc """
  Where a package from git comes from, keyed as the status's JSON keys
  it: `Console.Diffs` reads it off a commit with atom keys.
  """
  def git_said(%{} = git), do: Map.new(git, fn {k, v} -> {to_string(k), v} end)
  def git_said(_git), do: nil

  # What the cartridge asks for: a box's pin, or a git package's tag. A
  # package no cartridge brought — born with the project, added by
  # hand, or not read yet (`:reading`) — has nothing asking.
  defp brings(%{"by" => by}, _git) when by in [:born, :hand, :reading], do: nil
  defp brings(row, git), do: row["declared"] || row["requirement"] || held_to(git)

  # What a package from git is held to, in the place a version goes:
  # its tag, or failing that the branch or ref mix.exs names.
  defp held_to(%{} = git), do: git["tag"] || git["branch"] || git["ref"]
  defp held_to(_git), do: nil

  # A download count a reader can take in: 97.8M, not 97802365.
  defp downloads_said(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp downloads_said(n) when n >= 1_000, do: "#{div(n, 1000)}k"
  defp downloads_said(n), do: to_string(n)
end
