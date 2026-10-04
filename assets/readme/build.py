#!/usr/bin/env python3
"""The README's shelf: the cartridges on offer as a grid of box covers.

    ./wb.sh catalog --json --brief | python3 assets/readme/build.py [README.md]

Reads the catalog on stdin, cuts a thumbnail of every sealed cover into
assets/readme/covers/, and writes the grid between the two markers of
the README, leaving the rest of the file as it is:

    <!-- shelf:start -->
    <!-- shelf:end -->

The catalog is the one source: name, version and summary are what
'./wb.sh catalog' prints, and a box that is archived or pending is not
drawn. A cartridge without a sealed cover gets the placeholder, as on
the console's shelf. It also cuts the four states one cover went
through, for the README's strip of how the box art is made. PIL,
nothing else.
"""

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
COVERS = ROOT / "assets" / "covers"
THUMBS = ROOT / "assets" / "readme" / "covers"
FEATURES = "igniter/lib/workbench_igniter/features"
START, END = "<!-- shelf:start -->", "<!-- shelf:end -->"
PLACEHOLDER = "_placeholder"
THUMB_WIDTH = 320  # cut well over the size it is drawn at, for dense screens
COVER_WIDTH = 80  # as drawn in a row of the table
PAPERS = ("README", "NEED", "DESIGN", "CHANGELOG")
# One cover's four states, in order: the README's strip of how the art is made.
PIPELINE = ("test_doubles", ("art/hero.jpg", "art/padded.jpg", "art/expanded.jpg", "sealed/cover.jpg"))


def thumbnail(source, name):
    """Cut assets/readme/covers/NAME.jpg from SOURCE, and say its path from the root."""
    target = THUMBS / f"{name}.jpg"
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
            START,
            f"**On the shelf** — {len(plain)} cartridges, inserted when the project asks for them:",
            table(plain, placeholder),
            f"**Base cartridges** — the {len(base)} capabilities `phx.new` decides at birth, each one addable afterwards:",
            table(base, placeholder),
            END,
        ]
    )


def pipeline():
    feature, states = PIPELINE
    for step, state in enumerate(states, start=1):
        thumbnail(COVERS / feature / state, f"_pipeline-{step}")


def main():
    readme = ROOT / (sys.argv[1] if len(sys.argv) > 1 else "README.md")
    text = readme.read_text()
    if START not in text or END not in text:
        sys.exit(f"{readme.name}: no '{START}' … '{END}' markers to write between")
    before, rest = text.split(START, 1)
    after = rest.split(END, 1)[1]
    readme.write_text(before + shelf(json.load(sys.stdin)) + after)
    pipeline()


if __name__ == "__main__":
    main()
