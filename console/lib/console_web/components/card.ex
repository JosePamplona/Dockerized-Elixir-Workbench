defmodule ConsoleWeb.Card do
  @moduledoc """
  The card: the frame of a unit the reader acts on — a form, or a row
  of verbs. The console's boxes follow a rule of three families, read
  off its twelve boxes on 2026-09-27: a *card* frames what is acted on
  (New Project, Deployments, Danger, Commit, a container's ficha); a
  *sheet* — a paper, a table, a list — is what is read, and wears no
  frame; a *terminal box* (`.term-box`) frames what came out of a
  process or a file, as it came. The card's face is the house's
  (`.card` in `assets/design/generated/components.css`), and this is
  the one place that writes the class: a template names the card and
  hands it what the card holds, never `class="card"` by hand.

  The head is the card's `h3`: the name first, whatever the head
  carries after it (`:head` — a chip, a note in the note's own voice),
  and, when the card folds (`key`), the square that folds it
  (`ConsoleWeb.Folds.card_head/1`, the same fold as the rail's). A card
  without a name has no head — the box's specs — and one without a key
  does not fold — the Commit form.
  """
  use Phoenix.Component
  import ConsoleWeb.Folds, only: [card_head: 1, fold_class: 2]

  attr :name, :string, default: nil, doc: "the head's name; no name, no head"
  attr :key, :string, default: nil, doc: "the fold's key; without one the card does not fold"
  attr :folded, :any, default: nil, doc: "the section keys folded away, a MapSet"
  attr :title, :string, default: nil, doc: "the head's title attribute"

  attr :danger, :boolean,
    default: false,
    doc: "the bad's edge and head: a card of one destructive verb"

  attr :tag, :string, default: "section", values: ~w(section div form)
  attr :class, :any, default: nil, doc: "the content class the card's own rules hang from"
  attr :rest, :global, doc: "the element's own attributes: an id, a phx-submit"
  slot :head, doc: "what the head carries after the name"
  slot :inner_block, required: true

  def card(assigns) do
    assigns =
      assign(assigns, :classes, [
        "card",
        assigns.class,
        assigns.danger && "danger",
        assigns.key && fold_class(assigns.folded, assigns.key)
      ])

    ~H"""
    <.dynamic_tag tag_name={@tag} class={@classes} {@rest}>
      <.card_head :if={@name && @key} key={@key} name={@name} folded={@folded} title={@title}>
        {render_slot(@head)}
      </.card_head>
      <h3 :if={@name && !@key} title={@title}>
        <span class="name">{@name}</span>
        {render_slot(@head)}
      </h3>
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end
end
