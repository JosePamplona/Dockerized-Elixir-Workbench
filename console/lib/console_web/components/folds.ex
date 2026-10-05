defmodule ConsoleWeb.Folds do
  @moduledoc """
  A section that folds to its head. The rail's sections have folded
  since 2026-09-12, and the Deploy screen's three cards since
  2026-09-27 — the same fold, the same `fold_section` event, the same
  `folded` set on the server and the same memory of it in the browser
  (the Folds hook, `localStorage`), so a reader who has met one has met
  them all.

  Two heads, because two sizes: the rail's `h2` is the rail's
  (`ConsoleWeb.Board`), and `card_head/1` is a card's `h3` on a screen.
  Each key is its own: the rail's Deployments section and the Deploy
  screen's sheet are two things with one name, and fold apart.
  """
  use Phoenix.Component
  import ConsoleWeb.Square, only: [square: 1]

  @doc "Whether `key` is folded away, against the set the page carries."
  def folded?(nil, _key), do: false
  def folded?(folded, key), do: MapSet.member?(folded, key)

  @doc "`\"folded\"` when it is, for the section's class list."
  def fold_class(folded, key), do: folded?(folded, key) && "folded"

  @doc """
  A card's head: its name, whatever it carries of its own, and the
  square that folds it. The head itself takes the same click, so the
  name and the empty stretch fold too — LiveView fires only the binding
  closest to the click, so a square inside the slot keeps its own.
  """
  attr :key, :string, required: true
  attr :name, :string, required: true
  attr :folded, :any, default: nil
  attr :title, :string, default: nil
  slot :inner_block, doc: "what the head carries at its end, before the fold"

  def card_head(assigns) do
    ~H"""
    <h3 phx-click="fold_section" phx-value-key={@key} title={@title}>
      <span class="name">{@name}</span>
      {render_slot(@inner_block)}
      <.square
        mark="chevron"
        size="small"
        class="foldsq"
        label={"#{@name}: fold, or open"}
        aria-expanded={to_string(not folded?(@folded, @key))}
        phx-click="fold_section"
        phx-value-key={@key}
      />
    </h3>
    """
  end
end
