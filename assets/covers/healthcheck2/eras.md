# healthcheck2 — six proposals

Written from the cartridge's README and nothing else. The era block of
the winner goes into `cover.prompt.txt` verbatim; what follows is the
hero paragraph each era would put in it.

## The register

**Laconic** — the mechanism answers the one question it is asked, in
as few words as it can, and nothing more. Two routes, two questions —
*are you alive? can you take traffic?* — and one word back for each:
`ok`, or `unavailable`. No JSON, no versions, no session, no log line.
Subtitles answer.

Title `HEALTHCHECK II` — the sequel numeral is how every one of these
eras wrote a 2 on a box, and this cartridge is the second healthcheck
on the shelf. Subtitle `ALIVE. READY.` — the two answers, in the order
the platform asks them, and nothing after. Accent **signal green**
(#33FF66 or the era's nearest): the colour of a 200, and unused on the
shelf so far. Badge `EVERY ENV`: the shelf's badges say where a
cartridge lives (`PROD ONLY`, `DEV & TEST`), and this one is the same
plug in dev, test and the release. No furniture unless the era's own
column has one that says something about the feature.

The counts that are true: **two** routes; **one** query, `SELECT 1`;
**one** second before readiness gives up; **nine** plugs in a
production endpoint, this one **first**; **zero** dependencies. The
strings a hero may carry at foreground size, one per hero: `ok`,
`unavailable`, `SELECT 1`, `/health/live`, `/health/ready`, `200`,
`503`. Where two things appear, they are the two questions: something
that only says *here* and something that says *come in*.

## The six heroes

### 1 · Early carton, ~1978-82

Hero illustration, a technical schematic in one spot colour on the
uncoated board: one straight vertical line ruled down the exact centre
of the image from the top edge to the bottom edge, and strung on it
nine identical small squares in outline, evenly spaced, the first a
tenth of the height of the image from the top edge and the last a
tenth from the bottom edge. The first square alone is a flat field of
the spot colour; the other eight are empty outline. From the right
side of that first square one straight horizontal line is ruled to the
right edge of the image and ends in an arrowhead at the edge. Beside
the arrow, above the line, in the era's plain hand-set grotesque at
foreground size, the word `ok`. The board is the even cream of the
stock to all four edges, and the top left of the image is the bare
stock, calm.

### 2 · Home computer, ~1982-85

Hero illustration: a receding grid floor in the era's hard-edged
palette, its horizon at two fifths of the height of the image, and
standing on it at the centre one black door frame with no wall around
it, two fifths of the height of the image tall, its door swung open
toward the viewer, and through the opening one flat field of the
accent green where the grid would be. Beside the frame on its right,
at the height of a hand, one small square button on a black post,
lit in the same green. Painted on the lintel of the frame, in geometric
slab lettering at foreground size, the word `ok`. Wide empty fields of
flat colour above the horizon; the top left of the image an even field
of the sky colour, calm.

### 3 · Editorial cover, mid-1980s

Hero illustration: an even ground of one warm grey to all four edges,
and centred on it one brass desk bell — the domed kind with a button
on top, rung with one finger — seen straight on from slightly above,
lit from the upper left, a third of the width of the image across,
its dome throwing one soft shadow to the lower right. Engraved on the
front of the dome, in small serif capitals at foreground size, the
word `ok`. Nothing else on the ground; the top left of the image is
the same warm grey, calm.

### 4 · Console, late 1980s

Hero illustration: one chrome doorman robot standing at the centre of
the image, facing the viewer, half the height of the image tall, on a
steel floor that meets a riveted steel wall behind it at a third of
the height from the bottom edge. Its left arm hangs at its side; its
right arm is raised to shoulder height, the palm open toward the
viewer, and set in the palm one round green lamp, lit, the single
strongest light in the picture. Its visor is one horizontal slot lit
in the same green. On its chest plate, in the era's squared capitals
at foreground size, the word `ok`. The wall above the robot is even
steel to the top edge; the top left of the image is that steel, calm.

### 5 · CD-ROM, early 1990s

Hero illustration: an airbrushed starfield over a perspective grid,
the grid's horizon at two thirds of the height from the top edge, and
crossing the whole image one chrome line, from the left edge to the
right edge at half the height, flat and level except at the exact
centre, where it rises in one sharp spike to a quarter of the height
from the top edge and drops back — one beat. A lens flare sits on the
spike's tip. Along the flat line at the right, in extruded metallic
lettering with deep bevels and rainbow edges at foreground size, the
word `ok`. The starfield above the line is even to the top edge; the
top left of the image is starfield, calm.

### 6 · Big box PC, ~1992-96

Hero illustration: a stone gatehouse at night filling the lower two
thirds of the image, its arched gate open at the centre and the
portcullis drawn up into the arch, and on the wall above the arch one
watchman leaning out over the parapet, holding one lantern out at
arm's length toward the viewer — the lantern the single light source,
lighting his face from below, the stones of the arch, and the ground
before the gate, its glow green-white. Carved into the keystone of the
arch, in extruded lettering with a hard bevel at foreground size, the
word `ok`. Above the parapet the night sky is even to the top edge;
the top left of the image is that sky, calm.

## The recommendation

**3, the editorial cover.** The cartridge is one plug that answers two
one-word questions and does nothing else — no dependency, no
configuration, no body beyond `ok` — and the editorial era is the one
that composes with one object and the space around it. Every other era
has to add something the feature does not have: a robot, a gatehouse,
a grid. The desk bell is the whole mechanism: you ring it, it answers,
that is all.

The era column of the cover record as it stands: clustering *manual,
from the home-computer proposal*; exdebug *console*; exdoc *big box
PC*; coveralls, healthcheck and enhancements *starting over*. The
editorial entry is unused.

## The choice

First **6, the big box PC**, with two additions asked for at the
choice — the two routes shown, and compatibility with Kubernetes,
Fly.io and AWS ECS announced. One take was made and retired on taste
(`_archived/art/cover-1`); its facts are in the evidence table.

Then **3, the editorial cover**, carrying the same two additions in
the era's own form: the two routes engraved on the bell's base, and
the three platforms as one line of serif type under the subtitle, the
way a publisher's line sits under a title — the editorial column vetoes
any technical flash. Real marks are never asked of the generator; if
wanted after the take, they are composited.

Then **manual**: from the editorial take (`cover-2`) the hero was
remade in conversation with the generator, with no single prompt —
the ground turned to a dark plum leather, the three platforms got
their own marks drawn beside the names and again inlaid on the bell's
base, a cutaway window opened in the dome with callouts around it.
The image is the source now; `cover.prompt.txt` says so and logs what
is asked of it from here.

And once more, manual: the leather hero (`cover-3`) remade as a
technical drawing — an exploded view of the bell on graph paper
inside a drawing frame, the platforms as tables, callouts and stamps
as texture, a title block along the bottom. Logged as change 1 in
`cover.prompt.txt`.
