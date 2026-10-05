# ash — six proposals

Written from the cartridge's README and DESIGN.md and nothing else.
The era block of the winner goes into `cover.prompt.txt` verbatim;
what follows is the hero paragraph each era would put in it.

What the mechanism does: it takes an order — a data layer, the APIs,
the authentication strategies, whatever else from the site's catalogue
— and writes **one line**, `mix igniter.install ash ash_postgres
ash_phoenix … --yes`, which it hands to Igniter. Igniter fetches the
packages and each package's own installer builds its part: the repo,
the config, the `Accounts` domain with `User` and `Token`, the
migrations. The cartridge builds nothing itself and second-guesses
nothing the builders do. What goes wrong without it is a day of
reading and hand-editing; what went wrong *with* it, once, was a
builder that stopped to ask a question nobody was there to answer
(`Run the installer now? [Yn]`) — fixed by the order of the line.

## The register

**Commissioning** — the mechanism builds to your specification: you
say what, it decides how, and the builders are its own. Subtitles
specify. Added for this cartridge; no medium in it.

Title `ASH`. Subtitle `SAY WHAT. NOT HOW.` — the specification, and
the promise the one line makes. Badge `EXISTING APP`: the shelf's
badges say where a cartridge lives (`PROD ONLY`, `EVERY ENV`), and
this one lives in the site's *Existing App* tab — a project that
already exists gets the framework put into it. Accent **ember**
(#FF5A1F or the era's nearest): what the name says, and unused on the
shelf, whose accents so far are chrome, signal green and gold. No
furniture unless the era's own column has one that says something
about the feature. No version, no date: the back's.

The counts that are true: **one** line; **three** choices on the
order (data layer, APIs, authentication) and **one** open list
(`--with`); **two** packages always in (`ash`, `ash_phoenix`);
**six** builders on the verified run (`ash`, `ash_postgres`,
`ash_phoenix`, `ash_json_api`, `ash_authentication`,
`ash_authentication_phoenix`); **two** migrations out of it; **zero**
files written by the cartridge itself (one variable in `.env`). The
strings a hero may carry at foreground size, one or two per hero:
`mix igniter.install`, `ash`, `--yes`, `[Yn]`, `Accounts`, `User`,
`Token`. Small print is texture, never fact: a printed tape is *a
line of type*, never its characters.

The hero is 4:5 and is the window; the overlay's board covers the
top tenth and the bottom twentieth of the finished face, outside the
hero. Inside the hero the lockup takes the bottom fifth, the badge a
top corner, and the other top corner keeps a quarter-disc of calm for
the seal — each hero says which. Every position is measured from the
edges of the hero.

## The six heroes

### 1 · Early carton, ~1978-82

A technical schematic in two spot colours on cream uncoated board,
the cream continuing to all four edges. Across the upper half, drawn
in line, the front panel of a specification machine: three rotary
selectors in a row, their centres at a quarter, a half and three
quarters of the width and all at three tenths of the height down,
each a sixth of the width in diameter, drawn as a dial with a pointer
and eight tick marks round it, the pointer of each set to a different
tick. Under the row of dials, centred on the width with its top edge
at half the height down, a horizontal output slot a third of the width
wide, drawn as a double rule, and coming out of it and hanging down
one printed paper tape a twelfth of the width wide, running straight
down to two thirds of the height, where it curls once to the right.
On the tape, set along it in the second spot colour in plain
typewriter capitals at foreground size, the one line
`mix igniter.install ash`. To the right of the tape's curl, small,
six identical square outline stamps in a stack, each a twentieth of
the width, the stamps a builder's mark and nothing written in them.
The upper right corner of the hero is bare cream to a quarter-disc a
fifth of the width in radius; the badge sits in the upper left as a
hand-set line of the same typewriter capitals. Hairline leader lines
from the dials to the left margin, ending in short rules. Furniture:
a lot number hand-stamped in violet ink low on the left edge, five
characters as a shape.

### 2 · Home computer, ~1982-85

A receding grid floor in one hard ember colour over black, the horizon
at three fifths of the height down and the grid converging on a point
centred on the width. On the floor, centred on the width, a tower of
six identical square crates stacked straight up, each a sixth of the
width wide, in one flat ember with heavy black outlines, the bottom
crate resting on the floor at seven tenths of the height down and the
top crate's top at a quarter of the height. On the top crate, in
geometric slab capitals at foreground size, the one word `ash`. To
the left of the tower and to the right of it, three each, six blocky
builder robots of the same height as one crate, in one flat pale
colour with heavy black outlines, each with one arm raised toward the
tower, the six identical to the last line. Above the tower, floating,
one flat rectangular screen twice a crate's width and half its height,
its lower edge at a sixth of the height down, showing in the same slab
capitals the line `--yes`, and a hard-edged beam of the ember colour
going from the screen straight down onto the top crate. The upper
right corner of the hero is bare black to a quarter-disc a fifth of
the width in radius; the badge is a strip of the slab capitals in the
upper left. Furniture: a compatibility strip along the left edge,
three format marks as shapes.

### 3 · Editorial cover, mid-1980s

An even ground of one pale colour — bone — from edge to edge, and one
object on it, centred on the width with its centre nine twentieths of
the height down: a typed order card, the kind a workshop keeps on a
spike, seen straight on and turned two degrees off square, two fifths
of the width wide and a third of the height tall, lit from the upper
left so its left edge holds one thin line of shadow and its face is
lit evenly. On the card, typed in a small serif face at foreground
size, three lines flush left with a ruled line under each:
`postgres`, `json_api`, `password` — the order as it was placed, and
nothing else on the card. Through the card's top edge, centred, one
brass spike, a twentieth of the width tall, casting one short shadow
down the card. Below the card, on the bone ground, a single brass
stamp lying flat with its face up, a sixth of the width wide, its
rubber reading in reverse the one word `ash`, and beside it on the
ground the same word stamped once in ember ink, upright, at foreground
size. Generous ground on every side. The upper right corner of the
hero is bare bone to a quarter-disc a fifth of the width in radius;
the badge is a line of small serif capitals in the upper left. A
subtle deboss on the card's outline. Furniture: none.

### 4 · Console, late 1980s

A construction site at dusk, airbrushed with hard gradients, on a
ground of deep steel blue that goes to near-black at the bottom edge.
Rising through the centre of the hero, a steel tower under
construction, its base at four fifths of the height down and its top
girder at a sixth of the height, a third of the width wide, riveted,
with six yellow construction cranes around it — three on the left and
three on the right, their booms all swung in toward the tower and each
holding one girder — every crane airbrushed with one chunky specular
highlight along its boom. On the tower's top girder, a lit sign in
bold squared capitals at foreground size, glowing ember: `ash`. In
the lower left, standing on a platform with the top of the hard hat at
three fifths of the height down, one foreman in coveralls seen from
the side, one hand on a control lever pulled toward them and the other
arm raised, pointing up at the sign, in the stiff heroic stance of the
era, the sign's glow on the face and on the hat. The upper right corner
of the hero is bare sky to a quarter-disc a fifth of the width in
radius; the badge is a strip of the squared capitals in the upper
left. Furniture: a `2ND PRINT` band as a shape across the lower right,
its lettering at foreground size.

### 5 · CD-ROM, early 1990s

An airbrushed starfield on black with a perspective grid in one
saturated ember on the lower half, its vanishing point centred on the
width at half the height down. From the lower left corner of the hero
a chrome tape — a ribbon of polished metal a tenth of the width wide —
runs up and across the picture in one sweeping curve to the upper
right, catching rainbow specular edges along both sides, and along it,
extruded metallic capitals with deep bevels spell the one line
`mix igniter.install`, the letters standing off the tape and catching
the same light. Where the tape passes the centre of the hero it
threads through six chrome rings, evenly spaced along it, each a
twelfth of the width in diameter, each ring a builder. One lens flare
where the light hits the tape at a third of the width and a third of
the height down. The upper right corner of the hero is bare starfield
to a quarter-disc a fifth of the width in radius, the tape ending
short of it; the badge is a chrome plate in the upper left with its
lettering bevelled. Furniture: an award flash as a shape in the lower
right.

### 6 · Big box PC, ~1992-96

A great workshop at night in deep chiaroscuro, oil-painted, detail
carried down into the shadow: benches, tools hung on the walls, a
forge glowing at the far right edge. In the centre of the hero, seen
from behind and a little to the left with the head at a third of the
height down, one patron in a long coat holding out a rolled
specification — a sheet of parchment unrolled in both hands, lit from
the forge, its face toward the viewer and blank but for one line of
engraved-looking capitals at foreground size: `ash`. Facing the
patron across a bench, six craftsmen in leather aprons in a row, the
nearest at half the width and the farthest into the dark at the right
edge, each holding one tool raised — a hammer, a square, a caliper, a
chisel, a file, a brush — their faces lit from the parchment and the
forge, the light dying into the dark before it reaches the edges of
the hero. Behind them, half-built and half in shadow, a machine of
brass and iron rising to the top of the picture. The ground where the
light does not reach is near-black with a violet cast. The upper right
corner of the hero is dark, empty rafters to a quarter-disc a fifth of
the width in radius; the badge is a plate of extruded fantasy
lettering with a hard bevel in the upper left. Furniture: a
requirements flash as a shape in the lower right.

## The recommendation

**1**, the early carton. The reason is in the cartridge: everything
this mechanism produces is *one printed line* — it maps the order to a
command and hands it over, and writes nothing else. The two-colour
offset era is the one entry of the six that prints rather than paints,
and its schematic — three selectors, one slot, one tape with the line
on it, six blank stamps waiting beside it — says the whole design as a
drawing with no figure: options in, one command out, the builders'
work not shown because the cartridge does not do it. The heroes with
builders (2, 4, 6) all say "six build it" well; only the schematic
says "and this is all the cartridge is".

Runner-up **2**: the tower of six crates and the six builders say the
other half — Igniter's installers doing the work — and the shelf's
only home-computer row is a manual hero that started from that era
rather than a prompt made in it.

The shelf, era column as it stands (2026-08-28):

| Cartridge | Era |
| --- | --- |
| clustering | manual — from proposal 2 (home computer) |
| coveralls | *starting over* |
| healthcheck | *starting over* |
| healthcheck2 | manual — from proposal 3 (editorial cover) |
| exdebug | console, late 80s |
| exdoc | big box PC, mid 90s |
| enhancements | *starting over* |

Early carton and CD-ROM have no row yet; console and big box one
each; home computer and editorial one each, both manual. No era is
running three in a row.

## The choice

**6**, the big box PC (2026-08-28). The user's; against the
recommendation — the workshop with the patron's specification and the
six craftsmen is the commissioning stance drawn as a scene, the
builders in the picture and the order in the patron's hands. The
five that lost stay above. In the prompt the parchment carries the
line `mix igniter.install` rather than `ash` — the order is one line,
and the title already says the name — and the requirements flash was
left out: the lower fifth is the lockup's, and the scene has enough
to get right.
