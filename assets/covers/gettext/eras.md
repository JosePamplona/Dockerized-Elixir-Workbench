# gettext — six proposals

Written from the cartridge's NEED.md first, then its README and
DESIGN.md, and nothing else. The era block of the winner goes into
`cover.prompt.txt` verbatim; what follows is the hero paragraph each
era would put in it.

## The need

*Your users don't all read English, and the strings are already
written.* Before: strings hard-coded in the components; a second
language means touching every template, and a missing translation
shows nothing. After: every string is a `gettext` call with the
English as its own fallback; a locale is a `.po` file.

## The register

**Courteous** — the mechanism addresses whoever arrives in their own
words, and never leaves them without an answer. Subtitles greet.
Added for this cartridge.

Title `GETTEXT`. Subtitle `IN THEIR OWN WORDS`. Badge `PRIV/GETTEXT`:
where a locale lives, the one path the need implies. Accent **ink
blue** or the era's nearest, unused on the shelf. No furniture unless
the era's own column has one.

The counts that are true: **one** locale to begin with, `en`; **one**
file per language; **every** string wrapped; **one** fallback, the
English itself. The strings a hero may carry at foreground size, one
per hero: `msgstr`, `gettext`, `en`, `errors.po`. Where one sentence
appears in many scripts, they are the same sentence.

## The six heroes

### 1 · Early carton, ~1978-82

A two-colour schematic of a railway departures board drawn with a
ruler, 0.80 of the width across from 0.20 to 0.65 of the height: one
row of flap-tiles, seven tiles, showing the same short greeting
**mid-flip** — the first three tiles settled on one script, the middle
tile drawn half-turned, the last three still showing another script —
and below the board a single ruled card slot labelled in hand-set
grotesque at foreground size: `msgstr`. Two small figures in line
drawing wait beneath the board at 0.30 and 0.70 of the width, looking
up. Flat paper ground; the second spot colour is the tiles' faces.
Lockup along the bottom fifth, a lot stamp at the top left, top right
bare paper.

### 2 · Home computer, ~1982-85

A grid floor to a horizon at 0.45 of the height, and standing on it a
row of three blocky figures with heavy black outlines at 0.25, 0.50
and 0.75 of the width, each airbrushed a flat different colour, each
holding up a flat rectangular card at chest height; the three cards
carry the same greeting in three scripts as lettering shapes, and the
middle card, facing the viewer, reads at foreground size in slab
caps: `HELLO`. Above the horizon a flat empty sky in ink blue. Lockup
in slab caps along the bottom, a compatibility strip at the top left,
the top right the empty sky.

### 3 · Editorial cover, mid-1980s

An even ground of ink blue and one object: a folded paper name card,
the kind set at a place at table, standing at 0.50 of the width and
0.50 of the height, 0.40 of the width across, lit from the upper left
so its fold throws one clean shadow. On its face, in small serif at
foreground size, one word of welcome — `en` set small beneath it as a
locale mark — and, showing faintly through the paper from the back
face, the same word in another script, mirrored. Nothing else. Small
serif lockup at the bottom, a review-quote flash at the top left, the
top right clear blue.

### 4 · Console, late 1980s

An airbrushed innkeeper's daughter at an open half-door, 0.75 of the
height tall with the head at 0.18 of the height and the centre at 0.40
of the width, leaning out to greet three travellers painted in profile
entering from the right edge, each with a chunky highlight on a
different hat; a speech balloon painted above her at 0.30 of the
height holds the same three-word greeting three times, stacked, the
top line legible at foreground size — `gettext` — the two below as
lettering shapes in other scripts. Extruded lockup across the bottom
fifth; a small UPC block at the top right; the top left quadrant the
evening sky, calm.

### 5 · CD-ROM, early 1990s

A chrome ring, 0.65 of the width across, standing on edge at 0.50 of
the width and 0.45 of the height over a perspective grid to a
starfield horizon at 0.70 of the height, and around the ring, as
extruded bevelled lettering that follows its curve, one greeting
repeated in six scripts, the front-most legible at foreground size:
`GETTEXT`. A lens flare where the ring meets the grid. Rainbow
specular along every bevel. Chrome lockup along the bottom, a
security hologram at the top left, the top right the starfield.

### 6 · Big box PC, ~1992-96

A great hall's threshold at night in oil, one torch at the upper left:
a stone lintel 0.80 of the width across at 0.30 of the height, and
carved into it, one below the other, the same word of welcome in five
scripts, the deepest carving lit gold by the torch and legible at
foreground size — `errors.po` set small on a brass plate beside the
door — the others receding into shadow with every chisel mark
detailed. Through the open door below the lintel, a warm room. Extruded
fantasy lettering across the bottom fifth with a hard bevel, lit by
the torch; a disk-format flash at the top right; the top left the
hall's dark stone.

## The recommendation

**1, the early carton.** The need is *the same sentence, every
reader's way* — and the departures board mid-flip is that exactly: one
message, changing script while the travellers watch, with the empty
card slot saying what is still to be filled in. The carton era draws
it as apparatus and the courtesy is in the people waiting under it.

The shelf as it stands: clustering manual from a home-computer start;
healthcheck2 manual from an editorial start; exdebug console; exdoc
big box; ash big box; coveralls, healthcheck and enhancements starting
over. The carton has no cover. dashboard's proposals name it too; if
it goes there, 3 — the place card — keeps the stance with one object.

## The choice

—
