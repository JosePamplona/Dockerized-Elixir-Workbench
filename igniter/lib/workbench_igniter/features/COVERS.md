# Cartridge covers

Every feature in this folder is a *cartridge*, so every one of them can
have a box cover. This file is what keeps the set looking like a set:
the parts that never change, the slots each cartridge fills in, and the
template that assembles both into a prompt for an image generator.

Generated covers live in the repository's `assets/covers/<feature>.png`.
They are documentation art, not project assets — nothing plants them
into a generated project.

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

**System band** — the console is the workbench; the cartridges are its
features. This is why the band never names the feature.

```text
Top band across the full width, dark with a thin chrome rule, reading
"DOCKERIZED ELIXIR WORKBENCH" in condensed sans-serif caps.
```

**Seal of quality** — the single most important constant. Same corner,
same shape, same words, on every cover.

```text
Bottom right corner: a circular gold starburst seal with a scalloped
edge and an embossed bevel, reading "WORKBENCH SEAL OF QUALITY" in small
caps around its rim.
```

**Base palette** — violet and gold are fixed; the accent is the one
colour each cartridge gets to choose.

```text
Palette: Elixir violet (#4B275F) as the dominant colour, warm gold for
the seal, CRT phosphor haze in the background. No photographic elements.
No real brand marks or logos.
```

**Aspect ratio**: 5:7 portrait (NES boxes are 5×7 inches). Fall back to
3:4 if the generator only takes presets.

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
| **Accent** | One colour beside the violet, chosen to suit the feature. |
| **Unit badge** | The "1-2 PLAYERS" slot, in the feature's own units. |

### Writing the hero

This is where a cover earns its place. The rule: **draw what the
cartridge actually does**, literally, and let the airbrush style make it
heroic. Clustering is four droids linked by a mesh of beams because a
four-node cluster is six connections. Coveralls would be a percentage
gauge, not "an abstract sense of thoroughness".

Two habits that help:

* **Count things.** Four replicas, six links, three retries. Specific
  counts give the generator something to compose around, and they make
  the picture true.
* **Give the mechanism a body.** A DNS beacon tower, a lock, a gauge, a
  ledger. Abstractions render as fog.

## The template

Fill the five slots, paste the invariants unchanged.

```text
[MEDIUM AND FINISH — verbatim]

[SYSTEM BAND — verbatim]

Hero illustration: <HERO>.

Title lockup in the lower third: "<TITLE>" in a beveled chrome-and-
violet wordmark with a hard drop shadow, and beneath it a smaller
sans-serif subtitle "<SUBTITLE>".

[SEAL OF QUALITY — verbatim]
Bottom left: a small rectangular badge reading "<UNIT BADGE>".

[BASE PALETTE — verbatim] Accent: <ACCENT>.
```

## Worked example: clustering

> **Hero** — four identical armored server-droids standing in formation
> on a vast circuit-board plain under a deep violet sky, each linked to
> every other by taut glowing energy beams, a full mesh of six beams
> crossing between them; behind them a monolithic beacon tower emits a
> widening ring of light, and four small holographic address plates hang
> in the air around it, each reading a different numeric address
> (172.26.0.3 … 172.26.0.6)
>
> **Title** CLUSTERING · **Subtitle** CONNECT THE NODES ·
> **Accent** electric magenta · **Badge** 1-4 NODES

Note how the counts come from the real thing: four is the `--replicas`
default, six is how many links four nodes need, and the addresses are
the ones a real deployment prints.

## Slot suggestions for the rest

Starting points, not decisions. The hero column is a seed — expand it
with the counts and the body before generating.

| Cartridge | Subtitle | Badge | Hero seed |
| --- | --- | --- | --- |
| healthcheck | STILL BREATHING | 1 ENDPOINT | A vital-signs monitor bolted to a fortress gate, green trace pulsing |
| rest | SPEAK THE SPEC | 4 VERBS | Four heraldic banners (GET, POST, PUT, DELETE) over a marble API temple |
| graphql | ASK FOR EXACTLY THIS | 1 QUERY | A single beam splitting through a prism into a queried subtree |
| coveralls | LEAVE NOTHING UNTESTED | 100% | A colossal percentage gauge, needle climbing past a line of green cells |
| exdoc | READ THE MACHINE | ∞ PAGES | A librarian automaton in a vault of glowing indexed shelves |
| enhancements | THE FULL LOADOUT | 16 PARTS | An exploded diagram of a mech assembling itself mid-air |
| auth0 | NONE SHALL PASS | 1 TOKEN | A gate warden inspecting a glowing signed key against a wall of claims |
| openai | ASK THE ORACLE | 1 ASSISTANT | A monolith face answering a small figure across a conversation thread |
| credo | STYLE IS LAW | 0 WARNINGS | An inspector droid stamping verdicts on a scrolling wall of code |
| githooks | NOTHING GETS THROUGH | 3 HOOKS | Three iron hooks suspended over a commit conveyor belt |
| exmachina | BUILD THE WITNESSES | ∞ FACTORIES | An assembly line stamping out identical test subjects |
| mock | TRUST NO ONE | 1 DOUBLE | A shapeshifter mid-transformation into a service it is impersonating |
| exdebug | SEE THE FLOW | 1 BREAKPOINT | A cutaway of a pipeline frozen mid-execution, values glowing in place |
| psql_extras | INTERROGATE THE STORE | 20 QUERIES | A diagnostician droid with a stethoscope on a database obelisk |
| osmon | WATCH THE MACHINE | 4 GAUGES | Four dial gauges (CPU, memory, disk, ports) on a brass control panel |
| stripe | TAKE THE MONEY | 1 CHARGE | A vault door opening on a stream of coins routed into a ledger |

## Practical notes

**The text will come out wrong.** Almost no generator gets four separate
text blocks right at once. Either generate the illustration without the
lettering and set the type yourself — better result, and the only way to
keep the seal truly identical across covers — or generate with text and
pick the take that needs least repair.

**The seal is worth compositing.** Since it must be identical everywhere,
render it once, keep it as a transparent PNG, and paste it onto every
cover. That removes the one element the generator would otherwise vary.

**Fewer objects, cleaner result.** If a mesh of six beams turns to soup,
drop to three nodes and three links. A legible cover beats an accurate
one that reads as noise.

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
