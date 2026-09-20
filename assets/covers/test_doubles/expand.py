#!/usr/bin/env python3
"""test_doubles' expansion, made by hand from art/hero.jpg.

The hero is manual, and its margins are the case front.md names: the top
and bottom edge rows are one near-flat dark band (measured 2026-09-20:
stddev 6.9 and 3.9 over the 8 rows at each edge), so no second turn is
sent — a generator handed a flat field repaints it. The bridge's ceiling
runs on above and its floor below, each from the hero's own edge row; at
the sides, 19px of the hero's own edge columns carry the wall panels out
to the edge of the face.

    ./assets/covers/test_doubles/expand.py            # art/hero.jpg -> art/expanded.jpg
"""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
OX, OY, CW, CH = 19, 124, 863, 1214  # covers.py pad's placement for this hero

hero = Image.open(HERE / "art" / "hero.jpg").convert("RGB")
W, H = hero.size

canvas = Image.new("RGB", (CW, CH))
canvas.paste(hero, (OX, OY))

# The sides: the hero's own edge columns, repeated out to the face's edge.
left = hero.crop((0, 0, 1, H)).resize((OX, H), Image.NEAREST)
right = hero.crop((W - 1, 0, W, H)).resize((CW - OX - W, H), Image.NEAREST)
canvas.paste(left, (0, OY))
canvas.paste(right, (OX + W, OY))

# Above and below: the canvas row at each join, repeated to the edge.
top = canvas.crop((0, OY, CW, OY + 1)).resize((CW, OY), Image.NEAREST)
bottom = canvas.crop((0, OY + H - 1, CW, OY + H)).resize((CW, CH - OY - H), Image.NEAREST)
canvas.paste(top, (0, 0))
canvas.paste(bottom, (0, OY + H))

out = HERE / "art" / "expanded.jpg"
canvas.save(out, quality=95)
print(f"wrote {out}: {canvas.size}, the hero at +{OX}+{OY}")
