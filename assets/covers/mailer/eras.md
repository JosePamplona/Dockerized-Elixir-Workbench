# mailer — six proposals

Written from the cartridge's README and DESIGN.md and nothing else. The
era block of the winner goes into `cover.prompt.txt` verbatim; what
follows is the hero paragraph each era would put in it.

## The register

**Clerical** — the mechanism keeps the ledger: every letter composed is
accounted for, and in development none of them leaves the building.
Three counters for three environments — the `Local` adapter that keeps
the mail and shows it at `/dev/mailbox`, the `Test` adapter that files
it for the assertions, the production adapter the project names — and
one module, `Mailer`, behind all three. Subtitles file. Added for this
cartridge: none of the landmarks has the mechanism *holding* what it is
given.

Title `MAILER`. Subtitle `EVERY LETTER KEPT` — what the dev mailbox
does, and the promise of the test adapter. Badge `DEV · TEST · PROD`:
the three adapters, which is the fact the design states about where
the cartridge lives. Accent **postal red** or the era's nearest: the
one colour a post office owns, unused on the shelf. No furniture
unless the era's own column has one.

The counts that are true: **one** module; **seven** files changed and
**one** created; **two** dependencies; **three** adapters; **one**
route, forwarded. The strings a hero may carry at foreground size, one
per hero: `/dev/mailbox`, `Mailer`, `deliver`, `Swoosh`. Where three
things appear they are the three counters; where one, it is the
mailbox.

## The six heroes

### 1 · Early carton, ~1978-82

A schematic of a sorting office in two spot colours on the paper's
tooth: one envelope drawn as a line diagram at the centre, 0.55 of the
width across, its flap open, and from it three dotted routes drawn
with a ruler to three pigeonholes along a shelf at 0.30 of the height
from the top edge, each pigeonhole labelled in hand-set grotesque
caps `DEV`, `TEST`, `PROD` at foreground size, the first holding a
stack of envelopes, the second a single envelope with a tick, the
third empty with its route drawn through the shelf and off the right
edge. Flat ground of the paper colour; the second spot colour is the
envelope's border and the routes. The lockup takes the bottom fifth in
the same grotesque, the badge sits at the top left corner as a
stamped lot mark, and the top right quarter is bare paper.

### 2 · Home computer, ~1982-85

A grid floor receding to a horizon at 0.40 of the height. Standing on
it, a mailbox on a post — the flag up, painted flat red with a heavy
black outline — 0.60 of the height tall, its centre at 0.55 of the
width and 0.62 of the height. Three envelopes hover above it in a
column, airbrushed white with hard black edges, each smaller than the
one below, rising toward a flat cyan sky that is empty from 0.35 of
the height to the top edge. Slab lettering `/dev/mailbox` across the
mailbox's side at foreground size. The lockup along the bottom in
slab caps, the badge at the top left as a compatibility strip, the
top right an empty field of the sky's cyan.

### 3 · Editorial cover, mid-1980s

One object on an even ground of postal red: a single cream envelope,
centred, photographed straight on and lit from the upper left, 0.50 of
the width across at 0.50 of the height, its flap closed by a small
round wax seal in the ground's own red — so the seal reads as a
deboss, not a spot. Nothing else on the ground. The envelope carries
one line of small serif type where an address would go: `Mailer` at
foreground size and no more. The lockup is set small in serif at the
bottom, the badge as a bookshop price sticker at the top left, the
top right a clear field of red.

### 4 · Console, late 1980s

A heroic mail carrier in airbrushed profile striding out of a sorting
hall, 0.75 of the height tall with the head at 0.20 of the height and
the centre at 0.45 of the width, a leather satchel over the shoulder
bursting with three envelopes that catch a hard specular highlight
each. Behind, receding to the right, a wall of pigeonholes in airbrush
gradients, three of them lit from within — top left, centre, bottom
right. Lettering `DELIVER` painted along the satchel's strap at
foreground size. The lockup fills the bottom fifth in extruded caps,
the badge at the top right as a `2ND PRINT` band, and the top left
quadrant is the hall's dark ceiling, calm.

### 5 · CD-ROM, early 1990s

A chrome envelope the size of a starship, 0.70 of the width across,
banking up and to the right with its centre at 0.50 of the width and
0.48 of the height, its flap open and throwing a lens flare from the
upper right edge. Below it a perspective grid rolls to a starfield
horizon at 0.65 of the height; three chrome pipes rise from the grid
at 0.20, 0.50 and 0.80 of the width and end at the envelope's
underside. Extruded metallic lettering `SWOOSH` across the envelope's
face at foreground size, bevelled, rainbow on the edges. The lockup
in the same chrome across the bottom, the badge as a security
hologram at the top left, the top right the starfield alone.

### 6 · Big box PC, ~1992-96

A night sorting office painted in oil: one lamp, upper left, lighting
a long oak counter that runs from the left edge to 0.85 of the width
at 0.60 of the height. On it, three brass letter trays in a row at
0.25, 0.50 and 0.75 of the width — the first heaped with sealed
letters, the second holding one letter with a red wax seal, the third
empty and gleaming — and behind them, dissolving into the shadow, a
wall of pigeonholes carried down into the dark with every one
detailed. A single letter, mid-air, falling toward the first tray at
0.35 of the width and 0.35 of the height. Extruded fantasy lettering
`MAILER` across the bottom fifth with a hard bevel, lit by the lamp;
the badge as a requirements flash at the top right; the top left
holds the lamp's glow and nothing else.

## The recommendation

**3, the editorial cover.** This cartridge is one module and the
promise that nothing leaves: one envelope, sealed, on a ground of one
colour, is the mailer in the dev environment exactly — kept, whole,
and shown to whoever opens the mailbox. Every other era has to
*invent* motion (routes, a carrier, a starship) for a mechanism whose
whole point in the workbench is that the letters stay put.

The shelf as it stands: clustering manual from a home-computer start;
healthcheck2 manual from an editorial start; exdebug console; exdoc
big box; ash big box; coveralls, healthcheck and enhancements starting
over. Editorial has one manual descendant and no printed cover; big
box has two. Early carton and CD-ROM have none — 1 would be the
carton's first, and its sorting schematic is honest to the three
adapters, if the envelope alone is judged too still.

## The choice

—
