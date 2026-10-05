defmodule ConsoleWeb.Ribbon do
  @moduledoc """
  The row that says which document of a screen is being read — the
  papers of a box, the workbench's own, the project's, the daemon's —
  and, in a drawer's header, which of its screens. Six rows of the
  console wore the same `.dtab` and drifted on everything around it:
  each place set its own air, its own ground and its own margin, and
  each wrote the markup again with a small difference (one marked the
  unlit tab's `aria-selected`, one did not; one carried a sublabel).
  One component now, and one rule in `console.css` with two placements:
  `docked`, the row that anchors a pane with a rule under it, and the
  drawer's header, the one place the row rides up into the header's own
  rule.

  This is the console's own layout and not house notation — a cover has
  no tabs — so it lives here and in `console.css`, not in the design
  system. What it borrows from the system it keeps in one place: an
  unlit tab is `aria-disabled`, never `disabled`, so a screen reader
  keeps the map the rule set out to protect.
  """
  use Phoenix.Component

  attr :label, :string, required: true, doc: "what the row is, for the screen reader"
  attr :selected, :string, default: nil, doc: "the key of the document being read"
  attr :docked, :boolean, default: false, doc: "anchoring a pane, with a rule under it"

  attr :items, :list,
    required: true,
    doc:
      "maps with :key, :label and :href; :small for a sublabel; :why when unlit, with the reason; :badge with :badge_class and :badge_title"

  def ribbon(assigns) do
    ~H"""
    <div class={["dtabs", @docked && "docked"]} role="tablist" aria-label={@label}>
      <%= for i <- @items do %>
        <.link
          :if={!i[:why]}
          class="dtab"
          role="tab"
          patch={i.href}
          aria-selected={to_string(@selected == i.key)}
        >{i.label}<small :if={i[:small]}>{i.small}</small><span
          :if={i[:badge]}
          class={["badge", i[:badge_class]]}
          title={i[:badge_title]}
        >{i.badge}</span></.link>
        <button
          :if={i[:why]}
          class="dtab unlit"
          role="tab"
          type="button"
          aria-disabled="true"
          aria-selected="false"
          title={i.why}
        >{i.label}<small :if={i[:small]}>{i.small}</small></button>
      <% end %>
    </div>
    """
  end
end
