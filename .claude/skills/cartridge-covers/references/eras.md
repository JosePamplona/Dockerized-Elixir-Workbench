# The era repertoire

Read this when choosing what an era can do with a cartridge: the six
briefs, the six proposals that pick between them, the furniture each era
may carry, and the stance the pictures take.

## Tier 3 — the era repertoire

The house style is a repertoire of six, and each entry is a **brief, not
a costume**. An era is not a finish laid over a hero that was written
first: give the same cartridge to six eras and six different pictures
come back, because each one can only compose with what it has. The
editorial entry cannot paint a heroic figure and the console entry
cannot hold an empty ground, so asking each of them what it would do
with this cartridge is six ideas, not one idea six ways.

That is what [the six proposals](#the-six-proposals) are for, and it is
how the era gets picked: six briefs, one per era, read side by side, one
of them recommended, and the user choosing. The choice goes in the
[cover record](../../../assets/covers/README.md#cover-record) so a
regenerated cover keeps its era.

This replaces a die. The repertoire used to be rolled, on the argument
that choosing on taste converges on whatever is in favour that month —
a fair worry, but the die was a substitute for looking, made when there
was no way to see the alternatives. Now there is, in text. What the die
was protecting has not been thrown out with it: it moved to the era
column of the [cover record](../../../assets/covers/README.md#cover-record), which is watched instead
of enforced, and [the recommendation](#the-recommendation) is written
against that column.

Each block below replaces the *first* paragraph of what used to be the
house style. The second paragraph — the flat image, the window's proportion
for the front's hero and 5:7 for the back — is Tier 2 now and does not move.

Each block describes **technique and stock, never wear**: offset ink
out of register, airbrush, halftone, coated or uncoated board, a
laminate — what the printer did. Rubbed corners, yellowed and worn edges
were in three of the blocks and came out, with the furniture below, when
the overlay moved onto the finished cover: wear is what happens to the
object after printing, and a scuff generated in the art stops dead at
the overlay's edge. Both belong to the wear pass described there.

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
no wear.
```

### 2 · Home computer, ~1982-85

```text
Early-1980s home computer game cover art. Coarse airbrush over a short,
hard-edged palette that reads as a limited display: heavy black outlines,
a receding grid floor, wide empty fields of flat colour, geometric slab
lettering, matte board.
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
cardboard grain.
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

### Layout bleeds

Half of the first six put the art in an inset panel with a cardboard
margin and half bled it to the edges, and both looked right while the
art was the whole cover. Now the overlay supplies the margin, over
a bleed the generator extends from the hero: the hero fills its own
image to the four edges, and an inset panel would be a margin inside a
margin.

### Material furniture — commercial in the hero, wear deferred

It is the thing that makes a collection look collected rather than
printed in one run — a crooked price and a knocked corner are what turn
an image into an object somebody owned. It splits in two. The
*commercial* marks — the left column below — are printed on the cover,
and since the hero is the window they can be asked for in the hero,
where they come out whole; while the art was the whole face they were
kept out, because one generated across the overlay's edge would have
stopped dead at it. *Wear* — scuffs, ring stains, crushed corners —
happens to the finished box, board and all, and waits for a second
pass over `sealed/cover.jpg` that does not exist yet. This table serves
both.

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

## The six proposals

Six proposals for one cartridge, one per era, written down. It is the
step where the era gets decided, and the reason it can be decided rather
than rolled: the six are not the same picture in six finishes, they are
six compositions, each written from what its era can actually do.

Writing six heroes instead of one is the cost, and it falls on whoever
writes the prompts, not on whoever generates. It is also the point —
the second hero is usually better than the first, and the fourth is
sometimes a cartridge nobody had thought of.

**They are read, not drawn.** The first version of this step was a sheet
of six sketches from one prompt, so the eras could be seen side by side.
It came back as one finish with six motifs, which is what the README had
guessed a prompt asking for six materials would do — six blocks in one
prompt is six times the surface for the generator to average — and it
is measured there now, on clustering. The fallback, six separate
renders, would cost more generations than most covers take in total.
The briefs do the same job as text, at no generations: six heroes
compare fine without a picture, and every count and string in them is
still exact, which a sketch a third of the width of a face never was.

### The file

`<feature>/eras.md`, in three parts:

1. **The register**, one line, chosen first — all six proposals take it.
2. **The six heroes**, numbered 1 to 6 in the repertoire's order, each
   under its era's name. Each is the hero paragraph as it would go into
   the cover prompt: bodies, counts, positions, scale in the frame,
   every string at foreground size. The bodies and the counts come from
   the cartridge's README; what the scene is *about* — the thesis, the
   thing that goes wrong without it — from its `DESIGN.md`, which is
   also where the register's voice is heard before the prompt invents
   one. Not the era block — that goes into
   the cover prompt verbatim and in full once its era has won, and is
   the one part of a proposal that is never rewritten.
3. **The recommendation**, then **the choice** — one number each.

That is what "let's go with number 4" refers to. The five that lost
stay in the file: a regeneration that wants another era starts from
them, not from nothing.

### The recommendation

The user decides; the recommendation is there to be argued with, and it
is written under two rules that guard against the same thing.

The die was rolled because choosing on taste converges on whatever is
in favour that month. A recommendation is a choice on taste, and
whoever writes it has one — four of the first six covers are the console
entry. So:

* **The reason comes from the cartridge, never from the style.** "The
  editorial entry, because this cartridge is one route answering one
  question, and that era draws one object" is a reason. "The console
  entry, because it reads best" is a preference, and gets sent back.
* **Quote the shelf.** The era column of the cover record goes beside
  the recommendation, as it stands. It does not ration — a rule that
  forces the wrong cover onto a cartridge to even out a shelf costs more
  than the unevenness — but a recommendation made without looking at it
  is exactly the drift the die was against, and three cartridges running
  that pick the same era is the signal that turns this into a rule.

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
* **Laconic** — the mechanism answers the one question it is asked, in
  as few words as it can, and nothing more. Subtitles answer
  (`ARE YOU ALIVE? — YES.`).
* **Hospitable** — the mechanism receives whoever arrives and has
  already laid everything out for them. Subtitles invite
  (`ONE URL AWAY`). Added for exdoc.

Five landmarks, not five options. Add one when a cartridge wants a stance
none of these name, and describe it the same way: one line, no medium.

Era and register are independent axes, and their cross is where the shelf
gets its range. Ominous on the editorial cover is one lit object on an
empty ground; ominous on the CD-ROM entry is chrome and a lens flare over
the same threat. Same stance, two objects, and only the era moved.

Both are chosen — the era from the six proposals, the register by hand
and before them, since all six take the same stance. Both go in the
[cover record](../../../assets/covers/README.md#cover-record), so a regenerated cover keeps them.
