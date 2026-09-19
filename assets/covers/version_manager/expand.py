# version_manager's expansion, made by hand from art/hero.jpg (front.md: a hero
# whose margins are flat colour gets no second turn). Flat cream above, flat
# black below; at the sides the hero's own 3px black rules are painted over and
# the floor's grid lines run on to the edge of the face at their own slope.
import sys
from PIL import Image
hero_path, out_path = sys.argv[1], sys.argv[2]
OX, OY, CW, CH = 19, 124, 863, 1214          # covers.py pad's placement for this hero
RULE = 5                                       # the rule and its antialiased column
hero = Image.open(hero_path).convert('RGB'); W, H = hero.size
src = hero.load()

def lines(xa, xb):
    """The blue runs crossing column xa, each with its slope toward xb."""
    def runs(x):
        out, start = [], None
        for y in range(550, 1000):
            r, g, b = src[x, y]; blue = b > r + 35 and b > 90
            if blue and start is None: start = y
            if not blue and start is not None: out.append((start + y - 1) / 2); start = None
        return out
    a, b = runs(xa), runs(xb)
    return [(ya, (yb - ya) / (xb - xa), ) for ya, yb in zip(a, b)]

BLUE, BLACK = (66, 101, 128), (1, 1, 1)
canvas = Image.new('RGB', (CW, CH)); canvas.paste(hero, (OX, OY)); px = canvas.load()

def side(xa, xb, xs):
    ls = lines(xa, xb)                         # ordered top to bottom at xa
    assert len(ls) == len(lines(xa, (xa + xb) // 2)), "lines cross between the samples"
    for x in xs:                               # hero coordinates, may be outside it
        top = ls[0][0] + ls[0][1] * (x - xa)   # the first line is the wall's foot
        for y in range(H):
            if y < top - 1.5:              # the wall: as the hero has it, its tone near the foot
                c = src[xa, y] if y < ls[0][0] - 12 else src[xa, int(ls[0][0]) - 12]
            else:
                c = BLACK
                for ya, m in ls:
                    d = abs(y - (ya + m * (x - xa)))
                    a = max(0.0, min(1.0, 2.0 - d))
                    if a: c = tuple(round(c[i] * (1 - a) + BLUE[i] * a) for i in range(3))
            if 0 <= x + OX < CW: px[x + OX, y + OY] = c

side(RULE + 1, RULE + 19, range(-OX, RULE + 1))
side(W - RULE - 2, W - RULE - 20, range(W - RULE - 1, W + (CW - OX - W)))
# the hero's lighter first rows, then above and below: the rows at hand, repeated
row = canvas.crop((0, OY + 2, CW, OY + 3))
# the wall's corner line reaches the hero's top edge; above it the margin is the
# flat wall alone, or the line shows as a tick over the banner's band
lp = row.load()
for x in range(CW):
    if sum(lp[x, 0]) < 600: lp[x, 0] = lp[x - 8, 0] if x > 8 else lp[x + 8, 0]
for y in range(OY): canvas.paste(row, (0, y))
for y in range(OY, OY + 2): canvas.paste(canvas.crop((0, OY + 2, CW, OY + 3)), (0, y))
row = canvas.crop((0, OY + H - 1, CW, OY + H))
for y in range(OY + H, CH): canvas.paste(row, (0, y))
canvas.save(out_path, quality=95)
