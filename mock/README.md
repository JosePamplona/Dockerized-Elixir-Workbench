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
├── diffs.json             what each cartridge wrote, and how to show it (--diffs)
├── stacks.json            ./wb.sh stacks --json (the usable hexpm/elixir images)  ─ refreshed too
└── marked.min.js          the Markdown renderer, inlined so the page stays self-contained
```

Everything else the page shows is read from the repository at build
time: the mark on the band (`console/priv/static/images/logo.png`, inlined as
a PNG so its transparency survives — flattened it would arrive in a
box), the colours and type from `assets/design/` (`generated/tokens.css`), the sealed covers and the four placeholders (`cover_`/`back_` and `empty_cover_`/`empty_back_`) under `assets/covers/`, each
cartridge's README/DESIGN/CHANGELOG, the workbench's README, CHANGELOG
and `config.conf`, `wb.sh`'s version, and the workspace's README,
CHANGELOG and `.env` (secrets masked in the build, never in the page).

What is real and what is staged: the workspace, the catalog and the
documents are real; the logs and the diffs are real captures replayed;
the output of inserting, deploying, creating and saving is staged.

The diffs are the box's **Installation** screen, a tab of its own beside
the papers: the code was sharing a 621px column with the art, the specs,
the form and the output log, and living in a 340px window with a
scrollbar inside a list with a scrollbar inside a drawer with a
scrollbar. It has the drawer's full width and one scroll now. A cartridge's insert
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

A patch cannot be handed to a lexer — with the `+`, `-` and `@@` in
front of every line it is not code — so the capture carries **both faces
of each file**, coloured whole, and the hunks are put back together out
of them: context and additions off the new face, removals off the old.
The `@@` headers stay plain, being the only lines that belong to the
diff itself and not to either file. The palette is
`console/elixir_color_theme.jsonc` as written — One Dark, twelve rules
meant for a dark editor — on the house's own dark ground, the one the
Logs screen uses.

How each file is *shown* is not the mock's opinion: `--diffs` asks the
console (`mix console.highlight`, in `console/`) and stores the answer
beside the diff. `Console.Highlight` keeps the registry — a treatment
per filename, then per extension: a Makeup lexer, a drawing, plain text,
or left out. The SVGs are drawn rather than
printed, and `mix.lock` is read by the Elixir lexer its contents ask for
rather than by its extension: its lines run past a thousand characters,
but the package and the version are at the front of each one, and the
lock is the only place a cartridge shows what it *drags in* — `credo`
puts one line in `mix.exs`, and the lock is where `bunt` becomes
visible. Only the lines a patch renders are kept: the lexer reads whole
files, since it needs the context, but storing the other hundred and
ninety-two lines of a lock to show eight is how a page grows by two
megabytes.
Adding a language is a line in that registry and its `makeup_*`
dependency: every Makeup lexer emits the same token classes, so the
palette in the template is written once. What the registry does not name
is shown plain and never guessed at — the Elixir lexer on an `.eex`
template does not leave it grey, it colours `in` and `with` as keywords
inside a CSS comment.

Two things the page works out itself, which the console proper asks the
workbench: a collection's recipe as its options fill it (the catalog
carries the one its defaults give, and `mix workbench.expand` answers
for the rest), and which of its members the project already carries.
