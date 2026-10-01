defmodule ConsoleWeb.Refs do
  @moduledoc """
  The house's notation (assets/design, components.css) as components:
  the mention of a cartridge, the door on the app's port, the chip, the
  button that asks the workbench to run a line, and `unlit` — the one
  way the console says *not available*: never hidden, marked, with the
  reason in the title. There is no probe: a health
  endpoint is a door the console calls like any other.
  """
  use Phoenix.Component

  @doc """
  A drawer's query over the screen's own place: `over("/project?paper=history",
  "box=k6")` is `/project?paper=history&box=k6`. A key the query names is
  the drawer's — `paper` is the box's manual's, or the workbench's — and
  the screen's own value of it is left out, kept on the page instead
  (`ConsoleLive.take_paper`), so the URL names it once.
  """
  def over(back, query) do
    [path | rest] = String.split(back, "?", parts: 2)
    names = for kv <- String.split(query, "&"), do: kv |> String.split("=", parts: 2) |> hd()

    kept =
      case rest do
        [own] ->
          String.split(own, "&") |> Enum.reject(&(hd(String.split(&1, "=", parts: 2)) in names))

        [] ->
          []
      end

    path <> "?" <> Enum.join(kept ++ [query], "&")
  end

  @doc "A mention of a cartridge: its state as a dot, its name, a door to its box."
  attr :name, :string, required: true
  attr :installed, :boolean, default: false
  attr :known, :boolean, default: true
  attr :version, :string, default: nil
  attr :unlit, :string, default: nil, doc: "the reason this mention opens nothing"

  def cart_ref(assigns) do
    ~H"""
    <span :if={not @known} class="cart-ref unknown" title="no such cartridge">{@name}</span>
    <button
      :if={@known}
      type="button"
      class={["cart-ref", @installed && "in", @unlit && "unlit"]}
      aria-disabled={@unlit && "true"}
      title={
        @unlit ||
          "#{if @installed, do: "inserted#{@version && " · v#{@version}"}", else: "on the shelf, not inserted"} — open its box"
      }
      phx-click={!@unlit && "open"}
      phx-value-name={@name}
    >{@name}</button>
    """
  end

  @doc """
  A mention of an Elixir package, the one way the console names a
  dependency: hex's own mark, the name in mono, and the address of the
  package's page on hex.pm. With `version` it addresses that version's
  documentation on hexdocs instead, and prints the version. `path` goes
  after the package's page (`"versions"`). `mark` is false where the
  row already wears one — one mark says "this line is a package", two
  say nothing more. It leaves for somebody else's site, which is what
  tells it apart from a mention of a cartridge (`cart_ref/1`, a drawer
  in this console).
  With `git` — where a package from git comes from, as the status
  reports it — the package is its repository instead: GitHub's mark
  (the Invertocat as GitHub draws it, black on the light ground and
  white on the dark, both vendored), the repository's page, and with
  `version`, its tag's tree. A git
  host other than GitHub has no page the console can name, so the
  mention says the name and is no link.
  """
  attr :name, :string, required: true
  attr :git, :map, default: nil, doc: "where it comes from when from git: url, repo, tag…"
  attr :version, :string, default: nil, doc: "that version's docs, and what it prints"
  attr :path, :string, default: nil, doc: "under the package's page on hex.pm"
  attr :label, :string, default: nil, doc: "what it prints, when neither name nor version"
  attr :mark, :boolean, default: true
  attr :title, :string, default: nil
  attr :class, :any, default: nil

  def pkg_ref(%{git: %{} = git} = assigns) do
    repo = git["repo"]

    assigns =
      assign(assigns,
        repo: repo,
        href:
          repo &&
            if(assigns.version,
              do: "https://github.com/#{repo}/tree/#{assigns.version}",
              else: "https://github.com/#{repo}"
            ),
        says: assigns.label || assigns.version || assigns.name
      )

    ~H"""
    <a
      :if={@href}
      class={["pkg-ref", !@mark && "bare", @class]}
      href={@href}
      target="_blank"
      rel="noopener noreferrer"
      title={
        @title ||
          if(@version,
            do: "#{@repo} at #{@version}, on GitHub",
            else: "#{@name} on GitHub: #{@repo}"
          )
      }
    ><img
      :if={@mark}
      class="mark light"
      src="/images/vendor/github.svg"
      alt=""
      width="12"
      height="12"
    /><img
      :if={@mark}
      class="mark dark"
      src="/images/vendor/github-white.svg"
      alt=""
      width="12"
      height="12"
    />{@says}</a>
    <span
      :if={!@href}
      class={["pkg-ref", "bare", @class]}
      title={@title || "#{@name} from git: #{@git["url"]}"}
    >{@says}</span>
    """
  end

  def pkg_ref(assigns) do
    assigns =
      assign(assigns,
        href:
          if(assigns.version,
            do: "https://hexdocs.pm/#{assigns.name}/#{assigns.version}",
            else: "https://hex.pm/packages/#{assigns.name}#{assigns.path && "/#{assigns.path}"}"
          ),
        says: assigns.label || assigns.version || assigns.name
      )

    ~H"""
    <a
      class={["pkg-ref", !@mark && "bare", @class]}
      href={@href}
      target="_blank"
      rel="noopener noreferrer"
      title={
        @title ||
          if(@version,
            do: "the documentation of #{@name} #{@version}",
            else: "#{@name} on hex.pm"
          )
      }
    ><img :if={@mark} class="mark" src="/images/vendor/hex.svg" alt="" width="12" height="11" />{@says}</a>
    """
  end

  @doc """
  A mention of somebody else's site that is not a package — a theme's
  home, a face's: the `.pkg-ref`'s rules with a mark that says where it
  goes. A repository on GitHub is named as the packages table names one,
  `owner/repo` under the Invertocat (both vendored drawings, the ground's);
  any other host goes under the house's globe, by its name. It is the
  one link of a credits ficha.
  """
  attr :url, :string, required: true
  attr :name, :string, required: true, doc: "whose site it is, for the title"
  attr :class, :any, default: nil

  def site_ref(assigns) do
    assigns =
      case Regex.run(~r{^https?://github\.com/([^/]+/[^/#?]+)}, assigns.url) do
        [_, repo] -> assign(assigns, repo: repo, host: nil)
        _ -> assign(assigns, repo: nil, host: host_of(assigns.url))
      end

    ~H"""
    <a
      class={["site-ref", @class]}
      href={@url}
      target="_blank"
      rel="noopener noreferrer"
      title={if @repo, do: "#{@name} on GitHub: #{@repo}", else: "#{@name}'s site: #{@host}"}
    ><img
      :if={@repo}
      class="mark light"
      src="/images/vendor/github.svg"
      alt=""
      width="12"
      height="12"
    /><img
      :if={@repo}
      class="mark dark"
      src="/images/vendor/github-white.svg"
      alt=""
      width="12"
      height="12"
    /><ConsoleWeb.Square.mark :if={!@repo} name="globe" class="mark" />{@repo || @host}</a>
    """
  end

  defp host_of(url) do
    url
    |> String.replace(~r{^https?://(www\.)?}, "")
    |> String.split("/", parts: 2)
    |> hd()
  end

  @doc """
  A reading attached to whatever names the thing read: `{words, chip
  class}` as `Cartridges.container_reading/1` gives it — `healthy`,
  `running`, `starting`, `exited`, `exited 1`, `stopped` — or what a
  door answered when the console called it. Nothing at all when there
  is nothing to say, which is not the same as a thing that is down: a
  container that is not there has no reading, and the `why` beside it
  says so.

  One element for every place a state is read (2026-09-26): the plate
  of a service or a door, the Containers table on the rail, and the
  containers a cartridge brings on its own screen. They came off the
  same function already and wore two different faces, a `.chip` on the
  table and this on the plate, so a reader learnt the same vocabulary
  twice. `title` is the long form where there is one — a container's
  `Status`, which is Docker's own line, and the only thing the chip
  had that this did not.
  """
  attr :read, :any, default: nil, doc: "`{words, chip class}`, or nil for nothing to say"
  attr :title, :any, default: nil

  def state_read(assigns) do
    ~H"""
    <i :if={@read} class={["read", elem(@read, 1)]} title={@title}>{elem(@read, 0)}</i>
    """
  end

  @doc """
  An address: the label first, then the address in mono. Who opened it
  goes beside as a mention, never inside. `why` is the reason there is
  nothing to press, and it takes the href with it. `kind` is the layer
  the square before the label says — `"route"` (the project's, on the
  app's port), `"port"` (the compose's, published on the host),
  `"inside"` (the compose's, inside the pod only: the same blue, the
  square hollow — a port with no door), `"output"` (a page a tool of
  the project wrote on disk, green, written as the dir it is read from
  and served by the console on the origin beside it). `port` writes a route on its
  port, `:4001/dev/mailbox`, the port
  dimmed. `read` is what the address answered when the console called
  it, `{text, chip class}`, attached inside the border; nil when nothing
  called it. `build` is a page's, there or not: the Mix task the
  cartridge says writes it, a button on the same plate after the
  reading, running `./wb.sh mix <task>` as a job — the one thing to
  press while nothing is built, the rebuild beside the stamp once it is.
  """
  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :href, :string, default: nil
  attr :who, :string, default: nil
  attr :who_installed, :boolean, default: true
  attr :why, :string, default: nil
  attr :kind, :string, default: "route", values: ~w(route port inside output)
  attr :port, :any, default: nil
  attr :read, :any, default: nil

  attr :read_title, :any,
    default: nil,
    doc: "what the reading says at length: a container's own `Status` line, Docker's words"

  attr :build, :any,
    default: nil,
    doc: "the Mix task that would write this page, when it is not there"

  def door_ref(assigns) do
    # A service with no port to write (`listens` unknown) has an empty
    # address: not written, or the empty span takes the plate's gap and
    # the label ends in twice the room.
    assigns =
      assign(assigns,
        open: assigns.href && !assigns.why,
        addr: assigns.port || assigns.path != ""
      )

    ~H"""
    <span class="pair">
      <%!-- One plate, three things on it: the address, which is the link
            while it is open; its reading; and, on a page, the command
            that writes it — a button, which no `<a>` may hold, so the
            plate is a span and the link is its name and address
            (2026-09-25; the whole plate was the link before).

            The button says which of the two it is (2026-09-26): *build*
            while there is no page, *rebuild* once there is. A page's
            reading is the stamp of when it was written, and the two
            come off the same `built` in `Record` — a page with a stamp
            is a page on disk — so the reading is what the word reads. --%>
      <span
        class={["door-ref", "door-" <> @kind, !@open && @why && "unlit"]}
        title={door_title(@who, @path, @why)}
      ><a :if={@open} href={@href} target="_blank"><b>{@label}</b><span :if={@addr}><em :if={@port}>:{@port}</em>{@path}</span></a><b :if={
        !@open
      }>{@label}</b><span :if={!@open and @addr}><em :if={@port}>:{@port}</em>{@path}</span><.state_read
        read={@read}
        title={@read_title}
      /><button
        :if={@build}
        type="button"
        class="read build"
        phx-click="run"
        phx-value-args={"mix " <> @build}
        title={
          "./wb.sh mix #{@build} — writes this page in the workspace#{if @read, do: " again"}, as a job"
        }
      >{if @read, do: "rebuild", else: "build"}</button></span>
      <.cart_ref :if={@who} name={@who} installed={@who_installed} />
    </span>
    """
  end

  defp door_title(who, path, why),
    do:
      Enum.join(
        Enum.reject([who && "#{who}:", path, why && "— #{why}"], &(&1 in [nil, false, ""])),
        " "
      )

  @doc """
  A mention of a commit: the short sha, boxed because it opens History on
  that commit with its diff, the subject and date in the title.
  """
  attr :sha, :string, required: true
  attr :subject, :string, default: nil
  attr :date, :string, default: nil

  attr :open, :boolean,
    default: false,
    doc: "its diff is open under it, on History: the mention then folds it, and says so"

  def commit_ref(assigns) do
    ~H"""
    <.link
      class="commit-ref"
      patch={if @open, do: "/project?paper=history", else: "/project?paper=history&commit=#{@sha}"}
      aria-pressed={@open && "true"}
      title={
        Enum.join(Enum.reject([@subject, @date], &is_nil/1), " · ") <>
          if(@open, do: " — its diff is open under it; press again to fold it", else: " — open in History, with its diff")
      }
    >{String.slice(@sha, 0, 7)}</.link>
    """
  end

  @doc """
  A button that asks the workbench for a line of `wb.sh` — the one
  shape every such button has: Bake, Down, Stop, Up, Build, Create,
  Delete, and the Docker screen's removals.

  Two ways of sending it, and which one is right is decided by where
  the line comes from. A line that is only itself — `stop`, `down`,
  `delete`, a prune — travels on the click, written on the button.
  A line composed out of a form — the target picked, `--replicas`,
  the flags of `phx.new` — must not: the button is rendered with the
  form as it was, and a change and a click in the same instant sent
  the line as it was BEFORE the change (a `--database` chosen and a
  bare `new` run, which is why Create became a submit in the first
  place). Give it `form`, and it submits that form instead: the values
  travel whole and the server writes the line from them, with `name`
  and `value` saying which button was pressed. What is rendered on it
  is then only what it SAYS — its title — and never what it does.

  Unlit is the house's: marked, never hidden, the reason in the title,
  and nothing to press — a submit that cannot be pressed is a plain
  button, so the form cannot travel by it either.
  """
  attr :label, :string, required: true

  attr :args, :string,
    default: nil,
    doc: "the line without its ./wb.sh: what a click sends, and what the title says"

  attr :form, :string,
    default: nil,
    doc: "the form whose values compose the line; pressed, the button submits it"

  attr :name, :string, default: nil, doc: "with a form: which button was pressed"
  attr :value, :string, default: nil
  attr :why, :any, default: nil, doc: "unlit, with the reason"
  attr :class, :any, default: nil, doc: "primary, danger, mini — the button's weight"

  attr :event, :string,
    default: "run",
    doc: "the click's event, for the verbs that are not wb.sh lines"

  attr :title, :any, default: nil, doc: "what it says of itself; the line when it says nothing"
  attr :rest, :global

  def job_button(assigns) do
    assigns =
      assign(assigns,
        say: assigns.why || assigns.title || (assigns.args && "./wb.sh " <> assigns.args),
        # A reason can arrive as false as easily as nil — `!@project? &&
        # "…"` writes false — so this asks whether there is one, not
        # whether it is nil.
        sends: !assigns.why
      )

    ~H"""
    <button
      class={["btn", @class, @why && "unlit"]}
      type={if @form && @sends, do: "submit", else: "button"}
      form={@form && @sends && @form}
      name={@form && @sends && @name}
      value={@form && @sends && @value}
      aria-disabled={@why && "true"}
      title={@say}
      phx-click={is_nil(@form) && @sends && @event}
      phx-value-args={is_nil(@form) && @sends && @args}
      {@rest}
    >{@label}</button>
    """
  end

  @doc "A reading the console reports."
  attr :class, :string, default: nil
  attr :title, :string, default: nil
  slot :inner_block, required: true

  def chip(assigns) do
    ~H"""
    <span class={["chip", @class]} title={@title}>{render_slot(@inner_block)}</span>
    """
  end
end
