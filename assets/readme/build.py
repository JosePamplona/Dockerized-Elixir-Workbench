#!/usr/bin/env python3
"""The README's two tables of cartridges, written from the catalog.

    ./wb.sh catalog --json --brief | python3 assets/readme/build.py [--check] [README.md]

Reads the catalog on stdin, cuts a thumbnail of every sealed cover into
assets/readme/covers/, and writes two tables between their markers in
the README, leaving the rest of the file as it is: the cartridges on
offer, and the boxes that are pending.

    <!-- shelf:start -->      <!-- pending:start -->
    <!-- shelf:end -->        <!-- pending:end -->

The catalog is the one source: name, version, summary and need are
what './wb.sh catalog' prints. An archived box is in neither table. A
pending one is said to be designed when its directory carries a
DESIGN.md and identified when it does not, the reading the console
makes. A cartridge without a sealed cover gets the placeholder, as on
the console's shelf. It also cuts the four states one cover went
through, for the README's strip of how the box art is made. PIL,
nothing else.

With --check nothing is written: the tables the catalog would give are
compared with the ones the README has, every thumbnail they point to is
looked for, and a difference ends the run with a failure that says how
to mend it. That is the form CI runs, off the package's own task and
with no Docker (`mix workbench.catalog --json --brief`, from igniter/),
and it needs no PIL.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COVERS = ROOT / "assets" / "covers"
THUMBS = ROOT / "assets" / "readme" / "covers"
FEATURES = "igniter/lib/workbench_igniter/features"
SHELF = ("<!-- shelf:start -->", "<!-- shelf:end -->")
PENDING = ("<!-- pending:start -->", "<!-- pending:end -->")
PLACEHOLDER = "_placeholder"
THUMB_WIDTH = 320  # cut well over the size it is drawn at, for dense screens
COVER_WIDTH = 80  # as drawn in a row of the table
PAPERS = ("README", "NEED", "DESIGN", "CHANGELOG")
# One cover's four states, in order: the README's strip of how the art is made.
PIPELINE = ("test_doubles", ("art/hero.jpg", "art/padded.jpg", "art/expanded.jpg", "sealed/cover.jpg"))


# Under --check: nothing is cut, and a thumbnail that is not there is noted here.
CHECK = False
MISSING = []


def thumbnail(source, name):
    """Cut assets/readme/covers/NAME.jpg from SOURCE, and say its path from the root."""
    target = THUMBS / f"{name}.jpg"
    if CHECK:
        if not target.is_file():
            MISSING.append(target.relative_to(ROOT).as_posix())
        return target.relative_to(ROOT).as_posix()

    from PIL import Image  # here, so that --check asks for nothing but Python

    image = Image.open(source).convert("RGB")
    height = round(image.height * THUMB_WIDTH / image.width)
    image.resize((THUMB_WIDTH, height), Image.LANCZOS).save(target, quality=85, optimize=True)
    return target.relative_to(ROOT).as_posix()


def cover(name, placeholder):
    sealed = COVERS / name / "sealed" / "cover.jpg"
    return thumbnail(sealed, name) if sealed.is_file() else placeholder


def row(box, placeholder):
    """One cartridge as one row: its cover, its name and version, what it installs, its papers."""
    name = box["name"]
    home = f"{FEATURES}/{name}"
    image = f'<img src="{cover(name, placeholder)}" width="{COVER_WIDTH}" alt="The {name} box cover">'
    papers = "<br>".join(
        f"[{paper}]({home}/{paper}.md)" for paper in PAPERS if (ROOT / home / f"{paper}.md").is_file()
    )
    summary = box["summary"].replace("|", "\\|")
    return f"| [{image}]({home}/) | **{name}**<br>`v{box['version']}` | {summary} | {papers} |"


def table(boxes, placeholder):
    """
    A Markdown table, one cartridge to a row. Two tags are the only
    HTML, each for what Markdown cannot say: the image's, for a width
    (the cover is cut larger than it is drawn), and the line break's,
    which is the one way to a second line inside a cell — the version
    under the name, a paper to a line. The first heading is written with a
    no-break space on purpose: an image alone in a column is squeezed by
    the columns that hold text, down to nothing, and a heading that
    cannot wrap is what keeps the column as wide as the cover.
    """
    head = ["| Box&nbsp;cover | Cartridge | What it installs | Papers |", "| :-: | --- | --- | --- |"]
    return "\n".join(head + [row(box, placeholder) for box in boxes])


def shelf(catalog):
    THUMBS.mkdir(parents=True, exist_ok=True)
    placeholder = thumbnail(COVERS / "cover_placeholder.png", PLACEHOLDER)
    offered = [box for box in catalog if not box["archived"] and not box["pending"]]
    plain = [box for box in offered if not box["base"]]
    base = [box for box in offered if box["base"]]
    return "\n\n".join(
        [
            f"**On the shelf** — {len(plain)} cartridges, inserted when the project asks for them:",
            table(plain, placeholder),
            f"**Base cartridges** — the {len(base)} capabilities `phx.new` decides at birth, each one addable afterwards:",
            table(base, placeholder),
        ]
    )


def pending(catalog):
    """The boxes with no installer yet, the designed ones first, each with the need it answers."""

    def designed(box):
        return (ROOT / FEATURES / box["name"] / "DESIGN.md").is_file()

    boxes = sorted((box for box in catalog if box["pending"]), key=lambda box: not designed(box))
    head = ["| Pending box | Stage | The need it answers |", "| --- | --- | --- |"]
    rows = [
        f"| [`{box['name']}`]({FEATURES}/{box['name']}/) | {'designed' if designed(box) else 'identified'} "
        f"| {(box['need'] or '').replace('|', chr(92) + '|')} |"
        for box in boxes
    ]
    return "\n".join(head + rows)


def between(text, markers, content, name):
    """TEXT with CONTENT written between its two MARKERS, which stay."""
    start, end = markers
    if start not in text or end not in text:
        sys.exit(f"{name}: no '{start}' … '{end}' markers to write between")
    before, rest = text.split(start, 1)
    return f"{before}{start}\n\n{content}\n\n{end}{rest.split(end, 1)[1]}"


def pipeline():
    feature, states = PIPELINE
    for step, state in enumerate(states, start=1):
        thumbnail(COVERS / feature / state, f"_pipeline-{step}")


def main():
    global CHECK
    args = [arg for arg in sys.argv[1:] if arg != "--check"]
    CHECK = "--check" in sys.argv[1:]
    readme = ROOT / (args[0] if args else "README.md")
    # The catalog is one line, the last: a Mix that had something to
    # compile first says so on the same stream, above it.
    lines = [line for line in sys.stdin.read().splitlines() if line.strip()]
    catalog = json.loads(lines[-1]) if lines else sys.exit("no catalog on stdin")
    old = readme.read_text()
    new = between(old, SHELF, shelf(catalog), readme.name)
    new = between(new, PENDING, pending(catalog), readme.name)
    if not CHECK:
        readme.write_text(new)
        pipeline()
        return

    pipeline()
    wrong = [line for line in new.splitlines() if line not in old.splitlines()]
    for line in wrong:
        print(f"{readme.name} should say: {line[:160]}", file=sys.stderr)
    for path in MISSING:
        print(f"missing thumbnail: {path}", file=sys.stderr)
    if wrong or MISSING:
        sys.exit(
            f"{readme.name} is not what the catalog says. Write it again with\n"
            "  ./wb.sh catalog --json --brief | python3 assets/readme/build.py"
        )
    print(f"{readme.name} says what the catalog says.")


if __name__ == "__main__":
    main()
