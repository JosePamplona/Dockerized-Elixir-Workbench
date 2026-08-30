#!/usr/bin/env python3
"""Builds mock/workbench-console.html, the console mock, from the template
and the repository. Run from the repository root:

    ./mock/build.py

Inputs, in mock/: console.template.html (the page), catalog.json and
status.json (`./wb.sh catalog --json` with the covers, `./wb.sh status
--json` — refresh them with `./mock/build.py --refresh`, which needs
Docker), logs.json (a `docker compose logs --timestamps --no-color`
capture, parsed into [service, timestamp, text] rows) and marked.min.js.
Read from the repository: the design tokens (assets/design/generated/tokens.css), the sealed covers, the placeholder socket, the
cartridges' README/DESIGN/CHANGELOG, the workbench's README/CHANGELOG/
config.conf and wb.sh version, the workspace's README/CHANGELOG/.env
(secrets masked here, so the page never carries them).
"""
import sys, json, base64, io, os, re, subprocess
from PIL import Image

M = "mock"
if "--refresh" in sys.argv:
    with open(f"{M}/catalog.json", "w") as f: subprocess.run(["./wb.sh", "catalog", "--json"], stdout=f, check=True)
    with open(f"{M}/status.json", "w") as f: subprocess.run(["./wb.sh", "status", "--json"], stdout=f, check=True)

def jpg_uri(path, max_w=560, q=80):
    im = Image.open(path).convert("RGB")
    if im.width > max_w: im = im.resize((max_w, round(im.height * max_w / im.width)), Image.LANCZOS)
    b = io.BytesIO(); im.save(b, "JPEG", quality=q, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(b.getvalue()).decode()

catalog = json.load(open(f"{M}/catalog.json")); status = json.load(open(f"{M}/status.json")); logs = json.load(open(f"{M}/logs.json"))
F = "igniter/lib/workbench_igniter/features"
docs = {}
for name in sorted(os.listdir(F)):
    d = os.path.join(F, name)
    if os.path.isdir(d):
        docs[name] = {k: open(os.path.join(d, f)).read() for k, f in [("readme", "README.md"), ("design", "DESIGN.md"), ("changelog", "CHANGELOG.md")] if os.path.isfile(os.path.join(d, f))}
# A diagram referenced from a cartridge's document is put in the page
# inline (not as an <img>), so it takes the page's fonts and theme; the
# xml prolog and the font @import go, the SVG's own colour variables stay.
def inline_svgs(md, base):
    def sub(m):
        path = os.path.normpath(os.path.join(base, m.group(2)))
        if not (path.endswith(".svg") and os.path.isfile(path)): return m.group(0)
        svg = open(path).read()
        svg = re.sub(r"^<\?xml[^>]*>\s*", "", svg)
        svg = re.sub(r"@import url\([^)]*\);\s*", "", svg)
        return svg
    return re.sub(r"!\[([^\]]*)\]\(([^)]+\.svg)\)", sub, md)
for name, d in docs.items():
    for k in d: d[k] = inline_svgs(d[k], os.path.join(F, name))
for e in catalog: e["docs"] = {k: k in docs.get(e["name"], {}) for k in ("readme", "design", "changelog")}
art = {e["name"]: {"front": jpg_uri("assets/covers/" + e["covers"]["front"]), "back": jpg_uri("assets/covers/" + e["covers"]["back"])} for e in catalog if e.get("covers", {}).get("front") and e.get("covers", {}).get("back")}
readme = open("README.md").read()
# Images the README references from assets/, inlined so the page stays self-contained.
for ref in set(re.findall(r'src="(assets/[^"]+\.svg)"', readme)):
    if os.path.isfile(ref):
        readme = readme.replace(f'src="{ref}"', 'src="data:image/svg+xml;base64,' + base64.b64encode(open(ref, "rb").read()).decode() + '"')
version = re.search(r"v(\S+)", open("wb.sh").read().split("\n")[2]).group(1)
wb = {"version": version, "readme": readme, "changelog": open("CHANGELOG.md").read(), "config": open("config.conf").read(),
      "workspaces": sorted("./_workspaces/" + d for d in os.listdir("_workspaces") if os.path.isdir("_workspaces/" + d))}
ws = status["workspace"]
def mask(text):
    out = []
    for line in text.split("\n"):
        m = re.match(r"^(\w+)=(.*)$", line)
        if m and re.search(r"SECRET|TOKEN|PASSWORD|KEY", m.group(1)): out.append(f"{m.group(1)}=••••••••")
        elif m and "://" in m.group(2): out.append(m.group(1) + "=" + re.sub(r"://([^:@/]+):[^@/]+@", r"://\1:••••@", m.group(2)))
        else: out.append(line)
    return "\n".join(out)
proj = {k: (open(os.path.join(ws, f)).read() if os.path.isfile(os.path.join(ws, f)) else None) for k, f in [("readme", "README.md"), ("changelog", "CHANGELOG.md"), ("env", ".env")]}
if proj["env"]: proj["env"] = mask(proj["env"])

t = open(f"{M}/console.template.html").read()
# The house's colours and type: assets/design/tokens.json, projected to CSS.
tokens_css = open("assets/design/generated/tokens.css").read().strip()
t = t.replace("{{TOKENS_CSS}}", "  " + tokens_css.replace("\n", "\n  "), 1)
t = t.replace("<script>\n// Real data", "<script>\n" + open(f"{M}/marked.min.js").read() + "\n</script>\n<script>\n// Real data", 1)
for k, v in [("{{CATALOG}}", json.dumps(catalog)), ("{{STATUS}}", json.dumps(status)), ("{{LOGS}}", json.dumps(logs)), ("{{DOCS}}", json.dumps(docs)), ("{{WB}}", json.dumps(wb)), ("{{PROJ}}", json.dumps(proj)), ("{{ART}}", json.dumps(art)), ("{{SOCKET}}", jpg_uri("assets/covers/placeholder.png"))]:
    assert t.count(k) == 1, k; t = t.replace(k, v)
head, body = t.split('<header class="band">', 1); body = '<header class="band">' + body
head = head.replace("<style>", "<style>\n  [hidden]{display:none!important}\n  img{max-width:100%}", 1)
doc = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
       '<meta name="description" content="Mock of the Dockerized Elixir Workbench console: the workspace board, the cartridge shelf with each box\'s manual and design paper, live logs, deployments, the project\'s own documents, and the workbench\'s manual, changelog and editable config. Data read off ./wb.sh catalog --json and status --json; logs are a replayed capture; install, deploy and save output is staged.">\n'
       '<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 100 100\'%3E%3Ctext y=\'.9em\' font-size=\'90\'%3E%F0%9F%95%B9%3C/text%3E%3C/svg%3E">\n'
       + head.strip() + "\n</head>\n<body>\n" + body.strip() + "\n</body>\n</html>\n")
out = f"{M}/workbench-console.html"
open(out, "w").write(doc)
print(out, os.path.getsize(out) // 1024, "KB")
