#!/usr/bin/env python3
"""The cartridge covers pipeline, in one place.

    ./assets/covers/covers.py window                    what the overlay leaves, for the prompt
    ./assets/covers/covers.py pad   <feature>           hero -> padded canvas for the second turn
    ./assets/covers/covers.py cut   <feature>           expansion -> the 5:7 face, the hero in the window
    ./assets/covers/covers.py stamp <feature> [...]     overlay, seal, badge, lockup -> sealed/cover.jpg
    ./assets/covers/covers.py back  <feature>           plate + copy + screenshots -> sealed/back.jpg

Every number about the face comes from overlay.png, read here as the
largest fully transparent rectangle in its alpha; nothing in this
directory repeats it. Everything is composited with PIL: no
ImageMagick. The verdicts, the cover record and the evidence behind
every default are in README.md beside this file; the steps are the
cartridge-covers skill.
"""
import argparse
import functools
import math
import os
import re
import shlex
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

COVERS_DIR = os.path.dirname(os.path.abspath(__file__))
OVERLAY = os.path.join(COVERS_DIR, "overlay.png")
SEAL = os.path.join(COVERS_DIR, "seal.png")
QUALITY = 92

# The proportions the generator offers. The hero is generated at the one
# nearest the window's; `pad` absorbs the difference by setting the hero
# inside the window with a sliver of grey to paint on the two sides it
# does not reach.
GENERATOR = "Gemini"
RATIOS = {"1:1": 1/1, "4:5": 4/5, "3:4": 3/4, "2:3": 2/3, "9:16": 9/16,
          "5:4": 5/4, "4:3": 4/3, "3:2": 3/2, "16:9": 16/9, "21:9": 21/9}

B, C1, C3, R = "\x1b[1m", "\x1b[38;5;1m", "\x1b[38;5;3m", "\x1b[0m"


def die(msg):
    print(f"{B}{C1}Error{R} {msg}\n", file=sys.stderr)
    sys.exit(1)


def warn(msg):
    print(f"{B}{C3}Warning{R} {msg}", file=sys.stderr)


def px(value, factor):
    """Integer pixels, rounded."""
    return int(value * factor + 0.5)


# THE WINDOW ==================================================================

def largest_clear_rectangle(clear):
    """(x, y, w, h) of the largest all-True axis-aligned rectangle."""
    H, W = clear.shape
    heights = np.zeros(W, int)
    best = (0, (0, 0, 0, 0))
    for y in range(H):
        heights = np.where(clear[y], heights + 1, 0)
        stack = []
        for x in range(W + 1):
            cur = heights[x] if x < W else 0
            while stack and heights[stack[-1]] >= cur:
                i = stack.pop()
                h = heights[i]
                left = stack[-1] + 1 if stack else 0
                if h * (x - left) > best[0]:
                    best = (h * (x - left), (left, y - h + 1, x - left, h))
            stack.append(x)
    return best[1]


class Window:
    """The overlay's window: where the art shows, and the board around it.

    The window is the largest fully transparent rectangle in the
    overlay's alpha. That is what makes the overlay free to be any
    design: a board with four sides, a banner that leaves art showing
    above its band, a strip along one edge. Whatever is transparent
    outside that rectangle is bleed the art shows through; whatever is
    opaque is board.
    """

    def __init__(self, overlay_path=OVERLAY):
        if not os.path.isfile(overlay_path):
            die(f"The overlay is missing: {overlay_path}")
        self.image = Image.open(overlay_path).convert("RGBA")
        clear = np.array(self.image.split()[3]) < 128
        self.face_h, self.face_w = clear.shape
        self.x, self.y, self.w, self.h = largest_clear_rectangle(clear)
        if self.w == 0:
            die(f"{overlay_path} has no transparent window.")

    @property
    def margins(self):
        """Top, right, bottom, left: the board between the window and the face's edges."""
        return (self.y, self.face_w - self.x - self.w,
                self.face_h - self.y - self.h, self.x)

    @property
    def ratio(self):
        return self.w / self.h

    def nearest_ratio(self):
        name = min(RATIOS, key=lambda r: abs(RATIOS[r] - self.ratio))
        return name, RATIOS[name]

    def placement(self, hero_w, hero_h):
        """Where a hero of that size sits in a padded 5:7 canvas.

        The hero keeps its own pixels: the canvas is scaled so the window
        contains the hero whole, the hero centred in it. Returns the
        canvas size, the hero's offset in it, and the scale from the
        overlay's pixels to the canvas's — the numbers `pad` lays out by
        and `cut` reverses.
        """
        s = max(hero_w / self.w, hero_h / self.h)
        canvas = (round(self.face_w * s), round(self.face_h * s))
        offset = (round(self.x * s + (self.w * s - hero_w) / 2),
                  round(self.y * s + (self.h * s - hero_h) / 2))
        return canvas, offset, s

    def report(self):
        t, r, b, l = self.margins
        name, value = self.nearest_ratio()
        off = (value - self.ratio) / self.ratio * 100
        sides = [side for side, m in zip(("top", "right", "bottom", "left"), (t, r, b, l)) if m > 0]
        sliver = ("a sliver of grey at each side of the window" if value < self.ratio
                  else "a sliver of grey above and below in the window" if value > self.ratio
                  else "exactly the window")
        return "\n".join([
            f"face      {self.face_w}x{self.face_h}",
            f"window    {self.w}x{self.h} at +{self.x}+{self.y}, proportion {self.ratio:.3f} "
            f"({self.w}:{self.h}; {self.w/self.face_w:.3f} of the width, {self.h/self.face_h:.3f} of the height)",
            f"board     top {t}, right {r}, bottom {b}, left {l} — bleed on the {', '.join(sides) or 'no side'}",
            f"hero      generate at {name} ({GENERATOR}'s nearest, {off:+.1f}% off the window): pad leaves {sliver}",
        ])


# TYPE ========================================================================

@functools.lru_cache(maxsize=None)
def font_file(name):
    """The file behind a face named the way the era table names them —
    Family-Style, dashes for spaces — resolved through fontconfig and
    checked: fontconfig answers every query with *something*, so the
    answer's family and style have to be the ones asked for."""
    tokens = name.split("-")
    for k in range(len(tokens), 0, -1):
        family, style = " ".join(tokens[:k]), " ".join(tokens[k:])
        query = family + (f":style={style}" if style else "")
        out = subprocess.run(["fc-match", "-f", "%{family[0]}|%{style[0]}|%{file}", query],
                             capture_output=True, text=True).stdout
        if out.count("|") != 2:
            continue
        got_family, got_style, path = out.split("|")
        same = lambda a, b: a.lower().replace(" ", "") == b.lower().replace(" ", "")
        if same(got_family, family) and (not style or style.lower() in got_style.lower()):
            return path
    die(f"No font on this machine answers to '{name}' (fc-list to see what does).")


def font(name, size):
    return ImageFont.truetype(font_file(name), max(1, round(size)))


def wrap(text, fnt, width, kerning=0):
    """Lines of `text` no wider than `width`, words kept whole, newlines kept."""
    def length(s):
        return fnt.getlength(s) + kerning * max(0, len(s) - 1)
    lines = []
    for paragraph in text.split("\n"):
        words, line = paragraph.split(), ""
        for word in words:
            trial = f"{line} {word}" if line else word
            if line and length(trial) > width:
                lines.append(line)
                line = word
            else:
                line = trial
        lines.append(line)
    return lines


def draw_line(draw, xy, text, fnt, fill, kerning=0):
    x, y = xy
    if not kerning:
        draw.text((x, y), text, font=fnt, fill=fill)
        return
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += fnt.getlength(ch) + kerning


def caption(image, xy, text, fnt, fill, width, interline=0, kerning=0):
    """Text set left-aligned from `xy`, wrapped to `width`, the lines a
    font height plus `interline` apart — ImageMagick's caption:, which
    is what every back was typeset with."""
    draw = ImageDraw.Draw(image)
    ascent, descent = fnt.getmetrics()
    pitch = ascent + descent + interline
    x, y = xy
    for i, line in enumerate(wrap(text, fnt, width, kerning)):
        draw_line(draw, (x, y + i * pitch), line, fnt, fill, kerning)


def centred(image, text, fnt, fill, interline=0):
    """Text centred on the image, every line centred, for the flashes."""
    draw = ImageDraw.Draw(image)
    ascent, descent = fnt.getmetrics()
    pitch = ascent + descent + interline
    lines = text.split("\n")
    block = len(lines) * pitch - interline
    y = (image.height - block) / 2
    for i, line in enumerate(lines):
        draw.text(((image.width - fnt.getlength(line)) / 2, y + i * pitch), line, font=fnt, fill=fill)


def rgba(hex_or_tuple, alpha=1.0):
    if isinstance(hex_or_tuple, str):
        h = hex_or_tuple.lstrip("#")
        rgb = tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
    else:
        rgb = tuple(hex_or_tuple)
    return rgb + (round(alpha * 255),)


def paste(base, layer, xy):
    """Alpha-composite `layer` onto `base` at `xy`; negative and overhanging positions clip."""
    x, y = round(xy[0]), round(xy[1])
    sx, sy = max(0, -x), max(0, -y)
    if sx >= layer.width or sy >= layer.height or x >= base.width or y >= base.height:
        return
    region = layer.crop((sx, sy, min(layer.width, sx + base.width - max(0, x)),
                         min(layer.height, sy + base.height - max(0, y))))
    base.alpha_composite(region, (max(0, x), max(0, y)))


def outlined_box(size, fill, outline, stroke):
    """A box with a stroke inset one pixel, the way every badge is drawn."""
    box = Image.new("RGBA", size, fill)
    ImageDraw.Draw(box).rectangle((1, 1, size[0] - 2, size[1] - 2), outline=outline, width=stroke)
    return box


# The workbench's name, on the back: a membership badge in the legal
# strip beside the seal, typeset here like everything else on a back
# — a lozenge in the form of the platform lozenges a hero carries, a
# pale field with a thin ink rule and the name in small capitals. The plate carries no lettering at all,
# so the screenshots take the top of the face. The same on every back,
# like the seal: it says whose the cartridge is, not which era it is.
NAME = "DOCKERIZED ELIXIR WORKBENCH"
NAME_FIELD = "#EEE8DF"
NAME_INK = "#2A1830"


def lozenge(text, fnt, field, ink, kerning=0, pad=0.85, side=1.3, radius=0.35):
    """A lozenge as wide and as tall as its text asks: the pill the
    platform badges on a hero take, a field with a thin rule of the ink.
    The padding is measured from the ink of the letters — `pad` of the
    text's height above and below, `side` of it at the ends, a little
    more so the rounded ends do not crowd the first and last letter — so
    capitals do not sit high in a box sized for descenders they have not
    got. `radius` is the corners', as a fraction of the height."""
    x0, y0, x1, y1 = fnt.getbbox(text)
    text_w = (x1 - x0) + kerning * max(0, len(text) - 1)
    text_h = y1 - y0
    py, px_ = round(text_h * pad), round(text_h * side)
    w, h = round(text_w + 2 * px_), round(text_h + 2 * py)
    stroke = max(1, round(h * 0.045))
    badge = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(badge)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=round(h * radius), fill=rgba(field), outline=rgba(ink), width=stroke)
    draw_line(d, (px_ - x0, py - y0), text, fnt, rgba(ink), kerning)
    return badge


def name_badge(fnt, kerning=0):
    """The name lozenge: pale field, ink rule, the name in small capitals."""
    return lozenge(NAME, fnt, NAME_FIELD, NAME_INK, kerning)


def install_badge(text, fnt):
    """The install command's lozenge, set under the name's: the same pill
    inverted, ink field and pale type, in the caption face — a command."""
    return lozenge(text, fnt, NAME_INK, NAME_FIELD)


# THE FRONT: PAD AND CUT ======================================================

def cmd_window(args):
    print(Window().report())


def cmd_pad(args):
    """The canvas for the second turn: the hero set in the window of a
    5:7 face at its own resolution, whole and centred — the generator's
    proportion is only near the window's, so a sliver of the window
    stays grey on two sides — and the margins around it one flat grey,
    blank, for the generator to paint by continuing the scene. The
    generator will not add height to an image at its fixed output size
    ("extend to 3:4" kept exdebug's hero at full height and added 40px
    a side), so the space is made here and the generator only fills it."""
    hero_p = os.path.join(COVERS_DIR, args.feature, "art", "hero.jpg")
    out_p = os.path.join(COVERS_DIR, args.feature, "art", "padded.jpg")
    if not os.path.isfile(hero_p):
        die(f"No hero at {hero_p}")
    hero = Image.open(hero_p).convert("RGB")
    win = Window()
    canvas, (ox, oy), s = win.placement(hero.width, hero.height)
    off = (hero.width / hero.height - win.ratio) / win.ratio * 100
    if abs(off) > 8:
        die(f"The hero is {hero.width}x{hero.height} ({hero.width/hero.height:.3f}), {off:+.0f}% off the "
            f"window's {win.ratio:.3f}: generate it at {win.nearest_ratio()[0]}. Nothing written.")
    face = Image.new("RGB", canvas, (128, 128, 128))
    face.paste(hero, (ox, oy))
    face.save(out_p, quality=QUALITY)
    wx, wy, ww, wh = round(win.x*s), round(win.y*s), round(win.w*s), round(win.h*s)
    sliver = (f"{ox-wx}px at each side" if ww - hero.width > 1
              else f"{oy-wy}px above and below" if wh - hero.height > 1 else "none")
    print(f"wrote {out_p}: {face.width}x{face.height}, the hero at +{ox}+{oy} in the window {ww}x{wh} at +{wx}+{wy} "
          f"(grey inside the window: {sliver}), grey margins {wy} above, {face.height-wy-wh} below, "
          f"{wx} and {face.width-wx-ww} at the sides")


def find_hero(hero, exp):
    """Where the hero is in the expansion, and at what scale: coarse
    search over position and scale on greyscale thumbnails, then refined.
    The generator reuses the hero at whatever size fits its output."""
    def gray(im, w):
        h = max(1, round(im.height * w / im.width))
        return np.asarray(im.convert("L").resize((w, h), Image.BILINEAR), dtype=np.float32)

    def best_match(E, H):
        eh, ew = E.shape
        hh, hw = H.shape
        if hh > eh or hw > ew:
            return None
        Hn = (H - H.mean()) / (H.std() + 1e-6)
        best = (-2, 0, 0)
        for y in range(0, eh - hh + 1):
            for x in range(0, ew - hw + 1):
                P = E[y:y+hh, x:x+hw]
                c = float((Hn * (P - P.mean()) / (P.std() + 1e-6)).mean())
                if c > best[0]:
                    best = (c, x, y)
        return best

    COARSE, FINE = 96, 256
    E = gray(exp, COARSE)
    found = None
    for s in np.arange(0.30, 1.001, 0.02):          # hero width as a fraction of the expansion's width
        m = best_match(E, gray(hero, max(8, round(COARSE * s))))
        if m and (found is None or m[0] > found[0]):
            found = (m[0], m[1], m[2], s)
    s = found[3]
    E2 = gray(exp, FINE)
    best = None
    for s2 in np.arange(max(0.05, s - 0.03), min(1.0, s + 0.03) + 1e-9, 0.005):
        m = best_match(E2, gray(hero, round(FINE * s2)))
        if m and (best is None or m[0] > best[0]):
            best = (m[0], m[1], m[2], s2)
    corr, cx, cy, s = best
    f2 = FINE / exp.width
    return corr, cx / f2, cy / f2, s * exp.width


def cmd_cut(args):
    """The 5:7 face cut from the expansion around the hero, the hero in
    the window — the same placement `pad` used, at the scale the
    generator returned the hero at."""
    art = os.path.join(COVERS_DIR, args.feature, "art")
    hero_p, exp_p, out_p = (os.path.join(art, f) for f in ("hero.jpg", "expanded.jpg", "cover.jpg"))
    if not os.path.isfile(hero_p):
        die(f"No hero at {hero_p}")
    if not os.path.isfile(exp_p):
        die(f"No expansion at {exp_p}")
    hero, exp = Image.open(hero_p).convert("RGB"), Image.open(exp_p).convert("RGB")
    win = Window()
    corr, hx, hy, hero_w = find_hero(hero, exp)
    hero_h = hero_w * hero.height / hero.width
    print(f"hero found at +{hx:.0f}+{hy:.0f}, {hero_w:.0f}x{hero_h:.0f} in the {exp.width}x{exp.height} expansion (correlation {corr:.2f})")
    if corr < 0.6:
        die("That does not look like the hero: the expansion must contain it unchanged. "
            "Re-run the second turn keeping the image as it is.")
    canvas, (ox, oy), k = win.placement(hero.width, hero.height)
    r = hero_w / hero.width
    fx, fy, fw, fh = hx - ox*r, hy - oy*r, canvas[0]*r, canvas[1]*r
    short = {"left": -fx, "top": -fy, "right": fx+fw-exp.width, "bottom": fy+fh-exp.height}
    lacking = {side: v for side, v in short.items() if v > 1}
    TOLERANCE = 0.03   # of the hero's width: rounding in the match and the generator's resize, not a missing margin
    if any(v > hero_w * TOLERANCE for v in lacking.values()):
        msg = ", ".join(f"{side} by {v:.0f}px ({v/hero_w*100:.0f}% of the hero's width)" for side, v in lacking.items())
        die(f"The expansion is short on the {' and '.join(lacking)}: {msg}. Rerun the second turn; nothing written.")
    if lacking:
        pad = {side: int(math.ceil(v)) for side, v in lacking.items()}
        E = np.pad(np.array(exp), ((pad.get("top", 0), pad.get("bottom", 0)),
                                   (pad.get("left", 0), pad.get("right", 0)), (0, 0)), mode="edge")
        exp = Image.fromarray(E)
        fx += pad.get("left", 0)
        fy += pad.get("top", 0)
        print("edge-padded " + ", ".join(f"{side} {v}px" for side, v in pad.items()) + " (within tolerance)")
    face = exp.crop((round(fx), round(fy), round(fx + fw), round(fy + fh)))
    face.save(out_p, quality=QUALITY)
    print(f"wrote {out_p}: {face.width}x{face.height}, the hero at +{ox*r:.0f}+{oy*r:.0f}, "
          f"in the window at +{win.x*k*r:.0f}+{win.y*k*r:.0f}, board {k*r:.2f}x its own size")


# STAMPING ====================================================================

# The seal's size and insets are fractions of the width of the face that
# shows — the overlay's window, or the whole artwork when there is no
# overlay — so every seal lands at the same relative size and inset
# whatever the cover's resolution or the overlay's width. The vertical
# inset is a fraction of the width too, so a corner's two insets stay
# comparable. Insets are measured from the window's edge. The default
# size is the seal exdebug was stamped with, 0.32 of a window five
# sevenths of the face, carried over to a window as wide as the face —
# the seal is a sticker, and keeps its size.
SEAL_SIZE = 0.23
SEAL_MARGIN = "0.05,0.03"
# The badge: an outlined box of condensed caps in a corner of the
# window. Same fractions of the window's width as the seal, and the
# same look as the back's.
BADGE_HEIGHT = 0.054
BADGE_POINT = 0.026
BADGE_FONT = "Liberation-Sans-Narrow-Bold"
INK = "#F2ECF7"
LOCKUP_FIT = "0.80,0.16"
# `--mark NAME=FILE`: the tools a box installs, by their own marks — the
# projects' files, never generated — each on a pale square with rounded
# corners and its name under it, in a row centred along the top of the
# window, where the hero keeps a calm band for them (db_admin's four
# admins). Sizes are fractions of the window's width; the top, of its
# height.
MARK_SIDE = 0.115
MARK_GAP = 0.035
MARK_TOP = 0.06
MARK_FIELD = "#F6F3EE"
MARK_RULE = "#BEC4D0"
MARK_POINT = 0.023


def margins(spec):
    """Top, right, bottom, left from "F", "X,Y" or "T,R,B,L", all fractions."""
    try:
        m = [float(v) for v in spec.split(",")]
    except ValueError:
        die(f"Unreadable margin '{spec}'. Use F, X,Y or T,R,B,L, in fractions.")
    if len(m) == 1:
        return m * 4
    if len(m) == 2:
        return [m[1], m[0], m[1], m[0]]
    if len(m) == 4:
        return m
    die(f"Unreadable margin '{spec}'. Use F, X,Y or T,R,B,L, in fractions.")


def corner_insets(corner, t, r, b, l):
    """The horizontal and vertical values a corner is measured from."""
    try:
        return {"br": (r, b), "bl": (l, b), "tr": (r, t), "tl": (l, t)}[corner]
    except KeyError:
        die(f"Unknown corner '{corner}'. Use br, bl, tr or tl.")


def place_at_corner(base, layer, corner, inset_x, inset_y):
    """`layer` in `base`'s corner, inset by (inset_x, inset_y) — negative insets overhang."""
    x = inset_x if corner[1] == "l" else base.width - layer.width - inset_x
    y = inset_y if corner[0] == "t" else base.height - layer.height - inset_y
    paste(base, layer, (x, y))


def marks_strip(marks, window_width):
    """A row of marks, each fitted to a rounded square with its name
    under it: `marks` is [(name, path)]. Returns the strip, shadows
    included, on a clear field."""
    side, gap = px(window_width, MARK_SIDE), px(window_width, MARK_GAP)
    fnt = font(BADGE_FONT, px(window_width, MARK_POINT))
    label_gap = round(side * 0.08)
    x0, y0, x1, y1 = fnt.getbbox("Ag")
    drop = max(2, round(side / 40))
    w = len(marks) * side + (len(marks) - 1) * gap + drop * 2
    h = side + label_gap + (y1 - y0) + drop * 3
    strip = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ImageDraw.Draw(square).rounded_rectangle((0, 0, side - 1, side - 1), radius=side // 5,
                                             fill=rgba(MARK_FIELD), outline=rgba(MARK_RULE),
                                             width=max(2, side // 40))
    shadow = Image.new("RGBA", square.size, (0, 0, 0, 0))
    shadow.putalpha(square.split()[3].point(lambda v: int(v * 0.6)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(drop * 2))
    d = ImageDraw.Draw(strip)
    for i, (name, path) in enumerate(marks):
        if not os.path.isfile(path):
            die(f"No mark at {path}")
        x = i * (side + gap)
        strip.alpha_composite(shadow, (x + drop, drop * 2))
        strip.alpha_composite(square, (x, 0))
        # The mark fitted by its trimmed outline, wider than tall: a
        # mark with a word beside its symbol (Adminer's `<?`) keeps
        # the height of the rest.
        mark = Image.open(path).convert("RGBA")
        mark = mark.crop(mark.getbbox() or (0, 0, mark.width, mark.height))
        mark.thumbnail((round(side * 0.80), round(side * 0.66)), Image.LANCZOS)
        strip.alpha_composite(mark, (x + (side - mark.width) // 2, (side - mark.height) // 2))
        tw = fnt.getlength(name)
        ty = side + label_gap - y0
        d.text((x + (side - tw) / 2 + drop, ty + drop), name, font=fnt, fill=(0, 0, 0, 200))
        d.text((x + (side - tw) / 2, ty), name, font=fnt, fill=rgba(INK))
    return strip


def stamp(art, output, face="cover", corner="br", size=SEAL_SIZE, placement="straddle",
          margin=SEAL_MARGIN, badge="", badge_corner="", marks=(), lockup="", lockup_fit=LOCKUP_FIT,
          quiet=False):
    """Overlay, seal, lockup and badge onto `art`, written to `output`.

    The overlay and the seal are the two elements the generator must
    never draw: both are platform furniture, identical on every box,
    and identical is the one thing a generator cannot do. So they are
    composited here: the overlay laid on top at the cover's own size,
    its board covering the bleed, and the seal on the window that
    leaves. The front gets the overlay; the back does not. The badge
    and the lockup are typeset here only when the generated ones came
    back wrong — the fallbacks front.md keeps. Covers come out at
    different pixel widths, so all of it is scaled to each cover
    rather than to a fixed size.
    """
    if face not in ("cover", "back"):
        die(f"Unknown face '{face}'. Use cover or back.")
    if not os.path.isfile(SEAL):
        die(f"The seal is missing: {SEAL}")
    if not os.path.isfile(art):
        die(f"No artwork at {art}")
    m_top, m_right, m_bottom, m_left = margins(margin)
    m_x, m_y = corner_insets(corner, m_top, m_right, m_bottom, m_left)

    image = Image.open(art).convert("RGBA")
    if face == "cover":
        # The art is the whole face, composed with bleed, and the
        # overlay is scaled to it and laid on top.
        win = Window()
        f_top, f_right, f_bottom, f_left = win.margins
        scale = image.width / win.face_w
        image.alpha_composite(win.image.resize(image.size, Image.LANCZOS))
        fitting = "overlaid on the face,"
        if scale > 1.05:
            warn(f"overlay.png is being scaled up ×{scale:.2f} to the artwork; export it larger.")
        window_width = image.width - px(f_left, scale) - px(f_right, scale)
    else:
        f_top = f_right = f_bottom = f_left = 0
        scale = 1
        window_width = image.width
        fitting = "bare,"
        placement = "inside"

    # The seal. Straddling, its centre is the window's corner: the
    # board's own width on the two sides the corner touches, less half
    # the seal. Inside, it is inset from the window's edge by the
    # margin, and the board's width is added on. Each axis decides for
    # itself: where the window reaches the face's edge there is no
    # board to straddle, and that axis goes inside.
    seal_width = px(window_width, size)
    seal = Image.open(SEAL).convert("RGBA")
    seal = seal.resize((seal_width, round(seal.height * seal_width / seal.width)), Image.LANCZOS)
    f_x, f_y = corner_insets(corner, f_top, f_right, f_bottom, f_left)

    def inset(board, m):
        if placement == "straddle" and px(board, scale) > 0:
            return px(board, scale) - seal_width // 2
        return px(window_width, m) + px(board, scale)
    inset_x, inset_y = inset(f_x, m_x), inset(f_y, m_y)
    place_at_corner(image, seal, corner, inset_x, inset_y)
    if placement == "straddle":
        placing = ("straddling" if f_x > 0 and f_y > 0
                   else "straddling the top or bottom, inset from the side" if f_y > 0
                   else "straddling the side, inset from the top or bottom" if f_x > 0
                   else "inside (no board at that corner)")
    else:
        placing = f"inside, inset {inset_x}px x {inset_y}px"

    # The lockup, centred on the window, its bottom edge inset from the
    # window's bottom by the board's own width plus the fraction asked.
    locking = ""
    if lockup:
        if not os.path.isfile(lockup):
            die(f"The lockup is missing: {lockup}")
        l_w, l_b = (float(v) for v in lockup_fit.split(","))
        lk = Image.open(lockup).convert("RGBA")
        lockup_width = px(window_width, l_w)
        lk = lk.resize((lockup_width, round(lk.height * lockup_width / lk.width)), Image.LANCZOS)
        l_inset_y = px(window_width, l_b) + px(f_bottom, scale)
        l_centre_x = (image.width + px(f_left, scale) - px(f_right, scale)) / 2
        paste(image, lk, (l_centre_x - lk.width / 2, image.height - lk.height - l_inset_y))
        locking = f" lockup {lockup_width}px wide, bottom {l_inset_y}px up,"

    # The marks, a row centred on the window along its top.
    marking = ""
    if marks:
        ms = marks_strip(marks, window_width)
        w_top = px(f_top, scale)
        w_height = image.height - w_top - px(f_bottom, scale)
        m_centre_x = (image.width + px(f_left, scale) - px(f_right, scale)) / 2
        paste(image, ms, (m_centre_x - ms.width / 2, w_top + w_height * MARK_TOP))
        marking = f" {len(marks)} marks along the top,"

    # The badge, in the corner asked for, or the bottom corner the seal left free.
    badging = ""
    if badge:
        if not badge_corner:
            badge_corner = "br" if corner == "bl" else "bl"
        if badge_corner not in ("bl", "br", "tl", "tr"):
            die(f"Unknown badge corner '{badge_corner}'. Use bl, br, tl or tr.")
        bh = px(window_width, BADGE_HEIGHT)
        fnt = font(BADGE_FONT, px(window_width, BADGE_POINT))
        text_w = fnt.getlength(badge)
        box = outlined_box((round(text_w + bh * 0.8), bh), rgba("#1a1020"), rgba(INK), 2)
        centred(box, badge, fnt, rgba(INK))
        b_x, b_y = corner_insets(badge_corner, m_top, m_right, m_bottom, m_left)
        fb_x, fb_y = corner_insets(badge_corner, f_top, f_right, f_bottom, f_left)
        place_at_corner(image, box, badge_corner,
                        px(window_width, b_x) + px(fb_x, scale), px(window_width, b_y) + px(fb_y, scale))
        badging = f' badge "{badge}" {badge_corner},'

    os.makedirs(os.path.dirname(output) or ".", exist_ok=True)
    image.convert("RGB").save(output, quality=QUALITY)
    if not quiet:
        print(f"Stamped {B}{os.path.basename(output)}{R}: {fitting} seal {seal_width}px wide "
              f"({size} of the {window_width}px window), {placing}, corner {corner},{locking}{marking}{badging}")


def mark_arg(feature, value):
    """`NAME=FILE`, the file relative to the feature's directory."""
    name, sep, path = value.partition("=")
    if not sep or not name or not path:
        die(f"--mark takes NAME=FILE, got '{value}'")
    return name, os.path.join(COVERS_DIR, feature, path)


def cmd_stamp(args):
    art = os.path.join(COVERS_DIR, args.feature, "art", f"{args.face}.jpg")
    output = args.output or os.path.join(COVERS_DIR, args.feature, "sealed", f"{args.face}.jpg")
    stamp(art, output, face=args.face, corner=args.corner, size=args.size, placement=args.placement,
          margin=args.margin, badge=args.badge, badge_corner=args.badge_corner,
          marks=[mark_arg(args.feature, m) for m in args.mark], lockup=args.lockup,
          lockup_fit=args.lockup_fit)


# THE BACK ====================================================================

# Layout defaults, as fractions of the plate's width. layout.env overrides.
BACK_DEFAULTS = dict(
    FRAMES="0.0604,0.1827,0.264,0.3736 0.3681,0.1827,0.265,0.3736 0.6772,0.1827,0.264,0.3736",
    CAPTION_Y=0.574, HEAD_Y=0.628, HEAD_SIZE=0.054,
    PANEL="0.05,0.700,0.90,0.525",
    BLURB_Y=0.722, FEAT_Y=0.955, REQ_Y=1.128, LEGAL_Y="",
    MARGIN=0.075,
    # The seal: "block" sizes it to the strip's block when the name lozenge
    # is set (the pattern), and its margins are then computed; a number
    # and a margin set it by hand, as the backs before the pattern do.
    SEAL_SIZE="block", SEAL_MARGIN="", SEAL_CORNER="bl",
    # The name lozenge in the legal strip: its top edge and its left edge,
    # as fractions of the width; its size follows its type. Empty NAME_Y leaves it off,
    # for the backs made while the plate still carried the name. NAME_X
    # "centre" centres seal, lozenge and legal line on the width as one
    # block, and the seal's horizontal margin is computed from it.
    # NAME_KERN is the name's tracking; the install command's lozenge follows
    # the name's in the same row, in the caption face at INSTALL_POINT.
    NAME_Y="", NAME_X="centre", NAME_POINT=0.022, NAME_KERN=0.003, INSTALL_POINT=0.016,
    # INSTALL_ROW: below (under the name, its own row — the pattern) or
    # beside (after it in one row, smaller, where the band is short).
    INSTALL_ROW="below",
    # The legal line's left edge; empty follows NAME_X.
    LEGAL_X="",
    # The quote's top edge; empty leaves it off. F_QUOTE overrides the
    # blurb face for it (an italic, where the era has one).
    QUOTE_Y="", F_QUOTE="",
    ACCENT="#B6F542", INK=INK, MUTED="#CDBFDA",
    # The frames' rules, when the plate is generated without frames and
    # they are drawn here around each FRAMES rectangle: outer colour and
    # width, inner colour and width, in pixels of a 728px plate. Empty
    # when the plate brought its own frames. Five plates in a row put
    # generated frames between 0.5 and 0.6 of the height whatever the
    # prompt said, and the copy under them never fit; a drawn frame
    # goes where the layout puts it.
    FRAME_RULE="",
    # Type follows the era, so the composed half of the back is in the
    # same decade as the generated half. layout.env names the era (from
    # the cover record); F_HEAD, F_TEXT and F_MONO set there override
    # the preset one at a time. HEAD_KERN is the headline's tracking,
    # as a fraction of the width — the editorial entry sets its caps
    # open. FEAT_LEAD is the feature list's leading; faces with a tall
    # line box get less.
    ERA="console", F_HEAD="", F_TEXT="", F_MONO="", HEAD_KERN="", FEAT_LEAD="",
)
# The era's type: the URW base35 faces are clones of the PostScript
# classics these boxes were actually set in. Head, text, mono, kern, lead.
ERAS = {
    "carton":    ("URW-Gothic-Demi",                 "Nimbus-Sans-Regular",       "Courier-10-Pitch-Regular", 0,     0.011),
    "home":      ("URW-Bookman-Demi",                "Nimbus-Sans-Regular",       "Nimbus-Mono-PS-Regular",   0,     0.011),
    "editorial": ("P052-Roman",                      "Bitstream-Charter-Regular", "Nimbus-Mono-PS-Regular",   0.006, 0.004),
    "console":   ("Liberation-Sans-Narrow-Bold",     "Nimbus-Sans-Regular",       "Liberation-Mono",          0,     0.011),
    "cdrom":     ("Noto-Sans-Condensed-Black",       "Nimbus-Sans-Regular",       "Source-Code-Pro",          0,     0),
    "bigbox":    ("Noto-Serif-ExtraCondensed-Black", "Utopia-Regular",            "Nimbus-Mono-PS-Regular",   0,     0),
}


def read_env(path):
    """KEY=VALUE lines, shell-quoted, comments allowed: layout.env."""
    values = {}
    with open(path) as f:
        for token in shlex.split(f.read(), comments=True):
            if "=" in token:
                key, value = token.split("=", 1)
                values[key] = value
    return values


FEATURES_DIR = os.path.normpath(os.path.join(COVERS_DIR, "..", "..", "igniter", "lib", "workbench_igniter", "features"))


def cartridge_version(feature):
    """The cartridge's current version and its date, read off the first
    entry of its CHANGELOG.md — the one source, so the back never says a
    version the cartridge does not. None when the cartridge has no
    changelog yet."""
    p = os.path.join(FEATURES_DIR, feature, "CHANGELOG.md")
    if not os.path.isfile(p):
        return None
    with open(p) as f:
        m = re.search(r"^## v?(\S+?)\s*-\s*\((\d{4}-\d{2}-\d{2})\)", f.read(), re.M)
    return (m.group(1), m.group(2)) if m else None


def read_copy(path):
    """The sections of copy.md, one list of non-blank lines per '## name'."""
    sections, current = {}, None
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("## "):
                current = line[3:]
                sections[current] = []
            elif current and line.strip():
                sections[current].append(line)
    return sections


def strip_copy(s):
    return s.replace("`", "").replace(" · ", "  ·  ")


def cmd_back(args):
    """The back is composed, not generated: the generator makes only the
    plate, and every fact on the back — copy, screenshots, badge, legal
    line, seal — is typeset here. Positions are fractions of the
    plate's width, measured off the plate that came back and kept in
    <feature>/back/layout.env."""
    feature_dir = os.path.join(COVERS_DIR, args.feature)
    plate_p = os.path.join(feature_dir, "art", "back.jpg")
    back_dir = os.path.join(feature_dir, "back")
    copy_p = os.path.join(back_dir, "copy.md")
    output = args.output or os.path.join(feature_dir, "sealed", "back.jpg")
    if not os.path.isfile(plate_p):
        die(f"No plate at {plate_p}")
    if not os.path.isfile(copy_p):
        die(f"No copy at {copy_p}")
    L = dict(BACK_DEFAULTS)
    env_p = os.path.join(back_dir, "layout.env")
    if os.path.isfile(env_p):
        L.update(read_env(env_p))
    if L["ERA"] not in ERAS:
        die(f"Unknown era '{L['ERA']}' in layout.env. Use {', '.join(ERAS)}.")
    e_head, e_text, e_mono, e_kern, e_lead = ERAS[L["ERA"]]
    f_head, f_text, f_mono = L["F_HEAD"] or e_head, L["F_TEXT"] or e_text, L["F_MONO"] or e_mono
    head_kern = float(L["HEAD_KERN"]) if L["HEAD_KERN"] != "" else e_kern
    feat_lead = float(L["FEAT_LEAD"]) if L["FEAT_LEAD"] != "" else e_lead
    fl = lambda key: float(L[key])
    accent, ink, muted = rgba(L["ACCENT"]), rgba(L["INK"]), rgba(L["MUTED"])

    copy = read_copy(copy_p)
    section = lambda name: [strip_copy(l) for l in copy.get(name, [])]
    headline = "\n".join(section("Headline"))
    blurb = re.sub(" +", " ", " ".join(section("Blurb")))
    features = "\n".join(re.sub(r"^- ", "•  ", l) for l in section("Features"))
    req = "\n".join(section("Requirements")).replace("  ·  ", "\n")
    badge = "\n".join(section("Badge"))
    legal = "\n".join(l.rstrip() for l in section("Legal"))
    quote = " ".join(section("Quote"))
    install = " ".join(section("Install"))
    version = cartridge_version(args.feature)
    if version:
        v, date = version
        legal += f"\ncartridge v{v} · {date}"
    captions = [strip_copy(re.sub(r"^[0-9]+\. `[^`]*` — ", "", l)) for l in copy.get("Screenshots", [])]

    plate = Image.open(plate_p).convert("RGBA")
    W = plate.width
    P = lambda f: px(W, f)
    x0, text_w = P(fl("MARGIN")), P(1 - 2 * fl("MARGIN"))

    # Screenshots into the plate's frames, with the period treatment:
    # cover-fitted from the top, a touch of blur, a little less colour,
    # and scanlines at 15% every third row.
    frames = [tuple(float(v) for v in rect.split(",")) for rect in L["FRAMES"].split()]
    for n, (fx, fy, fw, fh) in enumerate(frames, 1):
        x, y, w, h = P(fx), P(fy), P(fw), P(fh)
        shot_p = os.path.join(back_dir, f"shot-{n}.png")
        if not os.path.isfile(shot_p):
            die(f"No screenshot at {shot_p}")
        shot = Image.open(shot_p).convert("RGB")
        k = max(w / shot.width, h / shot.height)
        shot = shot.resize((max(w, round(shot.width * k)), max(h, round(shot.height * k))), Image.LANCZOS)
        shot = shot.crop(((shot.width - w) // 2, 0, (shot.width - w) // 2 + w, h))
        shot = ImageEnhance.Color(shot.filter(ImageFilter.GaussianBlur(0.3))).enhance(0.92).convert("RGBA")
        scan = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(scan)
        for yy in range(0, h, 3):
            d.line((0, yy, w, yy), fill=(0, 0, 0, round(0.15 * 255)))
        shot.alpha_composite(scan)
        if L["FRAME_RULE"]:
            # The frame drawn around the shot: a rule outside the rectangle,
            # and a thinner line just inside the rule.
            oc, ow, ic, iw = L["FRAME_RULE"].split(",")
            ow, iw = px(W / 728, int(ow)), px(W / 728, int(iw))
            d = ImageDraw.Draw(plate)
            d.rectangle((x - ow - iw, y - ow - iw, x + w - 1 + ow + iw, y + h - 1 + ow + iw), outline=rgba(oc), width=ow)
            d.rectangle((x - iw, y - iw, x + w - 1 + iw, y + h - 1 + iw), outline=rgba(ic), width=iw)
        plate.alpha_composite(shot, (x, y))
        if n <= len(captions):
            caption(plate, (x, P(fl("CAPTION_Y"))), captions[n-1], font(f_mono, P(0.0155)), muted, w)

    # Headline.
    caption(plate, (x0, P(fl("HEAD_Y"))), headline, font(f_head, P(fl("HEAD_SIZE"))), accent, text_w,
            kerning=P(head_kern))

    # The copy panel: the even field the plate may not bring. An empty
    # PANEL in layout.env skips it, for a plate that brought its own.
    if L["PANEL"]:
        pxf, pyf, pwf, phf = (float(v) for v in L["PANEL"].split(","))
        pw, ph = P(pwf), P(phf)
        panel = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
        d = ImageDraw.Draw(panel)
        d.rounded_rectangle((0, 0, pw - 1, ph - 1), radius=6, fill=rgba((14, 6, 22), 0.62))
        d.rounded_rectangle((1, 1, pw - 2, ph - 2), radius=6, outline=rgba((220, 210, 230), 0.35), width=1)
        plate.alpha_composite(panel, (P(pxf), P(pyf)))
    caption(plate, (x0, P(fl("BLURB_Y"))), blurb, font(f_text, P(0.0235)), ink, text_w, interline=P(0.006))
    caption(plate, (x0, P(fl("FEAT_Y"))), features, font(f_head, P(0.030)), ink, text_w, interline=P(feat_lead))

    # The quote, when the copy carries one and the layout gives it a
    # place: a line of the source's words in the blurb face, its
    # attribution under it in the caption face, in the era's own
    # review-quote form.
    if quote and L["QUOTE_Y"]:
        m = re.match(r"^(.*?)\s+—\s+(.*)$", quote)
        words, who = (m.group(1), m.group(2)) if m else (quote, "")
        qfnt = font(L["F_QUOTE"] or f_text, P(0.0235))
        caption(plate, (x0, P(fl("QUOTE_Y"))), f"\u201c{words}\u201d", qfnt, ink, text_w, interline=P(0.006))
        if who:
            n = len(wrap(f"\u201c{words}\u201d", qfnt, text_w))
            ascent, descent = qfnt.getmetrics()
            caption(plate, (x0, P(fl("QUOTE_Y")) + n * (ascent + descent + P(0.006)) + P(0.004)),
                    f"— {who}", font(f_mono, P(0.0155)), muted, text_w)

    # Requirements flash (left) and badge (right), one row.
    rw, rh = P(0.56), P(0.078)
    flash = outlined_box((rw, rh), rgba((0, 0, 0), 0.35), accent, 2)
    centred(flash, req, font(f_head, P(0.023)), accent, interline=P(0.004))
    plate.alpha_composite(flash, (x0, P(fl("REQ_Y"))))
    bw = P(0.26)
    box = outlined_box((bw, rh), rgba("#1a1020"), ink, 2)
    centred(box, badge, font(f_head, P(0.032)), ink)
    plate.alpha_composite(box, (x0 + text_w - bw, P(fl("REQ_Y"))))

    # The strip: the seal at the left, the name lozenge beside it with the
    # legal line under it. NAME_X=centre centres the three on the width
    # as one block — seal, a gap, the wider of lozenge and legal — and
    # sets the seal's horizontal margin from it; LEGAL_X empty follows
    # NAME_X.
    legal_fnt = font(f_mono, P(0.0145))
    name_loz = inst_loz = None
    gap = P(0.02)
    below = str(L["INSTALL_ROW"]) == "below"
    seal_size = fl("SEAL_SIZE") if str(L["SEAL_SIZE"]) != "block" else 0.12
    la, ld = legal_fnt.getmetrics()
    legal_h = len(legal.split("\n")) * (la + ld) if legal else 0
    if L["NAME_Y"]:
        # The pattern: the name lozenge, the install lozenge under it, the
        # legal line under those, and the seal as tall as the three, centred
        # on them; the block centred on the width.
        name_y = P(fl("NAME_Y"))
        name_loz = name_badge(font(f_head, P(fl("NAME_POINT"))), kerning=P(fl("NAME_KERN")))
        if install:
            inst_loz = install_badge(install, font(f_mono, P(fl("INSTALL_POINT"))))
        stack_h = name_loz.height + (P(0.012) + inst_loz.height if inst_loz and below else 0)
        legal_y = P(fl("LEGAL_Y")) if str(L["LEGAL_Y"]) != "" else name_y + stack_h + P(0.014)
        block_h = legal_y + legal_h - name_y
        if str(L["SEAL_SIZE"]) == "block":
            seal_size = block_h / W
        margin_y = (plate.height - (name_y + block_h / 2 + P(seal_size) / 2)) / W
    else:
        name_y = 0
        legal_y = P(fl("LEGAL_Y")) if str(L["LEGAL_Y"]) != "" else P(1.285)
        margin_y = None
    row_w = max(name_loz.width if name_loz else 0, inst_loz.width if inst_loz else 0) if below else \
        (name_loz.width if name_loz else 0) + (gap + inst_loz.width if inst_loz else 0)
    if str(L["NAME_X"]) == "centre" and L["NAME_Y"]:
        legal_w = max(legal_fnt.getlength(l) for l in legal.split("\n")) if legal else 0
        block = P(seal_size) + gap + max(row_w, legal_w)
        seal_x = (W - block) / 2
        name_x = seal_x + P(seal_size) + gap
        margin_x = seal_x / W
        if block > W * (1 - 2 * fl("MARGIN")):
            warn(f"the strip's block is {block / W:.2f} of the width, wider than the margins allow: "
                 "shrink NAME_POINT, NAME_KERN or INSTALL_POINT.")
    else:
        name_x = P(fl("NAME_X")) if str(L["NAME_X"]) != "centre" else P(0.18)
        margin_x = None
    if str(L["SEAL_MARGIN"]) != "":
        parts = str(L["SEAL_MARGIN"]).split(",")
        mx = parts[0] if margin_x is None else f"{margin_x:.4f}"
        my = (parts[1] if len(parts) > 1 else parts[0]) if margin_y is None else f"{margin_y:.4f}"
        seal_margin = f"{mx},{my}" if len(parts) > 1 or margin_x is not None or margin_y is not None else parts[0]
    else:
        seal_margin = f"{margin_x if margin_x is not None else 0.03:.4f},{margin_y if margin_y is not None else 0.03:.4f}"
    legal_x = P(fl("LEGAL_X")) if str(L["LEGAL_X"]) != "" else name_x
    caption(plate, (legal_x, legal_y), legal, legal_fnt, muted, P(0.52))
    if name_loz:
        plate.alpha_composite(name_loz, (round(name_x), round(name_y)))
    if inst_loz and below:
        plate.alpha_composite(inst_loz, (round(name_x), round(name_y + name_loz.height + P(0.012))))
    elif inst_loz:
        plate.alpha_composite(inst_loz, (round(name_x + name_loz.width + gap), round(name_y)))

    with tempfile.NamedTemporaryFile(suffix=".jpg") as composed:
        plate.convert("RGB").save(composed.name, quality=QUALITY)
        stamp(composed.name, output, face="back", corner=L["SEAL_CORNER"], size=seal_size,
              margin=seal_margin, quiet=True)
    print(f"Composed {B}{os.path.basename(output)}{R}: {len(frames)} frames, seal {seal_size:.3f} {L['SEAL_CORNER']}, {W}px wide.")


# THE COMMAND LINE ============================================================

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("window", help="what the overlay leaves: the window, the board, the hero's proportion")

    p = sub.add_parser("pad", help="hero -> padded canvas for the second turn")
    p.add_argument("feature")

    p = sub.add_parser("cut", help="expansion -> the 5:7 face, the hero in the window")
    p.add_argument("feature")

    p = sub.add_parser("stamp", help="overlay, seal, badge and lockup onto a face")
    p.add_argument("feature")
    p.add_argument("-f", "--face", default="cover", help="cover | back (default: cover). The cover gets the overlay; the back does not.")
    p.add_argument("-c", "--corner", default="br", help="br | bl | tr | tl (default: br): the quiet corner of the artwork")
    p.add_argument("-s", "--size", type=float, default=SEAL_SIZE, help=f"seal width as a fraction of the window's width (default: {SEAL_SIZE})")
    p.add_argument("--straddle", dest="placement", action="store_const", const="straddle", default="straddle", help="centre the seal on the window's corner, half on the board, half on the art (default when overlaid)")
    p.add_argument("--inside", dest="placement", action="store_const", const="inside", help="set the seal inside the window, inset by the margin (always, on a bare face)")
    p.add_argument("-m", "--margin", default=SEAL_MARGIN, help=f"inset from the window's edges: T,R,B,L, X,Y or F, in fractions of the window's width (default: {SEAL_MARGIN})")
    p.add_argument("-b", "--badge", default="", help="typeset the unit badge")
    p.add_argument("--badge-corner", default="", help="bl | br | tl | tr (default: bottom left, or bottom right if the seal is there)")
    p.add_argument("--mark", action="append", default=[], metavar="NAME=FILE", help="a tool's own mark, FILE relative to the feature's directory, on a rounded square with NAME under it; repeat it, in order, for a row centred along the top of the window")
    p.add_argument("-l", "--lockup", default="", help="composite this title lockup PNG, centred on the window's width")
    p.add_argument("--lockup-fit", default=LOCKUP_FIT, help=f"its width, and the inset of its bottom edge from the window's bottom, as fractions of the window's width (default: {LOCKUP_FIT})")
    p.add_argument("-o", "--output", default="", help="write here instead of FEATURE/sealed/FACE.jpg, for a trial run")

    p = sub.add_parser("back", help="compose the back from its plate, copy and screenshots, and seal it")
    p.add_argument("feature")
    p.add_argument("-o", "--output", default="", help="write here instead of FEATURE/sealed/back.jpg")

    args = parser.parse_args()
    {"window": cmd_window, "pad": cmd_pad, "cut": cmd_cut, "stamp": cmd_stamp, "back": cmd_back}[args.command](args)


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    main()
