defmodule ConsoleWeb.Refs do
  @moduledoc """
  The house's notation (assets/design, components.css) as components:
  the mention of a cartridge, the door on the app's port, the chip, and
  `unlit` — the one way the console says *not available*: never hidden,
  marked, with the reason in the title. There is no probe: a health
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
  app's port), `"port"` (the compose's), `"console"` (the workbench's
  own). `port` writes a route on its port, `:4001/dev/mailbox`, the port
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
  attr :kind, :string, default: "route", values: ~w(route port console)
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
