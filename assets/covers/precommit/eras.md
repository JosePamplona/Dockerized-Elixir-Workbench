# precommit — six proposals

Written from the cartridge's NEED.md first, then its README and
DESIGN.md, and nothing else. The era block of the winner goes into
`cover.prompt.txt` verbatim; what follows is the hero paragraph each
era would put in it.

## The need

*You want the checks to run before the commit exists, not after the
push.* Before: the build going red twenty minutes later over a file
nobody formatted, and no way to run the checks locally without an
Elixir on your machine. After: a hook that runs the project's own
checks in the project's own container, refuses the commit on the first
failure, and is a shell script you can read and reorder. Not for:
making anyone else run them — a hook lives in one clone and
`--no-verify` skips it.

## The register

**Scrupulous** — the mechanism holds back what you were about to send,
over something small you would rather it had not noticed, and it holds
it because you fitted it there and for nobody else. Subtitles halt
(`NOT YET`). Added for this cartridge. Its neighbours are not it:
*ominous* is a mechanism superior to the viewer, and this one obeys —
one word and it stands aside; *custodial* holds what you hand it and
gives it back, where this one refuses to take it at all; *deadpan*
documents apparatus, and this is not apparatus, it is a scruple with a
latch on it.

Title `PRECOMMIT`. Subtitle `NOT YET` — the design's thesis, which is
that the cheapest place to find it is before the commit exists.
Badge `4 CHECKS` — the box's own count, the values of its `--checks`
option — as plain lettering in the era's own type. No furniture unless
the era's own column has one.

The picture's subject is **a threshold in your own house**: something
finished is about to leave, and a small fitting *you* put there holds
it until it is right. Three things every hero keeps, because they are
what the need says and what the box is not:

* **The thing held is one**, and it is finished and about to go —
  a parcel, a packet, a letter, a crate. Not a heap, not a queue: one
  commit.
* **What stops it is small, hand-fitted and reachable** — a bar, a
  chain, a latch, a ring — and the person stopped can reach it. No
  uniform, no badge of office, no institutional guard, no barrier of
  authority: the moment it reads as somebody else's rule it is CI, and
  the NEED says that in its *Not for*.
* **The person is the one held**, not the one enforcing. Where there
  is a figure, it is the developer, stopped mid-motion and looking at
  what stopped them — never operating it, never fighting it.

No hero draws code, a terminal, a container, a whale, a cog or a
pipeline: the mechanism is not the subject, the doorway is. Lettering
only where a slot below asks for it, at foreground size.

## 1 · Early carton, ~1978-82

Hero, two-colour line work: a cross-section of a wall and the parcel
chute through it, drawn as a technical schematic, flat fields of one
spot colour on the paper's own tone. The wall runs as a hatched band
from 0.38 to 0.62 of the width, floor to ceiling. Through it a chute
falls from the upper left to the lower right; on its lip, halted, one
square parcel tied with string, its centre at 0.44 of the width and
0.46 of the height down, 0.20 of the width across, drawn in outline
with the string in the second colour. Across the chute's mouth, one
drop-bar in solid second colour, its centre at 0.52 of the width and
0.54 of the height down, 0.26 of the width long, its two pivots drawn
as small open circles. From the bar's left pivot a cord runs down and
left to a pull-ring at 0.22 of the width and 0.78 of the height down,
0.07 of the width across; a hand, drawn in the same plain outline,
holds the ring from the lower left, the wrist leaving the image at the
bottom edge. Below the chute's far end, past the wall, the opening it
would have fallen into is drawn as an empty outlined mouth at 0.74 of
the width and 0.70 of the height down. Four short leader lines, evenly
spaced, run from the bar out to the right and stop at plain filled
dots — no numerals, no callout text. The top fifth of the image is the
plain ground, unmarked.

## 2 · Home computer, ~1982-85

Hero, coarse airbrush over flat hard-edged fields: a grid floor in
thin bright lines on near-black, running from the bottom edge back to
a horizon at 0.58 of the height down, its lines converging at the
centre of the width. Standing on the grid, four vertical bars of hard
light span the path from left to right: their bases sit on the grid at
0.66 of the height down, each bar 0.05 of the width wide and 0.22 of
the height tall, their centres at 0.28, 0.42, 0.56 and 0.70 of the
width. Three of the bars are cyan; the second from the left is red,
and the red one throws a flat red wash on the grid under it. Before
them, a courier in black silhouette with a heavy outline, halted
mid-stride with the forward foot down and the weight still back:
figure 0.30 of the height tall, its feet at 0.80 of the height down,
its centre at 0.36 of the width, carrying a single flat parcel under
one arm that glows the same cyan. Above the horizon the sky is one
wide empty field of flat violet-blue to the top edge, and in it, small
and far off at 0.80 of the width and 0.30 of the height down, a single
red point with four short rays — the trouble that would have been
found twenty minutes away.

## 3 · Editorial cover, mid-1980s

Hero, one object lit carefully on an even ground: a brass door chain,
taut. The ground is one even mid-tone, cool grey-green, edge to edge,
lit softly from the upper left with no visible source and no texture
but the stock's. The chain hangs from a small brass plate at 0.30 of
the width and 0.30 of the height down, runs down and to the right in a
straight tight line — every link drawn, no slack anywhere — to its
knob at the end of a slotted brass plate at 0.68 of the width and 0.62
of the height down; the two plates and the chain together span 0.46 of
the width. The knob sits hard against the closed end of the slot,
which is the whole picture: the chain is at the end of its travel and
has stopped something. Along the chain's length a narrow warm
highlight; under the plates and the links, one soft shadow falling
down and to the right, close, as of an object a hand's width above the
ground. Nothing else is in the image: no door, no frame, no wall, no
second object. The top fifth and the bottom fifth of the image are
that same even ground, unbroken.

## 4 · Console, late 1980s

Hero, painted airbrush with hard gradients and chunky speculars: a
doorway of warm light in a dark blue-grey wall, and a sentinel before
it. The doorway is a tall rectangle of light, its centre at 0.58 of
the width and 0.52 of the height down, 0.30 of the width across and
0.56 of the height tall, its light spilling onto the floor in a
widening band. Standing in it, seen from the front at three-quarters,
an armoured figure in burnished steel, 0.62 of the height tall, its
feet at 0.86 of the height down, its centre at 0.56 of the width, one
gauntleted palm raised flat toward the viewer at 0.46 of the width and
0.44 of the height down — chunky white speculars on the knuckles, the
shoulder and the raised palm's edge. Facing it from the left
foreground, seen from behind, the developer halted a stride away: 0.40
of the height tall, feet at 0.90 of the height down, centre at 0.22 of
the width, a sealed crate held against the hip in both hands, the
crate 0.14 of the width across. Above the doorway, four round lamps in
a row across its head, evenly spaced, their centres at 0.50 of the
height down: three dark, the second from the left burning red. The top
fifth of the image is the unlit wall, one even dark field across the
whole width.

## 5 · CD-ROM, early 1990s

Hero, chrome and flare over an airbrushed starfield: a closed iris of
polished chrome, seen straight on, its centre at 0.50 of the width and
0.46 of the height down and its outer ring 0.62 of the width across,
its eight blades shut tight in the middle with a hairline seam. Around
the iris, a ring of four segment lamps set at the quarters — top,
right, bottom, left — each 0.09 of the width across: three burning
green, the top one red, and the red one throwing a rainbow specular
along the chrome beside it. In front of the iris and slightly below
it, one packet of light hangs waiting: a violet rectangular slab at
0.50 of the width and 0.74 of the height down, 0.18 of the width
across, seen at a slight angle, its edges rimmed white. Under
everything a perspective grid in thin cyan lines runs from the bottom
edge back to a horizon at 0.62 of the height down. A single lens flare
crosses the upper left, its centre at 0.24 of the width and 0.22 of
the height down. Above the horizon, an airbrushed starfield of deep
blue-black fills the top fifth of the image across the whole width.

## 6 · Big box PC, ~1992-96

Hero, dense oil painting in deep chiaroscuro, one light source: a
night corridor of old stone, and a chain across it. A single lantern
hangs from the left wall at 0.20 of the width and 0.24 of the height
down, its flame the only light in the picture, warm and low. Across
the corridor, at the height of a man's chest, one iron chain runs
taut from a ring in the left wall at 0.22 of the width and 0.54 of the
height down to a ring in the right wall at 0.80 of the width and 0.50
of the height down, each heavy link modelled in the lantern's light,
the whole span lit along its upper edge and lost in shadow beneath.
Stopped at the chain, seen from behind and slightly to the left, the
developer: 0.52 of the height tall, feet at 0.88 of the height down,
centre at 0.42 of the width, a wax-sealed packet held under the left
arm, 0.12 of the width across, the seal catching the lantern. Their
right hand is raised to the chain and rests on it, fingers curled
under a link — they could lift it themselves, and have not. Beyond the
chain the corridor runs on into darkness, its far end unlit and
detailed only in the deepest browns. The top fifth of the image is the
corridor's vaulted stone in shadow, carried across the whole width.

## The recommendation

**3 · Editorial cover.**

The reason is the box, not the look. Everything this cartridge
installs is *one small fitting on a door the developer already owns*:
the hook is theirs, it stops them and nobody else, and `--no-verify`
unhooks it. Of the six eras, the editorial entry is the only one whose
whole method is a single object, lit and given room — so it can draw a
thing that **stops** rather than a thing that runs, and a taut chain at
the end of its slot says *held* with no struggle in it. The other five
each have to supply an antagonist to carry the halt: a sentinel, a red
lamp, a flare, a barrier. The moment the halt has an antagonist, the
cover is about a rule somebody else imposed, which is the one thing the
NEED's *Not for* says this box is not.

The shelf, as the cover record stands: **big box PC** three times
(exdoc, ash, changelog), **console** twice (exdebug, db_admin), **home
computer** once (version_manager), three manual heroes (clustering off
proposal 2, health_probe off proposal 3, test_doubles off proposal 5)
and the shared `base` art. **Early carton has never been chosen, and
the editorial entry has never carried a front of its own** — health
probe's manual hero started from its proposal and left the era behind.
That is not why it is recommended; it is what the column says.

The near alternative is **1 · Early carton**, and its reason is also
from the box: what this cartridge hands the project is a *readable
file you can reorder*, and the carton era is the one that draws a
schematic rather than a scene. It is left as the alternative because a
schematic is a picture of the mechanism, and the heroes that went that
way drew the engine with nobody's problem in it.

## The choice

**3 · Editorial cover**, as recommended (2026-09-20) — and then **manual**, the same day: the hero the author made in conversation with the generator kept this proposal's subject, the chain at the end of its travel, and left the era behind. The editorial take it replaces is archived as `cover-2`, and `cover.prompt.txt` is a log of changes now, not a prompt. What follows is what was decided while the prompt was still one.

Writing the prompt moved three things of the proposal, and the
proposal above is left as it was written:

* **The plates are placed and measured, and the slot is given its
  angle.** The proposal named the chain taut and the knob at the end of
  its travel; the prompt gives the slotted plate the chain's own angle
  and the knob's rest against the closed end of it, since *held* has to
  be a position and not a movement — a dial told its needle had risen
  came back with the needle at rest in the wrong place.
* **No furniture.** The editorial column offers a bookshop price
  sticker or a review-quote flash, and the era's whole method is one
  object with room around it: the badge takes the top left, the seal
  the top right, the lockup the bottom, and a sticker would be the
  fourth thing in a picture whose argument is that there are two.
* **The badge is a flash without a box**: words on the ground under a
  thin brass rule. A rectangular flash *drawn as a rectangle* is the
  one shape this era does not print, and a named rectangle comes back
  drawn at an inset of the generator's choosing.
