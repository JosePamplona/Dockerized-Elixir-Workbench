# The console mock

`workbench-console.html`, here, is a static mock of the workbench console,
made to judge its interaction with the eyes before any backend exists.
Open it in a browser. This directory is how it gets built:

```text
mock/
├── workbench-console.html the page itself: open it in a browser
├── build.py               the generator: ./mock/build.py, from the repository root
├── console.template.html  the page, with {{CATALOG}} … {{SOCKET}} where the data goes
├── catalog.json           ./wb.sh catalog --json (with the covers)   ─┐ refreshed by
├── status.json            ./wb.sh status --json                      ─┘ build.py --refresh
├── logs.json              a docker compose logs capture, as [service, timestamp, text] rows
├── diffs.json             what each cartridge wrote: ./mock/build.py --diffs [WORKSPACE]
├── stacks.json            ./wb.sh stacks --json (the usable hexpm/elixir images)  ─ refreshed too
└── marked.min.js          the Markdown renderer, inlined so the page stays self-contained
```

Everything else the page shows is read from the repository at build
time: the colours and type from `assets/design/` (`generated/tokens.css`), the sealed covers and the four placeholders (`cover_`/`back_` and `empty_cover_`/`empty_back_`) under `assets/covers/`, each
cartridge's README/DESIGN/CHANGELOG, the workbench's README, CHANGELOG
and `config.conf`, `wb.sh`'s version, and the workspace's README,
CHANGELOG and `.env` (secrets masked in the build, never in the page).

What is real and what is staged: the workspace, the catalog and the
documents are real; the logs and the diffs are real captures replayed;
the output of inserting, deploying, creating and saving is staged.

The diffs are the box's Implementation sheet. A cartridge's insert
commit is its whole diff — `add` refuses a dirty tree, so nothing else
rode in with it. A collection leaves no commit of its own, so its diff
is the range its members span, taken as one tree against another (never
a concatenation of their patches, whose line numbers already count the
ones before), and only when their commits are contiguous: a second
pass, a member born with `phx.new`, one ejected in between, and the
pick-by-pick breakdown is all there is to show. Under the range, each
file says which picks touched it — what the range itself cannot say and
the members' own commits can. `--diffs` reads the status workspace
unless given another; the old capture stays when there is no repository
there to read.

Two things the page works out itself, which the console proper asks the
workbench: a collection's recipe as its options fill it (the catalog
carries the one its defaults give, and `mix workbench.expand` answers
for the rest), and which of its members the project already carries.
