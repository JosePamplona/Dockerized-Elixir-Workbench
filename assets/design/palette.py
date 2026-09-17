#!/usr/bin/env python3
"""The terminal's sixteen, derived and checked.

Each ANSI colour is a hue of the design — the red of `bad`, the green of
`good`, the amber of `warn`, the blue of a port, the violet of a route,
a cyan of its own — set at a contrast on its ground: the normal row
5.5:1 on the dark ground and 6:1 on paper, the bright row 9:1 and
4.5:1, found by bisection on HSL lightness. Black, white and their
brights are the terminal's own greys, named here by hand. The values
go into tokens.json (ansi-*); this prints them with their contrasts,
so a change to a hue or a target is a change here, run, and copied.

    python3 assets/design/palette.py
"""
import colorsys

DARK, LIGHT = "#120B17", "#FDFBFE"  # the terminal's grounds (tokens.json: term)
HUES = {"red": 6, "green": 140, "yellow": 38, "blue": 212, "magenta": 277, "cyan": 180}
SAT = {"dark": {"red": 68, "green": 42, "yellow": 71, "blue": 62, "magenta": 52, "cyan": 52},
       "light": {"red": 63, "green": 50, "yellow": 71, "blue": 47, "magenta": 39, "cyan": 63}}
TARGET = {"dark": (5.5, 9.0), "light": (6.0, 4.5)}  # normal, bright
GREYS = {"dark": {"black": "#2C2036", "bright-black": "#8B7C96", "white": "#D9CFDF", "bright-white": "#EFE7F2"},
         "light": {"black": "#2B2133", "bright-black": "#8F819A", "white": "#D6CBDA", "bright-white": "#EBE3EE"}}
ORDER = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def rgb(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hex_of(t):
    return "#" + "".join("%02X" % round(max(0, min(1, x)) * 255) for x in t)


def luminance(c):
    f = lambda x: x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4
    r, g, b = rgb(c)
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def at(h, s, l):
    return hex_of(colorsys.hls_to_rgb(h / 360, l / 100, s / 100))


def solve(h, s, ground, target, lighter):
    lo, hi = 0.0, 100.0
    for _ in range(50):
        mid = (lo + hi) / 2
        k = contrast(at(h, s, mid), ground)
        if lighter:
            lo, hi = (mid, hi) if k < target else (lo, mid)
        else:
            lo, hi = (lo, mid) if k < target else (mid, hi)
    return at(h, s, (lo + hi) / 2)


def palette(ground_name):
    ground = DARK if ground_name == "dark" else LIGHT
    lighter = ground_name == "dark"
    normal, bright = TARGET[ground_name]
    out = dict(GREYS[ground_name])
    for name, h in HUES.items():
        s = SAT[ground_name][name]
        out[name] = solve(h, s, ground, normal, lighter)
        out["bright-" + name] = solve(h, min(100, s + (10 if lighter else 15)), ground, bright, lighter)
    return ground, out


# Nord has no light of its own. Its light here keeps Nord's hues —
# Aurora's red, green, yellow, magenta, Frost's blue and cyan — deepened
# on paper to the same targets as the house's light (6:1 the normal
# row, 4.5:1 the bright), with a floor on saturation, since Nord's
# colours are muted and turn to mud when only their lightness drops;
# black, white and their brights are Polar Night and Snow Storm.
NORD = {"red": "#bf616a", "green": "#a3be8c", "yellow": "#ebcb8b", "blue": "#81a1c1", "magenta": "#b48ead", "cyan": "#88c0d0"}
NORD_GREYS = {"black": "#2E3440", "bright-black": "#4C566A", "white": "#D8DEE9", "bright-white": "#ECEFF4"}


def hsl(c):
    r, g, b = rgb(c)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360, s * 100, l * 100


def nord_light():
    out = dict(NORD_GREYS)
    for name, c in NORD.items():
        h, s, _ = hsl(c)
        s = max(s, 40)
        out[name] = solve(h, s, LIGHT, 6.0, False)
        out["bright-" + name] = solve(h, s, LIGHT, 4.5, False)
    return out


if __name__ == "__main__":
    for g in ("dark", "light"):
        ground, pal = palette(g)
        print(f"the house's {g} on {ground}")
        for k in ORDER + ["bright-" + k for k in ORDER]:
            print(f"  ansi-{k:15} {pal[k]}  {contrast(pal[k], ground):4.1f}:1")
    pal = nord_light()
    print(f"Nord's light, derived, on {LIGHT}")
    for k in ORDER + ["bright-" + k for k in ORDER]:
        print(f"  ansi-{k:15} {pal[k]}  {contrast(pal[k], LIGHT):4.1f}:1")
