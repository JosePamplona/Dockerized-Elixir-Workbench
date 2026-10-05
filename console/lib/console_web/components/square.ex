defmodule ConsoleWeb.Square do
  @moduledoc """
  The square: the console's icon button, and the mark it wears. A
  square is 2em of its neighbour's type, a hairline, the second surface,
  and one drawing in the middle that takes the ink of whatever holds it;
  it carries a name for the screen reader always, since it has no word
  on its face. The drawings are files, `assets/design/icons/*.svg`, that
  `build.py` gathers into one sprite, `/images/icons.svg`, so a mark is
  drawn once, cached once, and edited where drawings are edited.

  Two sizes, one component: normal is the field's height, 2.5em of
  the field's type, and every square on a heading, a row or a corner
  is that one; small is a line's, 2em of 11px, for the jobs bar at the
  window's foot and the cogs on the rows of a card. Where a square stands is its holder's business (`console.css`);
  what a square is lives in the house's `components.css` (`.sq`).
  """
  use Phoenix.Component

  @logo_path Path.join(__DIR__, "../../../priv/static/images/logo.svg")
  @external_resource @logo_path
  @logo File.read!(@logo_path) |> String.trim()

  @doc "The house's mark, inline: the band wears it, and the miniature of the band."
  def logo(assigns) do
    assigns = assign(assigns, svg: Phoenix.HTML.raw(@logo))

    ~H"""
    {@svg}
    """
  end

  attr :name, :string,
    required: true,
    doc: "the symbol's id in the sprite: bell, eye, cog, reload, x, ground, workbench"

  attr :class, :any, default: nil

  @doc "A drawing from the sprite, in the ink of its holder."
  def mark(assigns) do
    assigns = assign(assigns, href: "/images/icons.svg#" <> assigns.name)

    ~H"""
    <svg class={@class} aria-hidden="true"><use href={@href} /></svg>
    """
  end

  attr :mark, :string, required: true, doc: "the drawing on its face"
  attr :label, :string, required: true, doc: "what pressing it does, for the screen reader"

  attr :patch, :string,
    default: nil,
    doc: "given, the square is a link that patches, not a button"

  attr :size, :string,
    default: "normal",
    values: ~w(normal small),
    doc: "normal is the field's height; small is a line's, for a bar or a row of a card"

  attr :class, :any,
    default: nil,
    doc: "its role where it stands (knock, eye, cog) and unlit when it cannot be pressed"

  attr :rest, :global,
    include: ~w(disabled form name value),
    doc: "phx-click, title, id, aria-busy, aria-pressed, aria-disabled and the rest"

  @doc "The square icon button: a mark, a name, and where it goes."
  def square(assigns) do
    ~H"""
    <.link :if={@patch} class={["sq", @size == "small" && "small", @class]} patch={@patch} {@rest}>
      <.mark name={@mark} /><span class="sr">{@label}</span>
    </.link>
    <button :if={!@patch} class={["sq", @size == "small" && "small", @class]} type="button" {@rest}>
      <.mark name={@mark} /><span class="sr">{@label}</span>
    </button>
    """
  end
end
