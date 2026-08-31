# The house's design tokens

Everything visual in the workbench that is not a cover reads its colours
and type from one file, `tokens.json`. The covers keep their own source
— the overlay is the one source of every number about a face — and this
file takes two things *from* them: the violet of the board and the gold
of the seal. Nothing else about colour is decided anywhere else.

```text
assets/design/
├── tokens.json             THE SOURCE: a palette, roles, type
├── build.py                ./assets/design/build.py [--check], from the repository root
└── generated/              projections; every one says it is generated
    ├── tokens.css          custom properties for the console (light, dark by media query, dark by data-theme)
    └── diagram-design.md   the diagram-design skill's style guide; also installed as the
                            profile ~/.diagram-design/profiles/workbench.md that the
                            repository's .diagram-design marker names
```

## The shape of the source

Three layers, the same three the covers have:

* **Palette** — the few values with a name of their own: `violet` and
  `violet-ink` (the board and its lettering), `gold` and `gold-deep`
  (the seal, and the seal on light ground). They are the only hex
  values that mean something by themselves, and roles refer to them as
  `{violet}`.
* **Roles** — what a colour is *for*, each with a light and a dark
  value: `ground`, `surface`, `line`, `ink`, `muted`, `accent`, the
  semantic three (`good`, `warn`, `bad`), the terminal, the service
  colours the logs use. A role that is the same in both themes carries
  one `value`. The names are the console's custom properties.
* **Type** — three families by role: `display` (Barlow Condensed, the
  band's lettering), `text` (Source Serif 4, the backs' prose), `code`
  (IBM Plex Mono). Each with its weights and its fallback stack.

## Who consumes what

| Consumer | Projection | How |
| --- | --- | --- |
| The console (its mock today, the LiveView app later) | `generated/tokens.css` | `mock/build.py` puts it in the page in place of a hand-written `:root{}`; the app will copy it into its assets |
| The diagram-design skill | `generated/diagram-design.md` → `~/.diagram-design/profiles/workbench.md` | `build.py` installs the profile and writes `.diagram-design` (`profile: workbench`) at the repository root; the skill resolves it before every diagram. The mapping from the house's roles to the skill's (`paper ← ground`, `rule ← line`, `link`, the type roles) lives in `build.py` with its reasons |
| The cartridges' diagrams (`assets/diagrams/`) | the SVGs they export | drawn through the skill, so the house comes in with the profile |
| The covers | nothing, for now | `covers.py` keeps its constants; reading violet and gold from here is a four-line change for the next cover |

## The components

Beyond colour and type, the house has two pieces of notation, projected
to `generated/components.css` and consumed everywhere a cartridge shows
its face — the console mock, the LiveView console, the box-back plates:

* **`.cart-ref`** — every mention of a cartridge, always a link to its
  detail. Three states: bare (on the shelf: hollow dot), `.in`
  (inserted: good dot), `.unknown` (no such cartridge: dashed, struck,
  no link). It never wears the gold. A printed back plate uses the bare
  form — a plate knows no project.
* **`.stamp`** — the golden state seal (`INSERTED`): the accent plate
  in condensed uppercase, tilted by whoever places it. This is one of
  the accent's three canonical uses (a button, a stamp, a focal node),
  and why nothing else is gold.

## The rules

* **Edit the tokens, run the build.** A generated file edited by hand is
  overwritten by the next build; the header on each one says so.
* **`build.py --check`** fails when any projection is stale, for a git
  hook or CI: a token in two places is two tokens.
* **A role is added when a consumer needs it**, not in anticipation.
  `link` exists because diagrams draw HTTP edges; `soft` because they
  set sublabels; neither existed while the console was the only reader.
