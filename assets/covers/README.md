# Cartridge covers

Every feature of the workbench is a *cartridge*
([the cartridges themselves](../../igniter/lib/workbench_igniter/features/)),
so every one of them can have a box cover. This directory is how those
covers get made — a small pipeline rather than a folder of images:

```text
assets/covers/
├── seal.png                the stamp, generated once, never regenerated
├── overlay.xcf             the overlay's source, drawn by hand
├── overlay.png             the overlay: the violet banner, name on its band, the window below it
├── covers.py               the pipeline: window, pad, cut, stamp, back — PIL, nothing else
└── <feature>/              one directory per cartridge, the whole box
    ├── art/hero.jpg        turn 1: the hero, generated at the proportion nearest the window's
    ├── art/padded.jpg      covers.py pad: the hero in the window of a 5:7 canvas, grey margins
    ├── art/expanded.jpg    turn 2: that canvas with its margins painted by the generator
    ├── art/cover.jpg       the 5:7 face covers.py cut from it, unstamped
    ├── art/lockup.png      the title lockup cut from a take, only when the art had to be generated without one
    ├── art/back.jpg        the generated back plate, blank
    ├── sealed/cover.jpg    the finished cover
    ├── sealed/back.jpg     the finished back
    ├── back/copy.md        the facts the back is typeset from
    ├── back/shot-N.png     real screenshots, 1 is the leftmost
    ├── back/layout.env     positions measured off that plate
    ├── eras.md             six proposals, one per era; the one recommended; the one chosen
    ├── cover.prompt.txt    the prompt to generate the cover from, now
    ├── back.prompt.txt     the prompt to generate the plate from, now
    └── _archived/          superseded work, local only, never in the repo
        ├── art/cover-N.jpg         a retired take, and beside it
        ├── art/cover-N.prompt.txt  the prompt that made it
        ├── art/back-N.jpg          the same for plates, on their own count
        └── back-N/                 a whole back — copy, shots, layout — when a box starts over
```

The covers are documentation art, not project assets — nothing plants
them into a generated project.

**The overlay is the one source of every number about the face.** Its
design is free to change — four sides, a banner, a strip — and when
it does, only the XCF and the PNG change: `covers.py` reads the window
off the PNG as the largest fully transparent rectangle, takes the
face's size, the window, the sides that have board and the hero's
proportion from it, and `covers.py window` says what it leaves in
words, for the prompt. No script, prompt or document repeats those
numbers. That rule came from the second overlay: the first had its
four widths copied into the stamping script and its window's
proportion, 2:3, written into six files, and the banner that replaced
it — 105 above, 55 below, nothing at the sides, art showing above the
band — made every copy wrong at once. The pipeline is one file for the
same reason: it was three shell scripts and a Python helper, two
languages and two image engines (ImageMagick for the compositing, PIL
for the geometry), and a fact that lives in two engines is two facts.

**This file is the record, not the procedure.** What a cover is, what
the collection has decided and what every take has taught are here; how
one is actually made is the `cartridge-covers` skill, in
`.claude/skills/cartridge-covers/`. The split is by lifetime: the skill
holds the steps, which are the same every time, and this file holds the
verdicts and the evidence, which are different every time and are what
the next rule gets written from. Nothing is duplicated across the two —
a rule that exists twice diverges by the third cartridge, and then
neither copy is the one that governs.

## What makes them a collection

Not a house style. A shelf of real 8-bit boxes is wildly inconsistent —
every publisher had its own illustrator, its own decade and its own
taste — and it still reads as one shelf, because the *platform* furniture
is identical on all of them. That is the model here, in three tiers:

| Tier | What | Varies? |
| --- | --- | --- |
| **The seal** | `WORKBENCH SEAL OF QUALITY` | Never. Shared by every workbench there could be |
| **Overlay, colour, format** | The overlay — the printed board in Elixir violet, `DOCKERIZED ELIXIR WORKBENCH` on its band, the window at its socket — composited like the seal, and carrying the house colour for the art it frames; a 5:7 portrait face | Never within a workbench; overlay and colour change if there is ever a Python or a JS one, the format not even then |
| **Everything else** | Era, art, layout, finish | Freely, cover to cover — the era is chosen from a repertoire |

So the covers are meant to be **collected, not manufactured**: generated
one at a time, each in whatever era and register suit its feature, and
none of them obliged to match the last. The overlay and the colour say
which workbench; the seal says it is one of ours; the format is what
lets a shelf of them line up.

Wear, stickers and the rest of a box's furniture are not on the list
because they are not generated any more, on either face: the art comes
out clean, and what happens to a box after printing is deferred to a
pass over the finished cover that does not exist yet. The reason is the
overlay — a scuff drawn in the art stops at its edge.

Everything below that reads like a rule was learned from a cover that
came out wrong. [What the generator gets wrong](#what-the-generator-gets-wrong)
has the evidence.

## Cover record

What each cartridge decided, and nothing about how its cover looks:
a cartridge started over is designed from its own feature README and
this table's *other* rows, never from a description of what it used to
be. That is why there are no stories here — a finished hero written
down is the first thing a fresh proposal copies — and why a row is
cleared, not annotated, when its cartridge starts over.

The accent column is a mirror, not a gate: the point is to notice when
six covers in a row have drifted to the same colour, not to stop the
seventh from reusing one (a repeat that *means* the same thing — green
for healthy, green for covered — is fine; shift the hue, not the
meaning). **The era column is the same, and is the one worth
watching**: it is what a die used to guarantee and a choice does not.
Nothing here rations the eras — a rule that forces the wrong cover onto
a cartridge to even out a shelf would cost more than the unevenness —
but three cartridges running that pick the same era is the signal, and
the rule gets written then, from that evidence. The corner column is
what `covers.py stamp` was passed, so a cover can be restamped identically;
since exdebug the seal straddles the window's corner by default, half
on the board and half on the art.
Exdebug, exdoc and enhancements predate the repertoire; their register
was never written down, and gets filled in when each is made again
rather than read back off a cover.

| Cartridge | Era | Register | Accent | Seal corner |
| --- | --- | --- | --- | --- |
| clustering | *starting over* | — | — | — |
| coveralls | *starting over* | — | — | — |
| healthcheck | *starting over* | — | — | — |
| exdebug | console, late 80s | deadpan | amber phosphor | tl, `--inside`, default size — the art in two turns under the banner overlay, hero at 4:5 with its own lockup, badge and price sticker, the padded canvas painted, cut by `covers.py cut`; straddling the band at a top corner covers the name's letters, so the seal sits inside the quiet quadrant instead |
| exdoc | big box PC, mid 90s | hospitable | vermilion ink | tl, `--inside`, default size — two turns under the banner, hero at 4:5 with its own lockup, badge and a disk-format flash; chosen against a carton recommendation. Back on the second plate: two 1.23 frames, the name as asked in two lines, a guild seal with an open book; the site's home and a module page shot off the regenerated docs of `test_27` at 780px CSS, the narrowest width at which ExDoc docks its sidebar, so the menu shows — 2.8× reduction into the frame, just under the line; copy cut to four lines and three bullets to fit; seal 0.12 bottom left |
| enhancements | *starting over* | — | — | — |

The whole shelf was archived on 2026-08-27, every box on its own
counts under `_archived/`, and the flow is being finished before any
of them is made again. The overlay was redrawn the same day, after
exdebug's front, from the four-sided board to the banner — the name
band across the top, a strip along the bottom, the sides open — so
exdebug's hero, generated at the old window's 2:3, was generated
again the same day at the new window's 4:5, from the same prompt, and
is the first cover made with `covers.py` end to end. Its back is the
third plate (two archived): two 6:5 frames measured into `layout.env`,
the name as a two-line chrome flash, a blind-stamped shield for the
device, and two real screens — `ExDebug.console/2` in an `iex` session
recorded with a TTY in the `test_27` workspace, and the library's page
on HexDocs — composed and sealed by `covers.py back` with the seal at
0.12, bottom left. Each box had been made under a different
version of the flow — coveralls and exdebug before the overlay existed,
with a generated band in their art; clustering under the first overlay,
whose sides covered a quarter of the height; healthcheck's prompt under
the same — and none of them under the overlay as it is now, the printed
board with its socket, which moved the house violet from the art to
the box. What each shelf row used to say is in its archived prompt and
`eras.md`; the accents are free again, and get chosen fresh under the
colour rule as it stands when the box is made.

## Measured on the backs

Three cartridges, eight plates. The first three rows are from
`coveralls` and `exdebug`; the rest are the six plates `healthcheck`
took, and they are the reason the section above is as long as it is.

| Guess | What happened | Rule it left |
| --- | --- | --- |
| The frames would not be where the prompt put them | They were roughly there | Measure the plate into `layout.env` |
| — | A five-word headline ran to two lines and into the blurb | The headline must fit one line at the house size; shorten the copy, keep the face |
| The treatment would be overdone | It was fine at scanlines 15% and blur 0.3 | Those are the defaults |
| Blank panels would fill with pseudo-text | They did not on `coveralls`, so the guess was deleted — and `healthcheck-1` came back with a neon sigma and "SUM OF THE PHOSPHOR" under it | Restored, and a second rule with it: **one confirming sample is not enough to delete a guess.** It takes a failure to keep a rule and more than one success to drop one |
| — | The prohibition ended "…no pictures inside the frames", and everything outside them stayed fair game | Scope a prohibition to the face, and enumerate: no title, no caption, no signature, no glyphs, no words of any kind |
| — | With the lettering finally banned, the era block's *one carefully lit object centred* put a photographed bottle in the middle third, over a frame's edge | Cut from a plate's era block whatever clause places a subject. A downstream prohibition cannot beat the prompt's own first paragraph |
| — | With the object clause cut too, the plate came back inert: a flat violet field with no paper, no deboss, no era | The clause that caused the bottle was also carrying the era's material. Cut what *places*, keep what *renders* |
| A plate that reads dead is dead | That inert plate composed well: the copy filled it, and an editorial back is supposed to be plain | **Judge a plate composed, not bare.** One `back.sh` run is cheaper than a regeneration and answers it |
| — | Three plates ran with a pure white margin on all four edges — a photograph of a box on a white ground, which Tier 2's format block forbids in those words — and none of the three reviews caught it | Check the **invariants** every take, not only the clauses that changed. Naming them is now step 9 |
| — | The band came back in the accent colour on two plates of three, on the one element defined as never varying | Tier 2 never fixed the lettering's colour. Saying *pale chrome white* held — and then the band left the art altogether: it is on the overlay now, composited, and the back carries the name in the era's own form instead |
| "Narrow and upright" would give a 5:7 frame | It gave 0.479, and `back.sh` cropped a third of the terminal away | Say proportions in numbers. Both plates asked in numbers came back within 0.02 |
| Dropping the redundant width clause would let "the same height" survive | It did not. Tops level, bottoms 115px apart, twice out of two | Relations lose to proportions. Give each frame its rectangle |
| — | A colophon asked for without its contents came back holding a monogram | Name the interior of anything you name |
| The positive-only format block — "flat illustration, all of it in one plane" — would hold on a plate as it half-held on the cover | It did not: a photographed box, bevel, rim and shadow on all four edges, with everything else on the plate exactly as asked | The format block keeps its enumerated list of what a photograph would add — after the positive description, as the backstop the rule allows, and the only form that ever came back clean |
| Frame edges given as words for the height — "from one fifth of the height down to two fifths" — beside hundredths for the width | The widths landed within 0.02 (6–48 → 6.2–47.7, 52–94 → 52.9–94.4); the heights came back 0.23–0.54, the frames nearly square, and the copy under them had 0.50 of the width — composed, the flash sat on the strip | `exdebug-2`: the same rule a third time, from the other side. Hundredths land, fifths do not; and give each frame its own proportion — *three wide by two tall* |
| Heights in hundredths (20–40) and each frame *three wide by two tall* would land the frames, as 5:7 had landed twice | The widths landed again (6–48 → 6.7–46.4, 52–94 → 53.2–93.0); the frames came back 0.26–0.49 of the height at 1.20 — and the name, asked on one line in a 0.05–0.125 rectangle, came back on **two** lines in a box to 0.21 that pushed the frames' top down | `exdebug-3`: a stated internal proportion can miss too, when something above it moves. The name is the mover: 26 characters of chrome wordmark at foreground size do not fit one line of a 0.8-wide rectangle, and the genre breaks them rather than shrink them. Kept: composed, the copy fits at 0.56 of the width of room, and the two-line flash is the era's own form. Next time, ask the name in two lines from the start, and give the frames their rectangle below where those two lines end |
| Asking the name in two lines from the start would give the frames their top | It did: the name came back exactly as asked, in its rectangle. The frames, asked 24–44 of the height at three by two, came back 0.30–0.59 and square (291×300) — the third plate running to square them (302×317, 289×241, 291×300), against every proportion asked. Composed, the features ran into the flash and the flash onto the strip | `exdoc-1`: the generator keeps the *width* it is given and raises the height to meet it. A frame's height is not a number the prompt controls; its width is. So size the width to the height the copy can afford — two frames 0.30 wide for a 0.20 band — and let them come back square if they will; a square screen at 0.30 of the width is 218px, still above the 3× line for a 600px shot |
| Narrower frames — 14–44 and 56–86 of the width — would come back narrower, and square, and so shorter | The generator widened them back: 8–46 and 54–92, at 277×226 (1.23), from 0.30 to 0.52 of the height. Four plates, four heights between 0.49 and 0.59 whatever the numbers | `exdoc-2`: two frames side by side come back about a quarter of the height tall and end near the half, and no number in the prompt has moved that. Kept: composed, with the copy cut to its rules' floor — four lines of blurb, three bullets — it fits with air. The lever on a back's room is the copy, not the plate; the next thing to try on a plate is *one* wide frame, or none |

## What the generator gets wrong

Measured on the first six covers. Read this before blaming a prompt.

| Symptom | Seen in | Rule it produced |
| --- | --- | --- |
| Seal drew four different ways, and once wrote "Nintendo" into it | all six; the trademark in `healthcheck.jpg` | Never generate the seal — composite it |
| A warm neutral accent dissolved into the violet | `exdoc` | Accents must contrast in value |
| The two small background IP labels came back with wrong digits, while the two large foreground ones were correct | `clustering` | Text in the art needs foreground size |
| A dial rendered perfectly with its needle in the wrong place | `coveralls` | Describe compositions, not states |
| A hero built as a bar of segments with some lit read as a battery icon, not as a scene | `coveralls-3` | A hero that is also a UI icon reads as the icon, and so does anything that "fills up": give the fact a body, not a widget |
| The figure went from half the panel to a speck | `clustering` vs `coveralls` | State the figure's scale in the frame |
| Proportions drifted narrower on two of six | `exdebug`, `enhancements` | State them inside the prompt, not only as a generator setting |
| The title lockup ran into the corner the prompt had asked to keep quiet | `coveralls` (regenerated) | Choose the seal corner after seeing the art; top right with `--margin 0.11` is the fallback |
| Ten segments came back as ten, but "the eight on the left lit" came back as seven lit | `coveralls-3` | Counts of marked members inside a field are not reliable; count separate bodies |
| "Exactly three panels that stay dark" in a lit field came back as two, and "a few" came back as none | `coveralls-4`, `coveralls` | Same rule, twice more: use such counts to compose, never as a fact |
| The lockup filled the bottom right corner again; the top right fallback overlapped the hero's edge | `coveralls-4` | An edge is not a focal element: keep the size, take the corner. Under a full-width lockup, ask for a *top* corner quiet from the start |
| Lens and light beam placed by separate clauses came back misaligned — the beam left the lens off-centre | `coveralls-4` | Tie linked objects to one axis in one sentence |
| A bare threshold line read as decoration | `coveralls-4` | A mark that carries a fact needs a label at foreground size |
| "One clean upward curve" of light came back as an arch, ends down — twice | `healthcheck-2`, `healthcheck-3` | A curve stated as a direction is read as one. Pin it by position: the lowest point *here*, both ends lifted |
| The editorial era's composition arrived and its material did not: even ground, one object, generous space, small serif — over a glossy modern render | `healthcheck` | A metal-and-glass hero overrides the era's finish. Asking for print as an adjective ("no digital gloss") half-works; the lever is the object, or the technique ("no gradients") |
| The title lockup filled the bottom right a third time, now in a different era | `healthcheck` | Not an era's fault: any lockup set full-width across the lower third takes that corner. Under one, ask for a top corner from the start |
| A composition given nothing about the overlay put the badge at the face's bottom left, where the overlay covers it, and everything else close enough to the edges that the window cropped the title tight | `clustering-2` | The bleed is in the format block, in numbers, and every position is given inside the rectangle it leaves — never on the face |
| The bleed asked for as "the rectangle they leave" came back drawn — a thin rule at a tenth of the face all round, a third of the inset asked for — and the badge placed at *its* corner, half under the overlay | `clustering-3` | Name no rectangle; it is a container, and it gets drawn. Measure every element from the edges of the face, one number each |
| Six patch cords between four posts came back six on one take and eight on the next, from the same sentence | `clustering-2`, `clustering-3` | Bodies that cross are not separate bodies: count them where they meet — *three cords leave every post* |
| The badge, given its position in numbers from the edges — a fifth in, an eighth up — came back at the face's corner, 50px from either edge, under the overlay; the second take in a row under it | `clustering-4` | Numbers do not move the badge: the genre puts it at the corner. It is a fact string, so it is typeset now, by `stamp.sh --badge`, inside the window |
| Six cords asked by position *and* as three per post came back nine — the hanging cords grew loops | `clustering-4` | Cords that hang invite slack. Ask for them taut and straight; if that fails, change the body — bars, not cords |
| The seal at `0.20` of the face met the hero on the first overlaid cover: on the window that shows it was 0.275, larger than on any cover before | `clustering-4` | `stamp.sh` measures the seal on the window's width now, so the seal keeps the size it has always had on the face that shows |
| Told the image was "the printed front face itself, its own printed surface", the generator photographed one: pale lit edges and a shadow all round — every one of them inside the bleed | `clustering` | A *face* is an object. Say *illustration*, *image*, *plane* — and judge an overlaid cover composed, not bare: the bleed exists to absorb exactly this |
| Two 4:3 frames given as rectangles in percentages — 6–48 and 52–94 across, 16–38 down — came back at 9–47, 53–91 and 18–38 | `clustering` | Percentages land within a few points; measure anyway, and never lay out from the prompt |
| A sheet of six sketches, one per era, came back in one finish with six motifs — the eras bled into each other and none was itself | `clustering`'s sheet, not kept | Six materials in one prompt average. The era is chosen from six *written* proposals and a recommendation, which is where the sheet's value was anyway |
| The title lockup, given its baseline at four fifths and its width at three quarters, came back with the baseline at 0.89 and the word 0.81 wide — the first and last letters under the overlay's sides — and the subtitle wholly under its bottom | `exdebug-4` | Numbers do not move the lockup either: the genre sets it on the bottom edge, the way it sets the badge in the corner. Give the lockup a top *and* a baseline, both inward of the bleed, say what fills the ground below it, and ask the word narrower than it should be — it comes back wider |
| `["Lorem", "Ipsum"]` at foreground size came back as `[Lorem]` over `[Ipsum]`: the words right, the quotation marks and the comma gone, one line made two | `exdebug-4` | Words at foreground size land; punctuation is not a word. Spell the characters out in order, and say *one line* |
| A porthole rim asked for with eight bolts came back with twelve | `exdebug-4` | Bolts on a rim are members of one body, not separate bodies — the same rule as segments in a field. Ask for *a bolted rim* and count nothing |
| The lockup, given a top at 0.70, a baseline at 0.75 and half the width, and the ground below it described, came back on the bottom edge again, 0.80 wide, the E and the G under the sides and the subtitle under the bottom — the second take in a row | `exdebug-5` | The console genre sets its title at the bottom edge at full width, and no number moves it. Generate the art with its lettering left out, and composite the lockup with `stamp.sh --lockup`, cut from a take whose lettering came out right |
| `["Lorem", "Ipsum"]` spelled out character by character came back with every character right — and wrapped in two lines inside the round porthole | `exdebug-5` | Spelling the characters holds. A round window wraps a line; a line that must stay one line needs a body wider than it is tall |
| With the lockup left out and "the cover's lettering is printed afterwards" said in its place, the illustration came back as an inset panel on a flat blue-grey margin, 52px and 37px at the sides, about 75px top and bottom | `exdebug-6` | Say nothing about what happens to the art afterwards: "printed afterwards" makes it a print, and a print gets a margin. The margin fell under the overlay on every side, so the take was kept at the time — and retired to the eye: the hero was squeezed into the middle of a face the window showed half of |
| Given the hero's size in numbers — pipe a third of the height, figure from a fifth to three quarters — the generator filled the image: the pipe came half the height and the figure's back ran to 0.94 of the width, under the board at 0.86; the take before, told the margins were empty ground, had squeezed everything into the middle | `exdebug-7` | Centres and heights land; extents and absences do not. A body that must stop short of the board is given the position of its far edge — *its back at four fifths of the width* — not a size. (Generating the art at the window's own 2:3 and setting it into the socket was written up here and taken out: the overlay's transparency is not promised to be a clean rectangle, and the art has to be congruent across the whole face) |
| "Extend this image to fill 3:4" on the 2:3 hero came back 765×1024 with the hero still 685×1021 inside it: 40px added at each side, none above or below | `exdebug`, `expanded-1` | The generator keeps its output size, so it cannot add height to a full-height picture. Make the space first — `bleed.sh --pad`, the hero in the window of a 5:7 canvas with grey margins — and ask it only to paint the grey |
| The badge asked for in the 2:3 hero as a flash in the top right corner — "DEV & TEST", with its ampersand — the term with straight quotes and its space, one hand on the pipe and the other at the side, and a half-peeled `$49.95` sticker in the bottom left all came back as asked, with the hero described as composition rather than by numbered edges | `exdebug` | Inside the hero, with nothing to keep clear of, the generator does what it is told; the numbers that matter are counts and strings. The badge is generated now, `--badge` a fallback |
| The lockup asked for in the 2:3 hero — two thirds of the width, baseline at nine tenths — came back on the bottom edge at nine tenths of the width, as the genre sets it: inside the window, whole, with the subtitle nearly as wide as the window | `exdebug` | With the hero the window, the genre's bottom-edge lockup is where it should be, and compositing one is no longer needed. What it costs is the bottom corners: the badge goes to a top corner (`--badge-corner tr`), and the seal takes the other |
| The padded 5:7 canvas came back painted, at 5:7 — the generator kept the canvas's proportion — with the hero 2–11px off the window from its own resize; the margins continued the scene and brought one thing not asked for, a guard rail on the catwalk, under the board | `exdebug` | Painting a blank border is a task the generator does as told. `bleed.sh` tolerates a few pixels of resize by repeating edge pixels; check the margins for what they add, since the prompt's "nothing new" is a backstop, not a guarantee |

What it gets right, consistently: the lettering of the title and
subtitle (their *position* is another matter, above), the badge, every
count of separate bodies it was given, any word given foreground size —
and, while it was still asked for, the band's wording, which is why the
back can carry it as generated text.

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
  with wrong digits, exactly as the small address plates did. Deferred
  with the furniture itself; kept for the wear pass.
* The era blocks' genre — "console game box cover art" — carries a top
  band in its memory, and the generator may draw one in the top bleed
  even though the prompt asks for ground there. Harmless while it
  falls under the overlay's band; the banner as it is now shows the
  art above its band, so a drawn band would show there.
* A laminated finish (CD-ROM, big box) renders as a sheen across the
  face, and the overlay has none: the join may show. If it does, the
  gloss clause goes to the wear pass with the rest.
* The back's name, asked for as a stats panel or a readout, will bring
  flipped digits with it — texture, never a fact.
* Choosing the era on a recommendation will drift toward one taste over
  eighteen cartridges, the way the die was meant to prevent — the
  recommender's taste now, not the sheet's. Watched in the era column
  of the [cover record](#cover-record), which every recommendation has
  to quote; unwritten as a rule until a shelf shows it.
