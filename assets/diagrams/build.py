#!/usr/bin/env python3
"""The cartridges' diagrams, drawn from one script.

    ./assets/diagrams/build.py            from the repository root

Each diagram is a function below that returns an SVG body; the script
wraps it twice — as a page (`<cartridge>/<name>.html`, the source the
diagram-design skill's taste gate is written against) and as a
standalone `<cartridge>/<name>.svg` that a README embeds. Colours are
the house's, from assets/design/tokens.json, written into the SVG as
custom properties under a `prefers-color-scheme` media query, so the
one file reads on light and dark ground alike — on GitHub, in the
console, in the mock. Fonts come from the same tokens; where a viewer
does not load web fonts (an SVG shown as an image), the fallback stacks
stand in.

Geometry follows the skill: a 4px grid, orthogonal connectors with
r=8 elbows, labels masked and 6px clear of their stroke, arrows drawn
before boxes, at most two accents per diagram, a legend strip at the
foot. The types: Deployment (clustering's README), Sequence
(clustering's DESIGN, §3.2; ash's DESIGN, §3.1), Architecture (ash's
README).
"""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "diagrams")
T = json.load(open(os.path.join(ROOT, "assets", "design", "tokens.json")))
PAL = {k: v["value"] for k, v in T["palette"].items()}

def role(name, mode):
    r = T["roles"][name]
    v = r["value"] if "value" in r else r[mode]
    return re.sub(r"\{([\w-]+)\}", lambda m: PAL[m.group(1)], v)

def rgb(h): h = h.lstrip("#"); return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))

# --- the skin, as custom properties on the svg element --------------------------
def vars_for(mode):
    ink, muted, accent = role("ink", mode), role("muted", mode), role("accent", mode)
    return {
        "paper": role("ground", mode), "surface": role("surface", mode), "paper-2": role("surface-2", mode),
        "ink": ink, "muted": muted, "soft": role("soft", mode), "rule": role("line", mode),
        "accent": accent, "accent-tint": role("accent-soft", mode), "link": role("link", mode),
        "ink-02": f"rgba({rgb(ink)},.02)", "ink-03": f"rgba({rgb(ink)},.03)", "ink-05": f"rgba({rgb(ink)},.05)",
        "ink-12": f"rgba({rgb(ink)},.12)", "ink-20": f"rgba({rgb(ink)},.20)", "ink-30": f"rgba({rgb(ink)},.30)",
        "muted-10": f"rgba({rgb(muted)},.10)", "accent-50": f"rgba({rgb(accent)},.50)",
    }

FONTS = {
    "display": f"'{T['type']['display']['family']}','Roboto Condensed','Arial Narrow',sans-serif",
    "text": f"'{T['type']['text']['family']}',Georgia,serif",
    "code": f"'{T['type']['code']['family']}',ui-monospace,Menlo,monospace",
}

def style(selector):
    def block(mode, indent):
        return "\n".join(f"{indent}--{k}:{v};" for k, v in vars_for(mode).items())
    return (f"{selector}{{\n{block('light', '  ')}\n  --f-display:{FONTS['display']};\n  --f-text:{FONTS['text']};\n  --f-code:{FONTS['code']};\n}}\n"
            f"@media (prefers-color-scheme: dark){{ :root:not([data-theme=\"light\"]) {selector}, {selector}:root{{\n{block('dark', '    ')}\n  }} }}\n"
            f":root[data-theme=\"dark\"] {selector}{{\n{block('dark', '  ')}\n}}\n")

# --- primitives -------------------------------------------------------------------
KINDS = {  # fill, stroke, dash
    "backend":  ("var(--surface)", "var(--ink)", None),
    "focal":    ("var(--accent-tint)", "var(--accent)", None),
    "store":    ("var(--ink-05)", "var(--muted)", None),
    "external": ("var(--ink-03)", "var(--ink-30)", None),
    "input":    ("var(--muted-10)", "var(--soft)", None),
    "optional": ("var(--ink-02)", "var(--ink-20)", "4,3"),
}

def esc(s): return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def text(x, y, s, font="code", size=8, fill="var(--muted)", anchor="middle", weight=None, tracking=None, italic=False):
    attrs = [f'x="{x}"', f'y="{y}"', f'fill="{fill}"', f'font-size="{size}"', f'font-family="var(--f-{font})"', f'text-anchor="{anchor}"']
    if weight: attrs.append(f'font-weight="{weight}"')
    if tracking: attrs.append(f'letter-spacing="{tracking}"')
    if italic: attrs.append('font-style="italic"')
    return f"<text {' '.join(attrs)}>{esc(s)}</text>"

def node(x, y, w, h, name, sub=None, tag=None, kind="backend", badge=None, chips=(), sub2=None):
    fill, stroke, dash = KINDS[kind]
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="var(--paper)"/>',
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill}" stroke="{stroke}" stroke-width="1"{dash_attr}/>']
    if tag:
        tw = 8 + 6 * len(tag)
        out.append(f'<rect x="{x + 8}" y="{y + 6}" width="{tw}" height="12" rx="2" fill="transparent" stroke="{stroke}" stroke-opacity="0.4" stroke-width="0.8"/>')
        out.append(text(x + 8 + tw / 2, y + 15, tag, size=7, fill=stroke, tracking="0.08em"))
    if badge:
        bw = 8 + 6 * len(badge)
        out.append(f'<rect x="{x + w - 8 - bw}" y="{y + 6}" width="{bw}" height="12" rx="2" fill="var(--paper)" stroke="{stroke}" stroke-opacity="0.4" stroke-width="0.8"/>')
        out.append(text(x + w - 8 - bw / 2, y + 15, badge, size=8, fill="var(--ink)"))
    cx = x + w / 2
    ny = y + (h / 2 - 6 if chips else h / 2 + (2 if not sub else -2))
    if chips: ny = y + 36
    out.append(text(cx, ny, name, font="display", size=13, fill="var(--ink)", weight="600", tracking="0.04em"))
    if sub: out.append(text(cx, ny + 14, sub, size=9))
    if sub2: out.append(text(cx, ny + 26, sub2, size=9))
    cy = ny + (30 if sub2 else 22 if sub else 12)
    for chip in chips:
        label, ver = chip
        out.append(f'<rect x="{x + 12}" y="{cy}" width="{w - 24}" height="24" rx="4" fill="var(--ink-05)" stroke="var(--muted)" stroke-width="0.8"/>')
        out.append(text(x + 20, cy + 15, label, font="display", size=12, fill="var(--ink)", anchor="start", weight="600", tracking="0.03em"))
        if ver: out.append(text(x + w - 20, cy + 15, ver, size=9, anchor="end"))
        cy += 32
    return "\n".join(out)

def zone(x, y, w, h, label, dashed=True):
    lw = 8 + 6 * len(label)
    return "\n".join([
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="var(--ink-02)" stroke="var(--ink-20)" stroke-width="0.8"' + (' stroke-dasharray="4,4"' if dashed else "") + "/>",
        f'<rect x="{x + 12}" y="{y + 4}" width="{lw}" height="12" rx="2" fill="var(--paper)"/>',
        text(x + 12 + lw / 2, y + 13, label, size=7, fill="var(--soft)", tracking="0.14em")])

def stroke_attrs(color="muted", dashed=False, width=1.2, marker=True):
    a = f'fill="none" stroke="var(--{color})" stroke-width="{width}"'
    if dashed: a += ' stroke-dasharray="5,4"'
    if marker: a += f' marker-end="url(#arrow-{color})"'
    return a

def hline(x1, x2, y, **k): return f'<line x1="{x1}" y1="{y}" x2="{x2}" y2="{y}" {stroke_attrs(**k)}/>'
def vline(x, y1, y2, **k): return f'<line x1="{x}" y1="{y1}" x2="{x}" y2="{y2}" {stroke_attrs(**k)}/>'

def elbow(x1, y1, x2, y2, mid, **k):
    """right (or left) then down/up then on: two quarter-arcs of r=8 at mid."""
    r = 8
    sx = 1 if x2 > x1 else -1
    sy = 1 if y2 > y1 else -1
    d = (f"M {x1},{y1} H {mid - sx * r} Q {mid},{y1} {mid},{y1 + sy * r} "
         f"V {y2 - sy * r} Q {mid},{y2} {mid + sx * r},{y2} H {x2}")
    return f'<path d="{d}" {stroke_attrs(**k)}/>'

def corner(x1, y1, x2, y2, **k):
    """one bend: vertical from (x1,y1) to y2's row, then horizontal into x2."""
    r = 8
    sx = 1 if x2 > x1 else -1
    sy = 1 if y2 > y1 else -1
    d = f"M {x1},{y1} V {y2 - sy * r} Q {x1},{y2} {x1 + sx * r},{y2} H {x2}"
    return f'<path d="{d}" {stroke_attrs(**k)}/>'

def label(cx, y_line, s, side="above", fill="var(--soft)"):
    """a masked arrow label, 6px clear of a horizontal stroke at y_line."""
    w = 8 + 6 * len(s)
    y = y_line - 20 if side == "above" else y_line + 8
    return (f'<rect x="{cx - w / 2}" y="{y}" width="{w}" height="12" rx="2" fill="var(--paper)"/>'
            + text(cx, y + 9, s, size=8, fill=fill, tracking="0.06em"))

def vlabel(x_line, cy, s, side="right", fill="var(--soft)"):
    """the same beside a vertical stroke at x_line."""
    w = 8 + 6 * len(s)
    x = x_line + 8 if side == "right" else x_line - 8 - w
    return (f'<rect x="{x}" y="{cy - 6}" width="{w}" height="12" rx="2" fill="var(--paper)"/>'
            + text(x + w / 2, cy + 3, s, size=8, fill=fill, tracking="0.06em"))

def legend(y, width, items):
    out = [f'<line x1="24" y1="{y - 8}" x2="{width - 24}" y2="{y - 8}" stroke="var(--ink-12)" stroke-width="0.8"/>',
           text(24, y + 8, "LEGEND", size=8, anchor="start", tracking="0.14em")]
    x = 96
    for kind, s in items:
        if kind in KINDS:
            fill, stroke, dash = KINDS[kind]
            out.append(f'<rect x="{x}" y="{y}" width="16" height="10" rx="2" fill="{fill}" stroke="{stroke}" stroke-width="0.8"' + (f' stroke-dasharray="{dash}"' if dash else "") + "/>")
        else:  # a stroke sample: colour[,dashed]
            color, dashed = (kind.split(",") + [""])[:2]
            out.append(f'<line x1="{x}" y1="{y + 5}" x2="{x + 16}" y2="{y + 5}" stroke="var(--{color})" stroke-width="1.2"' + (' stroke-dasharray="5,4"' if dashed else "") + "/>")
        out.append(text(x + 24, y + 8, s, size=8, anchor="start"))
        x += 32 + 6 * len(s) + 24
    return "\n".join(out)

MARKERS = "".join(
    f'<marker id="arrow-{c}" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0, 8 3, 0 6" fill="var(--{c})"/></marker>'
    for c in ("muted", "accent", "link", "ink"))

# --- 1. clustering: the scaled deployment, and what the cartridge adds -------------
def clustering():
    W, H = 960, 560
    o = []
    # zones first
    o.append(zone(24, 56, 200, 368, "HOST"))
    o.append(zone(248, 56, 688, 368, "WORKSPACE · BRIDGE NETWORK"))
    # arrows
    o.append(hline(200, 264, 180, color="link"))                       # browser -> balancer
    o.append(label(232, 180, ":4000", fill="var(--link)"))
    o.append(hline(408, 496, 180))                                     # balancer -> app
    o.append(label(452, 180, "ROUND-ROBIN"))
    o.append(hline(696, 776, 168, dashed=True))                        # app -> dns: query
    o.append(label(736, 168, "QUERY app"))
    o.append(hline(776, 696, 196, dashed=True))                        # dns -> app: answer
    o.append(label(736, 196, "4 × A", side="below"))
    o.append(vline(596, 240, 320))                                     # app -> database
    o.append(vlabel(596, 280, "TCP :5432 · BY NAME"))
    o.append(hline(776, 696, 356, dashed=True))                        # migrate -> database
    o.append(label(736, 356, "THEN EXIT"))
    # the distribution: what the cartridge adds — a loop on the app node
    o.append(f'<path d="M 556,120 V 96 Q 556,88 564,88 H 628 Q 636,88 636,96 V 120" {stroke_attrs("accent", dashed=True)}/>')
    o.append(label(596, 88, "DIST · EPMD", fill="var(--accent)"))
    # nodes
    o.append(node(40, 148, 160, 64, "browser · curl", ":4000 · :4001–:4004", kind="input"))
    o.append(node(264, 144, 144, 72, "balancer", "nginx · X-Served-By", tag="POD"))
    o.append(node(496, 120, 200, 120, "app", "alias app · one IP each", tag="RELEASE", badge="× 4",
                  chips=[("lorem-ipsum-8", "0.1.0-prod")]))
    o.append(node(776, 144, 136, 72, "embedded DNS", "127.0.0.11", kind="external", tag="DOCKER"))
    o.append(node(496, 320, 200, 72, "database", "postgres:latest", kind="store", tag="POD"))
    o.append(node(776, 320, 136, 72, "migrate", "bin/migrate · once", kind="optional", tag="JOB"))
    # the one accent inside the app: the cartridge's line
    o.append(f'<rect x="508" y="204" width="176" height="24" rx="4" fill="var(--accent-tint)" stroke="var(--accent)" stroke-width="0.8"/>')
    o.append(text(596, 219, "RELEASE_NODE=my_app@<ip>", size=9, fill="var(--ink)"))
    # a callout, editorial
    o.append(text(480, 460, "Without the cartridge the same compose comes up — replicas behind the balancer —", font="text", size=13, fill="var(--muted)", italic=True))
    o.append(text(480, 480, "and the release boots with a short name: DNSCluster has nobody to dial.", font="text", size=13, fill="var(--muted)", italic=True))
    o.append(legend(520, W, [("link", "crosses the host"), ("muted", "inside the network"), ("muted,d", "DNS · one-shot"), ("accent,d", "what clustering adds"), ("optional", "runs once")]))
    return W, H, "\n".join(o)

# --- 1b. clustering DESIGN §3.2: how the release becomes a named node --------------
def clustering_boot():
    W, H = 960, 640
    actors = [("bin/server", 96, "sh · sources env.sh"), ("the release", 288, "BEAM · app@172.18.0.4"),
              ("DNSCluster", 480, "every 5 s"), ("embedded DNS", 672, "127.0.0.11"), ("peer replica", 864, "app@172.18.0.5")]
    o = []
    # lifelines
    for _, cx, _ in actors:
        o.append(f'<line x1="{cx}" y1="112" x2="{cx}" y2="556" stroke="var(--ink-20)" stroke-width="1" stroke-dasharray="3,3"/>')
    # activation bars
    def bar(cx, y1, y2): return f'<rect x="{cx - 4}" y="{y1}" width="8" height="{y2 - y1}" fill="var(--ink-05)" stroke="var(--muted)" stroke-width="0.8"/>'
    o.append(bar(96, 128, 200)); o.append(bar(288, 192, 540)); o.append(bar(480, 232, 540)); o.append(bar(672, 312, 344)); o.append(bar(864, 376, 408))
    # a masked note beside a self-message or under a fragment tab: the text
    # crosses other lifelines, so it sits on paper
    def note(x, y, s, fill="var(--muted)"):
        w = 8 + 6 * len(s)
        return (f'<rect x="{x - 4}" y="{y - 9}" width="{w}" height="12" rx="2" fill="var(--paper)"/>'
                + text(x, y, s, size=8, anchor="start", tracking="0.04em", fill=fill))
    # the alt fragment, before the messages inside it
    o.append('<rect x="452" y="256" width="456" height="240" rx="4" fill="var(--ink-02)" stroke="var(--ink-20)" stroke-width="1"/>')
    o.append('<rect x="452" y="256" width="40" height="16" rx="2" fill="var(--paper)" stroke="var(--ink-20)" stroke-width="1"/>')
    o.append(text(472, 268, "ALT", size=8, tracking="0.12em"))
    o.append(note(500, 284, "[RELEASE_DISTRIBUTION=name · the cartridge's block]"))
    o.append('<line x1="460" y1="428" x2="900" y2="428" stroke="var(--ink-20)" stroke-width="1" stroke-dasharray="4,3"/>')
    o.append(note(500, 448, "[else · sname, Mix's default]"))
    # messages (y on the grid, ≥24 apart)
    def msg(x1, x2, y, s, color="muted", dashed=False):
        o.append(hline(x1, x2, y, color=color, dashed=dashed)); o.append(label((x1 + x2) / 2, y, s, fill=f"var(--{color})"))
    # the cartridge's line: env.sh exports the pair, before the script's defaults apply
    o.append(f'<path d="M 100,136 H 124 Q 132,136 132,144 V 152 Q 132,160 124,160 H 100" {stroke_attrs("accent")}/>')
    o.append(note(140, 151, "env.sh: RELEASE_NODE=$RELEASE_NAME@$(hostname -i) · DISTRIBUTION=name", fill="var(--accent)"))
    msg(100, 284, 192, "elixir --name app@<ip>")
    msg(292, 476, 232, "start_link(query: DNS_CLUSTER_QUERY)")
    msg(484, 668, 312, "A? app")
    msg(668, 484, 344, "4 × A · one per replica", dashed=True)
    msg(484, 860, 376, "Node.connect(:\"app@172.18.0.5\")")
    msg(860, 484, 408, "true", dashed=True)
    o.append(f'<path d="M 484,460 H 508 Q 516,460 516,468 V 476 Q 516,484 508,484 H 484" {stroke_attrs("muted")}/>')
    o.append(note(524, 475, "warning: node not running in distributed mode · dials nobody"))
    # actors on top
    for name, cx, sub in actors:
        o.append(node(cx - 80, 56, 160, 48, name, sub, kind="focal" if name == "bin/server" else "backend"))
    o.append(legend(600, W, [("muted", "call"), ("muted,d", "return"), ("accent", "what the cartridge exports"), ("focal", "the script that sources its file")]))
    return W, H, "\n".join(o)

# --- 2. ash: what the queued command wires ------------------------------------------
def ash_wiring():
    W, H = 960, 480
    o = []
    o.append(zone(544, 40, 392, 352, "THE PROJECT, AFTER APPLY"))
    # arrows
    o.append(hline(208, 256, 236))                                           # cartridge -> command
    o.append(label(232, 236, "QUEUES"))
    o.append(elbow(456, 216, 576, 100, 480))                                 # command -> domain
    o.append(elbow(456, 228, 576, 180, 496))                                 # -> data layer
    o.append(elbow(456, 240, 576, 260, 512))                                 # -> router
    o.append(elbow(456, 252, 576, 340, 528))                                 # -> auth
    o.append(corner(124, 272, 256, 372, color="accent"))                     # cartridge -> .env
    o.append(vlabel(124, 320, "WRITES", fill="var(--accent)"))
    o.append(f'<path d="M 576,356 H 552 Q 544,356 544,364 V 364 Q 544,372 536,372 H 456" {stroke_attrs("muted", dashed=True)}/>')  # auth -> .env
    o.append(label(500, 372, "READS · :PROD"))
    # nodes
    o.append(node(40, 200, 168, 72, "the cartridge", "workbench.install.ash", tag="IGNITER"))
    o.append(node(256, 200, 200, 72, "mix igniter.install", "ash ash_postgres … --yes", kind="focal", tag="QUEUED"))
    o.append(node(576, 72, 320, 56, "Accounts domain", "User, Token · ash.install", tag="DOMAIN"))
    o.append(node(576, 152, 320, 56, "AshPostgres.Repo", "migrations, snapshots · ash_postgres.install", kind="store", tag="DATA"))
    o.append(node(576, 232, 320, 56, "Router", "/api/json · /gql · ash_json_api, ash_graphql", tag="WEB"))
    o.append(node(576, 312, 320, 56, "AshAuthentication", "strategies · ash_authentication(_phoenix)", tag="AUTH"))
    o.append(node(256, 344, 200, 56, ".env", "TOKEN_SIGNING_SECRET", kind="focal", tag="STORE"))
    o.append(legend(440, W, [("focal", "what the cartridge itself produces"), ("backend", "written by the installers"), ("store", "state"), ("muted,d", "read at boot")]))
    return W, H, "\n".join(o)

# --- 3. ash DESIGN §3.1: who writes what, and when ---------------------------------
def ash_sequence():
    W, H = 960, 600
    actors = [("wb.sh add ash", 96), ("the cartridge", 288), ("Igniter", 480), ("igniter.install", 672), ("project files", 864)]
    o = []
    # lifelines
    for _, cx in actors:
        o.append(f'<line x1="{cx}" y1="112" x2="{cx}" y2="516" stroke="var(--ink-20)" stroke-width="1" stroke-dasharray="3,3"/>')
    # activation bars
    def bar(cx, y1, y2): return f'<rect x="{cx - 4}" y="{y1}" width="8" height="{y2 - y1}" fill="var(--ink-05)" stroke="var(--muted)" stroke-width="0.8"/>'
    o.append(bar(96, 136, 500)); o.append(bar(288, 136, 232)); o.append(bar(480, 232, 484)); o.append(bar(672, 300, 456)); o.append(bar(864, 264, 440))
    # the loop fragment, before messages that sit inside it
    o.append('<rect x="652" y="324" width="256" height="116" rx="4" fill="var(--ink-02)" stroke="var(--ink-20)" stroke-width="1"/>')
    o.append('<rect x="652" y="324" width="40" height="16" rx="2" fill="var(--paper)" stroke="var(--ink-20)" stroke-width="1"/>')
    o.append(text(672, 336, "LOOP", size=8, tracking="0.12em"))
    o.append(text(700, 348, "[for each package]", size=8, anchor="start", tracking="0.04em"))
    # messages (y on the grid, ≥24 apart)
    def msg(x1, x2, y, s, color="muted", dashed=False):
        o.append(hline(x1, x2, y, color=color, dashed=dashed)); o.append(label((x1 + x2) / 2, y, s, fill=f"var(--{color})"))
    msg(100, 284, 136, "mix workbench.install.ash --yes")
    o.append(f'<path d="M 292,160 H 316 Q 324,160 324,168 V 176 Q 324,184 316,184 H 292" {stroke_attrs("muted")}/>')
    o.append(text(332, 175, "argv: the packages mix.exs lacks", size=8, anchor="start", tracking="0.04em"))
    msg(292, 476, 232, "patch set: .env · add_task(igniter.install)", color="accent")
    msg(484, 860, 264, "write .env")
    msg(484, 668, 300, "run the queued task")
    msg(676, 860, 384, "<pkg>.install: mix.exs, config, files")
    o.append(f'<path d="M 676,404 H 700 Q 708,404 708,412 V 420 Q 708,428 700,428 H 676" {stroke_attrs("muted")}/>')
    o.append(text(716, 419, "deps.get · compile", size=8, anchor="start", tracking="0.04em"))
    msg(668, 484, 464, "output", dashed=True)
    msg(476, 100, 492, "notice: Ash's changes are in that output", dashed=True)
    # actors on top
    for name, cx in actors:
        o.append(node(cx - 80, 56, 160, 48, name, kind="focal" if name == "the cartridge" else "backend"))
    o.append(legend(560, W, [("muted", "call"), ("muted,d", "return"), ("accent", "the cartridge's whole diff"), ("focal", "the cartridge")]))
    return W, H, "\n".join(o)

# --- 4. precommit DESIGN §3: the commit that crosses the mount -------------------
def precommit_crossing():
    W, H = 1152, 800
    actors = [("git commit", 104, "on the host", "backend"),
              ("the shim", 304, ".git/hooks/pre-commit", "backend"),
              (".githooks/mix", 536, "the way in", "focal"),
              ("git_hooks.run", 800, "mix, in the container", "backend"),
              ("the checks", 1040, ".githooks/pre-commit", "focal")]
    o = []
    # the two grounds first, behind everything: the boundary is the diagram
    o.append(zone(24, 36, 628, 620, "THE HOST · DOCKER, NO ELIXIR"))
    o.append(zone(684, 36, 444, 620, "THE CONTAINER · /app/src"))
    # the fragment under the lifelines, so the activations stay readable inside it
    o.append('<rect x="220" y="184" width="908" height="428" rx="4" fill="var(--ink-02)" stroke="var(--ink-20)" stroke-width="1"/>')
    for _, cx, _, _ in actors:
        o.append(f'<line x1="{cx}" y1="112" x2="{cx}" y2="632" stroke="var(--ink-20)" stroke-width="1" stroke-dasharray="3,3"/>')

    def bar(cx, y1, y2): return f'<rect x="{cx - 4}" y="{y1}" width="8" height="{y2 - y1}" fill="var(--ink-05)" stroke="var(--muted)" stroke-width="0.8"/>'

    def note(x, y, s, fill="var(--muted)"):
        w = 8 + 6 * len(s)
        return (f'<rect x="{x - 4}" y="{y - 9}" width="{w}" height="12" rx="2" fill="var(--paper)"/>'
                + text(x, y, s, size=8, anchor="start", tracking="0.04em", fill=fill))

    def msg(x1, x2, y, s, color="muted", dashed=False):
        o.append(hline(x1, x2, y, color=color, dashed=dashed))
        o.append(label((x1 + x2) / 2, y, s, fill=f"var(--{color})"))

    o.append(bar(104, 128, 584)); o.append(bar(304, 152, 560))
    o.append(bar(536, 240, 528)); o.append(bar(800, 288, 496)); o.append(bar(1040, 344, 464))

    # git's own turn, above the fragment: the hook is a file with the bit set
    msg(108, 300, 152, "runs the hook, mode 0755")

    # the ALT: what the cartridge configures, against the library's own example
    o.append('<rect x="220" y="184" width="40" height="16" rx="2" fill="var(--paper)" stroke="var(--ink-20)" stroke-width="1"/>')
    o.append(text(240, 196, "ALT", size=8, tracking="0.12em"))
    o.append(note(272, 212, "[precommit: mix_path = sh .githooks/mix · project_path \".\"]", fill="var(--accent)"))

    msg(308, 532, 240, "sh .githooks/mix git_hooks.run pre_commit")
    msg(540, 796, 288, "docker compose exec -T app mix", color="accent")
    o.append(note(556, 306, "run --rm with the workspace down · either way, the same source", fill="var(--accent)"))
    msg(804, 1036, 344, "{:cmd, \"sh .githooks/pre-commit\"}")
    o.append(f'<path d="M 1044,368 H 1068 Q 1076,368 1076,376 V 384 Q 1076,392 1068,392 H 1044" {stroke_attrs("muted")}/>')
    o.append(note(852, 408, "set -e · the blocks, in order"))
    msg(1036, 804, 440, "exit 1", dashed=True)
    msg(796, 540, 472, "non-zero", dashed=True)
    msg(532, 308, 504, "non-zero", dashed=True)
    msg(300, 108, 536, "the commit is aborted", dashed=True)

    # the else: the library's own example, on a machine with no Elixir
    o.append('<line x1="228" y1="560" x2="1120" y2="560" stroke="var(--ink-20)" stroke-width="1" stroke-dasharray="4,3"/>')
    o.append(note(272, 580, "[else · the library's own example: {:cmd, \"mix format --check-formatted\"}, project_path from File.cwd!()]"))
    o.append(hline(308, 448, 600, marker=False))
    o.append(f'<path d="M 452,594 l 12,12 M 464,594 l -12,12" fill="none" stroke="var(--muted)" stroke-width="1.4"/>')
    o.append(note(480, 604, "cd /app/src: no such file · mix: not found — the arrow never leaves the host"))

    for name, cx, sub, kind in actors:
        o.append(node(cx - 80, 56, 160, 48, name, sub, kind=kind))
    o.append(legend(712, W, [("focal", "what the cartridge writes"), ("accent", "the crossing"),
                             ("muted", "call"), ("muted,d", "return")]))
    return W, H, "\n".join(o)

# --- writing ----------------------------------------------------------------------------
DIAGRAMS = [
    ("clustering", "scaled-deployment", "Deployment", "The scaled deployment, and what clustering adds inside it",
     "Deployment diagram of ./wb.sh up --deploy scaled: a browser reaching an nginx balancer on the host port, four production replicas of the app sharing the alias app on a bridge network, Docker's embedded DNS answering that alias with four addresses, the database reached by name, a one-shot migration, and — the cartridge's addition — the replicas booting as named distributed nodes that find each other.", clustering),
    ("clustering", "named-node-boot", "Sequence", "How the release becomes a named node, and what DNSCluster does with the name",
     "Sequence diagram of a clustered release booting: the release script sources env.sh, which exports RELEASE_NODE with the container address and RELEASE_DISTRIBUTION=name; the VM starts with that long name; the supervision tree starts DNSCluster with the query from DNS_CLUSTER_QUERY; every five seconds it asks Docker's embedded DNS for the alias, receives one address per replica, and dials basename@address on each peer — or, with the default short name, logs that the node is not running in distributed mode and dials nobody.", clustering_boot),
    ("ash", "queued-command", "Architecture", "What the queued command wires into the project",
     "Architecture diagram of the ash cartridge: the cartridge queues one mix igniter.install command and writes a TOKEN_SIGNING_SECRET entry in .env; the command's installers write the Accounts domain, the AshPostgres repo with its migrations, the API routes and the authentication strategies into the project, and the authentication reads the secret at boot in production.", ash_wiring),
    ("ash", "who-writes-what", "Sequence", "Who writes what, and when",
     "Sequence diagram of an ash install: wb.sh runs the cartridge, which builds the argv of missing packages and hands Igniter a patch set holding only the .env entry and a queued igniter.install task; Igniter writes .env, runs the task, each package installer writes its files, and the output — where Ash's changes appear — returns with a notice.", ash_sequence),
    ("precommit", "the-crossing", "Sequence", "The commit that crosses the mount",
     "Sequence diagram of a commit in a workbench project: git runs the shim git_hooks installed in .git/hooks, which calls .githooks/mix on the host; that script reaches the app container with docker compose exec, where mix git_hooks.run executes the project's .githooks/pre-commit — the formatter first, then each cartridge's block, the first failure cutting the rest — and the non-zero status walks back across the mount to abort the commit. The alternative branch is the library's own example, a mix command run on the host: it finds no Elixir there and cannot cd into the container's path, so the arrow never leaves the host.", precommit_crossing),
]

def page(slug, kind, title, desc, W, H, body):
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{esc(title)}</title>
  <link href="{T['google-fonts']}" rel="stylesheet">
  <style>
    *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
{style('svg.diagram').replace(chr(10), chr(10) + '    ')}
    body {{ font-family: {FONTS['text']}; background: var(--page); color: var(--page-ink); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 3rem 2rem; }}
    :root {{ --page: {role('ground', 'light')}; --page-ink: {role('ink', 'light')}; --page-muted: {role('muted', 'light')}; }}
    @media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --page: {role('ground', 'dark')}; --page-ink: {role('ink', 'dark')}; --page-muted: {role('muted', 'dark')}; }} }}
    :root[data-theme="dark"] {{ --page: {role('ground', 'dark')}; --page-ink: {role('ink', 'dark')}; --page-muted: {role('muted', 'dark')}; }}
    .frame {{ max-width: 1200px; width: 100%; }}
    .eyebrow {{ font-family: {FONTS['code']}; font-size: 0.66rem; font-weight: 500; letter-spacing: 0.18em; text-transform: uppercase; color: var(--page-muted); margin-bottom: 0.5rem; }}
    h1 {{ font-family: {FONTS['text']}; font-size: clamp(1.5rem, 2.4vw + 0.75rem, 2rem); font-weight: 400; letter-spacing: -0.02em; line-height: 1.15; margin-bottom: 1.5rem; }}
    svg {{ width: 100%; min-width: 900px; display: block; }}
  </style>
</head>
<body>
  <div class="frame">
    <p class="eyebrow">{kind} · Dockerized Elixir Workbench</p>
    <h1>{esc(title)}</h1>
{svg(slug, title, desc, W, H, body, standalone=False)}
  </div>
</body>
</html>
"""

def svg(slug, title, desc, W, H, body, standalone):
    head = ('<?xml version="1.0" encoding="UTF-8"?>\n' if standalone else "")
    css = style("svg") if standalone else ""
    fonts = f"@import url('{T['google-fonts'].replace('&', '&amp;')}');\n" if standalone else ""
    st = f"<style>{fonts}{css}</style>" if standalone else ""
    return (f'{head}<svg class="diagram" viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg" role="img" aria-labelledby="{slug}-title {slug}-desc">\n'
            f'  <title id="{slug}-title">{esc(title)}</title>\n  <desc id="{slug}-desc">{esc(desc)}</desc>\n'
            # The ground with coordinates, not percentages: a percentage is
            # of the viewport, and a viewer that pans by moving the viewBox
            # would drag the ground along with it.
            f'  <defs>{st}{MARKERS}</defs>\n  <rect x="0" y="0" width="{W}" height="{H}" fill="var(--paper)"/>\n{body}\n</svg>')

if __name__ == "__main__":
    for cart, slug, kind, title, desc, fn in DIAGRAMS:
        W, H, body = fn()
        d = os.path.join(OUT, cart); os.makedirs(d, exist_ok=True)
        open(os.path.join(d, slug + ".html"), "w").write(page(slug, kind, title, desc, W, H, body))
        open(os.path.join(d, slug + ".svg"), "w").write(svg(slug, title, desc, W, H, body, standalone=True) + "\n")
        print(f"{cart}/{slug}.html + .svg  ({kind}, {W}×{H})")
