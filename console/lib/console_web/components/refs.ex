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
  An address: the label first, then the address in mono. Who opened it
  goes beside as a mention, never inside. `why` is the reason there is
  nothing to press, and it takes the href with it. `kind` is the layer
  the square before the label says — `"route"` (the project's, on the
  app's port), `"port"` (the compose's). `port` writes a route on its
  port, `:4001/dev/mailbox`, the port
  dimmed. `read` is what the address answered when the console called
  it, `{text, chip class}`, attached inside the border; nil when nothing
  called it.
  """
  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :href, :string, default: nil
  attr :who, :string, default: nil
  attr :who_installed, :boolean, default: true
  attr :why, :string, default: nil
  attr :kind, :string, default: "route", values: ~w(route port)
  attr :port, :any, default: nil
  attr :read, :any, default: nil

  def door_ref(assigns) do
    assigns = assign(assigns, open: assigns.href && !assigns.why)

    ~H"""
    <span class="pair">
      <a
        :if={@open}
        class={["door-ref", "door-" <> @kind]}
        href={@href}
        target="_blank"
        title={door_title(@who, @path, @why)}
      ><b>{@label}</b><span><em :if={@port}>:{@port}</em>{@path}</span><i
        :if={@read}
        class={["read", elem(@read, 1)]}
      >{elem(@read, 0)}</i></a>
      <span
        :if={!@open}
        class={["door-ref", "door-" <> @kind, @why && "unlit"]}
        title={door_title(@who, @path, @why)}
      ><b>{@label}</b><span><em :if={@port}>:{@port}</em>{@path}</span><i
        :if={@read}
        class={["read", elem(@read, 1)]}
      >{elem(@read, 0)}</i></span>
      <.cart_ref :if={@who} name={@who} installed={@who_installed} />
    </span>
    """
  end

  defp door_title(who, path, why),
    do: Enum.join(Enum.reject([who && "#{who}:", path, why && "— #{why}"], &(!&1)), " ")

  @doc """
  A mention of a commit: the short sha, boxed because it opens History on
  that commit with its diff, the subject and date in the title.
  """
  attr :sha, :string, required: true
  attr :subject, :string, default: nil
  attr :date, :string, default: nil

  def commit_ref(assigns) do
    ~H"""
    <.link
      class="commit-ref"
      patch={"/project?paper=history&commit=#{@sha}"}
      title={Enum.join(Enum.reject([@subject, @date], &is_nil/1), " · ") <> " — open in History, with its diff"}
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
