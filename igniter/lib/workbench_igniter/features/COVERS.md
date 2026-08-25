# Cartridge covers

Every feature in this folder is a *cartridge*, so every one of them can
have a box cover. This file is how the covers get made.

Generated covers live in the repository's `assets/covers/<feature>.jpg`.
They are documentation art, not project assets — nothing plants them
into a generated project.

## What makes them a collection

Not a house style. A shelf of real 8-bit boxes is wildly inconsistent —
every publisher had its own illustrator, its own decade and its own
taste — and it still reads as one shelf, because the *platform* furniture
is identical on all of them. That is the model here, in three tiers:

| Tier | What | Varies? |
| --- | --- | --- |
| **The seal** | `WORKBENCH SEAL OF QUALITY` | Never. Shared by every workbench there could be |
| **Band + house colour** | `DOCKERIZED ELIXIR WORKBENCH`, Elixir violet | Never within a workbench; both change if there is ever a Python or a JS one |
| **Everything else** | Art, layout, finish, era, wear, stickers | Freely, cover to cover |

So the covers are meant to be **collected, not manufactured**: generated
one at a time, each in whatever register suits its feature, and none of
them obliged to match the last. The band and the colour say which
workbench; the seal says it is one of ours.

Everything below that reads like a rule was learned from a cover that
came out wrong. [What the generator gets wrong](#what-the-generator-gets-wrong)
has the evidence.

## Tier 1 — the seal

```text
Bottom right corner: a circular gold starburst seal with a scalloped
edge and an embossed bevel, reading "WORKBENCH SEAL OF QUALITY" in small
caps around its rim.
```

**Never ask the generator for this.** Render it once, keep it as a
transparent PNG, and composite it onto every cover. It is the only
element that is composited, and the rule is not an optimisation:

* It came out different on all six of the first covers — three lines,
  four lines, a star in the middle, an empty middle.
* On `healthcheck.jpg` the generator wrote **"Nintendo"** into it, in a
  prompt that said `No real brand marks or logos`. Describing 80s console
  packaging summons the trademark, and a negative instruction does not
  hold it back. The only reliable defence is not asking for the seal.

Never ask for the Nintendo logo, the "Official Nintendo Seal of Quality",
the NES wordmark or its typefaces either. This seal is our own
equivalent, which is also what we actually want: a workbench cartridge,
not a counterfeit.

### Stamping it

The seal lives at `assets/covers/seal.png`, and `assets/covers/stamp.sh`
puts it on:

```sh
./assets/covers/stamp.sh clustering --corner br
```

It reads `assets/covers/art/<feature>.jpg` — the raw generated artwork —
and writes the stamped cover to `assets/covers/<feature>.jpg`. Keep both:
regenerating a cover means replacing the art and stamping again.

Size and inset are **fractions of each cover's width**, not pixels,
because covers come out at different resolutions — the first six were
765px wide and 687px wide. A fixed pixel size would make the seal look
bigger on the narrow ones. Defaults: `0.24` of the width, inset `0.04`.

Corners are a per-cover choice, but two are constrained: the top ones
collide with the band and need `--margin 0.11` or so to clear it, and the
bottom left is usually where the badge sits. Bottom right is the default
for a reason.

## Tier 2 — band and house colour

Both go into every prompt verbatim. The band renders reliably — it came
out identical on all six of the first covers — so unlike the seal, it is
generated with the rest.

```text
Top band across the full width, dark with a thin chrome rule, reading
"DOCKERIZED ELIXIR WORKBENCH" in condensed sans-serif caps.
```

```text
Elixir violet (#4B275F) as the dominant colour of the composition.
```

The band never names the feature: the console is the workbench, the
cartridges are its features. And the violet is this workbench's mark —
a Python or a JS workbench would swap the band and the colour together,
and keep the same seal.

A cover may leave the violet when the feature genuinely demands it
(money green, forensic monochrome), but that is a departure to make on
purpose, one cover at a time — not a free choice per cartridge.

**The accent**, the one colour beside the violet, must **contrast in
value against it**. That is the one hard rule about colour: warm neutrals
are banned, because `exdoc.jpg` used parchment ivory, dissolved into the
background, and is the least legible cover of the set. Otherwise pick
whatever suits the feature, repeats included — green reads as "healthy"
and as "covered" alike, and both covers are better for it. See the
[accent record](#accent-record).

## Tier 3 — house style

Defaults, not rules. Start here; depart when a feature is better served
another way, and let the shelf be uneven.

```text
Late-1980s console game box cover art, front face only, portrait
orientation. Painted airbrush illustration with the slightly stiff,
heroic look of North American 8-bit era packaging: hard airbrush
gradients, chunky specular highlights, visible matte cardboard grain and
faint edge wear.

Flat front face reproduced straight on, filling the frame edge to edge:
not a photograph of a physical box, no perspective, no drop shadow, no
surrounding background, no visible spine or side panels. Proportions 5:7
portrait.
```

Two departures already worth knowing about. Half of the first six put
the art in an inset panel with a cardboard margin and half bled it to
the edges; both look right, and the inset version leaves the lettering
more room. And two came back as photographed 3D boxes with drop shadows
— out of style here, but a fine deliberate choice for a "collector's
edition" one-off.

### Period furniture

Optional, and the thing that makes a collection look collected rather
than printed in one run. Sprinkle, do not stack:

* A price sticker in a corner — `$49.95`, slightly crooked, half peeled.
* A video rental label with a hand-written cartridge number.
* A reissue band across the top corner — `CLASSIC SERIES`, `2ND PRINT`.
* A magazine award flash — `EDITOR'S CHOICE`, `4 STARS`.
* Shelf wear: a scuffed corner, a ring stain, a faded spine edge.
* An age or region marker in the era's visual idiom.

None of these are invariants. A cover with a rental sticker and one
without belong to the same shelf precisely because the seal and the band
do not move.

## The slots

Five things change per cartridge. Keep them short — every extra clause
is one more thing the generator can get wrong.

| Slot | Rule |
| --- | --- |
| **Title** | The cartridge name, uppercase. Nothing else. |
| **Subtitle** | Two to four words, imperative or boastful. It is a tagline, not a description. |
| **Hero** | One concrete scene depicting the *mechanism*, not the abstraction. See below. |
| **Accent** | One colour beside the violet, contrasting in value, chosen because it suits the feature. |
| **Unit badge** | The "1-2 PLAYERS" slot, in the feature's own units. One line, one short phrase. |
| **Seal corner** | Which corner the composition keeps quiet for the seal. Bottom right unless the art wants otherwise. |

## The craft: writing the hero

This is the part that has nothing to do with consistency. A cover earns
its place by being *true*: **draw what the cartridge actually does**,
literally, and let the era's style make it heroic. Clustering is four
droids linked by a mesh of beams because a four-node cluster is six
connections. Coveralls is a gauge with a red notch at 80 because 80% is
the real quality gate the cartridge writes into `coveralls.json`.

Five habits, in order of how much they buy you:

* **Count things.** Four replicas, six links, three watchers, six
  lecterns. The single most reliable instruction in the whole document:
  every count asked for came back correct. Counts give the generator
  something to compose around, and they make the picture true.
* **Give the mechanism a body.** A beacon tower, a gauge, a gate, a
  foundation slab. Abstractions render as fog.
* **Describe compositions, not states.** The generator draws objects, not
  what they are doing. "The needle risen just past the 80 notch" produced
  a perfect dial with the needle at 15. Say "the needle resting against
  the red notch" — a position, not a movement.
* **Give text in the art foreground size.** Above that threshold the
  generator is reliable: `/health`, `/dev/docs`, `200` and the two large
  address plates on clustering all came out right. Below it digits flip —
  the two plates set small and far back on that same cover came back
  reading `172.28.x` instead of `172.26.x`. Use as many strings as the
  composition wants, all at foreground size; anything that must sit far
  back should be texture rather than a fact.
* **Fix the figure's scale.** Say how big the body is in the frame, or it
  will drift: coveralls' droid is a speck at the foot of its gauge while
  clustering's fill half the panel. "Waist-high to the gauge" or
  "occupying the lower third" is enough.

## The template

Everything except the seal, which is composited afterwards.

```text
[HOUSE STYLE — verbatim, or a deliberate departure]

[BAND — verbatim]

Hero illustration: <HERO>.

Title lockup in the lower third: "<TITLE>" in a beveled chrome-and-
violet wordmark with a hard drop shadow, and beneath it a smaller
sans-serif subtitle "<SUBTITLE>".

Bottom left: a small rectangular badge reading "<UNIT BADGE>".

[optional: one or two pieces of period furniture]

The <SEAL CORNER> of the artwork is composed as a quiet area: low detail,
no focal element, an even field of tone.

Palette: [HOUSE COLOUR — verbatim], CRT phosphor haze in the background.
No photographic elements. No real brand marks or logos.
Accent: <ACCENT>.
```

The last line is the seal's corner, and it is art direction rather than a
reservation: **ask for calm, not for emptiness**. A generator told to
leave a corner clear leaves a hole in the picture. Told that the corner
is an even field of tone with no focal element, it composes around it and
the seal drops in as if it had always been there.

If the lettering comes out wrong on a take that is otherwise good,
compositing it is always available — it just is not the default any more,
because band, title, subtitle and badge all render well enough.

## Worked example: clustering

> **Hero** — four identical armored server-droids standing in formation
> across the lower half of the panel on a vast circuit-board plain under
> a deep violet sky, each linked to every other by taut glowing energy
> beams, a full mesh of six beams crossing between them; one large
> holographic address plate hovering beside each droid, all four the same
> size and all in the foreground, reading 172.26.0.3, 172.26.0.4,
> 172.26.0.5 and 172.26.0.6; behind the formation a monolithic beacon
> tower emits a widening ring of light
>
> **Title** CLUSTERING · **Subtitle** CONNECT THE NODES ·
> **Accent** electric magenta · **Badge** 1-4 NODES

The counts come from the real thing: four is the `--replicas` default and
six is how many links four nodes need.

The address plates are the size rule in practice. The first version let
the generator place them freely, and the two it put small and far back
came back with a wrong digit while the two large ones were right. Hence
*the same size, all in the foreground*: the plates stay, they just stop
being background texture.

## Cover record

The accent column is a mirror, not a gate: the point is to notice when
six covers in a row have drifted to the same colour, not to stop the
seventh from reusing one. The corner column is what `stamp.sh` was
passed, so a cover can be restamped identically.

| Cartridge | Accent | Seal corner |
| --- | --- | --- |
| clustering | electric magenta | — |
| coveralls | phosphor green | — |
| healthcheck | vital signal green | — |
| exdebug | electric cyan | — |
| exdoc | *unassigned* — parchment ivory failed the contrast rule | — |
| enhancements | hot forge orange | — |

The corners are empty because these six predate the seal: each carries a
*generated* seal baked into the artwork, including the one on
`healthcheck.jpg` that says "Nintendo". They want regenerating from the
current guide — artwork into `art/`, then stamped — and healthcheck wants
it first.

Coveralls and healthcheck sharing green is fine: covered lines are green
and so is a vital-signs trace, and both covers read instantly because of
it. If two neighbours on the shelf feel too alike, shift the hue — a
cooler or warmer green — rather than the meaning.

exdoc is the one that actually needs redoing, and not because ivory was
taken: it failed the contrast rule.

## Slot suggestions for the rest

Starting points, not decisions. The hero column is a seed — expand it
with the counts, the body and the scale before generating.

| Cartridge | Subtitle | Badge | Hero seed |
| --- | --- | --- | --- |
| rest | SPEAK THE SPEC | 4 VERBS | Four heraldic banners (GET, POST, PUT, DELETE) over a marble API temple |
| graphql | ASK FOR EXACTLY THIS | 1 QUERY | A single beam splitting through a prism into a queried subtree |
| auth0 | NONE SHALL PASS | 1 TOKEN | A gate warden inspecting a glowing signed key against a wall of claims |
| openai | ASK THE ORACLE | 1 ASSISTANT | A monolith face answering a small figure across a conversation thread |
| credo | STYLE IS LAW | 0 WARNINGS | An inspector droid stamping verdicts on a scrolling wall of code |
| githooks | NOTHING GETS THROUGH | 3 HOOKS | Three iron hooks suspended over a commit conveyor belt |
| exmachina | BUILD THE WITNESSES | 1 FACTORY | An assembly line stamping out identical test subjects |
| mock | TRUST NO ONE | 1 DOUBLE | A shapeshifter mid-transformation into a service it is impersonating |
| psql_extras | INTERROGATE THE STORE | 20 QUERIES | A diagnostician droid with a stethoscope on a database obelisk |
| osmon | WATCH THE MACHINE | 4 GAUGES | Four dial gauges (CPU, memory, disk, ports) on a brass control panel |
| stripe | TAKE THE MONEY | 1 CHARGE | A vault door opening on a stream of coins routed into a ledger |

## What the generator gets wrong

Measured on the first six covers. Read this before blaming a prompt.

| Symptom | Seen in | Rule it produced |
| --- | --- | --- |
| Seal drew four different ways, and once wrote "Nintendo" into it | all six; the trademark in `healthcheck.jpg` | Never generate the seal — composite it |
| A warm neutral accent dissolved into the violet | `exdoc` | Accents must contrast in value |
| The two small background IP labels came back with wrong digits, while the two large foreground ones were correct | `clustering` | Text in the art needs foreground size |
| A dial rendered perfectly with its needle in the wrong place | `coveralls` | Describe compositions, not states |
| The figure went from half the panel to a speck | `clustering` vs `coveralls` | State the figure's scale in the frame |
| Proportions drifted narrower on two of six | `exdebug`, `enhancements` | State them inside the prompt, not only as a generator setting |

What it gets right, consistently: the band, the title and subtitle
lockup, the badge, every count it was given, and any string given
foreground size.

Layout drift — inset panel or bleed, flat face or photographed box — is
no longer on this list. That is the collection working as intended.

## Tonal variants

Only the hero and subtitle change register; band, colour and seal hold.

* **Heroic** (default) — airbrushed, triumphant, blue-violet skies.
* **Ominous**, in the style of European boxes — obsidian monoliths with
  a single violet eye, black background and fog, subtitles that threaten
  (`THEY SPEAK AS ONE`).
* **Comic**, in the style of Japanese manuals — round mascot robots,
  flat saturated colours, thick linework, subtitles that endear
  (`NOBODY DEPLOYS ALONE`).

Pick one per cartridge and note it beside the slots, so a regenerated
cover keeps its register.
