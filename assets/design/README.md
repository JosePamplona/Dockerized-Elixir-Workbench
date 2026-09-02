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
* **`.chip`** — a reading the console reports: a container's health, a
  job's exit code, the edition of a box. Roles: bare (a fact with no
  state — `v0.2.0`, `base`, `collection`), `.good`/`.warn`/`.bad` (a
  state, on a plate tinted 16% from its colour), `.off` (an absence —
  `not baked`, `idle`: no plate at all, but the plated chips' padding
  kept, so a column of states has one left edge and not two), `.busy` (with one of the
  above: a pulsing dot).
* **The two, apart.** The chip and the reference were once the same
  declaration to the character — the chip had been written by hand in
  the console while the reference was generated here, and nobody was
  watching two files that were one. They are separated now along two
  lines that mean something. **Shape**: a bordered box with a dot is a
  door you press; a chip is never pressable, so it has neither, and the
  dot survives only on `.busy`, where it means something is moving.
  **Voice**: mono in lower case, which in the console already means
  *read off the machine* — the board's tables, the log lines, the
  terminal — where the condensed uppercase is the house's lettering for
  *names*. `assets/design/chapas-y-menciones.html` is the page the
  decision was made on, with the five candidates it was chosen from.
* **`.unlit`** — the one way the house says *not available*. The rule it
  carries: **never hide what the reader could have.** A control they could
  make appear stays where it is, marked, with the reason in its title and,
  where there is one, the action that would light it. Hiding is only for
  what is not applicable and never will be here. A tab is the clearest
  case: the tab row is the console's map, and a reader arriving at an
  empty workspace should be able to count its screens before earning any
  of them — `Cluster` names the cartridge that lights it, `Project` names
  the command that starts one, and a box's `DESIGN` sits there dimmed so
  the row shows what a box is made of, not only what this one brought.
  Two things this replaced, both worth knowing: three different opacities
  (`.4`, `.45`, `.55`) for the same idea in as many places, and a
  `pointer-events:none` that was quietly eating the `title` it was paired
  with — the title is the reason, so nothing here may take it. The name is
  the house's own verb negated: the console *lights up* the day a
  cartridge is inserted. It is not `off`, which a chip already uses for a
  different thing — a chip reports an absence out in the world (`not
  baked`, `idle`); `.unlit` marks a control you cannot use yet. Tabs mark
  with `aria-disabled`, never the `disabled` attribute: a disabled
  `<button>` takes no focus, and a tab a screen reader cannot reach was
  hidden after all.
* **Controls the reader sets** — checkboxes and radios wear
  `accent-color: var(--accent)`. Not a fourth use of the gold: it is the
  first one — *a control the reader acts on* — read wider than "a button".
  It lives here because it was four scoped rules in the console and four
  controls that had missed all of them, left in the browser's blue.
* **`.stamp`** — the golden state seal (`INSERTED`): the accent plate
  in condensed uppercase, tilted by whoever places it. This is one of
  the accent's three canonical uses (a control the reader acts on, a stamp,
  a focal node),
  and why nothing else is gold — and why a chip's plate is a tint and
  never a saturated fill: nothing may compete with the seal.

## The rules

* **Edit the tokens, run the build.** A generated file edited by hand is
  overwritten by the next build; the header on each one says so.
* **`build.py --check`** fails when any projection is stale, for a git
  hook or CI: a token in two places is two tokens.
* **A role is added when a consumer needs it**, not in anticipation.
  `link` exists because diagrams draw HTTP edges; `soft` because they
  set sublabels; neither existed while the console was the only reader.
