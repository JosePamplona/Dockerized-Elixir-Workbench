# test_doubles — six proposals

Written from the cartridge's NEED.md first, then its README and
DESIGN.md, and nothing else. The era block of the winner goes into
`cover.prompt.txt` verbatim; what follows is the hero paragraph each
era would put in it.

## The need

*Your tests must not call the real thing.* Before: tests that reach the
network, or `with_mock` replacing `File` for the whole VM, which costs
the suite its `async: true`. After: Mox for the service you own a
contract with, Mimic for the module that is not yours — mocks, stubs
and spies, each where it belongs.

## The register

**Understudy** — the mechanism sends in a stand-in that plays the part
exactly, so the real one is never called and nothing is at risk.
Subtitles substitute (`NEVER THE REAL ONE`). Added for this cartridge:
*rehearsing*, mailer's, lets you run the real thing with nothing at
stake — the letter is really sent, it just goes nowhere. Understudy is
the other half of that: the real one is not run at all. Somebody else
walks on wearing its face, and the performance is identical.

Title `TEST DOUBLES`. Subtitle `NEVER THE REAL ONE`. Badge `2 DOUBLES`
— the box's own count, the values of its option — in the era's own
lettering. Furniture from the era's own column where it fits.

## The picture's metaphor

The **stand-in**, which is where the cartridge's own name comes from: a
test double is what walks on in the real one's place, and the real one
is never called. The cast is three bodies, and the third is the box's
whole content — there are two ways to get a double, and they are not
the same thing:

* **the real one**, present, untouched, and never reached;
* **the copy**, taken from the real one's own body, which is what
  Mimic does to a module that is not yours;
* **the one built to a written specification**, which is what Mox
  does — it never touches the original, it makes a new body that
  answers to the same contract.

No hero names Mimic or Mox, and none draws a real project's mark: the
three plates say what each body *is*, in the developer's words. Every
string is at foreground size. Nowhere is there a version or a date.

## The six heroes

### 1 · Early carton, ~1978-82

A flat two-colour schematic drawn in black line on an even ochre
ground: three identical mannequin figures standing in a row on one
straight baseline drawn across the image at 0.74 of the height, each
figure half the image height tall, their centres at 0.22, 0.50 and 0.78
of the width. The figure at 0.22 is filled solid in the ochre's second
spot colour and stands behind a straight vertical bar drawn from the
baseline up to 0.18 of the height; the two others are open outline,
head a plain circle, drawn in black line only. One straight line runs
from the upper left corner of the image down to the chest of the figure
at 0.50 and ends there in a solid arrowhead. Under the baseline, three
small square plates at 0.82 of the height, centred under their figures,
hand-set in plain grotesque capitals at foreground size: `THE REAL
ONE`, `COPIED`, `BUILT TO SPEC`. The top right of the image is an even
field of the ochre with nothing drawn on it.

Furniture: a lot number hand-stamped in ink at the right edge, its
centre at 0.30 of the height. Seal corner: top right.

### 2 · Home computer, ~1982-85

A receding grid floor of thin cyan lines on black filling the image
from the bottom edge up to a horizon at 0.42 of the height, and above
the horizon one flat field of deep magenta to the top edge. Standing on
the grid, three identical humanoid robots with heavy black outlines,
each a third of the image height tall, their centres at 0.20, 0.47 and
0.74 of the width and their feet at 0.80 of the height. The robot at
0.20 stands inside an upright glass tube that runs from the floor up to
0.30 of the height, and is painted flat dark blue with no highlight.
The two others are painted flat white with hard cyan edges, square to
the viewer. One straight cyan beam runs from the upper left corner of
the image to the chest of the robot at 0.47. Flat on the grid at 0.88
of the height, three slab-lettered plates centred under their robots at
foreground size: `THE REAL ONE`, `COPIED`, `BUILT TO SPEC`. The top
right of the image is the flat magenta field with nothing on it.

Furniture: none — the era's hand-written shop price would land in the
same top band the badge takes. Seal corner: top right.

### 3 · Editorial cover, mid-1980s

An even ground of deep slate grey, edge to edge, lit softly from the
upper left. Centred on it, three identical black bakelite telephone
handsets lying side by side in a row, seen from directly above, each a
fifth of the image width long, their centres at 0.26, 0.50 and 0.74 of
the width and all three at 0.48 of the height, a hand's breadth apart,
each casting one soft shadow to the lower right. From the handset at
0.26 a braided cord runs to the right and leaves the image at the right
edge at 0.40 of the height. From each of the other two an identical
braided cord curls once and ends in a brass plug lying loose on the
ground below it, at 0.62 of the height. Under each handset, small serif
capitals debossed into the ground at 0.68 of the height at foreground
size: `THE REAL ONE`, `COPIED`, `BUILT TO SPEC`. Generous even ground
above and below, the top right an unbroken field of the slate.

Furniture: a small white oval bookshop price sticker at the left edge,
its centre at 0.24 of the height, printed `4.95` at foreground size.
Seal corner: top right.

### 4 · Console, late 1980s

A hangar interior in painted airbrush, its dark ribbed rear wall
filling the upper half and its pale floor the lower. Centred at 0.55 of
the width, a broad-shouldered figure in a white flight suit and a
mirrored gold visor stands square to the viewer, arms at their sides,
head at 0.32 of the height and boots at 0.86, occupying the middle
third of the width. Behind and to the left, its centre at 0.17 of the
width, a tall glass capsule stands on the floor from 0.82 of the height
up to 0.20; inside it an identical figure in the same suit stands
motionless, lit dim blue, and a stencilled plate on the capsule's base
at 0.78 of the height reads `THE REAL ONE` at foreground size. At 0.86
of the width, a third identical figure in the same suit steps forward
out of a doorway of white light, its head at 0.38 of the height. One
amber lamp burns on the rear wall at 0.72 of the width and 0.10 of the
height. The top left of the image is dark ribbed wall with nothing on
it.

Furniture: a half-peeled `$49.95` sticker at the right edge, its centre
at 0.46 of the height. Seal corner: top left.

### 5 · CD-ROM, early 1990s

An airbrushed starfield graded violet to black filling the image, with
a cyan perspective grid running from the bottom edge to a horizon at
0.46 of the height. Standing on the grid, three identical chrome
humanoid figures, each two fifths of the image height tall, their
centres at 0.20, 0.50 and 0.80 of the width and their feet at 0.82 of
the height. The figure at 0.20 stands sealed inside a smooth glass
cylinder. The figure at 0.50 is solid mirror chrome with rainbow
specular edges along its arms. The figure at 0.80 is chrome from the
waist down and an open cyan wireframe of the same shape from the waist
up; a flat sheet of glowing blue schematic lines hangs in the air
beside it at 0.90 of the width and 0.40 of the height, lettered `BUILT
TO SPEC` across its face at foreground size. One lens flare sits at
0.18 of the width and 0.16 of the height. The top right of the image is
the graded starfield with nothing in it.

Furniture: a small iridescent security hologram oval at the right edge,
its centre at 0.66 of the height. Seal corner: top right.

### 6 · Big box PC, ~1992-96

A vaulted stone workshop at night in dense oil paint, one lantern
hanging at 0.16 of the width and 0.12 of the height and lighting the
whole scene from there. Across the lower half, a heavy oak table runs
from the left edge to the right edge with its top at 0.66 of the
height. Lying on the table on its back, a life-size wooden artist's
mannequin, its head at 0.28 of the width and its feet at 0.56. Standing
upright on the same table at 0.78 of the width, a second mannequin of
the same size and the same wood, newly finished, its head at 0.34 of
the height; pinned to the stone behind it, a sheet of vellum at 0.90 of
the width and 0.30 of the height carrying a drawn figure and ruled
measurements, lettered `BUILT TO SPEC` at foreground size. Behind the
table at 0.46 of the width, in a shallow stone alcove running from 0.62
of the height up to 0.18, a suit of plate armour stands on its stand
with its visor down, lit only along one shoulder by the lantern's edge,
a brass plate at its foot lettered `THE REAL ONE` at foreground size.
The top left of the image is dark vaulting with nothing in it.

Furniture: a requirements flash as a small hard-edged shape at the
right edge, its centre at 0.52 of the height. Seal corner: top left.

## The recommendation

**3, the editorial cover.**

The reason is the cartridge's, not the style's. Everything this box
contains is a **distinction between two things that look alike**: a
copy taken from the original and a body built to a written contract
answer the same calls and are not the same thing, and the box exists
because the shelf spent years calling both of them "mock". The
editorial entry is the only one of the six that can set three
near-identical objects side by side, label each under it in small type,
and let the difference *be* the picture. Every other entry has to build
a scene around them — a hangar, a starfield, a workshop — and the scene
becomes the subject: the hero stops being about which double is which
and starts being about the lantern.

It is also the entry that does not need a figure, and this cartridge has
no protagonist. The developer is not in the picture on any of the six,
because the need is not something that happens to them on screen; it is
a decision they make about what their tests are allowed to touch.

**The shelf, as the era column stands.** Big box PC three (exdoc, ash,
versioning). Console two (exdebug, db_admin). Home computer one
(version_manager), and clustering's manual hero started there. **Early
carton and CD-ROM have never been chosen at all**, on any cartridge.
Editorial has been chosen twice — healthcheck2 and dashboard_extras —
and both times the generated take was continued by hand into something
else, so the shelf has no editorial cover that came off a prompt; that
is an argument to watch this one closely, not to avoid the era, and it
is the honest caveat on the recommendation above.

If the recommendation is refused, **1, the early carton** is the one I
would argue next, and for the same reason: it is the other entry that
draws a schematic rather than a scene, the three bodies are a diagram
there, and nothing on the shelf has ever come from it.

## The choice

**5, the CD-ROM entry** (2026-09-20). Editorial (3) was chosen first,
as recommended, and its prompt was written and generated; the take did
not read — the three handsets seen from above did not say *stand-in* to
the eye of whoever was looking, which is the judgement this guide does
not try to write down. The editorial prompt is superseded in
`cover.prompt.txt`; no take reached the repository, so there is nothing
archived.

What the failure says, and what the CD-ROM hero is written against:
**the era has to make the three bodies read as bodies**. Editorial's
restraint put the whole burden of the idea on three small debossed
captions under three objects that are not figures, and an object lying
flat is not somebody standing in for somebody else. The CD-ROM entry
draws figures, and three chrome figures — one sealed away, one a solid
mirror, one half-built out of its own plan — carry the distinction in
the bodies themselves, before a single word is read.

The four that lost stay above: a regeneration that wants another era
starts from them.

Writing the prompt moved four things of the proposal, and the proposal
above is left as it was written:

* **The three plates come back.** The proposal had dropped them and
  left `BUILT TO SPEC` on the schematic sheet alone; the editorial take
  is the argument for lettering all three. They float as extruded
  chrome above the figures' heads at 0.30 of the height, which is the
  era's own idiom and keeps the bottom for the lockup.
* **The schematic sheet loses its lettering and gains an interior.** A
  sheet named and left blank is the container the record says comes
  back filled, so its face is described: fine ruled construction lines
  and small circles, edge to edge.
* **The lens flare comes down off the corner**, to 0.30 of the width and
  0.38 of the height, just above the horizon: the top left is the
  badge's and the top right has to stay quiet for the seal.
* **The second turn is sent.** Unlike the editorial hero, these margins
  have something in them to continue — the grid's lines, the horizon,
  the graded starfield — so the foot of `cover.prompt.txt` carries the
  expansion turn rather than a note about doing it by hand.

Title `TEST DOUBLES`. Subtitle `NEVER THE REAL ONE`. Badge `2 DOUBLES`,
top left. Furniture: a security hologram, the era's own. Seal corner:
top right.
