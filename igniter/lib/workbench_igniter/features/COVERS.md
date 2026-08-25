# Cartridge covers

Every feature in this folder is a *cartridge*, so every one of them can
have a box cover. This file is what keeps the set looking like a set:
the parts that never change, the slots each cartridge fills in, and the
template that assembles both into a prompt for an image generator.

Generated covers live in the repository's `assets/covers/<feature>.jpg`.
They are documentation art, not project assets — nothing plants them
into a generated project.

Everything below that reads like a rule was learned from a cover that
came out wrong. [What the generator gets wrong](#what-the-generator-gets-wrong)
has the evidence.

## How a cover is made

**The generator draws the art. We set the type.** Six covers in, the
lettering is where every inconsistency came from: the seal rendered
differently on all six, badges reflowed and one got clipped off the
edge, and small strings inside the art came out plausible and false.

So the production path is two steps:

1. Generate **the art panel only**, using the template below with the
   lettering block omitted.
2. Composite the furniture — band, title, subtitle, badge and seal — over
   the cardboard field around it.

The one-shot path (generate everything, lettering included) is fine for
seeing whether an idea works. It is not fine for a cover that ships:
even then, **the seal must be replaced**, for the reason in the next
section.

## The invariants

These blocks go into every prompt **verbatim**. They are what makes two
covers recognizable as belonging to the same shelf. Do not reword them
per cartridge; if one needs changing, change it here and regenerate the
whole set.

**Medium and finish**

```text
Late-1980s console game box cover art, front face only, portrait
orientation. Painted airbrush illustration with the slightly stiff,
heroic look of North American 8-bit era packaging: hard airbrush
gradients, chunky specular highlights, visible matte cardboard grain and
faint edge wear.
```

**Presentation** — a flat front face, never a photograph of a box.

```text
Flat front face reproduced straight on, filling the frame edge to edge:
not a photograph of a physical box, no perspective, no drop shadow, no
surrounding background, no visible spine or side panels. The artwork sits
in an inset rectangular panel with a thin border, leaving a cardboard
margin around all four sides. Proportions 5:7 portrait.
```

The inset panel is not decoration: it is the flat area the band, title,
badge and seal get composited onto. Art bled to the edges leaves the
lettering nowhere to sit.

**System band** — the console is the workbench; the cartridges are its
features. This is why the band never names the feature.

```text
Top band across the full width, dark with a thin chrome rule, reading
"DOCKERIZED ELIXIR WORKBENCH" in condensed sans-serif caps.
```

**Seal of quality** — the single most important constant, and the one
thing the generator must never draw.

```text
Bottom right corner: a circular gold starburst seal with a scalloped
edge and an embossed bevel, reading "WORKBENCH SEAL OF QUALITY" in small
caps around its rim.
```

Render it **once**, keep it as a transparent PNG, and composite it onto
every cover. This is a rule, not an optimisation:

* It came out different on all six of the first covers — three lines,
  four lines, a star in the middle, an empty middle.
* On `healthcheck.jpg` the generator wrote **"Nintendo"** into the seal,
  in a prompt that said `No real brand marks or logos`. Describing 80s
  console packaging summons the trademark, and a negative instruction
  does not hold it back. The only reliable defence is not asking for the
  seal at all.

**Base palette** — violet and gold are fixed; the accent is the one
colour each cartridge gets to choose.

```text
Palette: Elixir violet (#4B275F) as the dominant colour, warm gold for
the seal, CRT phosphor haze in the background. No photographic elements.
No real brand marks or logos.
```

The accent must **contrast in value against the violet**. That is the
only hard rule: warm neutrals are banned, because `exdoc.jpg` used
parchment ivory, dissolved into the background, and is the least legible
cover of the set. Saturated magenta, green and forge orange all held.

Beyond contrast, pick whatever suits the feature — including a colour
another cartridge already uses. Accents are not allocated. Green means
"healthy" and "covered" alike, gold means money, orange means forge; a
uniqueness rule would trade that legibility for bookkeeping, and would
run out of usable colours long before the shelf runs out of cartridges.
What binds the set is the violet, the gold, the seal and the layout, not
one colour per box.

**Trademarks**: never ask for the Nintendo logo, the "Official Nintendo
Seal of Quality", the NES wordmark or its typefaces. The band and the
seal above are our own equivalents, which is also what we actually want:
a workbench cartridge, not a counterfeit.

## The slots

Five things change per cartridge. Keep them short — every extra clause
is one more thing the generator can get wrong.

| Slot | Rule |
| --- | --- |
| **Title** | The cartridge name, uppercase. Nothing else. |
| **Subtitle** | Two to four words, imperative or boastful. It is a tagline, not a description. |
| **Hero** | One concrete scene depicting the *mechanism*, not the abstraction. See below. |
| **Accent** | One colour beside the violet, contrasting in value, chosen because it suits the feature. |
| **Unit badge** | The "1-2 PLAYERS" slot, in the feature's own units. One line, one short phrase, composited with a safe margin from the box edge. |

### Writing the hero

This is where a cover earns its place. The rule: **draw what the
cartridge actually does**, literally, and let the airbrush style make it
heroic. Clustering is four droids linked by a mesh of beams because a
four-node cluster is six connections. Coveralls is a gauge with a red
notch at 80 because 80% is the real quality gate the cartridge writes
into `coveralls.json`.

Five habits, in order of how much they buy you:

* **Count things.** Four replicas, six links, three watchers, six
  lecterns. This is the single most reliable instruction in the whole
  document: every count asked for came back correct. Counts give the
  generator something to compose around, and they make the picture true.
* **Give the mechanism a body.** A beacon tower, a gauge, a gate, a
  foundation slab. Abstractions render as fog.
* **Describe compositions, not states.** The generator draws objects, not
  what they are doing. "The needle risen just past the 80 notch" produced
  a perfect dial with the needle at 15. Say "the needle resting against
  the red notch" — a position, not a movement.
* **Text inside the art has a size threshold.** Above it the generator is
  reliable — `/health`, `/dev/docs` and `200` all came out right, and so
  did the two large foreground address plates on clustering. Below it,
  digits flip: the two plates set small and far back on that same cover
  came back reading `172.28.x` instead of `172.26.x`. So use as many
  strings as the composition wants, but give every one of them the size
  of a foreground element. If a label has to sit far back, let it be
  texture rather than a fact, or composite it afterwards.
* **Fix the figure's scale.** Say how big the body is in the frame, or it
  will drift: coveralls' droid is a speck at the foot of its gauge while
  clustering's fill half the panel. "Waist-high to the gauge" or
  "occupying the lower third" is enough.

## The template

Fill the five slots, paste the invariants unchanged. For the production
path, stop after the hero paragraph and composite the rest.

```text
[MEDIUM AND FINISH — verbatim]

[PRESENTATION — verbatim]

Hero illustration: <HERO>.

[BASE PALETTE — verbatim] Accent: <ACCENT>.

--- lettering, one-shot path only; composite it instead ---

[SYSTEM BAND — verbatim]

Title lockup in the lower third: "<TITLE>" in a beveled chrome-and-
violet wordmark with a hard drop shadow, and beneath it a smaller
sans-serif subtitle "<SUBTITLE>".

Bottom left: a small rectangular badge reading "<UNIT BADGE>".
```

Note the seal is not in the template at all, on either path.

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

## Accent record

A mirror, not a gate. Fill a row when a cover is generated, so the
distribution of the shelf is visible at a glance — the point is to
notice when six covers in a row have drifted to the same colour, not to
stop the seventh from reusing one.

| Cartridge | Accent |
| --- | --- |
| clustering | electric magenta |
| coveralls | phosphor green |
| healthcheck | vital signal green |
| exdebug | electric cyan |
| exdoc | *unassigned* — parchment ivory failed the contrast rule |
| enhancements | hot forge orange |

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
| Art bled to the edges on half the set, and two came out as photographed 3D boxes on different backgrounds | `healthcheck`, `exdoc`, `enhancements` | The presentation invariant |
| Two covers came out visibly narrower than the rest | `exdebug`, `enhancements` | Proportions stated inside the prompt, not only as a generator setting |
| A warm neutral accent dissolved into the violet | `exdoc` | Accents must contrast in value |
| The two small background IP labels came back with wrong digits, while the two large foreground ones were correct | `clustering` | Text in the art needs foreground size |
| A dial rendered perfectly with its needle in the wrong place | `coveralls` | Describe compositions, not states |
| The badge split its number into a second box, and once got clipped by the edge | `healthcheck`, `exdebug`, `enhancements` | Badge is one line, composited, with a safe margin |
| The figure went from half the panel to a speck | `clustering` vs `coveralls` | State the figure's scale in the frame |

What it gets right, consistently: the system band, the title and subtitle
lockup, every count it was given, and one large string inside the art.

## Tonal variants

The invariants hold in all three; only the hero and subtitle change
register. Useful when the default heroic tone does not suit a feature.

* **Heroic** (default) — airbrushed, triumphant, blue-violet skies.
* **Ominous**, in the style of European boxes — obsidian monoliths with
  a single violet eye, black background and fog, subtitles that threaten
  (`THEY SPEAK AS ONE`).
* **Comic**, in the style of Japanese manuals — round mascot robots,
  flat saturated colours, thick linework, subtitles that endear
  (`NOBODY DEPLOYS ALONE`).

Pick one per cartridge and note it beside the slots, so a regenerated
cover keeps its register.
