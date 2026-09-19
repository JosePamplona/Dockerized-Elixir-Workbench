# The front

Read this when writing or reviewing a cover prompt, and when stamping.
The era's own block comes from `references/eras.md`; the evidence these
rules were drawn from is in `assets/covers/README.md`.

## Band, house colour and format

The format block itself is in `SKILL.md`; this is why it does not
move.

The band is on the overlay, not in the art, and it never names the
feature: the console is the workbench, the cartridges are its features.
And the violet is this workbench's mark — a Python or a JS workbench
would swap the overlay and the colour together, and keep the same seal.

The violet lives on the overlay: the printed board around the window is
#4B275F on every cover, close to half the face, so the house colour is
guaranteed before the art is generated. The window is a socket, and
what sits in it reads as a thing set into the board only when its
ground is clearly lighter or darker than the board — seen on the first
three covers stamped under it, where a violet ground ran into the
violet board and the one black-and-green ground was the one that read
as set in. So the format block's last sentence asks for a ground that
contrasts in value with the violet; the back has no overlay, and its
form asks for the violet dominant. That is all that is said about
colour. The era chooses the rest — the ground's tone, the one colour
beside it — and the choice is read off the art afterwards, never
decided before it; an accent slot used to be filled here and was
dropped on 2026-08-28, since every colour it chose the era would have
chosen alone. A cover whose ground *is* the violet is the departure to
make on purpose, one cover at a time, and it needs a reason the board
cannot give it.

### Why the format is an invariant

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

## The slots

Eight things change per cartridge. Keep them short — every extra clause
is one more thing the generator can get wrong.

| Slot | Rule |
| --- | --- |
| **Era** | Chosen from the six written proposals in `eras.md`, one of them recommended, then recorded. |
| **Register** | The stance the hero and the subtitle take. Chosen before the proposals, since all six share it. Has no text of its own. |
| **Title** | The cartridge name, uppercase. Nothing else. |
| **Subtitle** | Two to four words, imperative or boastful. It is a tagline, not a description — the design's thesis, from `DESIGN.md`, in the register's voice. |
| **Hero** | One concrete scene depicting the *mechanism*, not the abstraction. See below. |
| **Unit badge** | The "1-2 PLAYERS" slot, in the feature's own units — a fact `DESIGN.md` states, like the platforms it was designed for. One line, one short phrase, asked for in the hero as a small flash in a top corner, in the era's lettering. `covers.py stamp --badge` typesets one instead when the generated one is wrong; it was the only way while the corner the generator puts it in was under the overlay. |
| **Furniture** | One commercial mark from the era's column in `eras.md` — a price sticker, a rental label — printed on the cover inside the hero, with its position; or none. Wear is not asked for. |
| **Seal corner** | Which corner of the window the seal straddles; the composition keeps a quarter-disc there calm. Chosen from the art. |

Two things are never slots. The **version** and the **date**: they
belong to the back, typeset from the cartridge's `CHANGELOG.md`, and
a version drawn into the hero is wrong at the next release — the
healthcheck2 hero carries a `VERSION 0.1.0` the generator drew on its
own, and it is asked out at the next continuation.

The back adds one of its own, the **device**: the mark ghosted into its
middle third, keyed to the era and named with its contents. See
[The device](back.md#the-device).

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

[FORMAT — the hero's form, verbatim, at the proportion `covers.py window` names]

Hero illustration: <HERO>.

Title lockup across the lower part of the image: "<TITLE>" set large
in <THE ERA'S LETTERING>, and beneath it a smaller subtitle
"<SUBTITLE>".

In the <TOP CORNER> of the image, a small rectangular flash in the
era's lettering reading "<UNIT BADGE>" at foreground size.

<FURNITURE, if any: one commercial mark from the era's column, its
position and its wording>.

<THE TERM(S), THE TITLE, THE SUBTITLE, THE FLASH AND THE STICKER> are
all the lettering in the image.

The <SEAL CORNER> of the artwork is composed as a quiet area: low detail,
no focal element, an even field of tone.

Every mark on the face is printed illustration or type, and the marks
named above are all of them.

--- second turn, with the padded canvas from covers.py pad ---

The flat grey border around this picture is blank. Paint it by
continuing the picture outward into it on every side, to the edges —
<WHAT CONTINUES ON EACH SIDE, FROM THE HERO>. Keep the picture inside
exactly as it is, and add nothing new: no figure, no object, no
lettering.
```

The second turn is the bleed. The generator has no 5:7 and cannot hold
a margin, so the hero is generated at the proportion nearest the
window's that the generator offers — `covers.py window` reads the
window off the overlay and names it — where the era composes for the
whole image; then `covers.py pad` sets it whole in the window of a
5:7 canvas with flat grey margins — the space is made here, because
the generator keeps its output size and "extend to 3:4" kept exdebug's
hero at full height with 40px added a side; where the generator's
proportion falls short of the window's, a sliver of the window is grey
too — and the generator paints the grey, in the same chat, so the art
under the board is the same scene continued. `covers.py cut` then finds the
hero in what comes back — the generator reuses it pixel for pixel, at
whatever scale fits its output — and cuts the 5:7 face around it so
the hero lands in the window, wherever the overlay's design leaves it:
nothing but the overlay knows where. If the result is short on a side,
the generator cropped or moved the picture, and the turn is rerun.
When the hero's margins are flat colour — a field with nothing in it
above and below, as on clustering — the second turn is not sent at
all: the expansion is made by hand, the field's tone sampled off the
hero and the hero's edge pixels repeated into the side slivers, and
`covers.py cut` takes it from there. The generator repaints what it is
told to keep; a flat margin gives it nothing to repaint.

The marks line used to read `No photographic elements. No real brand
marks or logos.` — the line that was in the prompt the day the seal
said "Nintendo". It now says what the marks are and that the list is
complete, under the rule in `SKILL.md`: the prohibited thing has to
have nowhere to be, not a name.

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
compositing it is always available — it just is not the default,
because title and subtitle render well enough as *lettering*, and
their *position* stopped being a problem when the hero became the
window: the console genre sets its lockup on the bottom edge at four
fifths of the width whatever numbers it is given, which under the old
face-with-bleed model put the first and last letters under the sides
and the subtitle under the bottom (`exdebug-4`, `exdebug-5`), and in
the hero, which is the window, puts it exactly where it shows. The lockup is asked for
in the hero; the bottom corners are then its, so the badge takes a
top corner (`--badge-corner tr`) and the seal the other. The
composited lockup stays as the way through when a take's lettering
has to be replaced, in two takes: keep the take whose lettering came
out right, cut the lockup from it — crop, then key the ground out on
luminance, `-colorspace gray -level 12%,45%` as the alpha, and trim —
save it as `<feature>/art/lockup.png`, regenerate the art with the
lockup paragraph replaced by a description of the ground where it
was, and stamp with `--lockup art/lockup.png`, which composites it
centred on the window at `--lockup-fit W,B` — width, and the inset of
its bottom edge from the window's bottom, fractions of the window's
width. Record both in the cover record's options column.

The prompt lives beside the art, verbatim, as
`<feature>/cover.prompt.txt` (and `back.prompt.txt` for the plate), and
it is a **working file, not a record**: it always holds the prompt to
generate from *now*. Every revision is written there, in the repository,
before the next take is generated — never anywhere else. The two parties
that make a box do not share a screen, so this file is the whole
handoff; a revision that lands somewhere the other party does not read
is not a revision, it is a take spent regenerating the same prompt.
Hand it over as a path. A diff quoted in conversation is a preview of
what the file now says, never the thing to work from.

The record is `_archived/`: the retired prompt sits beside the take it
made, so the first thing to diff when a regeneration comes back
different is the current file against `cover-N.prompt.txt`. The cover
record says what was decided; the archived pair says what was actually
sent, and what it produced.

## Tier 1 — the seal

```text
Bottom right corner: a circular gold starburst seal with a scalloped
edge and an embossed bevel, reading "WORKBENCH SEAL OF QUALITY" in small
caps around its rim.
```

**Never ask the generator for this.** Render it once, keep it as a
transparent PNG, and composite it onto every cover. It and the overlay
are the only elements that are composited, and the rule is not an
optimisation:

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

## Tier 2 — the overlay

`overlay.png`, beside `covers.py`: the printed board in the house
violet, the band with the workbench's name drawn on it, and the
window, transparent, where the art shows. It is drawn by hand in
`overlay.xcf`, beside it, which is its source: a generated board was
the starting point, but the generator never gave the board as it
needed to be, so it was finished in the editor and has no prompt.
`covers.py stamp` scales it to the artwork and lays it on top, so the
finished cover is the artwork's own size and the band is the same
pixels on every one. This is how a printer's overlay meets art
delivered with bleed: the hero is the window, its expansion is the
bleed, `covers.py cut` cuts the face so the two line up, and the overlay
covers exactly the margins.

**The overlay is the one source of every number about the face**, and
its design is free: it has been a board with four opaque sides, and is
a banner now — the name band across the top, a strip along the
bottom, no sides, and the top of the face showing above the band. The
window is *the largest fully transparent rectangle* in the PNG, which
is what lets the transparency above the band be bleed the art shows
through and not part of the window. `covers.py` reads it and takes
everything from there — where the
window is, which sides have board, what the hero's proportion is —
so there is no second copy to keep in step: redrawing the overlay is
exporting it. `./assets/covers/covers.py window` prints what the
overlay leaves, and that is where the prompt's proportion and the
prose's numbers come from; a number written anywhere else is a copy
that will be wrong after the next export.

The alternative — setting the artwork whole *inside* the window and
adding the overlay around it — was tried first on clustering and taken
out the same day: the era's own space around the hero and the overlay's
margin then add up, and the hero shrinks to a third of the cover. It
came up again on exdebug, after three takes in which the generator
either squeezed the hero into the middle of the face or ran it under
the board, as `--fit window`: art generated at the window's own
proportion with no bleed, set into the socket by the script. It was taken out
before a take was made, for a reason that holds whatever the generator
does: the overlay's transparency is not promised to be a clean
rectangle, so there has to be congruent art across the whole face,
under the board too. The overlay is meant to consume the art's margin,
not to add one — and now the margin is generated *after* the hero, by
extending it, so the hero never has to keep clear of anything. Inside
the hero the same lesson still applies: centres and heights land,
extents do not, so a body that must stop short of an edge gets the
position of its far edge, not a size.

The overlay is a bitmap, so a cover wider than it scales it up;
`covers.py stamp` says so when it happens, and the answer is to export
`overlay.png` larger from `overlay.xcf`.

### Stamping it

`covers.py stamp` puts the overlay on and the seal inside it:

```sh
./assets/covers/covers.py stamp clustering --corner br
./assets/covers/covers.py stamp coveralls --face back --corner bl --size 0.12
```

It reads `<feature>/art/<face>.jpg` — the raw generated artwork — and
writes the finished cover to `<feature>/sealed/<face>.jpg`; the face is
`cover` unless told otherwise, and only the cover is overlaid. The two directories are what keep an
unstamped cover from being mistaken for a finished one, and they mean
regenerating is always the same two steps: replace the art, stamp again.

On the front the seal **straddles the window's corner**: its centre is
the corner, so half of it lies on the board and half on the art, the
way a sticker crosses a join. That is the default when overlaid
(`--straddle`), and it is decided per axis: where the window reaches
the face's edge there is no board on that side to straddle, and the
seal is inset by the margin on that axis alone — under the banner it
straddles the band or the strip and sits in from the side. `--inside`
sets it within the window, inset by the margin, which is what a bare
face — the back, with no join to cross — always gets. Size is a **fraction of the width of the face that shows**
— the overlay's window, or the whole artwork when there is no overlay —
not pixels, because covers come out at different resolutions (the first
six were 765px wide and 687px wide): a seal sized on the full face was
0.275 of the window on the first overlaid cover, and met the hero.
`0.32` was chosen on exdebug against the four-sided board, whose
window was five sevenths of the face: at `0.40` the seal reached the
band's rule and the mounting hole in the top corners and ran past the
image's edge in the bottom ones; `0.32` cleared all four. The default
is `0.23` now, the same seal carried over to a window as wide as the
face — the seal is a sticker, and keeps its size when the overlay
changes; the badge's fractions were carried over the same way. Inside, the inset is measured from the window's edge, in the same
units: `0.05` horizontally and `0.03` vertically by default. `--badge "<UNIT>"` typesets the badge in the
window's bottom left, or bottom right when the seal has the left — or
wherever `--badge-corner bl|br` says, when a composited lockup's
subtitle reaches the corner the badge would take — at
the same insets and in the same box the back's badge is set in.

The inset is per direction. `--margin 0.11,0.04,0.03,0.04` gives top,
right, bottom and left their own — CSS order, and the form the default is
written in, so the four sides are always there to be edited. The short
forms stand in for it: `--margin 0.04,0.11` sets the horizontal and the
vertical, `--margin 0.04` all four at once. Only the two sides the chosen
corner touches are ever read; the vertical is still a fraction of the
*width*, so a corner's two insets stay comparable. Whichever form, the
values are fractions.

Corners are a per-cover choice, made from the art: the seal takes a
quarter-disc of the window at its corner, and that quarter-disc is what
the prompt asks to be calm. Bottom corners are usually easier — the
lockup sits between them, and only one of them holds the badge.

### Why a top margin never matches the number

Two constants pull the seal away from where the fraction says, and both
were found by tuning a top corner by eye and not believing the result.
The first was measured on covers that carried a generated band in their
own art, from before the overlay; they are archived, and art made under
the overlay carries no band of its own, while `covers.py stamp` measures the
seal on the window, which starts under the overlay's band already. So
under the overlay only the second constant, the seal's own air, still
moves anything. The first is kept as the evidence it was.

**The field starts under the band, not at the edge.** A top inset is
spending most of itself on a strip that is not part of the picture. On
`healthcheck` and `exdebug` the violet begins at `y=83` of 728, which is
**0.114 of the width** — and that is exactly the `0.11` this section used
to recommend for top corners without knowing why. The number was never
about the seal. Measured on those two covers only: `coveralls` and
`exdoc` have no dark strip for the scan to find, so treat 0.114 as their
figure rather than a property of the format, and measure per cover:

```sh
python3 -c "
from PIL import Image; import statistics, sys
g = Image.open(sys.argv[1]).convert('L'); W, H = g.size; q = g.load()
for y in range(H // 3):
    if statistics.median([q[x, y] for x in range(0, W, 4)]) > 60:
        print(f'field starts y={y} = {y/W:.3f} of the width'); break
" assets/covers/<feature>/art/cover.jpg
```

**The seal carries its own air.** The disc inside `seal.png` stops
**6.2%** short of the file's edge on every side, so at `--size 0.24` it
lands a further **0.015 of the cover's width** inside whatever margin was
asked for. That one is uniform — it shifts every side equally, which is
why it goes unnoticed until a side is compared against a top.

Together:

```text
optical side gap = margin + 0.015
optical top gap  = margin + 0.015 - band
top margin that matches the sides = band + side margin - 0.015
```

`healthcheck` is that arithmetic: `0.114 + 0.05 - 0.015` = `0.15`, and
`--margin 0.05,0.15` is what it was stamped with. At `0.11` the seal sat
8px under the band against 47px at the right, and read as hanging off the
band rather than placed in the field.

None of this decides anything — a seal tucked under the band is a
legitimate choice. It just means the choice gets made from a number that
describes what the eye will see.

### Archiving

A cover that gets superseded moves to `<feature>/_archived/art/cover-N.jpg`,
where the number is assigned **at archive time as one more than the
highest already there for that feature**. So 1 is the first ever made, n
is the one most recently retired, and nothing is ever renumbered. This
guide writes those as `coveralls-3` for short. Plates are archived the
same way as `back-N`, on their own count: `healthcheck` retired six
covers-worth of plate before one passed, and they are `back-1` to
`back-6`.

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

**The prompt goes in with it**, as `_archived/art/cover-N.prompt.txt`.
A retired take is only evidence if what was asked for is still readable
beside it — otherwise the archive is a pile of images whose intent has
been overwritten, and the diff that explains a regeneration has nowhere
to run.

The six `-1` files are the exception that proves it. They were made
before the seal existed, with a generated one baked into the artwork, so
there is no separable art to archive — the sealed cover is all there is,
and it goes in `_archived/sealed/` instead. That is also why `sealed/`
holds only what was made the current way: the directory is a standard,
not an inventory.

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
| stripe | TAKE THE MONEY | 1 CHARGE | A vault door opening on a stream of coins routed into a ledger |
