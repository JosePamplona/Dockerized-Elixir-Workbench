#!/usr/bin/env python3
"""Builds mock/workbench-console.html, the console mock, from the template
and the repository. Run from the repository root:

    ./mock/build.py

Inputs, in mock/: console.template.html (the page), catalog.json and
status.json (`./wb.sh catalog --json` with the covers, `./wb.sh status
--json` — refresh them with `./mock/build.py --refresh`, which needs
Docker), logs.json (a `docker compose logs --timestamps --no-color`
capture, parsed into [service, timestamp, text] rows), diffs.json (what
each cartridge wrote, captured off a workspace's insert commits with
`./mock/build.py --diffs [WORKSPACE]`, the status workspace by default)
and marked.min.js.
Read from the repository: the design tokens (assets/design/generated/tokens.css), the sealed covers, the four placeholders (cover_/back_ and empty_cover_/empty_back_), the
cartridges' README/DESIGN/CHANGELOG, the workbench's README/CHANGELOG/
config.conf and wb.sh version, the workspace's README/CHANGELOG/.env
(secrets masked here, so the page never carries them).
"""
import sys, json, base64, io, os, re, subprocess, hashlib
from PIL import Image

M = "mock"
if "--refresh" in sys.argv:
    with open(f"{M}/catalog.json", "w") as f: subprocess.run(["./wb.sh", "catalog", "--json"], stdout=f, check=True)
    with open(f"{M}/status.json", "w") as f: subprocess.run(["./wb.sh", "status", "--json"], stdout=f, check=True)
    # The usable stacks, from Docker Hub via wb.sh; the old snapshot stays if the Hub does not answer.
    r = subprocess.run(["./wb.sh", "stacks", "--json"], capture_output=True, text=True)
    if r.returncode == 0 and r.stdout.strip().startswith("["): open(f"{M}/stacks.json", "w").write(r.stdout)

# The mark keeps its transparency, so it goes in as a PNG and not
# through jpg_uri: it is white line art meant to sit on the band's
# violet, and flattened onto a ground it would arrive in a box.
def png_uri(path, max_h=88):
    im = Image.open(path).convert("RGBA")
    if im.height > max_h: im = im.resize((round(im.width * max_h / im.height), max_h), Image.LANCZOS)
    b = io.BytesIO(); im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()

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
        # NEED.md — the developer's need the cartridge answers — parsed into
        # its four parts, for the box's own sheet (not a document tab).
        if os.path.isfile(os.path.join(d, "NEED.md")):
            docs[name]["need_md"] = open(os.path.join(d, "NEED.md")).read()
            nd = re.sub(r"^#[^\n]*\n+", "", docs[name]["need_md"].strip())
            grab = lambda label: (lambda m: re.sub(r"\s+", " ", m.group(1)).strip() if m else None)(re.search(r"\*\*" + label + r":\*\*\s*(.+?)(?=\n\s*\n|\Z)", nd, re.S))
            want = nd.split("\n\n")[0]
            docs[name]["need"] = {"want": None if want.startswith("**") else re.sub(r"\s+", " ", want).strip(), "before": grab("Before"), "after": grab("After"), "not_for": grab("Not for")}
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
    for k in d:
        if isinstance(d[k], str): d[k] = inline_svgs(d[k], os.path.join(F, name))
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

# --- the diffs: what a cartridge wrote ---------------------------------------
# One insert commit is one cartridge's whole diff: 'add' refuses a dirty
# tree, so the commit holds that cartridge and nothing else. A collection
# leaves no commit of its own, so its diff is the range its members span,
# taken as a difference between two trees — never a concatenation of the
# members' patches, whose line numbers already count the ones before. A
# range is only honest when the members are contiguous: a second pass
# (rerun: adds), a member born with phx.new, or one ejected in between
# leaves a gap, and then the breakdown is all there is.
def capture_diffs(ws, catalog):
    def git(*a): return subprocess.run(["git", "-C", ws, *a], capture_output=True, text=True).stdout
    log = [l.split("\x1f") for l in git("log", "--format=%H\x1f%s\x1f%ci").splitlines() if l]
    # The walk wb.sh's active_inserts does: a revert cancels the next
    # (older) insert with that subject.
    pending, active = {}, []
    for sha, subject, date in log:
        if subject.startswith('Revert "Insert ') and subject.endswith('"'):
            s = subject[8:-1]; pending[s] = pending.get(s, 0) + 1
        elif subject.startswith("Insert "):
            if pending.get(subject, 0): pending[subject] -= 1
            else: active.append((sha, subject, date))

    def path_of(chunk):
        for pat in (r"^\+\+\+ b/(.+)$", r"^--- a/(.+)$", r"^diff --git a/(.+?) b/"):
            m = re.search(pat, chunk, re.M)
            if m and m.group(1) != "dev/null": return m.group(1)
        return "?"
    # A revision's diff, file by file: the path, its ± counts (None for a
    # binary), and its own hunk of the patch. Per file, so the page can
    # fold what nobody reads (mix.lock's lines run past a thousand
    # characters) without hiding that it changed.
    def files_of(*rev):
        cmd = ["diff"] if len(rev) == 2 else ["show"]
        counts = {}
        for line in git(*cmd, "--format=", "--numstat", *rev).splitlines():
            f = line.split("\t")
            if len(f) == 3: counts[f[2]] = (None if f[0] == "-" else int(f[0]), None if f[1] == "-" else int(f[1]))
        out = []
        for chunk in re.split(r"(?m)^(?=diff --git )", git(*cmd, "--format=", *rev)):
            if not chunk.startswith("diff --git "): continue
            path = path_of(chunk)
            add, rem = counts.get(path, (None, None))
            # The four header lines (diff --git, index, --- , +++) say
            # nothing the row above the patch does not already say, so
            # the patch starts at its first hunk. What only the header
            # knows — that the file is new, or gone — is kept as a fact.
            born = bool(re.search(r"(?m)^new file mode ", chunk))
            gone = bool(re.search(r"(?m)^deleted file mode ", chunk))
            hunk = re.search(r"(?m)^@@ ", chunk)
            out.append({"path": path, "added": add, "removed": rem, "born": born, "gone": gone,
                        "patch": (chunk[hunk.start():] if hunk else chunk).rstrip("\n")})
        return out

    def totals(files):
        return {"added": sum(f["added"] or 0 for f in files), "removed": sum(f["removed"] or 0 for f in files)}

    index = {sha: i for i, (sha, _, _) in enumerate(log)}   # 0 is newest
    seen, cartridges = {}, {}
    for sha, subject, date in active:                       # newest first: the
        name = subject.split()[1]                           # latest insert wins,
        if name in seen: continue                           # as eject reads it
        seen[name] = sha
        files = files_of(sha)
        cartridges[name] = {"sha": sha, "subject": subject, "date": date, "files": files, **totals(files)}

    collections = {}
    for e in catalog:
        if not e.get("collection"): continue
        members = [m["name"] for m in (e.get("members") or []) if m["name"] in seen]
        if not members: continue
        idx = sorted(index[seen[m]] for m in members)
        contiguous = idx[-1] - idx[0] + 1 == len(idx)
        newest, oldest = log[idx[0]][0], log[idx[-1]][0]
        base = git("rev-parse", "--verify", "--quiet", oldest + "^").strip()
        c = {"members": members, "contiguous": contiguous,
             "between": idx[-1] - idx[0] + 1 - len(idx),   # commits in the span that are not the collection's
             "files": [], "added": 0, "removed": 0}
        if contiguous and base:
            files = files_of(base, newest)
            # Who wrote each file of the range: the range itself cannot
            # say, and the members' own commits can.
            touched = {m: {f["path"] for f in cartridges[m]["files"]} for m in members}
            for f in files: f["by"] = [m for m in members if f["path"] in touched[m]]
            c.update({"files": files, "range": base[:7] + ".." + newest[:7],
                      "base": base, "tip": newest, **totals(files)})
        collections[e["name"]] = c
    return {"workspace": ws, "cartridges": cartridges, "collections": collections}

# --- the colour: the console's own registry, asked the same way -------------
# A whole new file is read as code, not as change, so it is the one worth
# colouring. The console decides how (Console.Highlight: a lexer, a
# drawing, plain text, or nothing at all) and the mock asks it rather
# than growing a second opinion. Keyed by content, because a file a pick
# adds shows up twice — in its cartridge and in the collection's range.
def capture_highlight(ws, diffs):
    # Bytes, not text: a cartridge ships images too, and a PNG is not
    # something to decode on the way to a lexer.
    def show(rev, path):
        r = subprocess.run(["git", "-C", ws, "show", "%s:%s" % (rev, path)], capture_output=True)
        if r.returncode: return None
        try: return r.stdout.decode()
        except UnicodeDecodeError: return None
    want, index_rev = {}, {}

    # A patch cannot be handed to a lexer: with the +, - and @@ in front
    # of every line it is not code. So both faces of the file go instead
    # — the one the commit left and the one it found — and the page puts
    # the hunks back together out of them, added and context lines off
    # the new face, removed lines off the old. Keyed by path *and*
    # content: the same file rides in its cartridge and in the
    # collection's range, and the treatment is read off the name, so two
    # files with the same bytes under different names are not one job.
    def ask(path, rev, binary):
        if not rev: return None
        src = "" if binary else show(rev, path)
        if src is None: return None
        h = hashlib.sha1((path + "\\0" + src).encode()).hexdigest()[:16]
        want.setdefault(h, {"path": path, "source": src})
        index_rev.setdefault(h, rev)
        return h

    for scope in ("cartridges", "collections"):
        for entry in diffs.get(scope, {}).values():
            tip = entry.get("sha") or entry.get("tip")
            base = entry.get("base") or (tip and tip + "^")
            for f in entry.get("files", []):
                binary = f.get("added") is None
                if not f.get("gone"): f["new"] = ask(f["path"], tip, binary)
                if not f.get("born"): f["old"] = ask(f["path"], base, binary)
    if not want: return {}
    image = "workbench-console:%s-%s" % (os.environ.get("ELIXIR_VERSION", ""), os.environ.get("ERLANG_VERSION", ""))
    if "--" in image or image.endswith("-"):
        image = next((l.split()[0] for l in subprocess.run(["docker", "images", "--format", "{{.Repository}}:{{.Tag}}"],
                     capture_output=True, text=True).stdout.split("\n") if l.startswith("workbench-console:")), "")
    if not image:
        print("no workbench-console image: the colour stays as it was"); return {}
    batch = [{"path": v["path"], "source": v["source"]} for v in want.values()]
    r = subprocess.run(["docker", "run", "--rm", "-i", "--user", "%d:%d" % (os.getuid(), os.getgid()),
                        "--volume", os.path.abspath("console") + ":/app/src", "--workdir", "/app/src",
                        "--env", "HOME=/tmp", image,
                        "sh", "-c", "mix local.hex --force >/dev/null 2>&1; mix console.highlight 2>/dev/null"],
                       input=json.dumps(batch), capture_output=True, text=True)
    try: answer = json.loads(r.stdout[r.stdout.index("["):])
    except Exception:
        print("the console could not colour this batch: it stays as it was"); return {}
    # Which lines of each face a patch actually asks for. A whole new file
    # asks for all of them; an edit of mix.lock asks for eight out of two
    # hundred, and storing the other hundred and ninety-two is how the
    # page grew by two megabytes to show three lines of dependency tree.
    # The lexer still reads the whole file — it has to, for the context —
    # but only what gets rendered is kept.
    needed = {}
    for scope in ("cartridges", "collections"):
        for entry in diffs.get(scope, {}).values():
            for f in entry.get("files", []):
                o = n = 0
                for line in (f.get("patch") or "").split("\n"):
                    m = re.match(r"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
                    if m: o, n = int(m.group(1)), int(m.group(2)); continue
                    if not line or re.match(r"^(diff --git |index |new file|deleted file|similarity |rename |--- |\+\+\+ |\\)", line): continue
                    if line[0] == "+": needed.setdefault(f.get("new"), set()).add(n); n += 1
                    elif line[0] == "-": needed.setdefault(f.get("old"), set()).add(o); o += 1
                    else:
                        needed.setdefault(f.get("new"), set()).add(n)
                        needed.setdefault(f.get("old"), set()).add(o)
                        o += 1; n += 1

    # One line of highlighted HTML per source line. Makeup's newlines sit
    # inside the tokens, so each break closes the open spans and the next
    # line opens them again — cut naively, the tags come out unbalanced.
    def split_lines(html):
        stack, rows, cur = [], [], ""
        for m in re.finditer(r"<(/?)span([^>]*)>|([^<]+)", html):
            close, attrs, text = m.group(1), m.group(2), m.group(3)
            if text is None:
                if close:
                    if stack: stack.pop()
                    cur += "</span>"
                else:
                    stack.append(attrs); cur += "<span%s>" % attrs
                continue
            for i, piece in enumerate(text.split("\n")):
                if i:
                    rows.append(cur + "</span>" * len(stack))
                    cur = "".join("<span%s>" % a for a in stack)
                cur += piece
        rows.append(cur)
        return rows

    # What each treatment needs to be shown: the lexer gives HTML, plain
    # needs the text itself, and a drawing needs its bytes.
    out = {}
    for (h, asked), done in zip(want.items(), answer):
        entry = {"treatment": done["treatment"], "error": done.get("error")}
        keep = needed.get(h)
        if done["treatment"] in ("lexer", "plain"):
            rows = split_lines(done["html"]) if done["treatment"] == "lexer" else \
                   [l.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") for l in asked["source"].split("\n")]
            entry["lines"] = {str(i): rows[i - 1] for i in sorted(keep or ()) if 0 < i <= len(rows)}
        elif done["treatment"] == "image":
            ext = os.path.splitext(asked["path"])[1].lower()
            if ext == ".svg":
                # The markup, not a data URI: smaller than base64, and the
                # page can put it inline so it takes the page's own theme,
                # as it already does with the cartridges' diagrams.
                entry["svg"] = re.sub(r"^<\\?xml[^>]*>\\s*", "", asked["source"])
            else:
                # A raster goes in scaled down. app-logo.png is 1.9 MB on
                # disk, and a logo shown beside a diff needs none of it.
                raw = subprocess.run(["git", "-C", ws, "show", "%s:%s" % (index_rev[h], asked["path"])], capture_output=True).stdout
                im = Image.open(io.BytesIO(raw))
                if im.width > 320: im = im.resize((320, round(im.height * 320 / im.width)), Image.LANCZOS)
                # WEBP, which keeps the transparency a logo needs and is a
                # fraction of the PNG at the size a thumbnail is read at.
                buf = io.BytesIO(); im.save(buf, "WEBP", quality=80, method=6)
                entry["uri"] = "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()
        out[h] = entry
    return out

# Captured with --diffs (the workspace it reads defaults to the status
# one); like the logs, a real capture the page replays. The old capture
# stays when the workspace is not there to be read.
if "--diffs" in sys.argv:
    i = sys.argv.index("--diffs")
    src = sys.argv[i + 1] if len(sys.argv) > i + 1 and not sys.argv[i + 1].startswith("--") else ws
    if os.path.isdir(os.path.join(src, ".git")):
        captured = capture_diffs(src, catalog)
        captured["highlight"] = capture_highlight(src, captured)
        json.dump(captured, open(f"{M}/diffs.json", "w"))
    else: print(f"no repository at {src}: keeping the diffs already captured")
diffs = json.load(open(f"{M}/diffs.json")) if os.path.isfile(f"{M}/diffs.json") else {"cartridges": {}, "collections": {}}
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
tokens_css = (open("assets/design/generated/tokens.css").read().strip() + "\n" +
              open("assets/design/generated/components.css").read().strip())
t = t.replace("{{TOKENS_CSS}}", "  " + tokens_css.replace("\n", "\n  "), 1)
t = t.replace("<script>\n// Real data", "<script>\n" + open(f"{M}/marked.min.js").read() + "\n</script>\n<script>\n// Real data", 1)
stacks = json.load(open(f"{M}/stacks.json")) if os.path.isfile(f"{M}/stacks.json") else []
js = lambda o: json.dumps(o).replace("</", "<\\/")
for k, v in [("{{CATALOG}}", js(catalog)), ("{{STACKS}}", js(stacks)), ("{{STATUS}}", js(status)), ("{{LOGS}}", js(logs)), ("{{DOCS}}", js(docs)), ("{{WB}}", js(wb)), ("{{PROJ}}", js(proj)), ("{{DIFFS}}", js(diffs)), ("{{ART}}", js(art)), ("{{LOGO}}", png_uri("console/assets/images/logo.png")), ("{{PH_COVER}}", jpg_uri("assets/covers/cover_placeholder.png")), ("{{PH_BACK}}", jpg_uri("assets/covers/back_placeholder.jpg")), ("{{PH_EMPTY_COVER}}", jpg_uri("assets/covers/empty_cover_placeholder.jpg")), ("{{PH_EMPTY_BACK}}", jpg_uri("assets/covers/empty_back_placeholder.jpg"))]:
    assert t.count(k) == 1, k; t = t.replace(k, v)
head, body = t.split('<header class="band">', 1); body = '<header class="band">' + body
head = head.replace("<style>", "<style>\n  [hidden]{display:none!important}\n  img{max-width:100%}", 1)
doc = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
       '<meta name="description" content="Mock of the Dockerized Elixir Workbench console: the workspace board, the cartridge shelf with each box\'s manual and design paper, live logs, deployments, the project\'s own documents, and the workbench\'s manual, changelog and editable config. Data read off ./wb.sh catalog --json and status --json; logs are a replayed capture; install, deploy and save output is staged.">\n'
       '<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 100 100\'%3E%3Ctext y=\'.9em\' font-size=\'90\'%3E%F0%9F%A7%B0%3C/text%3E%3C/svg%3E">\n'
       + head.strip() + "\n</head>\n<body>\n" + body.strip() + "\n</body>\n</html>\n")
out = f"{M}/workbench-console.html"
open(out, "w").write(doc)
print(out, os.path.getsize(out) // 1024, "KB")
