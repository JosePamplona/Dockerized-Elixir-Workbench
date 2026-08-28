# The back

Read this only once the front's row in the cover record is complete. The
back takes era, accent and register from that row and decides nothing of
its own.

## The back of the box

Only once the front is validated. The back is the other face of the
same box, so it takes **era, accent and register from the front's row in
the [cover record](../../../assets/covers/README.md#cover-record)** and decides nothing of its own: a
box whose two faces come from different decades is two boxes.

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
| The generator | The plate: era material and finish, the workbench's name in the era's own form, the era's device ghosted into the middle, a darker strip for the legal line |
| Composition | The frames and the screenshots in them, the copy, the badge, the requirements flash, the legal line, the seal |

The frames used to be the generator's. Five plates in a row put them
between 0.5 and 0.6 of the height whatever rectangle the prompt gave —
two frames or one, in hundredths or fifths, with or without their own
proportion — and the copy under them never fit without cutting. So the
plate is generated **without frames**, and `covers.py back` draws them
around each `FRAMES` rectangle, with `FRAME_RULE` in `layout.env`
naming the rule: outer colour and width, inner colour and width, in
the era's idiom (a heavy black rule with a thin accent line inside for
the home computer; a gilt rule for the big box). The frame's rectangle
is then a layout decision, measured against the copy's budget instead
of the plate. The plate prompt's layout clause loses its frames
paragraph; everything else in it stays.

One back has been made this way — coveralls — and the rules below are
what it left. Where a guess survived contact it says so; where it did
not, it is gone.

### The plate

The template is the front's with the hero swapped for a layout. Era and
format go in verbatim, so the plate is unmistakably the same box; the
era block already carries the material, and the layout is described in
era-neutral words so it does not fight it.

```text
[ERA — verbatim, the same block as the front]

[FORMAT — verbatim, up to "Proportions 5:7 portrait." — the bleed
sentence is the overlay's, and the back has no overlay. The list of what a
product photograph would add matters *more* here: a rim the front's
overlay would cover, the back shows]

Back face layout. This face carries no subject: no figure, no scene, no
picture of anything. One thing on it is lettered, and only one: the
words "DOCKERIZED ELIXIR WORKBENCH", set <in the era's own form: a
rubber stamp, a flash, a stats panel, an announcement> inside <its
rectangle>, at foreground size. Nothing else on the face is lettered:
no title, no caption, no signature, no placeholder text, no glyphs, no
words of any kind anywhere else, neither inside the frames nor outside
them.

Across the middle of the face the printed board continues, bare, and
one <DEVICE> is ghosted into it, centred, barely darker than
the stock it sits on — a watermark rather than a print, and the one mark
on this face. <What is inside it, exactly.> It carries no lettering.

Across the bottom edge, over the full width, a band of the same board
printed in a darker ink, about a fifteenth of the height of the face.

Palette: [HOUSE COLOUR — verbatim], CRT phosphor haze in the background.
Every mark on the face is printed material or type, and the marks named
above are all of them.
Accent: <the front's accent>.
```

Two or three frames, or one wide one, and now that they are drawn the
choice is the layout's: what shrinks a screenshot is not the frame's
shape but how many share the width. On a 728px face, three 5:7 frames
in a row are 192px wide each, two of the same height at 4:3 are 340px
— 77% more linear resolution for the same band of the face — and one
wide frame across the face holds a terminal at 80 columns. Mixed
shapes in one row cost nothing: `layout.env` gives every frame its
own `w` and `h`, so a narrow upright frame for a console print beside
a wide one for a page is a layout decision, not a tooling one. What
the frames leave below them is the copy's budget, and it is set here
too: frames ending above two fifths of the face keep the back
writable.

Match the shot's aspect to its frame. `covers.py back` scales the shot
to cover the frame and crops from the top, so a mismatch is not letterboxed — it silently
loses the sides of the picture. The plate carries no furniture, like
the front: it is generated clean, and the barcode the coveralls plate
brought predates that.

Three things in that template are not obvious, and each one cost a
plate. They are set out below; what the plates actually did is in
[Measured on the backs](../../../assets/covers/README.md#measured-on-the-backs).

**Rectangles, not relations.** Say where each thing's edges are as a
fraction of the face — the name's rectangle, the device's centre and
width. Do not say "of equal size", "the same height" or "twice the
width of the other": a stated *relation between two objects* is what
gets dropped when the generator has to choose. This was learned on the
frames, when the plate still carried them — 5 wide by 7 tall landed
twice, and then 3 by 2 did not, when the name above grew and pushed
them — and it is the reason they are drawn now: a rectangle whose
position matters is composited, not asked for.

**The frames set the copy's budget.** A back has room for the frames and
then for headline, blurb, features, flash and legal strip, and the
second half is what makes it a back. `coveralls` left the copy 0.84 of
the width in height; plates whose frames ran to half the face left
0.42–0.56, and no `layout.env` recovers that — the blurb loses a line,
then a feature bullet goes, then the flash lands in the legal strip.
With the frames drawn, the budget is set in `layout.env`: frames ending
above two fifths of the face keep the back writable, and the wide era
faces (Bookman, Palatino, the Noto blacks) want the copy at its floor —
one line of headline, four of blurb, three bullets — before the
layout is blamed.

**The device is asked for, not forbidden.** See below. So is the name.

### The name

The front's band is on the overlay, and the back does not get the overlay:
the plate carries the workbench's name itself, and it is the one piece
of text this face lets the generator draw. **The words stay, the form
is free** — a rubber stamp across a corner, a flash, a stats panel, an
announcement strip, whatever composes the plate in the era's own idiom.
That is the point of it: the front says which workbench by the overlay,
and the back gets to say it the way its decade would have.

Three rules, all from the tables:

* **Foreground size.** That is the threshold above which generated text
  is reliable, and `DOCKERIZED ELIXIR WORKBENCH` came back right on
  every band that was ever asked for. Below it the words go the way of
  the small address plates.
* **If it is a stats panel, the numbers are texture.** A form that
  carries figures — a dial, a readout, a score — carries flipped digits.
  Ask for the shape; never for a number the back has to get right.
* **It has a rectangle.** Say where it sits, as fractions of the face,
  like a frame; then measure it into `layout.env` as a place the copy
  keeps clear. A name left to float lands on a frame or under the blurb.

Its shape is still the era's furniture, and the anachronism column in
`references/eras.md` still vetoes it: no hologram flash on a carton, no
grease-pencil stamp on a CD-ROM.

### The device

The middle third of a back is where the copy is composited, so the plate
wants it plain — and asking for it plain does not work. Over six plates
that field came back as a neon sigma with invented lettering under it,
then as a photographed glass bottle overlapping a frame, then, when
every intrusion had finally been prohibited, as a flat void. The field
was never once *designed*; it was either an intrusion or an absence.

So it gets a slot. A real back's middle is not empty either: it carries
the publisher's device, ghosted large behind the copy. Ask for that, and
the same field that fought three prompts comes back right in one.

This is where the container rule in `SKILL.md` was learned, and the
third of the three times it turned up. The colophon is the clearest
case: a container named without its contents came back with a monogram
inside it — lettering, on the one face whose whole doctrine is that no
text is generated. Naming the interior fixed it in one take: *an upright
oval outline, and inside it one small filled circle and nothing else*
came back exactly.

Keyed to the era, like the furniture:

| Era | Its device |
| --- | --- |
| Early carton | A printer's fist or a lozenge, struck in the one spot colour |
| Home computer | A hard-edged geometric monogram-free glyph, flat |
| Editorial cover | A publisher's colophon: an oval outline with one figure inside |
| Console | An embossed shield, blind-stamped into the board |
| CD-ROM | A chrome sunburst, ghosted at low contrast |
| Big box PC | A guild seal in the same ink as the board |

Two rules bind it. It carries **no lettering** — a device is a mark, and
the back's text is all composited. And it must be **barely darker than
the stock**: the copy is set over it, and a device that competes with
the blurb has stopped being a watermark.

**The era block is cut for a plate.** Whatever clause in it places a
subject comes out. The editorial entry says *one carefully lit object
centred with generous space around it*, which is a composition
instruction for a front; left in, it put a bottle in the middle of a
back and no prohibition downstream could hold it, because the
prohibition was arguing with the prompt's own first paragraph. Material
and technique stay; anything that places something goes.

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

**The frame follows the content, not the box.** The face is 5:7 because
Tier 2 says so; the frames inside it are not, and asking for them in the
layout clause is what stops the format block propagating inward. Screens
are landscape, and so are the screen panels on every box back this
collection is quoting — a portrait frame is less period-accurate, not
more.

This is the correction of a rule that read the evidence backwards. What
`coveralls` showed was that a 1280×800 window squeezed into a 5:7 frame
is unreadable, and two conclusions fit: change the shot, or change the
frame. The guide took the first — *"do not fight it in the prompt,
retake the screenshots at the frames' ratio"* — on the strength of the
frames having *come back* 5:7 once, which was never a claim that they
had to be. Its cost came due on `healthcheck`: Swagger UI has no mobile
layout, so the "narrow viewport is still an actual screen" argument
produced a page with its tag description broken to one letter per line.

**Portrait frames keep one real use**: content with no layout to break.
A short console print — nine lines of fifty characters — reads the same
upright as wide, and so does a genuine mobile view. There the shape goes
back to being a composition choice.

Then take each shot at the CSS width where its own layout works, and at
its frame's aspect. Between those two the width matters more: a page
shot at 900px and printed into a 363px frame is at 2.5× reduction, and
somewhere past 3× a screenshot stops being readable and becomes
decoration.

The terminal is rendered from real output (ANSI through `aha`, in a fake
window) at whatever size the frame wants.

Then the period treatment before they go in — a slight softening and a
faint scanline overlay is enough to make a 2026 browser window read as
a printed screen — but stop before they lose legibility: a screenshot
that cannot be read is decoration, and the front has enough of that.

### Assembly

PIL, in **fractions of the plate's width** like the front, so a back
set at 728px and one at 1024px come out identical. Fonts are the
system's, named the way ImageMagick named them — `Family-Style`,
dashes for spaces — and found through fontconfig, which is asked for
the family *and* the style and checked, because it answers every query
with something. (The backs before the port were set by ImageMagick,
which read the URW faces' Type 1 files and their looser line box; PIL
reads the OpenType ones, so those faces set tighter now, and the
layouts measured before are a hair off in the vertical.) **They follow
the era**: the composed half of a back is
half of its decade, and until clustering every back was set in one
console-era triad whatever its plate. `layout.env` names the era
(`ERA=editorial`, copied from the cover record) and `covers.py back` picks the
triad; `F_HEAD`, `F_TEXT`, `F_MONO`, `HEAD_KERN` and `FEAT_LEAD` set
there override it one at a time. The URW base35 faces are clones of
the PostScript classics these boxes were actually set in:

| Era | Headline, features, flash, badge | Blurb | Captions, legal |
| --- | --- | --- | --- |
| `carton` | `URW-Gothic-Demi` — ITC Avant Garde, 1970 | `Nimbus-Sans-Regular` | `Courier-10-Pitch-Regular` — a typewriter |
| `home` | `URW-Bookman-Demi` — the early-80s advertising face | `Nimbus-Sans-Regular` | `Nimbus-Mono-PS-Regular` |
| `editorial` | `P052-Roman` — Palatino, caps tracked open (`HEAD_KERN` 0.006) | `Bitstream-Charter-Regular` — 1987, drawn for low-resolution print | `Nimbus-Mono-PS-Regular` |
| `console` | `Liberation-Sans-Narrow-Bold` | `Nimbus-Sans-Regular` | `Liberation-Mono` |
| `cdrom` | `Noto-Sans-Condensed-Black` — the heavy face under the chrome | `Nimbus-Sans-Regular` | `Source-Code-Pro` |
| `bigbox` | `Noto-Serif-ExtraCondensed-Black` — the extruded fantasy serif | `Utopia-Regular`, 1989 | `Nimbus-Mono-PS-Regular` |

Two things the first re-set of the shelf taught. A wide black —
`Red-Hat-Display-Black` was the first CD-ROM pick — runs a six-word
headline to two lines and the features into the flash; the headline
rule says shorten the copy and keep the face, but a face that breaks
every existing back is the wrong face, so the CD-ROM entry is a
condensed one. And faces with a tall line box (Noto, Palatino) push a
feature list into the flash at the leading Liberation Narrow was
measured with, so `FEAT_LEAD` is per era — zero for the Noto faces,
0.004 for the editorial — and healthcheck's layout moved its features
up a hair besides. A re-set back is judged the way a plate is:
composed, and looked at.

**The name is the exception to this face's own doctrine**, on purpose.
Everything else on a back is typeset here precisely because generated
text is what fails; the name is generated, at the one size where it does
not, and in a form the era chooses. It used to be the band, verbatim,
and on `healthcheck` two plates of three put it in the accent colour —
which is when the band left the art for the overlay. The front got the
overlay; the back was deliberately left without it, so the two faces are
one box by the seal, the colour and the era, and the back is where the
era gets to play. The two backs made before this carry a generated band
and differ until they are remade.

The seal goes on last, through the same stamping as the front, **small** — `SEAL_SIZE=0.12`
or so — in the legal strip, bottom left, where a back has always carried
it. It is the
one element that appears on both faces, which is the point: either side
up on the shelf, the box says it is one of ours.

`covers.py back` does all of this:

```sh
./assets/covers/covers.py back coveralls
```

It reads `<feature>/art/back.jpg`, and from `<feature>/back/` the copy,
the shots and `layout.env` — the frame rectangles and text positions
**measured off that plate**, as fractions of its width, since no two
plates put the frames in the same place — composes, and seals the
result into `<feature>/sealed/back.jpg`. It was written after the
coveralls back was composed by hand, from that composition, and
reproduced it pixel for pixel; the port to PIL was checked the same way
against exdebug's archived back. Making a back is therefore: generate
the plate, measure it into `layout.env`, write `copy.md`, take the
shots, run `covers.py back`. The
accent goes in `layout.env` too (`ACCENT=`), since it is the front's and
not the tool's.

### What every plate has taught

The evidence these rules came from — thirteen rows over eight plates —
is *Measured on the backs* in `assets/covers/README.md`. Read it before
writing a plate prompt, and add to it after every take.
