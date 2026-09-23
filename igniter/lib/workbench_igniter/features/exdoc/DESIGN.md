# exdoc — Design

Revision: cartridge v0.7.0 (2026-09-22)

*Written at v0.2.0, the change that gave the cartridge its papers.
ExDoc is quoted from its own source at 0.40.4, as `mix deps.get`
fetched it into a probe project on 2026-09-21 (`lib/ex_doc.ex`, the
options' documentation; `lib/ex_doc/formatter.ex`, the asset copy).*

## Abstract

A project's reference documentation is best written where the code is
— `@moduledoc`, `@doc` — and rendered by ExDoc, which every Elixir
library already uses. This cartridge sets ExDoc up for an application
rather than a library: the curated pages beside the modules, the module
groups an application needs, the site's sources where they belong.

Two decisions shape it. The first is who **serves** the result: v0.1.0
planted a controller, a static pipeline and `/dev/docs` routes in the
project's router, so the app served its own docs while it ran; since
v0.2.0 the project serves nothing — `mix docs` writes `doc/`, and the
console serves that directory off the workspace on an origin of its
own. The second is which pages the site lists, and it took four
versions to say it plainly: **a page is listed when its file has an
owner**. The changelog is the changelog box's, so `--changelog` builds
on it; the test suite report is coverage's, so `--coverage` builds on
that box's `--md-report`; the README is nobody's, so it is read and its
entries wait commented out when there is none. What the box used to do
instead — list a file because it happened to be there, plant pages
nobody owned, carry a database page and a theme script of its own — is
gone, each with its reason recorded below.

## 1. Problem

### 1.1 The docs were the workbench's reading, carried by the project

Nothing in v0.1.0's router was there for the project's reasons. The
routes existed so that someone at the workbench could open the docs;
they compiled only under `dev_routes`, answered only while the app ran,
and needed a controller and a test of their own — plus dummy pages
under `doc/` so that test passed before the first `mix docs`, plus a
`--version` option to stamp the dummies' titles. Four pieces of the
project, and one option of the installer, for the workbench's
convenience. It is the contract the workbench has refused elsewhere:
the project owes the workbench nothing, and the workbench reads what is
there (the health probes became plain doors on the same grounds,
2026-09-08).

### 1.2 What there is to read is already on disk

ExDoc's output is a directory of static files:

> `:output` - Output directory for the generated docs. Default: "doc".
> May be overridden by command line argument. [1]

phx.new gitignores it, and the console runs with the workspace mounted.
Serving `doc/` needs nothing from the project but the files `mix docs`
already writes.

## 2. Background

**An image for each theme is ExDoc's own.** Since v0.27 (2022) its
stylesheet hides `img[src*="#gh-dark-mode-only"]` in the light theme
and `#gh-light-mode-only` in the dark one, the fragment GitHub reads
too, so a page names both files and the theme picks. It is worth saying
that this is **undocumented**: the rule lives in `assets/css/_html.css`
and is named nowhere a reader would look — not the README, not the
`ExDoc` moduledoc, not the CHANGELOG [7]. The box's own README is
where a project on this shelf learns it. In EPUB the dark image is
hidden always (`_epub.css`), which is right for a printed book. v0.1.0 to v0.3.1
planted a script for it instead (`themedImage.js`, injected through
`:before_closing_body_tag`), written before that release and kept since
out of habit; it also named one pair of files, the database model's, so
it worked for one page and nothing else. It is gone in v0.4.0, with the
`before_closing_*_tag` functions that carried it: what ExDoc does
already is not worth a file in every project. The `:before_closing_*`
hooks stay available for a theme that needs code, which none of the
shelf does.

The files a page loads travel with the site through

> `:assets` - A map of source => target directories that will be copied
> as is to the output path. It defaults to an empty map. [1]

**A missing asset directory is skipped, not an error.** The copy reads,
in full for the branch that matters:

```elixir
is_binary(dir_or_files) and File.dir?(dir_or_files) ->
  dir_or_files
  |> File.cp_r!(target_dir, dereference_symlinks: true)
  …
is_binary(dir_or_files) ->
  []
```

[2]. It is why the coverage output dir can be one of the site's assets
before any `mix coveralls.html` has run: `mix docs` copies nothing and
goes on (verified in the probe, §4).

**A module group is a list of patterns, and a pattern can be a
function.** The options' documentation shows lists of modules and
says "A regex or the string name of the module is also supported" [1];
the matcher accepts one more kind:

```elixir
def match_module(group_patterns, module, id, metadata) do
  match_group_patterns(group_patterns, fn pattern ->
    case pattern do
      %Regex{} = regex -> Regex.match?(regex, id)
      string when is_binary(string) -> id == string
      atom when is_atom(atom) -> atom == module
      function when is_function(function) -> function.(metadata)
    end
  end)
end
```

[4], where `metadata` is the module's documentation metadata with
`:kind` put in. Read with `Code.fetch_docs/1` in the probe, it carries
the behaviours the module declares — `[Plug]` for a controller,
`[Phoenix.Endpoint, Plug]` for the endpoint, `[Application]` — and its
`:source_path`. In tunez, an Ash project, a domain carries
`[Ash.Domain]`, a change `[Ash.Resource.Change]`, a calculation
`[Ash.Resource.Calculation]`, a sender `[AshAuthentication.Sender]`,
and a resource carries none. The first group that matches wins, and the
groups appear in the order they are listed.

**What projects do with module groups.** A research pass on 2026-09-21
read the mix.exs of fourteen well-known Phoenix applications —
Plausible, Livebook, hexpm, changelog.com, Supabase Realtime, Logflare,
Firezone among them — and none sets `groups_for_modules` [5]. The
applications that do group by **context**: OpenFn Lightning, one regex
per context then `Web` and a catch-all; Trento, one per bounded context
plus `Web` [5]. Ash's own packages group by **role in the DSL** —
Resources, Changes, Validations, Types, Errors [5]. Libraries leave
their core ungrouped and group the rest (adapters, testing, exceptions),
which is a library's question, not an application's. No project read
uses a function pattern: grouping by behaviour is this cartridge's.

**The console's pages carry a foreign origin's script.** ExDoc's pages
run JavaScript — search, the sidebar, settings in `localStorage`. The
console, on the other side, is the page that runs `wb.sh --yes`.
`console/PLAN.md` (*The project's pages are served by the console*)
records the decision this cartridge relies on: the pages are served on
a listener apart from the console's, another port, so another origin,
read-only and limited to the directories the inserted cartridges
declare [3].

## 3. Design

**The pin follows the tool** (v0.8.0). It was `~> 0.38` while this
paper quoted ExDoc at 0.40.4, which is the kind of contradiction a
paper is written to catch; checked against hex.pm on 2026-09-23, the
latest is 0.40.4 (2026-09-03) and `~> 0.38` resolves to neither 0.39
nor 0.40 [7]. The pin is `~> 0.40` now, and what comes with it was run
in a probe before it was believed: a stock `phx.new` project with this
cartridge as a path dependency builds its site, and `mix docs` says
what it wrote — `doc/index.html`, which the console serves, a Markdown
tree with `llms.txt` beside it, and the EPUB. The two new formats are
0.40's defaults, and the box leaves them: a cartridge installs a tool
as its author wrote it, and `doc/` is gitignored, so what the project
carries does not change. The validations 0.39 and 0.40 added — an
`:extras` entry that is not what ExDoc expects, an extra with a
reserved filename, `:assets` given a string — pass: this box writes a
map for the assets and names no reserved page.

**ExDoc, and no alternative was weighed.** It is the ecosystem's
documentation tool, HexDocs is its output, and the reader of an Elixir
project expects its pages. A second generator would be a second
vocabulary for the same `@doc`.

**The console serves `doc/`; the project serves nothing.** The cartridge
declares a door of the output kind — `{"docs", {:output, "doc",
"index.html"}}` — and the console serves it [3]. The alternatives:

* *The project serves it (v0.1.0).* Rejected for §1.1: four pieces of
  the project for the workbench's sake, and docs that are dark whenever
  the app is — a broken build, a prod deployment, nothing up.
* *The console serves it on its own origin, under a sandboxing CSP.*
  Rejected in the console's plan: a `sandbox` without
  `allow-same-origin` gives the page an opaque origin, where ExDoc's
  `localStorage` throws [3].
* *A static server in the workspace's compose.* It would serve the
  files with no route in the project, but it is a container per
  workspace for a directory the console already has mounted, and it
  would carry the same origin question to another port anyway.

**The site's sources live under `guides/`.** v0.1.0 planted them under
`assets/exdoc/`, and in a Phoenix application `assets/` is the release
build's input: `phx.gen.release`'s Dockerfile copies the directory into
its builder stage and tailwind scans it for classes. The config and the
config is a dev tool's code, unlinted and untested, and the
placeholder logo is 1.9 MB; none of it belongs on that path, even where
it does not reach the release itself. Of 23 dependencies read on
2026-09-21, the libraries keep their logo under `assets/` (bandit,
credo, finch), `logos/` (the Ash packages, igniter, spark), the root
(phoenix, absinthe) or `guides/images/` (ecto) — and a library's
`assets/` means nothing, which is why it is free for them; Phoenix,
the one that gives `assets/` its meaning, keeps its logo at the root.
`guides/` is where Elixir projects keep their docs' sources, pages and
images alike, so it takes the whole of `assets/exdoc/` with its layout
unchanged: `config/` to the site's root, `js/` and `images/` under its
`assets/`, the pages beside them — a relative `./images/` in a page
resolves as it did. Rejected: `doc/`, ExDoc's output, gitignored — a
logo there is lost on a clone and `mix docs` stops on the missing
`logo:`; `logos/` for the logo alone, which leaves the scripts on the
build's path; and a `.dockerignore` line, which hides the files from
one consumer of `assets/` and not from the others.

**The mark is the site's config.** `installed?/1` reads
`guides/config/docs_config.js`, or v0.1.0's
`assets/exdoc/config/docs_config.js`. v0.1.0's mark was the controller,
which is gone; the config is the one file every edition planted, so a
project that still carries v0.1.0 reads as exdoc — which it is — and
`eject` stays a revert of its insert commit. Rejected: the `docs:` key
of `mix.exs`, which any project writing its own docs has, whether or
not this cartridge ever ran.

**`--auth0` left with the controller.** The "Get access tokens" page
logged in through Auth0 and redirected back to its own page:
`redirect_uri: window.location.origin`, and a fixed
`/dev/docs/token.html` for the return. Served by the console the page's
origin is the console's pages port, which no Auth0 application lists
and which is not even fixed, and the page calls the app's API from
another origin. Nothing short of the project serving the page again
makes it work; auth0 is archived, and the page is its to carry when it
comes back. Trying the API from a page is what `rest`'s Swagger does,
on the app's own origin.

**`--coverage` joins the report to the site.** Two extras and one
asset: `TESTING.md`, the Test Suite Report `mix cover` writes, and
ExCoveralls' output dir copied into the site's root (`"cover" => "/"`),
so the HTML report is `doc/excoveralls.html`, beside `testing.html`.
The two link each other by relative paths (coverage v0.4.0), which
hold wherever the site is served — the console's `/docs/`, or
`/dev/docs` in a project that still carries v0.1.0. The report also
has a door of its own, coverage's `cover/`, for a project without the
site.

**A page is listed when its file has an owner** (v0.7.0). v0.1.0 listed
`CHANGELOG.md` always, and `mix docs` stops on it: *could not read file
"CHANGELOG.md": no such file or directory*, found in the probe (§4).
v0.2.0 to v0.4.1 listed it when the file happened to be there — the
site's table of contents as a reading of the working directory at
insert time. v0.5.0 made it an option on by default with a commented
slot for the file that was not there yet. What that left unsaid is who
writes the file, and the two pages answer differently:

* **The changelog is the changelog box's.** `--changelog` builds on it
  (`requires` on the option's value, as credo's `--githook` builds on
  precommit): asked for without that box, the run is refused naming it,
  and the console draws the option unlit with a door to that box. So
  the option is **off by default** — `add exdoc` on any project still
  works — and when it is on the file is there, so the entries go in
  live and there is no slot to write. The other order is the changelog
  box's own: inserted after the site, it lists its page itself, which
  is what it did before the option existed.
* **The report page is the coverage box's**, one box further out:
  `--coverage` lists `TESTING.md`, which `mix cover` writes, which the
  coverage box plants with *its* `--exdoc`. So the requirement carries
  that state — `{"coverage", exdoc: true}` — and a project with
  coverage in without it is told so, with the line that tops it up
  (that box adds its pieces on a second run). The placeholder
  `TESTING.md` stays: the box is in, the task is there, and the file
  arrives when the suite first runs — the placeholder is what keeps
  `mix docs` building until then, which is the same reason it was
  planted before.
* **The README is nobody's box.** `phx.new` writes it, a hand rewrites
  it, and the shelf deliberately has no cartridge that would (a
  generated README would have to know every cartridge — the features
  index says so). So `--readme` stays on by default and reads the file:
  with a `README.md` the two entries are live and the site opens on it
  (`main: "readme"`); without one they are written **commented out**,
  the way `source_url` and `homepage_url` are when nothing is found,
  and `main:` is left out with them. The two failures are not the same,
  and only one of them is loud: `mix docs` **stops** on an extra whose
  file is missing (`File.read!` in `ExDoc.Extras`, an unrescued
  `File.Error`), while a `main:` naming a page nobody listed is not
  validated at all [7] — `index.html` redirects to a page that is not
  there, and the site is quietly broken. The loud one is why the entry
  waits commented, which ExDoc never reads; the quiet one is why
  `main:` goes out with it. Both lines are whole lines, so the list's
  comma goes into the comment with them (and the formatter then drops
  it), and the lists stay valid — asserted by parsing the generated
  `mix.exs` in each shape. `state/1` answers the **live** entry alone;
  a comment is a slot, not a listing.

The code that writes into the block is here, because the block's shape
is this cartridge's: `list_page/4`, which changelog and guidelines call,
and beside it `uncomment_page/4`, which fills a slot. Filling a slot is
a function of its own rather than a step of `list_page/4` for two
reasons: the two answer different questions — *the site kept a place for
this page* against *the site does not list this page yet* — and
guidelines, whose `:Support` page never had a slot, must not have an
entry resurrected out of a comment somebody wrote for their own reasons.
It drops the commented lines and calls `list_page/4` for the live ones
rather than taking the `# ` off, because the formatter drops the comma
before a trailing comment: an uncommented line would land in the list
with no comma before it, and `mix.exs` would not parse.

Rejected: planting a placeholder changelog, as this cartridge does for
`TESTING.md` — a changelog is a history the project keeps, and one this
cartridge made up would be the first entry of it.

**The sidebar links where it is told.** ExDoc's sidebar takes its link
from one option, `<% url = config.homepage_url || "#{config.main}.html"
%>` [6], for the project's name and its logo alike. v0.1.0 wrote the
repository there, so the logo opened GitHub; the repository has its own
option, `source_url`, and its own links, the source of each function.
`--homepage-url` is the website, written live only when given; unasked
the line is written commented with a placeholder, as `source_url` is
when no repository is found, so the key waits where it goes, and the
sidebar opens the docs' main page until it is filled in. Live, the
placeholder would send the logo to example.com.

**The logo is asked for.** `--app-logo` plants the placeholder and the
`logo:` that names it, off by default. ExDoc requires the file behind
the option:

> `:logo` - Path to a logo image file for the project. Must be PNG,
> JPEG or SVG. [1]

so the two go in together or not at all. Off, because the placeholder
is 1.9 MB with somebody else's name on it, committed into the project
to be replaced; the site without a logo is ExDoc's own. `state/1` reads
the `logo:` line, not the file: the file is a binary copied after the
patch set is applied, where the project's rewrite never sees it.

**The module groups are a preset, read off the project when not
asked.** `--module-groups` takes `layers` (the Phoenix layers: the
application's own modules, contexts, schemas, live views, controllers,
components, plugs, web, Mix tasks, exceptions), `ash` (domains, then a
group per DSL role told by its behaviour, the resources after them, the
same web layer), `contexts` (a group per directory under `lib/<app>/`,
then the application's own modules and the web layer) or `none`
(ExDoc's flat list). Unasked, a project that depends on Ash gets `ash`
and any other `layers`: the line the project is on decides, as its Ecto
decides the database page.

The groups are functions of `mix.exs`, written after the project's own,
because two things a literal cannot say
decide them: a module's behaviours — a live view and a change are named
like anything else — and, for `contexts`, the directories of `lib/<app>/`
as they are when the docs are built, so the context added next month is
a group without touching the file. The alternatives:

* *v0.1.0's one set of regexes.* On tunez it put the changes,
  calculations and senders under Schemas, the live views under Web, and
  left the repo, the mailer, the release and the Mix tasks ungrouped
  (§4). Names alone cannot tell an Ash change from a resource.
* *Groups written as literals at install, one per context found.* A new
  project has no contexts yet, and a list written once goes stale with
  the first context added; the large project, which is the case for the
  `contexts` preset, is the one where it goes stale fastest.
* *`nest_modules_by_prefix` instead of groups.* It nests names under a
  prefix and leaves the groups as they are; it answers "what is in
  Music" only as well as the names do, and a live view under a context
  prefix still reads as that context's.
* *A library preset.* The workbench makes applications.

Two rules the presets keep, both from the matcher: specific before
general, since the first match wins — the Ash roles before Resources,
Controllers before Web — and a name that ends in `Error` or `Exception`
kept out of Schemas and Resources, which match on shape, so an
exception reaches its group at the end.

**The name is found, not asked.** The site is titled with `name:` from
`mix.exs`; the one the project has is kept, and without one the app's
name is made words — `lorem_ipsum` is *Lorem Ipsum*, which is also
where the workbench's `PROJECT_NAME` came from. v0.1.0 capitalized the
atom whole (*Lorem_ipsum*). An acronym comes out as a word (`my_api` is
*My Api*); `--project-name` says it otherwise.

**The repository is found, and only the project's own.** `source_url:`
drives ExDoc's links to each function's source. The installer keeps
the one mix.exs has, or reads the `origin` remote and makes it the page
a browser opens (`git@host:owner/repo.git` is `https://host/owner/repo`).
Git answers for the nearest repository up the tree, and a project
directory can sit inside another one: tunez under `_workspaces/` has no
`.git` of its own, and `git config --get remote.origin.url` there
answers the workbench's. So the remote is read only when the directory
is the root of its repository — `git rev-parse --show-prefix` prints an
empty line exactly there. Otherwise the placeholder is written
**commented out**: live, it turned every "source" link of the site into
a 404 on a repository that does not exist; commented, ExDoc leaves the
links out (verified in the probe: the page's only GitHub link left is
ExDoc's own footer) and the line waits to be filled in. `authors:`,
which is the URL's owner, is left out with it. Under `Igniter.Test` the remote is not read at
all: the suite runs inside the workbench's repository.

**The database page is no longer here** (v0.4.1). It was read off the
project — a project with Ecto got `database.md` among the extras, a
placeholder until `mix db` wrote it — which made this cartridge reason
about a page a task it does not install would overwrite. It belongs to
[dbschema](../dbschema/), which writes the page and lists it here with
`list_page/4` when there is a site, the way changelog lists its own.

**The insert does not build the site** (v0.6.0). `--build` queued
`mix docs` behind the patch set, because the task needs the
dependencies fetched and compiled, which happens after the files land.
It is gone: the box already names the command twice — `afterwards/0`
for the reader and `build:` on its door for the console — and the door
runs it as a job, whose output the reader watches, where the queued
task ran inside an insert whose log nobody reads for that. An option
that leaves no mark (`state/1` answered `nil` for it) and only queues a
command the box already names is a third place saying the same thing.

## 4. Evaluation

Verified on 2026-09-21 in a probe (`mix phx.new --no-ecto`, the
package as a path dependency): `workbench.install.exdoc --coverage`
and `workbench.install.coverage --exdoc` leave the router as phx.new
wrote it; `mix coveralls.html`, `mix cover` and `mix docs` build a site
with `excoveralls.html` beside `testing.html`; served by the console's
listener, the report page opens the report, the report's *Pages* tab
opens the report page, its project name opens the site; `mix docs` with
no `cover/` yet builds the site without the report. In a second probe
from the same birth, exdoc alone: `mix.exs` names neither a changelog
nor a logo and `mix docs` builds; `workbench.install.changelog` then
lists `CHANGELOG.md` among the extras and in the `Project` group, and
the next `mix docs` has `changelog.html`. The cartridge suite asserts, option by option and both ways: the router
untouched, no controller and nothing under `doc/`, the mark on a v0.1.0
project, the name and the repository found or asked for and the
placeholder commented out, the website live or commented, the logo only
when asked, the module groups by the project's line and by the flag
with an unknown preset refused, the README listed or waiting in its
slot with `main:` going out with it, the changelog refused without its
box and listed with it — and in the other order, listed by the box that
opens the file — the report page refused without coverage's
`--md-report` and listed with it, live where the report is there and
commented where it is not, nothing of it without `--coverage`, no run
queued by the insert, and every one of those answered back by
`state/1`.

The module groups were built with `mix docs` and read back off the
sidebar ExDoc wrote (`doc/dist/sidebar_items-*.js`). In the probe, with
a context, a schema in another context, an exception, a live view and a
plug added: `layers` groups each where it belongs and leaves nothing
ungrouped; `contexts` gives Accounts and Billing, the exception inside
Billing; `none` is ExDoc's flat list, which itself sets exceptions
apart. In tunez, with the `ash` preset in place of its hand-written
groups: two domains, seven resources, three changes, one calculation,
one type, three senders, five live views, and one module ungrouped,
`Tunez.Seeder`, which has no role the preset can read. Before, a
simulation of ExDoc's matcher over the same modules had shown v0.1.0's
regexes on tunez as described in §3.

Not verified here either: a project that declares no behaviour where
the preset reads one — a live view written without `use Phoenix.LiveView`
— lands by its name or in Web.

Not verified: an Ash project's module groups (the regexes are written
for the Phoenix line's contexts and web modules); the epub formatter,
which the hooks also serve.

## 5. Limitations

* **`README.md` is listed by default, and read.** phx.new writes it, so
  the site opens on it; `--no-readme` (v0.3.0) leaves it out, for a
  README written for the repository's front page rather than the docs',
  and the site then drops `main: "readme"` and opens on ExDoc's own
  default, the API reference. With the option on and no README there —
  a project that deleted it — the two entries and `main:` are written
  commented out (v0.7.0), which is the slot the other pages get: `mix
  docs` stops on an extra whose file is missing as much as on a `main:`
  naming no page, and it never reads a comment. Nobody fills that slot
  automatically, because no box on the shelf writes a README: the one
  that would have to know every cartridge is the coupling this
  structure exists to remove.
* **An output dir moved by the project is not followed.** A `docs:
  [output: …]` other than `doc` leaves the console's door reading
  *nothing built*. `state/1` could report it; the console's plan
  records the question [3].
* **ExDoc follows symlinks when it copies an asset dir**
  (`dereference_symlinks: true`, [2]); a link under `cover/` pointing
  out of the project lands in the site. The console's listener follows
  them too [3].

## References

1. ExDoc 0.40.4, `lib/ex_doc.ex`, the documentation of `ExDoc`'s
   options (`:output`, `:assets`, `:before_closing_body_tag`), read in
   `deps/ex_doc` on 2026-09-21.
2. ExDoc 0.40.4, `lib/ex_doc/formatter.ex`, `copy_assets/2`, read on
   2026-09-21.
3. `console/PLAN.md`, *The project's pages are served by the console,
   settled on 2026-09-20*, in this repository.
4. ExDoc 0.40.4, `lib/ex_doc/config.ex`, `match_module/4`, and
   `lib/ex_doc/retriever.ex`, where `:kind` is put into the metadata,
   read on 2026-09-21.
5. A research pass of 2026-09-21 over the raw `mix.exs` of each
   project's default branch, by a subagent of this session; read by it,
   not by this paper's author, and cited as its report gives them:
   OpenFn Lightning (`groups_for_modules` at L276), Trento web (L196),
   ash (L197), ash_postgres (L142), ash_authentication (L195), and the
   fourteen applications without module groups named above.
6. ExDoc 0.40.4,
   `lib/ex_doc/formatter/html/templates/sidebar_template.eex`, line 8,
   read on 2026-09-21.
7. A check of this paper's claims against ExDoc as published, on
   2026-09-23, by a subagent of this session: hex.pm's API for the
   released versions, and the repository for `assets/css/_html.css`
   (the themed image's rule and its silence, commit `e1da25c1` of
   2021-12-07, first released in v0.27.0), `lib/ex_doc/extras.ex` (the
   `File.read!` that stops on a missing extra) and
   `lib/ex_doc/formatter/html.ex` (the only `:main` guard, which is
   `"index"`). The sidebar's link and `:assets`' shape were confirmed
   there too, as this paper had them.
