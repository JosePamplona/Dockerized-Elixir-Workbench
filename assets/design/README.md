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
    ├── components.css      the house's notation: the mention, the door, the probe, the chip, the seal
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
| The console, both of them | `generated/tokens.css`, `generated/components.css` | `mock/build.py` puts them in the page in place of a hand-written `:root{}`; `build.py` writes the same two into `console/priv/static/assets/css/`, where the LiveView console links them beside `console.css`, and `--check` keeps the copies honest |
| The diagram-design skill | `generated/diagram-design.md` → `~/.diagram-design/profiles/workbench.md` | `build.py` installs the profile and writes `.diagram-design` (`profile: workbench`) at the repository root; the skill resolves it before every diagram. The mapping from the house's roles to the skill's (`paper ← ground`, `rule ← line`, `link`, the type roles) lives in `build.py` with its reasons |
| The cartridges' diagrams (`assets/diagrams/`) | the SVGs they export | drawn through the skill, so the house comes in with the profile |
| The tab, in both consoles | `console/priv/static/favicon.svg` | `build.py` writes it from `logo.svg` and the board's two colours; the LiveView console links it and `mock/build.py` carries a base64 copy inside the single-file page. `favicon.ico` beside it is the fallback for what does not take an SVG icon, rendered from the SVG once and committed — it changes only when the mark does, and the command that made it is in `build.py` |
| The covers | nothing, for now | `covers.py` keeps its constants; reading violet and gold from here is a four-line change for the next cover |

## The components

Beyond colour and type, the house has its notation, projected to
`generated/components.css` and consumed everywhere a cartridge shows its
face or the console reports a reading — the console mock, the LiveView
console, the box-back plates. Two of them name a cartridge, two name an
address on the app's port, and the split inside each pair is the same
one: a bordered box is a door you press.

* **`.cart-ref`** — every mention of a cartridge, always a link to its
  detail. Three states: bare (on the shelf: hollow dot), `.in`
  (inserted: good dot), `.unknown` (no such cartridge: dashed, struck,
  no link). It never wears the gold. A printed back plate uses the bare
  form — a plate knows no project.
* **`.door-ref`** — an address on the app's port that a cartridge opened
  (`/dev/docs`, `/dev/mailbox`, `/admin`). One order wherever it is read:
  the label first, in the house's lettering because it is a name, then
  the address in mono because it is read off the machine. Who opened it
  is never inside it — that is a mention, so it goes beside as a
  `.cart-ref` and opens that box with the same click. It has no states of
  its own: pressable while something answers, `.unlit` with the reason in
  the title when nothing does, and an unlit door drops its `href` too,
  since `.unlit` dims a link but cannot stop one. The addresses the
  workbench opens itself (`app`, `pgAdmin`) wear it with nothing beside
  them: having nobody to name is the fact.
* **`.probe-ref`** — the same address when the console is the one calling
  it (healthcheck2's `{path}/live`). It is the door minus the box — no
  border, no ground, no cursor — because the line already drawn between
  the chip and the mention holds one floor down: a bordered box is a door
  you press, and nobody presses a probe. What it answered goes beside it
  in a `.chip`. `assets/design/puertas-y-sondas.html` is the page the two
  were decided on, with the five candidates and the finding that started
  it: the same door was drawn one way in the rail and another on the box,
  and the `<small>` meant the cartridge in one and the door's own name in
  the other.
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
* **`.fetch`** — a field whose values are not the workbench's: they come
  from outside it, over the network, and somebody has to go and get them.
  The square button beside the field is who goes. It takes its width out
  of the field, so the pair is exactly as wide as the field was and the
  form keeps its column; it stands one field-padding away rather than
  welded to it, because a select carries its own chevron at that edge and
  two glyphs side by side say nothing about which belongs to the field;
  it is 2.5em of the field's own type,
  which is what a field of that type is tall, so the square follows the
  scale and not a measured pixel; it wears a reload; and it turns while
  it is away. **The rule it carries is the reason it exists: a field like
  this never goes on its own.** Opening the drawer that holds one costs
  nothing and there is no clock behind it — the trip happens when the
  button is pressed, so every call the console makes to the internet is
  one the reader can point at. What settled it was a measurement — the
  stack list took **20.8 seconds**, paid on every drawer open, in the
  background, with the band saying `idle` — and then that measurement
  turned out to be about us and not about Docker Hub: `wb.sh` was asking
  for the five pages one after another, and asking for them at once
  brought the same 483 tags back in **1.5 seconds**. The rule outlived
  its own argument, which is how you know it was the right one: a field
  like this never goes on its own because a call that leaves the machine
  should have somebody who caused it, not because it is slow. What speed
  decides is only how pleasant the button is to press. What comes back is held for the whole console until
  somebody presses again; being a day old is not a reason to go. A list
  that never arrived says so where the field's help is, rather than
  reading as a list with nothing in it — the old code kept a failure as
  an empty list, so an offline console said *no published image for this
  combination (of the 0 usable)*, which is not what had happened.
* **`.fold`** — the control that opens and closes something: a section of
  the rail, a file in a diff, a job in the tray. Two rules, and they are
  the whole component. The caret **leads** — first on the line, before
  the name — so a column of folds reads down and the eye finds them
  without reading the rows; and it is **drawn from `aria-expanded`**,
  never typed into the template, so the attribute a screen reader reads
  is the one that draws the arrow and the two cannot come to say
  different things. That second rule is what the console had already
  broken in one place out of three: the jobs list typed `▾`/`▸` beside a
  class, which is one truth in two hands. Everything else belongs to
  where it is used — a section head is condensed uppercase, a job row is
  mono, a file row is a path — so this sets the control and the caret and
  nothing else. It is also why the jobs row grew a real button: a caret
  drawn from `aria-expanded` needs something to carry it, and the output
  below stopped being a click target that closed what you were reading.
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

**The underline is a mark, not a default.** `.cart-ref` and `.door-ref`
each turn it off in their own declaration, and for the same reason: in
this console a link is almost never a word in a sentence — it is a tab, a
box on the shelf, a door, a row, the whole jobs bar — and all of those
already say they are pressable by their shape. The console was taking the
browser's underline off one element at a time (`a.tab`, `a.dtab`, `a.box`,
`a.lrow`, `a.btn`, `a.tray-bar`), which is how the jobs bar ended up wearing
one: its class was renamed and the rule that undressed it went on matching
nothing. `console.css` states it once now — `a{text-decoration:none}` — and
the two links that really are prose ask for it: a link inside rendered
Markdown, and `.lk`, the button that reads as one. No token and no
component: it is the same rule the two references already carry, said in
one place instead of six.

**The state on the band.** The band's middle says what the console is
doing: a dot and a word, mono in lower case — `idle`, `up dev`, `reading
the cartridges…`, `waiting for your word`, `no connection`. It is the
chip's grammar with the plate taken off, the move `.probe-ref` already
made on `.door-ref`: nobody presses it, so it has no box. The dot pulses
only while something is moving, which is what `.chip.busy`'s dot means,
and the last of those five is written in CSS on the class LiveView puts
on the page when the socket goes — a server that cannot be reached cannot
be the one to say so. `assets/design/estado-en-la-banda.html` is the page
it was decided on, with the five candidates and what each would cost.

The terminal follows the ground since 2026-09-07: `term`, `term-ink`,
`term-dim`, `term-line`, `term-scroll` carry a light value, `term-tint`
washes a line on it, and the six `ansi-*` are what a job's colours are set
in on each ground, the same red, green and yellow as the semantic three
so an error in a job and a chip in red say the same thing. The Files
sheet's twelve are One Dark on the dark ground and One Light on the light,
kept beside the jsonc in `console.css`, not here: they are an editor's
palette, not the house's. `assets/design/fuente-claro.html` is the page
it was decided on, with the three candidates and what each lost.

Two things came from it. `board-warn` and `board-bad` are roles now,
because the band is the one surface whose ground does not follow the
theme — it is the same violet on both, like a cover's board — so a
semantic colour on it is always the dark value, in both themes. They
carry a single `value`, the shape `board` and `board-ink` already have,
and it is written `{warn:dark}`, not the hex: a role that *is* another
role read on a fixed ground should never be a copy that can drift (the
`{role:mode}` form in `build.py` exists for exactly these). There is no
`board-good` — nothing on the band reports a good state yet. And the
progress bar stays: it says something else, a navigation loading, and it
says it in `--accent` now instead of Phoenix's `#29d`, which had been the
one colour in the console decided outside `tokens.json`. The indicator's
own face is not house notation — it appears on the band and nowhere else,
so it lives with the band in `console.css`; `components.css` is for what
crosses surfaces.

**A measure in a column.** `.num` is a cell that holds a reading — cpu,
memory, a size, a duration: mono, flush right, tabular digits, no
wrapping. The notation does half the work; the other half is the
writer's, and it is a rule: **one unit per column, and a fixed number of
decimals**. Right-aligned — the column's head too, on the same edge, since a head
sits where its column is read from — that is what makes the decimal
points line up without splitting a number in two, and what keeps a column from
redrawing itself every two seconds — Docker prints three significant
figures, so the same memory column said `1.9MB`, `1.84MB` and
`282.4MiB`, a different length on every refresh, and the whole table
danced. `Console.Docker.stat/1` normalises the stream (cpu with one
decimal, memory always in MiB with one decimal), and the two live
columns reserve, in `ch`, the width of the widest value they can hold.
Decided on 2026-09-05 over the Docker screen's containers table.

## The rules

* **Edit the tokens, run the build.** A generated file edited by hand is
  overwritten by the next build; the header on each one says so.
* **`build.py --check`** fails when any projection is stale, for a git
  hook or CI: a token in two places is two tokens.
* **A role is added when a consumer needs it**, not in anticipation.
  `link` exists because diagrams draw HTTP edges; `soft` because they
  set sublabels; neither existed while the console was the only reader.
* **The scrollbar sits on the edge of the box that scrolls**, with
  nothing between the two. Side air goes on the element that scrolls
  (or on its content), never on a wrapper around it, and a measure goes
  on the content, never on the scroller; a bordered box that scrolls
  keeps its bar on its own inner edge. Every pane that can scroll says
  `scrollbar-gutter:stable`. The note on scrollbars in components.css
  says why.
