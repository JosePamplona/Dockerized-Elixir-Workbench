# Cartridge covers

Every feature of the workbench is a *cartridge*
([the cartridges themselves](../../igniter/lib/workbench_igniter/features/)),
so every one of them can have a box cover. This directory is how those
covers get made — a small pipeline rather than a folder of images:

```text
assets/covers/
├── seal.png                the stamp, generated once, never regenerated
├── stamp.sh                puts it on
├── back.sh                 composes a back and puts it on
└── <feature>/              one directory per cartridge, the whole box
    ├── art/cover.jpg       the generated artwork, unstamped
    ├── art/back.jpg        the generated back plate, blank
    ├── sealed/cover.jpg    the finished cover
    ├── sealed/back.jpg     the finished back
    ├── back/copy.md        the facts the back is typeset from
    ├── back/shot-N.png     real screenshots, 1 is the leftmost
    ├── back/layout.env     positions measured off that plate
    ├── cover.prompt.txt    the prompt that made the current art
    ├── back.prompt.txt     the prompt that made the current plate
    └── _archived/          superseded work, local only, never in the repo
        ├── art/cover-N.jpg
        └── sealed/cover-N.jpg
```

The covers are documentation art, not project assets — nothing plants
them into a generated project. Commands below are written to be run from
the repository root.

## What makes them a collection

Not a house style. A shelf of real 8-bit boxes is wildly inconsistent —
every publisher had its own illustrator, its own decade and its own
taste — and it still reads as one shelf, because the *platform* furniture
is identical on all of them. That is the model here, in three tiers:

| Tier | What | Varies? |
| --- | --- | --- |
| **The seal** | `WORKBENCH SEAL OF QUALITY` | Never. Shared by every workbench there could be |
| **Band, colour, format** | `DOCKERIZED ELIXIR WORKBENCH`, Elixir violet, a 5:7 portrait face | Never within a workbench; band and colour change if there is ever a Python or a JS one, the format not even then |
| **Everything else** | Era, art, layout, finish, wear, stickers | Freely, cover to cover — the era is drawn from a repertoire |

So the covers are meant to be **collected, not manufactured**: generated
one at a time, each in whatever era and register suit its feature, and
none of them obliged to match the last. The band and the colour say which
workbench; the seal says it is one of ours; the format is what lets a
shelf of them line up.

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

`stamp.sh` puts the seal on:

```sh
./assets/covers/stamp.sh clustering --corner br
./assets/covers/stamp.sh coveralls --face back --corner bl --size 0.12
```

It reads `<feature>/art/<face>.jpg` — the raw generated artwork — and
writes the finished cover to `<feature>/sealed/<face>.jpg`; the face is
`cover` unless told otherwise. The two directories are what keep an
unstamped cover from being mistaken for a finished one, and they mean
regenerating is always the same two steps: replace the art, stamp again.

Size and inset are **fractions of each cover's width**, not pixels,
because covers come out at different resolutions — the first six were
765px wide and 687px wide. A fixed pixel size would make the seal look
bigger on the narrow ones. Defaults: `0.24` of the width, inset `0.04`.

Corners are a per-cover choice, but two are constrained: the top ones
collide with the band and need `--margin 0.11` or so to clear it, and the
bottom left is usually where the badge sits. Bottom right is the default
for a reason.

### Archiving

A cover that gets superseded moves to `<feature>/_archived/art/cover-N.jpg`,
where the number is assigned **at archive time as one more than the
highest already there for that feature**. So 1 is the first ever made, n
is the one most recently retired, and nothing is ever renumbered. This
guide writes those as `coveralls-3` for short.

`_archived/` is **local and gitignored**, like `_workspaces/`: retired
art is what a new prompt gets compared against on the machine where the
prompt is being written, and nothing else ever reads it. Git never
forgets a binary, and a shelf of eighteen cartridges at four takes each
would be a repository nobody wants to clone. The cost is that the
evidence this guide cites by number cannot be opened from a fresh clone
— which is why every table row carries what the image showed, in words,
and the image is only ever the footnote.

What goes in is the **artwork**, not the sealed cover. Stamping is one
command, so the art is the half worth keeping: it is what a new prompt
gets compared against, and what you would re-stamp if a regeneration
turns out worse than what it replaced.

The six `-1` files are the exception that proves it. They were made
before the seal existed, with a generated one baked into the artwork, so
there is no separable art to archive — the sealed cover is all there is,
and it goes in `_archived/sealed/` instead. That is also why `sealed/`
holds only what was made the current way: the directory is a standard,
not an inventory.

## Tier 2 — band, house colour and format

All three go into every prompt verbatim. The band renders reliably — it
came out identical on all six of the first covers — so unlike the seal,
it is generated with the rest.

```text
Top band across the full width, dark with a thin chrome rule, reading
"DOCKERIZED ELIXIR WORKBENCH" in condensed sans-serif caps.
```

```text
Elixir violet (#4B275F) as the dominant colour of the composition.
```

```text
Flat front face reproduced straight on, filling the frame edge to edge:
not a photograph of a physical box, no perspective, no drop shadow, no
surrounding background, no visible spine or side panels. Proportions 5:7
portrait.
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
[cover record](#cover-record).

### The format

That third block used to be the second half of the house style. It moved
here because the shape of the face is platform furniture in exactly the
way the band is: it says which workbench, not which cartridge.

It is an invariant rather than a default for a downstream reason. The
covers are headed for a catalogue in a GUI, and a catalogue lays cards
out in a grid: with one aspect ratio that is arithmetic, with six it is
letterboxing, ragged rows or a crop — and a crop eats precisely the top
band and the seal corner, the two things that identify the collection.
One ratio is what keeps six eras a shelf instead of a pile.

State it **inside the prompt**, not only as a generator setting: two of
the first six drifted narrower when it was only a setting.

Two consequences, written down before someone tries to fix them:

* At 5:7 a mid-90s big box **is not** a mid-90s big box. Each era is a
  *quotation* of its graphic language on our face, not a facsimile of its
  packaging. A shelf of reissues looks exactly like that — every spine
  the same height — and that is the trade, made on purpose.
* The flat front face is part of this block, so the photographed 3D box
  breaks it. That departure stays available as a deliberate collector's
  edition one-off: the *image* is still 5:7, which is all the catalogue
  grid cares about.

## Tier 3 — the era repertoire

The house style is a repertoire of six. **Roll for it**, then keep the
roll unless it fights the feature, in which case roll once more. One
veto, and the result goes in the [cover record](#cover-record) so a
regenerated cover keeps its era.

The die is the point. Choosing each era on taste converges on whatever is
in favour that month; rolling is what produces a shelf that looks
accumulated over twenty years, which is the whole conceit.

Each block below replaces the *first* paragraph of what used to be the
house style. The second paragraph — flat face, 5:7 — is Tier 2 now and
does not move.

Two rules bind every entry.

**Describe technique and material, never a publisher.** The hardest-won
lesson in this document is that describing 80s console packaging summons
"Nintendo" into the artwork, and that a negative instruction does not
hold it back. Every era has its own magnets, and naming one invites its
logo, its typefaces and its trade dress along with it. If an era cannot
be described without naming who printed it, the description is not
finished.

**Never mention the format of that era's own box.** Not "big box", not
"cassette folio", not "landscape sleeve". Say it and the generator draws
that box *inside* our portrait face, and the result is a photograph of a
box instead of a cover.

### 1 · Early carton, ~1978-82

```text
Late-1970s computer game packaging art. Two-colour offset printing on
uncoated board, ink very slightly out of register: a line illustration or
a technical schematic rather than a painted scene, flat fields of one
spot colour, plain grotesque type set by hand, visible paper tooth and
yellowed edges.
```

### 2 · Home computer, ~1982-85

```text
Early-1980s home computer game cover art. Coarse airbrush over a short,
hard-edged palette that reads as a limited display: heavy black outlines,
a receding grid floor, wide empty fields of flat colour, geometric slab
lettering, matte board with rubbed corners.
```

### 3 · Editorial cover, mid-1980s

```text
Mid-1980s literary game cover art. Restrained editorial design rather
than illustration: an even ground of a single colour, one carefully lit
object centred with generous space around it, serif type set small, a
subtle deboss, clean printing on coated stock.
```

### 4 · Console, late 1980s

```text
Late-1980s console game box cover art. Painted airbrush illustration with
the slightly stiff, heroic look of North American 8-bit era packaging:
hard airbrush gradients, chunky specular highlights, visible matte
cardboard grain and faint edge wear.
```

### 5 · CD-ROM, early 1990s

```text
Early-1990s CD-ROM game cover art. Chrome and lens flare over an
airbrushed starfield: extruded metallic lettering with deep bevels,
rainbow specular edges, a perspective grid, saturated gradients pushed
just past taste, a glossy laminated finish.
```

### 6 · Big box PC, ~1992-96

```text
Mid-1990s PC game cover art. Dense oil-painted illustration in the
fully-rendered style of the 256-colour era: deep chiaroscuro, heavy
detail carried down into the shadows, dramatic single-source lighting,
extruded fantasy lettering with a hard bevel, a glossy laminated finish.
```

### Layout is free, and independent of the era

Half of the first six put the art in an inset panel with a cardboard
margin and half bled it to the edges; both look right, and the inset
version leaves the lettering more room. Neither belongs to an era — pick
per cover, or leave it to the generator.

### Material furniture

Optional, and the thing that makes a collection look collected rather
than printed in one run: a crooked price and a knocked corner are what
turn an image into an object somebody owned.

Keyed to the era, because the table is a **guard** and not a menu. A
barcode on a 1979 carton, or an age rating on a 1988 box when rated game
packaging is a 1994-and-after thing, gives the forgery away faster than
any drawing error could. The right-hand column is the half that earns its
keep.

Two rules:

* **One commercial mark and one wear mark, at most.** The old advice here
  was "sprinkle, do not stack", which a per-era menu makes much easier to
  ignore. A count is harder to ignore: one of price / barcode / rating /
  requirements flash, and one of scuff / ring stain / fade / crushed
  corner.
* **Furniture is texture, never fact.** All of it is small print, and the
  measured failure of this generator is that text below foreground size
  flips digits — the two small address plates on `clustering`. Ask for "a
  barcode block", never for its digits; for a ratings flash by its shape,
  never by its wording. The price sticker is the exception: it sits at
  legible size and can carry a real number.

| Era | Its own furniture | Anachronism to veto |
| --- | --- | --- |
| Early carton | Price in grease pencil, a lot number hand-stamped in ink, a tape or staple seal, yellowing and a crushed corner | Any barcode, any age rating, shrink-wrap sheen |
| Home computer | A die-cut hang tab, a compatibility strip along one edge, a format mark (tape / disk), a hand-written computer-shop price | Modern barcode, holograms, disc flashes |
| Editorial cover | A bookshop price sticker, a review-quote flash, a remainder mark on one edge, rubbed board edges | Large barcode, starbursts, any technical flash |
| Console | A half-peeled `$49.95` sticker, a rental label with a hand-written number, a `2ND PRINT` band, a small UPC block on the bottom edge | Age rating, security hologram |
| CD-ROM | A security hologram, shrink-wrap sheen, an award flash, anti-theft strip residue, a UPC | Uncoated board wear, hand-written price |
| Big box PC | A requirements flash in the idiom of `256 COLORS` (as a shape), a disk-format mark, a store UPC, a ring stain in a corner | Console rental label, hang tab |

None of this is an invariant. A cover with a rental sticker and one
without belong to the same shelf precisely because the seal, the band and
the format do not move.

## The slots

Seven things change per cartridge. Keep them short — every extra clause
is one more thing the generator can get wrong.

| Slot | Rule |
| --- | --- |
| **Era** | Rolled from the repertoire, kept unless it fights the feature. One veto, then recorded. |
| **Register** | The stance the hero and the subtitle take. Chosen, never rolled. Has no text of its own. |
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
connections. Coveralls is a beam sweeping a plain of code panels toward
a red target line, because what the report does is show precisely how
far the tests reach and how far they have to.

Five habits, in order of how much they buy you:

* **Count things.** Four replicas, six links, three watchers, six
  lecterns. The most reliable instruction in the whole document: every
  count of a *whole* asked for came back correct. Counts give the
  generator something to compose around, and they make the picture true.
  The reliable count is of *separate bodies*: four droids, six beams.
  Counting marked members inside a field is not — "ten segments with
  eight lit" came back seven lit, and "exactly three panels that stay
  dark" came back as two. Use those counts to compose, and never for a
  number the cover has to get right; if the number is a fact, give it a
  body of its own.
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

### When the era has no scene

Those five habits assume an illustrated era. Two entries in the
repertoire are graphic rather than illustrative — the early carton and
the editorial cover — and on those there is no figure whose scale to fix
and no formation of droids to count. The hero becomes **a symbol or a
schematic**, and the counts move into the geometry: six nodes on a
diagram, four banners on a chart, three hooks in a line drawing. The
truth still comes from the count; it just stops being a cast.

## The template

Everything except the seal, which is composited afterwards.

```text
[ERA — one block from the repertoire, verbatim]

[FORMAT — verbatim]

[BAND — verbatim]

Hero illustration: <HERO>.

Title lockup in the lower third: "<TITLE>" set large in <THE ERA'S
LETTERING>, and beneath it a smaller subtitle "<SUBTITLE>".

Bottom left: a small rectangular badge reading "<UNIT BADGE>".

[optional: one commercial mark and one wear mark from the era's furniture]

The <SEAL CORNER> of the artwork is composed as a quiet area: low detail,
no focal element, an even field of tone.

Palette: [HOUSE COLOUR — verbatim], CRT phosphor haze in the background.
No photographic elements. No real brand marks or logos.
Accent: <ACCENT>.
```

**The lockup follows the era.** A beveled chrome-and-violet wordmark with
a hard drop shadow is the console entry's lettering, and still the right
answer there — but it cannot land on a two-colour carton from 1979. Each
era block names its own type; the title takes it from there. This is the
one place where the template would otherwise smuggle a house style back
in through the door the repertoire opened.

The last line is the seal's corner, and it is art direction rather than a
reservation: **ask for calm, not for emptiness**. A generator told to
leave a corner clear leaves a hole in the picture. Told that the corner
is an even field of tone with no focal element, it composes around it and
the seal drops in as if it had always been there.

If the lettering comes out wrong on a take that is otherwise good,
compositing it is always available — it just is not the default any more,
because band, title, subtitle and badge all render well enough.

The prompt that made the current art is kept beside it, verbatim, as
`<feature>/cover.prompt.txt` (and `back.prompt.txt` for the plate). The
cover record says what was decided; the prompt file is what was actually
sent, and the first thing to diff when a regeneration comes back
different.

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
> **Era** console, late 80s · **Register** heroic ·
> **Title** CLUSTERING · **Subtitle** CONNECT THE NODES ·
> **Accent** electric magenta · **Badge** 1-4 NODES

The counts come from the real thing: four is the `--replicas` default and
six is how many links four nodes need.

The address plates are the size rule in practice. The first version let
the generator place them freely, and the two it put small and far back
came back with a wrong digit while the two large ones were right. Hence
*the same size, all in the foreground*: the plates stay, they just stop
being background texture.

## The back of the box

Only once the front is validated. The back is the other face of the
same box, so it takes **era, accent and register from the front's row in
the [cover record](#cover-record)** and rolls nothing: a box whose two
faces come from different decades is two boxes.

The front draws the mechanism. The back shows the **evidence**: what a
real back has always carried is a blurb, two or three screenshots, a
list of features, the badge again, a requirements flash, a legal strip
with the seal set small in it. Nearly all of that is text below
foreground size, which is the one thing this generator measurably cannot
do. So the rule that follows is the opposite of the front's:

**The back is composed, not generated.** The generator makes only the
*plate* — the era's material with blank panels and fields on it. Every
fact is typeset and composited afterwards, at any size, because typeset
text does not flip digits.

| Made by | What |
| --- | --- |
| The generator | The plate: band, era material and finish, empty frames for the screenshots, an even field for the copy, a darker strip for the legal line |
| Composition | The copy, the screenshots, the badge, the requirements flash, the legal line, the seal |

One back has been made this way — coveralls — and the rules below are
what it left. Where a guess survived contact it says so; where it did
not, it is gone.

### The plate

The template is the front's with the hero swapped for a layout. Era,
format and band go in verbatim, so the plate is unmistakably the same
box; the era block already carries the material, and the layout is
described in era-neutral words so it does not fight it.

```text
[ERA — verbatim, the same block as the front]

[FORMAT — verbatim]

[BAND — verbatim]

Back face layout, with no printed text anywhere except the band. In the
upper half, <N> empty rectangular inset frames of equal size arranged in
a row, each with a thin bevelled edge. Below them, an even unprinted
field of tone taking the middle third of the face. Along the bottom
edge, a narrow darker unprinted strip across the full width. Every
frame, field and strip is blank: no lettering, no placeholder text, no
glyphs, no pictures inside the frames.

Palette: [HOUSE COLOUR — verbatim], CRT phosphor haze in the background.
No photographic elements. No real brand marks or logos.
Accent: <the front's accent>.
```

Two or three frames, never more: it is a count of separate bodies, which
is the kind the generator gets right — three asked, three delivered. The
plate's furniture follows the era table exactly as the front's does — a
barcode block is asked for as texture, and only where the era allows
one; the coveralls plate brought one, blank, exactly where asked.

What the first plate did and did not bring, so the next prompt knows
what it is negotiating:

* **It came back clean.** No pseudo-text, no glyphs, nothing inside the
  frames. The guess that blank panels would fill themselves with
  lettering was wrong, and is deleted.
* **The frames came back 5:7**, the box's own format, not the 16:10 of a
  screen. The generator repeats the shape it was given. Do not fight it
  in the prompt: retake the screenshots at the frames' ratio instead
  (below).
* **The even field is a coin toss.** On the CD-ROM plate the middle
  third became the era's perspective grid — the era block winning over
  the layout clause; on the console plate it came back as asked, an
  airbrushed flat. The copy needs a ground either way, so `back.sh` can
  draw one itself — a translucent panel behind the blurb, features and
  flash, the copy box every real back has anyway — and skips it when
  `layout.env` sets `PANEL=""` because the plate brought its own.

### The copy

Written by hand, in the front's register, and mostly already written:
the cartridge's own README is the source. Its *Description* is the
blurb, *What it installs* is the feature list, *Options* is the
requirements flash. Keep it to what fits a back in one glance:

| Piece | Length | Source |
| --- | --- | --- |
| Headline | Up to six words, in the front's register, and **one line at the house size** — five words ran to two on exdebug, and the fix was a shorter headline, not a smaller face | New — a second tagline, not the subtitle again |
| Blurb | 40-70 words | The cartridge README's *Description*, cut to its first paragraph |
| Features | Three or four bullets, up to eight words each | *What it installs* |
| Requirements flash | One line in the idiom of a system-requirements box | *Options*, and the workbench itself: `REQUIRES: DOCKER, ONE WORKBENCH` |
| Badge | The front's, verbatim | Cover record |
| Legal strip | Repository, licence, "actual screens shown" | Small, and true |

It lives in `<feature>/back/copy.md`, one heading per piece, so a back
can be re-set without rewriting it.

### The screenshots

**Real ones**, of what the cartridge actually installs, which is the
truth principle applied to the back: coveralls shows its HTML report,
the `TESTING.md` page in the docs and the `mix cover` run in a terminal.
"Actual screens shown" is the period phrase for it, and here it is not
a lie.

Take them from a generated project **at the ratio of the frames that
came back**, not at a desktop width. The coveralls plate's frames are
5:7, and a 1280×800 window squeezed into one is unreadable; the same
pages at a 420×595 viewport are their own mobile layout — the report's
big number, the result board's table — and read at frame size. The
pages are responsive, so a narrow viewport is still an actual screen.
The terminal is rendered from the real `mix cover` output (ANSI through
`aha`, in a fake window) at whatever size the frame wants.

Then the period treatment before they go in — a slight softening and a
faint scanline overlay is enough to make a 2026 browser window read as
a printed screen — but stop before they lose legibility: a screenshot
that cannot be read is decoration, and the front has enough of that.

### Assembly

ImageMagick, in **fractions of the plate's width** like `stamp.sh`, so
a back set at 728px and one at 1024px come out identical. Fonts are the
system's, and the choice is what keeps the back in the era without
asking the generator for type:

* Headline and features: a condensed grotesque, `Liberation Sans
  Narrow` or `Nimbus Sans Narrow`, uppercase.
* Blurb: `Inter`, sentence case, generous leading.
* Terminal screenshots and the legal strip: `Liberation Mono`.

The seal goes on last, through `stamp.sh`, **small** — `--size 0.12`
or so — in the legal strip, bottom left, where a back has always carried
it. It is the
one element that appears on both faces, which is the point: either side
up on the shelf, the box says it is one of ours.

`back.sh` does all of this:

```sh
./assets/covers/back.sh coveralls
```

It reads `<feature>/art/back.jpg`, and from `<feature>/back/` the copy,
the shots and `layout.env` — the frame rectangles and text positions
**measured off that plate**, as fractions of its width, since no two
plates put the frames in the same place — composes, and hands the result
to `stamp.sh`, which writes `<feature>/sealed/back.jpg`. It was written
after the coveralls back was composed by hand, from that composition,
and reproduces it pixel for pixel: the same order `stamp.sh` came in.
Making a back is therefore: generate the plate, measure it into
`layout.env`, write `copy.md`, take the shots, run `back.sh`. The
accent goes in `layout.env` too (`ACCENT=`), since it is the front's and
not the tool's.

### Measured on the first back

| Guess | What happened | Rule it left |
| --- | --- | --- |
| Blank panels would fill with pseudo-text | They did not, on the first try | Deleted. Ask for "no lettering, no placeholder text" and expect to get it |
| The frames would not be where the prompt put them | They were roughly there, but in the box's 5:7, not a screen's shape | Measure the plate into `layout.env`; take the shots at the frames' ratio |
| — | The even field came on one plate of two: the era's grid took its place on the CD-ROM one, the console one brought it | The copy panel is composed when the plate has none, `PANEL=""` when it has |
| — | A five-word headline ran to two lines and into the blurb | The headline must fit one line at the house size; shorten the copy, keep the face |
| The treatment would be overdone | It was fine at scanlines 15% and blur 0.3 | Those are the defaults |

## Cover record

The accent column is a mirror, not a gate: the point is to notice when
six covers in a row have drifted to the same colour, not to stop the
seventh from reusing one. The corner column is what `stamp.sh` was
passed, so a cover can be restamped identically. The era column is
retrospective for all but coveralls: the other five predate the
repertoire, so all of them are its fourth entry. The register column is
empty for the same five — it was never written down at the time, and
reading it back off a finished cover is a guess, so it gets filled in as
each one is regenerated rather than reconstructed now.

| Cartridge | Era | Register | Accent | Seal corner |
| --- | --- | --- | --- | --- |
| clustering | console, late 80s | — | electric magenta | — |
| coveralls | CD-ROM, early 90s (rolled) | ominous | acid lime green | tr, `--size 0.20 --margin 0.11` |
| healthcheck | console, late 80s | — | vital signal green | — |
| exdebug | console, late 80s | deadpan | electric cyan | br, `--size 0.20 --margin 0.03` |
| exdoc | console, late 80s | — | *unassigned* — parchment ivory failed the contrast rule | — |
| enhancements | console, late 80s | — | hot forge orange | — |

exdebug is the first cover made the current way, and the second with a
back: a console-era plate that brought its own field, two real
`ExDebug.console/2` runs at `width: 56` (the 80-column default does not
fit a 5:7 frame) and the library's HexDocs page, in cyan. The ones still
blank
in the corner column are in `_archived/sealed/` as `-1`: each carries a
*generated* seal baked into the artwork, including the one that says
"Nintendo". They want regenerating, and healthcheck wants it first.

coveralls is the first cover started over from the repertoire. Both of
its gauge-and-droid versions are in `_archived/` (`-1` with a generated
seal, under `sealed/`; `-2` made the current way, under `art/`), and nothing from them carries over: the
die was rolled — it came up CD-ROM and was kept — the register was chosen,
and the hero is a new one. The first attempt at it is `-3`: a beam of ten
segments with eight lit, which is 80% as a count and a battery indicator
as a picture. A hero that is also a UI icon reads as the icon, and so
does anything that "fills up" — so the hero is now the report itself as
terrain: a lens sweeping a plain of code panels, lit behind the beam, dark
ahead of it, and a red target line labelled at foreground size. The dark
panels asked for on the lit side never held: "exactly three" came back as
two on `-4`, "a few" came back as none on the cover, and both were kept,
because unlike 80% that number was never a fact. The sweep is written as
a position, not a motion. Green stays because
covered lines are green, shifted to acid lime so it does not sit next to
healthcheck's vital-signal green as a twin: shift the hue, not the
meaning.

The sweep's first take is `-4`, retired for three things the prompt let
happen: the light curtain fell from the right edge of the lens rather
than from its centre, because lens and curtain were placed independently;
the red target line explained nothing, because nothing in the art named
it; and the lockup filled the bottom right corner that the prompt had
asked to keep quiet, while the top right fallback overlapped the edge of
the lens. That last one was first answered by shrinking the seal to
`0.16` in the gap between the title and the badge — the wrong trade. The
rim's edge is not a focal element, and a seal the same size as its
neighbours matters more than a corner with nothing under it: shrink the
seal last, not first. The regeneration ties the curtain to the lens's
centre, hangs a foreground plate on the red line, and asks for the top
right quiet from the start — all three came back as asked, and the seal
sits in the starfield over the red line at the standard `0.20`.

Its back is the first one made. The plate came back clean with three
5:7 frames and the barcode; the three screens are real — the coverage
report at 81.7% against the 80% gate, the *Test Suite Report* page with
39 passing tests, and the `mix cover` run — taken from a generated
project at a 5:7 viewport. `coveralls/back/` holds the copy, the shots
and the measured layout; `back.sh coveralls` rebuilds it.

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
| The title lockup ran into the corner the prompt had asked to keep quiet | `coveralls` (regenerated) | Choose the seal corner after seeing the art; top right with `--margin 0.11` is the fallback |
| Ten segments came back as ten, but "the eight on the left lit" came back as seven lit | `coveralls-3` | Counts of marked members inside a field are not reliable; count separate bodies |
| "Exactly three panels that stay dark" in a lit field came back as two, and "a few" came back as none | `coveralls-4`, `coveralls` | Same rule, twice more: use such counts to compose, never as a fact |
| The lockup filled the bottom right corner again; the top right fallback overlapped the hero's edge | `coveralls-4` | An edge is not a focal element: keep the size, take the corner. Under a full-width lockup, ask for a *top* corner quiet from the start |
| Lens and light beam placed by separate clauses came back misaligned — the beam left the lens off-centre | `coveralls-4` | Tie linked objects to one axis in one sentence |
| A bare threshold line read as decoration | `coveralls-4` | A mark that carries a fact needs a label at foreground size |

What it gets right, consistently: the band, the title and subtitle
lockup, the badge, every count it was given, and any string given
foreground size.

Layout drift — inset panel or bleed, flat face or photographed box — is
no longer on this list. That is the collection working as intended.

### Anticipated, not measured

The repertoire is new, so none of this has a cover behind it yet. It is
kept apart from the table above on purpose: that one is evidence, this
one is a guess, and a guess that turns out wrong gets deleted rather than
defended.

* Naming an era's own box format will draw that box inside our face.
* A wider repertoire is a wider trademark surface — more eras, more
  houses whose trade dress the generator has memorised.
* Furniture asked for as a fact rather than as texture will come back
  with wrong digits, exactly as the small address plates did.

## The register

The register is a **stance, not a finish**: what the mechanism is doing to
whoever is looking, and what the subtitle promises them. It lives in two
slots and no others — the hero and the subtitle — and it is the only thing
in this document with no block of its own to paste.

That is also why it must never carry a technique, which is the whole rule
here: **a register that can only be described in the vocabulary of one era
is not a register.** Airbrushed skies, obsidian and fog, thick linework and
flat saturated colour are all ways of printing, and they belong to the era
blocks. This section used to name three variants in exactly those terms,
two of them by region — the moment the die stopped always coming up
console, all three stopped meaning anything.

So the list is **open**. A register is any stance that can be stated in one
line without naming a medium; the era renders it:

* **Heroic** — the mechanism triumphs, and the viewer is invited to join
  it. Subtitles boast or command (`CONNECT THE NODES`).
* **Ominous** — the mechanism is superior to the viewer, and withholds.
  Subtitles threaten (`THEY SPEAK AS ONE`).
* **Comic** — the mechanism is friendly, and a little silly about it.
  Subtitles endear (`NOBODY DEPLOYS ALONE`).
* **Deadpan** — the mechanism is documented apparatus and needs no
  selling. Subtitles state (`ALIVE FROM THE CODE`).

Four landmarks, not four options. Add one when a cartridge wants a stance
none of these name, and describe it the same way: one line, no medium.

Era and register are independent axes, and their cross is where the shelf
gets its range. Ominous on the editorial cover is one lit object on an
empty ground; ominous on the CD-ROM entry is chrome and a lens flare over
the same threat. Same stance, two objects, and only the era moved.

The era is rolled, the register is chosen. Both go in the
[cover record](#cover-record), so a regenerated cover keeps them.
