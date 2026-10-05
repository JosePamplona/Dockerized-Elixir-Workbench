# test_data's expansion, made by hand from art/hero.jpg: no second turn.
# The editorial hero's margins are one even warm grey field on all four
# edges (about 202,194,186), which a generator turn could only repaint;
# each margin repeats the hero's own edge row or column outward instead.
# The chain's outer hands stop 42px from the hero's sides, so the side
# slivers carry ground only. Same recipe as precommit's expand.py.
#
#     python3 assets/covers/test_data/expand.py <padded.jpg> <hero.jpg> <out.jpg>
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
