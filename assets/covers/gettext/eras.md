# gettext — six proposals

Written from the cartridge's README and DESIGN.md and nothing else. The
era block of the winner goes into `cover.prompt.txt` verbatim; what
follows is the hero paragraph each era would put in it.

## The register

**Courteous** — the mechanism addresses whoever arrives in their own
words. One backend, one locale to begin with, and every string the
components and layouts carry wrapped so that a second language is a
`.po` file away; the message id is the fallback, so nobody is ever
answered with nothing. Subtitles greet. Added for this cartridge:
hospitable lays the table, courteous speaks the guest's language.

Title `GETTEXT`. Subtitle `IN YOUR OWN WORDS`. Badge `PRIV/GETTEXT`:
where the messages live, the one path the design fixes. Accent
**ink blue** or the era's nearest: the colour of a stamp on a `.po`
file, unused on the shelf. No furniture unless the era's own column
has one.

The counts that are true: **one** backend; **one** locale, `en`;
**one** domain, `errors`; **three** files created; **two** tasks,
extract and merge; thirty-odd strings wrapped in the components. The
strings a hero may carry at foreground size, one per hero: `msgid`,
`msgstr`, `gettext`, `en`, `errors.po`. Where two things appear they
are a message and its translation; where many, they are one message
in many tongues.

## The six heroes

### 1 · Early carton, ~1978-82

A technical drawing of a card index in two spot colours: one drawer
pulled open at the centre, 0.60 of the width across, its centre at
0.55 of the height, and inside it a row of tabbed cards, the front
card standing proud and ruled like a form with two lines of hand-set
grotesque — `msgid` on the first, `msgstr` on the second, the second
line left blank by the ruler. Above the drawer, at 0.25 of the height,
five small tab labels in a row reading as language codes at small
size, the first `en` at foreground size and the rest as shapes. Flat
paper ground; the second colour is the drawer's outline and the tabs.
Lockup along the bottom fifth, badge as a lot stamp at the top left,
top right bare paper.

### 2 · Home computer, ~1982-85

A grid floor to a horizon at 0.45 of the height, and on it a single
speech balloon rendered as a solid slab, 0.55 of the width across with
its centre at 0.50 of the width and 0.50 of the height, heavy black
outline, airbrushed magenta. Inside the balloon, in slab caps at
foreground size, `HELLO` — and radiating from the balloon's tail to
the four corners of the floor, four smaller balloons, each a flat
different colour, each holding one word-shape in a different script,
drawn as shapes and not as text. Empty flat sky above 0.40 of the
height. Lockup in slab caps along the bottom, the badge as a
compatibility strip at the top left, top right the empty sky.

### 3 · Editorial cover, mid-1980s

An even ground of ink blue and one object: a rubber stamp, wooden
handle up, resting on its side so its face shows, centred at 0.50 of
the width and 0.50 of the height, 0.45 of the width long, lit from
the upper left so the rubber's relief reads. The relief spells one
word, mirrored as a stamp's face is, at foreground size: `msgstr`.
Beside it on the ground, a faint debossed impression of the same word
the right way round, as if it had been pressed once. Small serif
lockup at the bottom, a review-quote flash at the top left, the top
right clear blue.

### 4 · Console, late 1980s

A heroic town crier on a stone step, painted in airbrush, 0.75 of the
height tall with the head at 0.18 of the height and the centre at
0.40 of the width, one arm raised with a scroll unrolling to the right
edge. On the scroll, the same short line written five times in five
scripts, one below the other, the top one legible at foreground size
— `gettext("Hello")` — and the four below rendered as lettering
shapes. Behind, a crowd painted as a gradient of upturned faces to the
horizon at 0.70 of the height. Extruded lockup across the bottom
fifth; the badge as a small UPC block at the top right; the top left
quadrant a calm painted sky.

### 5 · CD-ROM, early 1990s

A chrome globe, 0.65 of the width across, centred at 0.50 of the
width and 0.45 of the height, its meridians extruded as bevelled
metal ribs, floating over a perspective grid that runs to a starfield
horizon at 0.70 of the height. Around the equator, a ring of
extruded metallic lettering orbits the globe, the front word legible
at foreground size — `GETTEXT` — and the rest curving away into
rainbow specular edges. One lens flare at the upper right rim.
Chrome lockup across the bottom, a security hologram badge at the
top left, top right the starfield.

### 6 · Big box PC, ~1992-96

A scriptorium at night in oil: one candle at the lower left lights a
slanted desk that fills the middle of the frame, and on it an open
ledger 0.70 of the width across at 0.55 of the height. The left page
carries one line of illuminated lettering at foreground size —
`msgid` — and the right page the same line begun in another hand, the
quill still on it, ink wet with a specular point. Behind the desk,
shelves of bound volumes carried down into the shadow with every
spine detailed, the nearest spine reading `errors.po` at small size.
Extruded fantasy lettering across the bottom fifth with a hard bevel,
lit by the candle; a disk-format flash at the top right; the top left
the dark of the room.

## The recommendation

**1, the early carton.** Gettext is a card index — an id, a
translation, a drawer per locale — and the carton era is the one
that draws apparatus as apparatus, with the two words the mechanism
actually uses set in type and the blank `msgstr` line saying what the
project still has to do. The other five have to dress a filing
system as a crier or a globe.

The shelf as it stands: clustering manual from a home-computer start;
healthcheck2 manual from an editorial start; exdebug console; exdoc
big box; ash big box; coveralls, healthcheck and enhancements starting
over. The carton has no cover yet; this would be its first. The
mailer's proposals recommend editorial, so the two neighbours would
not double up.

## The choice

—
