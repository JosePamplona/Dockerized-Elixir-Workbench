defmodule ConsoleWeb.Refs do
  @moduledoc """
  The house's notation (assets/design, components.css) as components:
  the mention of a cartridge, the door on the app's port, the probe,
  the chip, and `unlit` — the one way the console says *not available*:
  never hidden, marked, with the reason in the title.
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
  An address on the app's port: the label first, then the address in
  mono. Who opened it goes beside as a mention, never inside. `why` is
  the reason there is nothing to press, and it takes the href with it.
  """
  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :href, :string, default: nil
  attr :who, :string, default: nil
  attr :who_installed, :boolean, default: true
  attr :why, :string, default: nil

  def door_ref(assigns) do
    assigns = assign(assigns, open: assigns.href && !assigns.why)

    ~H"""
    <span class="pair">
      <a
        :if={@open}
        class="door-ref"
        href={@href}
        target="_blank"
        title={door_title(@who, @path, @why)}
      ><b>{@label}</b><span>{@path}</span></a>
      <span :if={!@open} class={["door-ref", @why && "unlit"]} title={door_title(@who, @path, @why)}><b>{@label}</b><span>{@path}</span></span>
      <.cart_ref :if={@who} name={@who} installed={@who_installed} />
    </span>
    """
  end

  defp door_title(who, path, why),
    do: Enum.join(Enum.reject([who && "#{who}:", path, why && "— #{why}"], &(!&1)), " ")

  @doc "The same address when the console is the one calling it, with what it answered."
  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :who, :string, default: nil
  attr :read, :any, default: nil, doc: "{text, chip class}"

  def probe_ref(assigns) do
    ~H"""
    <span class="pair">
      <span class="probe-ref" title={"#{if @who, do: "#{@who}: "}#{@path}"}><b>{@label}</b><span>{@path}</span></span>
      <.cart_ref :if={@who} name={@who} installed={true} />
      <span :if={@read} class={["chip", elem(@read, 1)]}>{elem(@read, 0)}</span>
    </span>
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
