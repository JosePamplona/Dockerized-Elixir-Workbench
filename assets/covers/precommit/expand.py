# precommit's expansion, made by hand from art/hero.jpg: no second turn.
# Each margin repeats the hero's own edge row or column outward. For the
# manual hero, a door, that carries the vertical wood grain, the jamb and the
# dark gap straight on to the top and the foot, and every pixel it smears falls
# under the board: pad's margins are 124 above and 66 below, the band's and the
# strip's 124 and 65. Written first for the editorial take, whose margins were
# two flat fields; the same repetition serves both, and neither can be
# repainted by a generator turn.
#
#     python3 assets/covers/precommit/expand.py <padded.jpg> <hero.jpg> <out.jpg>
import sys

from PIL import Image

pad_path, hero_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
OX, OY = 19, 124  # covers.py pad's placement of this hero in the 863x1214 canvas

hero = Image.open(hero_path).convert("RGB")
out = Image.open(pad_path).convert("RGB")
hw, hh = hero.size
W, H = out.size
px = out.load()

# The side slivers of the window: the hero's own edge columns, row by row.
for y in range(hh):
    left, right = hero.getpixel((0, y)), hero.getpixel((hw - 1, y))
    for x in range(OX):
        px[x, OY + y] = left
    for x in range(OX + hw, W):
        px[x, OY + y] = right

# Above and below the window: the full rows just completed, to the edges.
for x in range(W):
    top, bottom = px[x, OY], px[x, OY + hh - 1]
    for y in range(OY):
        px[x, y] = top
    for y in range(OY + hh, H):
        px[x, y] = bottom

out.save(out_path, quality=95)
print(f"wrote {out_path}: {W}x{H}, the hero's edges carried out under the board")
