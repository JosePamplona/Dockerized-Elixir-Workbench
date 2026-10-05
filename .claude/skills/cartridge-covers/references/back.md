# The back

Read this only once the front's row in the cover record is complete. The
back takes era and register from that row and decides nothing of its
own.

## The back of the box

Only once the front is validated. The back is the other face of the
same box, so it takes **era and register from the front's row in
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
| The generator | The plate: era material and finish, the era's device ghosted into the middle, a darker strip for the legal line — and nothing lettered |
| Composition | The frames and the screenshots in them, the copy, the badge, the requirements flash, the name lozenge, the legal line, the seal |

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

One back has been made this way — coverage — and the rules below are
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
picture of anything. The face is <the era's material, even across the
whole face>. Nothing on the face is lettered: no title, no caption, no
signature, no placeholder text, no glyphs, no words of any kind
anywhere on the face.

Across the middle of the face the printed board continues, bare, and
one <DEVICE> is ghosted into it, centred, barely darker than
the stock it sits on — a watermark rather than a print, and the one mark
on this face. <What is inside it, exactly.> It carries no lettering.

Across the bottom edge, over the full width, a band of the same board
printed in a darker ink, about a fifteenth of the height of the face.

Every mark on the face is printed material or type, and the marks named
above are all of them.
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
the front: it is generated clean, and the barcode the coverage plate
brought predates that.

Three things in that template are not obvious, and each one cost a
plate. They are set out below; what the plates actually did is in
[Measured on the backs](../../../assets/covers/README.md#measured-on-the-backs).

**Rectangles, not relations.** Say where each thing's edges are as a
fraction of the face — the device's centre and
width. Do not say "of equal size", "the same height" or "twice the
width of the other": a stated *relation between two objects* is what
gets dropped when the generator has to choose. This was learned on the
frames, when the plate still carried them — 5 wide by 7 tall landed
twice, and then 3 by 2 did not, when the name above grew and pushed
them — and it is the reason they are drawn now: a rectangle whose
position matters is composited, not asked for.

**The frames set the copy's budget.** A back has room for the frames and
then for headline, blurb, features, flash and legal strip, and the
second half is what makes it a back. `coverage` left the copy 0.84 of
the width in height; plates whose frames ran to half the face left
0.42–0.56, and no `layout.env` recovers that — the blurb loses a line,
then a feature bullet goes, then the flash lands in the legal strip.
With the frames drawn, the budget is set in `layout.env`: frames ending
above two fifths of the face keep the back writable, and the wide era
faces (Bookman, Palatino, the Noto blacks) want the copy at its floor —
one line of headline, four of blurb, three bullets — before the
layout is blamed.

**The device is asked for, not forbidden.** See below.

### The name

The front's band is on the overlay, and the back does not get the
overlay: it carries the workbench's name as a **membership badge in
the legal strip**, beside the seal — a lozenge in the form of the
platform lozenges a hero carries, a pale field with a thin ink rule
and the name in small capitals of the era's headline face, padded evenly from the letters' ink. `covers.py
back` typesets it (`NAME_Y`, `NAME_X`, `NAME_POINT` and `NAME_KERN` in
`layout.env`; its size follows its type; an empty `NAME_Y` leaves it
off),
and it is the same on every back, like the seal: it says whose the
cartridge is, not which era it is.

It used to be generated on the plate, at foreground size, in the era's
own form — the one piece of text the back let the generator draw, and
the reason the plate had a foreground element at all. Three plates on
`health_probe` ended that: given a rectangle, the name came back inside
a drawn panel that took a sixth of the face; asked out of the panel, it
kept the panel's place and size; and either way the top third of the
face was the name's, with the screenshots squeezed to 0.30 of the width
under it and the blurb cut to fit. A back's top is for its screens, and
its foot is where a box says who published it — which is what the name
is. With it typeset, the plate carries no lettering, and the one
prohibition on this face is the whole of it.

The backs made while the plate still carried the name — coverage,
exdebug, exdoc, clustering — keep their generated name until they are
remade, and their `layout.env` has no `NAME_Y`.

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

Written by hand, in the front's register. It has three sources in the
cartridge's anatomy, and which one is which matters. `NEED.md` is the
developer's situation in their own second person — what a back's blurb
*is*, and the register's home. The README says what the cartridge
*installs*, and copy drawn from it alone is a spec sheet —
health_probe's first back read "`/health/ready`: `SELECT 1` on the
repo, 1 s timeout" and was retired for it; health_probe's kept back
was drawn from `DESIGN.md` because the need had no file yet, and what
it drew from the Abstract and Problem is what `NEED.md` now says
directly. `DESIGN.md` remains the source for what only it knows: the
decisions as benefits, the verified requirements, the quotable
sources. Keep it to what fits a back in one glance:

| Piece | Length | Source |
| --- | --- | --- |
| Headline | Up to six words, in the front's register, and **one line at the house size** — five words ran to two on exdebug, and the fix was a shorter headline, not a smaller face | New — the need read in the register, not the subtitle again: *Alive is not ready* |
| Blurb | 40-70 words | `NEED.md` — its sentence and its *Before*/*After*, already in the reader's second person; `DESIGN.md`'s *Problem* for the precision the need compresses. The *Not for* line belongs here too when it saves a buyer a mistake |
| Features | Three or four bullets, up to eight words each | `DESIGN.md`'s decisions, each as the benefit it buys — *readiness that sheds traffic before requests time out* — never the file it lives in |
| Requirements flash | Two lines in the idiom of a system-requirements box — what it needs, what it works with; commas inside a line, since ` · ` is the line break | `DESIGN.md`'s *Evaluation* (what the generated code was verified on) and its platform survey: `REQUIRES: PHOENIX 1.8, ELIXIR 1.19 / OTP 27` / `WORKS WITH KUBERNETES, FLY.IO, AWS ECS` |
| Quote | One sentence and its attribution, `words — who`, set in the era's italic between the features and the flash (`QUOTE_Y`, `F_QUOTE`); optional, the editorial era's review-quote flash and other eras' at their discretion | A verbatim quotation from `DESIGN.md`'s sources — the design already quotes them exactly |
| Version | Not written: `covers.py back` reads `cartridge vX.Y.Z · date` off the first entry of the cartridge's `CHANGELOG.md` and sets it under the legal line, so the back never carries a version the cartridge does not | `CHANGELOG.md` |
| Install | The one command, as a second lozenge under the name's — the same pill inverted, ink field and pale type, in the caption face (`INSTALL_POINT`; `INSTALL_ROW=beside` puts it after the name in one row, smaller, where the band is short) | The README's install line |
| Badge | The front's, verbatim | Cover record |
| Captions | One line each, in the same register | What the screen shows, said the way the blurb would say it |
| Legal strip | Repository, licence, "actual screens shown" | Small, and true |

It lives in `<feature>/back/copy.md`, one heading per piece, so a back
can be re-set without rewriting it.

### The screenshots

**Real ones**, of what the cartridge actually installs, which is the
truth principle applied to the back: coverage shows its HTML report,
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
`coverage` showed was that a 1280×800 window squeezed into a 5:7 frame
is unreadable, and two conclusions fit: change the shot, or change the
frame. The guide took the first — *"do not fight it in the prompt,
retake the screenshots at the frames' ratio"* — on the strength of the
frames having *come back* 5:7 once, which was never a claim that they
had to be. Its cost came due on `health_endpoint`: Swagger UI has no mobile
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
0.004 for the editorial — and health_endpoint's layout moved its features
up a hair besides. A re-set back is judged the way a plate is:
composed, and looked at.

**Nothing on a back is generated text any more.** The name was the
exception — generated at the one size where text does not fail, in a
form the era chose, after the band it used to be came back in the
accent colour on two `health_endpoint` plates of three — and it was the
exception that cost the face its top third. It is the lozenge now, set
here with everything else; the two faces are one box by the seal, the
colour, the era and the lozenge.

The seal goes on last, through the same stamping as the front, **small** — `SEAL_SIZE=0.12`
— in the legal strip at the left of the lozenge, **centred on the
block the lozenge and the legal line make**: `SEAL_MARGIN="X,Y"` sets
its height, and `NAME_X=centre` centres the three — seal, a gap, the
wider of lozenge and legal line — on the width as one block and sets
the seal's `X` from it, so no back computes the strip by hand. It is the one element that appears on both
faces, which is the point: either side up on the shelf, the box says it
is one of ours.

### The layout, as health_probe set it

The first back made whole this way is `health_probe`, and its
`back/layout.env` is the worked example the next back starts from,
measured again against its own plate. Top to bottom: the screenshots
first, under the plate's top edge, two frames at the shots' own
proportion and as wide as the face allows (0.40 of the width each,
about 2× reduction); their captions; the headline; the blurb; the
features; the requirements flash and the badge in one row on the
material; and on the darker band, the name lozenge, the install command's
lozenge under it, the legal line and the version under those, and the
seal as tall as the three and centred on them, the whole centred on
the width. All of the strip is `covers.py back`'s defaults from one
number, `NAME_Y` — where the name lozenge starts on the band; the
install row, the legal line's place, the seal's size and margins and
the block's centring follow from it (`INSTALL_ROW`, `LEGAL_Y`,
`SEAL_SIZE`, `SEAL_MARGIN`, `NAME_X` override one at a time; the backs
made before the pattern set them by hand). The band is the strip's
room whatever the plate draws across it — health_probe's embossed frame
runs through its band, and the block ignores it. `covers.py back`
warns when a row runs wider than the margins; `NAME_POINT`, `NAME_KERN`
and `INSTALL_POINT` bring it in. The plate carries nothing
lettered, the copy comes from `DESIGN.md`, and the frames are drawn.
What changes from box to box is the plate's material and where its
band and device fall — everything else is this order.

`covers.py back` does all of this:

```sh
./assets/covers/covers.py back coverage
```

It reads `<feature>/art/back.jpg`, and from `<feature>/back/` the copy,
the shots and `layout.env` — the frame rectangles and text positions
**measured off that plate**, as fractions of its width, since no two
plates put the frames in the same place — composes, and seals the
result into `<feature>/sealed/back.jpg`. It was written after the
coverage back was composed by hand, from that composition, and
reproduced it pixel for pixel; the port to PIL was checked the same way
against exdebug's archived back. Making a back is therefore: generate
the plate, measure it into `layout.env`, write `copy.md`, take the
shots, run `covers.py back`. The
accent goes in `layout.env` too (`ACCENT=`), read off the front's art
— the one colour the era put beside the ground — since it is the box's
and not the tool's.

### What every plate has taught

The evidence these rules came from — thirteen rows over eight plates —
is *Measured on the backs* in `assets/covers/README.md`. Read it before
writing a plate prompt, and add to it after every take.
