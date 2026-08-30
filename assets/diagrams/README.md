# Cartridge diagrams

Where a cartridge adds a path at runtime — a container, an edge on the
network, a plug in a pipeline, a process in the tree — its document
carries a picture of that path. The pictures are made here, one script
for all of them, the way the covers are: a source, and outputs nobody
edits by hand.

```text
assets/diagrams/
├── build.py                  ./assets/diagrams/build.py, from the repository root
├── README.md
└── <cartridge>/
    ├── <name>.html           the page: the source the diagram-design skill's taste gate is written against
    └── <name>.svg            the figure the cartridge's README or DESIGN embeds
```

## Which document, which diagram

The README is operational, so it gets **the mechanism as installed** —
one figure of what the cartridge wires, no more. DESIGN is the why, so
it gets **the comparison** where a decision has alternatives the prose
cannot hold side by side: what happens in whose turn, what edge
disappears without the cartridge. Dependency-only cartridges have no
runtime path and get no diagram: a `credo` figure would be a box that
says "credo".

| Cartridge | Document | Figure | Type |
| --- | --- | --- | --- |
| clustering | README, *Seeing it work* | the scaled deployment, and the edge the cartridge opens inside it | Deployment |
| clustering | DESIGN, §3.2 | how the release becomes a named node, and what the same boot does without the block | Sequence |
| ash | README, *What it installs* | what the queued command wires into the project | Architecture |
| ash | DESIGN, §3.1 | who writes what, and when — why the cartridge's diff is empty | Sequence |

## How one is drawn

Through the [diagram-design](https://github.com/) skill's rules — a 4px
grid, orthogonal connectors, masked labels clear of their stroke, arrows
under boxes, two accents at most, a legend strip — with the house's skin:
`build.py` reads `assets/design/tokens.json` and writes the colours into
each SVG as custom properties under a `prefers-color-scheme` media query,
so **one file reads on light and dark ground** — on GitHub, in the
console, in the mock. The skill's own style guide is the `workbench`
profile the repository's `.diagram-design` marker names, generated from
the same tokens by `assets/design/build.py`.

Fonts are the house's too. A viewer that shows the SVG as an image
(GitHub's README) does not load web fonts, and the fallback stacks
stand in; the console puts the SVG in the page inline, where the page's
fonts apply. Embedding the faces in every SVG was weighed and left out:
it would add a hundred kilobytes to each figure for a case the console
does not have.

A cartridge's diagram is referenced from its document by relative path
(`../../../../../assets/diagrams/<cartridge>/<name>.svg`); the mock's
build inlines it, the console will serve it.
