<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and the format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/):

- `Added` for new features.
- `Updated` for changes in existing functionality.
- `Deprecated` for once-stable features removed in upcoming releases.
- `Removed` for deprecated features removed in this release.
- `Fixed` for any bug fixes.
- `Security` to invite users to upgrade in case of vulnerabilities.

## Unreleased

### Added

- **The mishka_chelekom cartridge: Mishka Chelekom's components
  without Ash.** The library was on the shelf only as a value of
  ash's `--components`. Its own box adds `{:mishka_chelekom, "~>
  0.0.9", only: :dev}` and queues the library's batch task, `mix
  mishka.ui.gen.components --import --helpers --global --yes`, the one
  its installer composes, so nothing of it is reimplemented. Two
  decisions are the box's. `--components` names the ones to generate:
  the library's task generates exactly the names it is given, so the
  list is completed with what each component declares `necessary` and
  with the eight whose functions stand in for `CoreComponents`
  (`alert`, `button`, `icon`, `input_field`, `list`, `modal`,
  `navbar`, `table`), without which the swap leaves `Layouts` calling
  a `<.flash>` nobody defines. Ten components are 263 KB of minified
  CSS where all 74 are 1.46 MB. `--no-daisy` takes daisyUI out — its
  plugins, its dependency, its classes in `Layouts` and the home page,
  rewritten as Tailwind utilities, and the page's ground as a rule of
  its own. It exists because of a measurement: on a Phoenix 1.8.15
  project, over the computed style of 146 elements with daisyUI's
  plugin in and out, the two libraries share five class names, and
  Mishka's open `collapse` is 0 px high beside daisyUI. daisyUI stays
  by default, and the option is refused while `cinder` or
  `ash_authentication_phoenix` is in. The generated components are run
  through `mix format` — the library leaves `button.ex` a line short of
  it, which a pre-commit format check refuses — unless `--no-format`.
  `--mcp` forwards the library's MCP server at `/mcp` in the router,
  under `dev_routes`: the way to serve it that needs no `mix` on the
  host. The route is the one `mix mishka.mcp.setup` writes, and the
  cartridge writes it itself, a WORKAROUND marked where it shows: on
  the router `phx.new` generates, that task puts its `forward` inside
  `pipeline :browser` (0.0.9 and 0.0.10-alpha.8; the draft of the
  issue is `ISSUE-mishka_chelekom-mcp-route.md`, not filed). Each
  component's value carries its page in the library's documentation.
  The queued command goes through `mix workbench.mishka_components`,
  which completes the list off the fetched package's catalog. Inserted and ejected through `wb.sh` on
  a copy of a workbench project. mishka_chelekom v0.1.0; its DESIGN
  has the sources and what was not measured.

- **`mix mcp.json`, planted by mishka_chelekom's `--mcp`: the
  client's side of MCP, read off the project when it is run.** A
  client needs the address of `/mcp`, and its port is the one the
  compose publishes the app on — a fact of where the project runs. A
  `.mcp.json` written by the installer carries a number the next bake
  changes; a port-free stdio entry through `docker compose exec` makes
  Docker a requirement of a file in a project that runs with `mix`
  anywhere else. The author's answer is a task of the project's own:
  it takes the endpoint's port from the app's configuration, looks in
  `docker-compose.yml` for the line that publishes it (`4011:4000`),
  falls back to the endpoint's port where there is no compose, and
  adds its entry to `.mcp.json`, keeping the file's other servers.
  The file is the machine's, as `.env` is, and `.gitignore` lists it.
  Run on a host project in the four cases, and its premises read
  inside a workbench project's container: the compose is there, the
  endpoint is on 4000, and the line found is `4011:4000`.

### Updated

- **A door can be for a client, and the console gives the client's
  line with the port in it.** A cartridge's doors were pages: the
  console links them and reads a 4xx as a warning. mishka_chelekom's
  `/mcp` is an endpoint a program talks to, and a `GET` gets the
  server's own 406, so as a door it was an amber chip on a link that
  opens an error. A door now says `client: [{label, line}, …]`
  (`Feature.console/0`): the console shows its address and does not
  link it, reads any answer to the bell as *answers*, and under the
  box's *Opens* gives each line with `{url}` filled — `claude mcp add
  --transport http mishka-chelekom http://localhost:4011/mcp` — and a
  *copy* button, the console's first (`Copy` in `hooks.js`). The words
  are the cartridge's and the console learns no protocol. A door of
  this kind may name the project's task that sets a client up
  (`build:`), offered on its plate as a page's is. The protocol's own check
  — `initialize`, then `DELETE` of its session — was measured and left
  out of the bell: 1 to 2.3 s on a project in dev, once over 8 s,
  against the 2.5 s a door is given. Seen on the console from the
  working tree, against a project up in dev.

- **A long list of names in a box's form is set in columns, and a
  value documented by an address carries it beside its name.**
  mishka_chelekom's `--components` is 74 values in six sections, each
  with its page in the library's documentation: read down, with the
  link under each, 148 lines. A value whose doc is an address and
  nothing else now has a `↗` mark after its name, which opens the page
  apart while the name still ticks the box; and an option with more
  than a dozen values, none of them with a sentence under it, sets
  each section in columns read down (`.vals.cols`). A value with a
  sentence keeps its line, so ash's options are as they were. Seen on
  the console from the working tree: five columns to a section.

- **A section's name ticks its values, or clears them.** In an option
  that takes several, each section's name is the control for the whole
  of it — the 22 form fields at one press — and counts what is ticked
  in it (`forms 22 of 22`). Pressed when they all are, it clears its
  own and leaves the other sections alone; a value shut for what the
  project lacks stays out. There is none for the whole option: left
  empty, an option already means all of them. The form's state is the
  server's, so it is an event of the box in hand (`section`,
  `Box.section/5`), pressed through the LiveView in its test.

- **`workbench.igniter_install`'s listening shell runs any package's
  task.** What made `mix igniter.install` fail on an installer's
  issues, and gave a spinner a screen over a pipe, is `watched/2`
  there; `run/1` calls it, and so does the mishka_chelekom
  cartridge's queued command.

### Fixed

- **Coverage's option is `--md-report` wherever the papers name it.**
  It was `--exdoc` until coverage v0.9.0, and the old name had stayed
  in the manifest's own documentation (`Feature.console/0`'s example of
  `build:`, and the example of a refusal), in chiefs_setup's table of
  its recipe — which already passed `--md-report` — in the shelf's
  index and in the comments of five test files. Found when the old name was
  repeated in an answer about why the coverage page has two commands.
  The records of the renaming, and a test's fixture of an old project's
  `Insert coverage --exdoc`, stay as they are.

- **`catalog --json --brief` takes an option whose values come in
  sections.** The brief read `value` off every choice, and a sectioned
  list is groups of them: it raised on the first cartridge to declare
  one, mishka_chelekom's `--components`. The brief keeps the values
  alone, flat.

## v0.18.4 - (2026-10-06)

### Added

- **`.field-error`, how a field says its value will not do.** The
  design system had chips, the unlit button with its reason, and
  `.note` and `.help` for the small print, and no piece for the error
  of a field; the first one that came up, the project's name ending in
  `Web`, was set in `.note` under the New Project card's command and
  read as the hint of a field. It is one line under the field, in
  `--bad`, with the `×` before it, and the field marked `aria-invalid`,
  which rings it in the same ink — said where the value is edited and
  nowhere else. A screen that only reads the value says it with a
  `.chip.bad` and the way to the field. Settled on a page of three
  takes on the real Config field and the real card
  (`los-errores-de-un-campo`, retired the same day): the marked field
  with its line, over a chip alone, which hides the reason behind a
  hover, and a block, which is the weight of a job that failed.

### Updated

- **The README's file tree is a drawing again.** Under *The Workbench
  & its Workspace* it had become the `File | Role` table of the
  cartridges' *Contents* (v0.18.2); it is the block `igniter/README.md`
  draws its own tree in, the marks and a `#` comment to a line. Eight
  lines are read at a glance in a block, and a package's README draws
  its tree while a cartridge's lists its files with a role each. The
  two workspaces of the example are named as projects are.

### Fixed

- **A project's name cannot end in `Web`.** `./wb.sh add health_probe`
  stopped on *Could not find module PortfoliosWeb.Endpoint* in a
  project named *Portfolios Web*, whose endpoint is
  `PortfoliosWebWeb.Endpoint`. Phoenix disagrees with itself about
  such a name: `phx.new` always adds `Web` to the app's module
  (`phx_new/single.ex`, `web_namespace`), while its own generators
  take a module that already ends in `Web` to *be* the web module
  (`Mix.Phoenix.web_module/1`: `phx.gen.html`, `.live`, `.json`,
  `.auth`, `.channel`, `.socket`, `.release`). Igniter copies that rule
  (`Igniter.Libs.Phoenix.web_module/1`), and with it eleven cartridges
  and the birth's own setup, which had already written
  `config :portfolios_web, PortfoliosWeb.Endpoint, http: [ip: …]` into
  that project's `dev.exs`, for a module that is not there, and said
  nothing.

  The workbench could teach its own cartridges the right module. It
  could not teach Phoenix's generators, nor Ash's installers, nor
  whatever else the reader runs afterwards, and a project that looks
  sound and fails later, far from the cause, is the worse gift. So
  `new` refuses the name, when changing it costs nothing: an app whose
  name ends in `web` as a word of its own (`Portfolios Web`,
  `portfolios_web`; not `Cobweb`, not `Web Shop`), with the reason and
  the name without that word. In the console it is the field's own
  error: under `PROJECT_NAME` in the workbench's Config, where the name
  is edited, and the New Project card, which only reads the name, shows
  it in a `project name` row with a chip and the cog that leads there,
  Create unlit with a short reason, and submits nothing. `adopt`
  takes such a project as it is — it exists, and it is the reader's —
  and warns that the inserts that touch the endpoint or the router
  will fail on it. No issue was found upstream for it (one search of
  Phoenix's tracker, 2026-10-06); the refusal goes when `phx.new` and
  `Mix.Phoenix.web_module/1` agree.

## v0.18.3 - (2026-10-06)

### Updated

- **Going back one box and putting the box away are two buttons.** In
  v0.18.2 Put back became the step back along the trail of boxes, and a
  reader five boxes deep had five presses between them and the screen.
  A square beside the box's name is the step back now — one box, on
  the paper it was left on, at the line it was left at — and Put back,
  Close and the scrim put the box away whole, whatever led to it, onto
  what it stands over: the screen, or the workbench's drawer. The
  square is there only when the box was opened from another: a box
  taken off the shelf has nothing behind it, which is not a verb it
  cannot do now but one it does not have.

- **Two drawings in the sprite, `back` and `expand`.** Both were
  characters, `‹` and `⤢`, and a character sits where its face puts
  it: neither stood in the middle of its square. They are
  `assets/design/icons/*.svg` now, like every other mark, and the hint
  on a figure, on a thumbnail and on the box's face wears the drawing
  (measured in a browser: both 0 px off the centre of their button).
  The step back is Put back's own button, a `.btn` as tall as it and
  square, with the drawing for its words: as the house's square it was
  another size, another ground and another ink in one head. Settled on
  a page of six takes on the box's real head (`el-boton-de-volver`,
  retired the same day): the same button with the drawing alone, over
  the same with its destination, the two grouped at the right, a
  breadcrumb, and both as squares.

### Fixed

- **The expand hint of a cover in the README's tables is on the cover.**
  A figure in a paper is a block as wide as what holds it, and its hint
  stands at that block's corner: right for a diagram, which fills the
  column, and beside the picture for an 80-pixel cover in a table's
  cell, where the hint's two words did not fit either. A picture in a
  cell that declares its width is a thumbnail now (`.fig.thumb`, the
  Booklet hook): its figure is the picture's size and the hint the mark
  alone, the sprite's drawing in a 22-pixel square in its corner.

- **The shelf's cover column is as wide as the cover.** A table whose
  cells are pictures shares its width evenly between its columns, and
  the rule asked for *a* cell holding only a picture. The shelf met it
  the day its cover stopped being a link (v0.18.2): four equal columns,
  197 pixels around an 80-pixel cover. *Every* cell is what was meant,
  and a selector cannot ask it — `:has()` does not nest — so the
  renderer marks such a table (`Console.Papers.mark_picture_tables/1`,
  `table.pics`), as it marks a file tree. In a table of words a picture
  that declares its width is drawn that wide and its column is the
  picture's: both tables of the shelf draw every cover at 80 by 113.

## v0.18.2 - (2026-10-06)

### Updated

- **The workbench's README opens a cartridge in the console, not on
  GitHub.** Read in the drawer's Manual, a link into a cartridge's
  directory led to a path the console does not serve. Each is now read
  by the shape of its address, wherever it stands — a cell of the
  shelf's table, of the pending one, or a sentence: the directory is
  the box, a paper the box carries is that paper in its Manual, and
  its NEED is the box itself, as from the cartridge's own papers
  (`Console.Papers.workbench_link/2`, beside `link_tag/3`). Whatever
  else points into the repository — another package's README, the
  licence, a paper a box does not carry — is read on GitHub, which is
  the rule a cartridge's papers already had; a picture under `assets/`
  is the figures route's.

- **A box opens over what was being read, and is put back onto it.**
  Pressing a cartridge in the workbench's README opened its box in the
  drawer's place, and Put back left the reader on the bare screen: the
  README, and their place in it, gone. The two are on the page at once
  now, the box on top. The address carries both (`?wb=manual&box=…`),
  the drawer stays mounted under the box, `inert`, and Put back, Close
  and the scrim take the box away and nothing else. `paper` in that
  address is the box's manual's, so the drawer stays on the paper it
  was on. Both in the address used to mean the opposite, the drawer
  shown and the box hidden, which nothing in the console led to.

  A box pressed in another box's paper cannot be drawn over it: there
  is one box in hand, with one form, one recipe and one face. It leaves
  a trail in the address instead — `from=coverage.manual.readme`, the
  box, its screen and its paper — and Put back becomes *Back to
  coverage*: one box back at a time, on the paper it was left on, and
  the Booklet hook returns the page to the line the reader left
  (measured in a browser: left at 2316 px, back at 2316 px). The box's
  own links keep the trail, and a link to another of its papers adds
  nothing to it.

- **A cover in the README's tables is pressed to be seen, not to go
  somewhere.** The cover was the link to the cartridge, and in the
  console one press opened the picture's viewer and left for the box at
  the same time. The name is the link now, and the cover is a picture.

- **The README's two drawings of what is not yet there.** The file
  tree under *The Workbench & its Workspace* is the `File | Role` table
  the cartridges' *Contents* are, branches in code with no-break
  spaces: it is by those that the console tells a tree from a table
  (`mark_trees/1`), and two rows written with plain spaces came out as
  ordinary cells. The table of pending boxes has the shelf's shape
  without the cover — a pending box has none, and a placeholder took a
  column to say nothing: the name, the stage in a column of its own,
  the need, and the papers it has so far (`assets/readme/build.py`).

## v0.18.1 - (2026-10-06)

### Fixed

- **`./wb.sh new --database sqlite3` creates the project again: a
  deployment a project cannot have is no longer an error.** Since the
  three compose files are baked at a project's birth (2026-09-27),
  `new` and `adopt` ended on `** (Mix) workbench.compose: a scaled
  deployment cannot run on SQLite`, because the bake of the scaled
  file was one more step of a chain and its refusal failed the whole
  birth. The refusal was right and its kind was wrong: N replicas on
  SQLite are N database files, so what a request reads depends on the
  replica that answers it, with a balancer or without one, clustered
  or not (the `ecto` cartridge, v0.3.2, DESIGN §3.5). That is not a
  render that failed. It is a deployment this project does not have.

  A cartridge's `compose/1` can now say so: `{:unavailable, reason}`
  beside `{:error, reason}`, which stays for a set of services that is
  wrong (two databases). `mix workbench.compose` prints
  `unavailable> REASON` and exits with 4, the way a port still to
  choose is `need> NAME DEFAULT` and 3, and `wb.sh` reads it without
  naming a service or a deployment: the reason is the cartridge's,
  shown as written. `new` and `adopt` leave the project with its dev
  and prod files and one note. `add` removes a scaled file the project
  can no longer have, in the insert's own commit (a project born
  `--no-ecto` and given `ecto --database sqlite3` afterwards), and the
  eject's revert brings it back to be rendered again. `bake --deploy
  scaled` ends with the reason.

  The status carries it — `deployments.<deploy>.unavailable` in
  `status --json`, null for a deployment the project can have, and
  *not available* with the reason under the Deployments line of the
  text — and the console draws it where the deployment would be: the
  scaled row stays on the Deployments sheet with *not available* and
  the reason in full, its Bake, Build and Up unlit with that reason,
  on the rail too. Switched off and saying why, not hidden.

  It was first read as a consequence of `iex` attaching to the running
  node (2026-09-16), which it is not: dev runs no release. Its
  container boots `elixir --sname <app> -S mix phx.server` and `iex`
  enters with `--remsh`; a release is only what prod and scaled run.

## v0.18.0 - (2026-10-04)

### Added

- **Six boxes on the shelf that are identified and not designed:
  `security_review`, `machine_learning`, `seo_aeo`, `browser_tests`,
  `message_broker`, `event_stream`.** Pending, as `stripe` and `specdd` are — a manifest
  whose `pending?/0` is true, so the catalog lists them, the console
  counts them under *Not done* and `add` refuses them — and each with
  the two papers such a box can honestly have: a `NEED.md`, which the
  catalog test asks of every cartridge, and a README that says what the
  box is expected to bring and, under *Open*, what its design has to
  settle before a line of installer is written. No `DESIGN.md`, no
  version, no test: there is nothing yet for them to be about.

  That made a second kind of pending visible, and the console was
  saying one thing of both. *Designed, not built* was its line for
  every box that is not done, true of `specdd`, whose design is
  written, and false of these six the moment they appeared — and of
  `stripe`, as it turns out, which has had a need and no design all
  along. A pending box is now read as one of two stages:
  **designed** when it carries a `DESIGN.md`, **identified** when its
  need is all there is. `ConsoleWeb.Cartridges.not_done/1` reads it off
  the papers on the mount, the way the Manual reads them, so no
  manifest declares it and nothing has to be flipped: writing the
  design is what moves the box. The chip's title, the reason the Files
  screen is dark and the sentence that stands in for a missing summary,
  on the box and in the shelf's list, all say it from that one place.

  They are named for the need and not for the tool, the rule `db_admin`
  and `test_doubles` already follow, because the tool is the part most
  likely to become an option: `message_broker` starts from RabbitMQ and
  `event_stream` from Kafka, each with Broadway in the project, and
  either may offer another server the way `db_admin` offers four
  admins. `security_review` is a review of the project against the
  OWASP Top 10's current edition, kept as a file of the repository,
  with the checks a machine can run (Sobelow, `mix deps.audit`,
  `mix hex.audit`) behind one task to shorten it — the review is the
  box, the tools are what speed it up. `machine_learning` is a model
  served from inside the application with Nx — Bumblebee to load it, an
  `Nx.Serving` in the supervision tree — where the usual answer is a
  second service in another language. `seo_aeo` is the one named by
  its discipline, because that is the name the need goes by: what the
  application emits so a search engine and an answer engine find and
  quote its pages — metadata, sitemap, crawling rules, structured data
  — with the answer-engine half as options the reader chooses, since
  that half is young and `llms.txt` is a proposal, not a standard.
  `browser_tests` is tests that drive the application through a real
  browser — Playwright as a service of the workspace under a profile
  `up` never starts, the way `k6` is — for what only a browser does: a
  hook, an upload, a full navigation. The two messaging services go
  after `monitoring` in the registry and the other four before the
  services;
  both services are expected to take `messaging`, a role the vocabulary
  has had since it was written and no box has used.

  More candidates were listed the same day (a notebook on the running
  node, background jobs, tracing, type checks) and deliberately not
  made boxes: choosing them and drawing where each one ends is analysis
  that has not been done, and a shelf with more boxes pending than
  built would read as a promise. The README names the eight pending
  ones, by stage, in a table `assets/readme/build.py` writes from the
  catalog.

- **The Changes paper can throw the changes away, not only commit
  them.** The paper said what a dirty tree costs — `add` and `eject`
  both want a clean one — and offered one way out of it: the commit.
  The reader who had decided their changes were not worth keeping had
  to leave the console for a terminal, which is the one thing the
  console is for. `wb.sh discard` is the other way out: the tracked
  files back to HEAD and the untracked ones gone, exactly what the
  commit would have taken, and nothing git ignores — `deps/` and
  `_build/` are the container's work, and throwing them away would cost
  a recompile to undo nothing. It is the verb `undo_failed_insert`
  already ran for an insert that failed, named and given to the reader.
  The console keeps its side of the house: `Console.Git` still only
  reads, the button runs the verb as a job, and the job waits for the
  reader's word first, like `delete` and `prune`.

  The two live in the one card, whose foot now reads down and presses
  across — the Deployments card's shape (2026-09-26) — each line the
  danger card's three-cell grid: the command taking the width, the verb
  at the right edge on `--verb`, the note under the command, where what
  it says is what that command takes. Which cost Commit the row it had
  been keeping to itself, with the button at the left and the `wb.sh`
  line nowhere but in its title, and gained it the shape every other
  box that runs a command already had. Discard went through a danger
  card of its own under the files first, the way `delete` sits apart on
  the Deploy tab: one dirty tree is one thing, and what can become of it
  is a choice between two, not two boxes. What that card's red edge
  said, the button says, filled as `delete` is: in this house the fill
  is what the verb costs and not how often it is pressed — `eject` is
  outlined because the cartridge can go back in, and this, like
  `delete`, cannot be taken back. The note is under it, and the word it
  asks for comes before it runs. Asking, the note takes the row, so the
  card does not move under the hand at the moment it decides, and its
  two buttons carry `type="button"`: a button with no type inside a form
  is a submit, and the card is the commit's form, so bare they confirmed
  the discard and committed behind it — the author saw it. In the danger
  card they had stood in a `section`, where there was nothing to submit.

### Updated

- **The README is a tour, read in order.** It was an operating manual
  in the order the commands were written; it is now written so that
  every section only uses what an earlier one explained. It opens on
  the two things the workbench is — a development environment that
  asks the host for nothing but Docker, and a knowledge base of the
  ecosystem kept as cartridges — and on what that is good for; then the
  workbench and its workspace, the cartridges as a concept and as a
  shelf, the console screen by screen with a capture of each, writing a
  cartridge, and why it is shaped like this, with what each decision
  costs. The captures are on the dark ground and come from one session
  on a real workspace (`assets/readme/console/`); the legend of the
  rail's plates is drawn from the console's own stylesheets
  (`assets/readme/legend.html`).

  Two tables are not written by hand: the shelf, one cartridge to a row
  with its cover, version, summary and papers, and the pending boxes
  with their stage and need. `assets/readme/build.py` writes both from
  `./wb.sh catalog --json --brief`, between markers, and cuts the
  covers' thumbnails. CI holds the README to them: `build.py --check`
  writes nothing, compares the tables the catalog would give with the
  ones the page has and looks for every thumbnail, off the package's
  own `mix workbench.catalog` and with no Docker, so a cartridge added
  or versioned without writing them again fails the run and says how
  to mend it. The file is Markdown with two tags, each for what
  Markdown cannot say — an `<img>` for a width or a side, a `<br>` for a
  second line inside a table's cell — and says so to markdownlint.

  What it claims was measured or read, and it says where it was not: it
  has been run on Linux, and macOS and Windows are still to try. On
  Linux it names the native Engine, with the one measurement behind it
  (2026-10-04, one run each on the same machine: the workbench's image
  from scratch in 143 s on the Engine and 837 s on Docker Desktop;
  compiling, testing and inserting a cartridge the same on both). *What
  I would do differently* is a sentence for now, to grow as the
  decisions are tested. The draft's two predecessors
  (`README2.md`, `README3.md`) and the two captures only the old page
  used are gone.

- **The two package READMEs say what is there.** `igniter/README.md`
  still took `health_endpoint` for its reference, kept templates inside
  the cartridge's directory and Elixir assets under an `.asset` suffix,
  listed five Mix tasks of eleven and named one cartridge as not done:
  it now draws the package as it is — `health_probe` the reference,
  everything that is not code under `priv/features/<feature>/`, the
  file modules, the three suites that stand over the cartridges' own
  tests. `console/README.md` names the seven screens and the modules
  that came after its table was written (Docker, Terminals, Installers,
  Nodes, Hex, Themes, Services, Doors, Reports), and speaks of the mock
  in the past.

- **The rail opens 500px wide.** 380px was the width the rail was born
  with, and the papers it now carries — the Record's address face, the
  cartridge in hand, the tables — were all read in a rail the reader had
  to drag wider first. The default is what they would have dragged it
  to; the bounds, the memory per browser and the grip's double-click
  reset are unchanged, so a reader who already has a width keeps it.

### Fixed

- **CI is green again, and it had not been since 2026-09-29.** Two
  things, neither of them in the code under test. The console's
  Dialyzer step failed every run with ten calls to functions of
  `WorkbenchIgniter` it called missing: the console carries the package
  as a path dependency, the lock file says nothing of one, and dialyxir
  takes its cached PLT for current as long as the lock is — so every
  function the package grew after that PLT was built did not exist to
  it. The step runs with `--force-check`, which looks at the modules
  themselves (half a minute); the same flag is in the commands the
  README and `CLAUDE.md` give. And `grown_vs_born_test.exs` timed out
  on three runs of eight: it grows a project order by order on every
  core, a desk has twelve and the runner a handful, and ExUnit's minute
  was not always enough. The two tests take ten.

- **The drawer's Manual reads the new README whole.** Three things
  stood between that page and the console, and the README found all
  three the day it was written. The renderer leaves raw HTML out, so
  the covers of the shelf and the lines inside its cells were gone:
  `Console.Papers.house_tags/1` takes the README's two tags out before
  the page is rendered and writes them back after, and what it writes
  is not what it read — the source when it is a picture under
  `assets/`, a width in digits, a side, the `alt` escaped; an
  `onerror`, a `style` or a source anywhere else is not copied. For the
  workbench's README alone: a cartridge's papers never pass through it,
  and nothing turns the renderer's escaping off. A heading's anchor was
  written as its `id`, and the README has a *Deployments* and a *Logs*,
  as the page does (the rail's table, the logs' pane): two elements
  with one id. The anchor is `data-anchor` now, which is what the
  booklet's hook looks for, so a paper is free to name its sections
  anything. And a heading with an ampersand reached the index twice
  escaped, *THE WORKBENCH &AMP; ITS WORKSPACE*, with an id no link
  written for GitHub could land on: the index and the anchor take the
  heading's words as written.

- **The ash cartridge queues `mishka_chelekom` first, and `/sign-in`
  has its styles back.** The author found the Ash sign-in page unstyled
  on `_001` (2026-10-03) — no blue on the buttons. Tailwind 4 scans
  only what `app.css` names, and the
  `@source "../../deps/ash_authentication_phoenix"` that
  `ash_authentication_phoenix`'s installer writes was not there: 18 of
  the page's 70 classes had no rule in the compiled stylesheet. Ejecting
  and re-inserting the cartridge reproduced it, and the cause is
  `mishka_chelekom` 0.0.9, which reads `app.css` off the disk and writes
  it back whole — and Igniter flushes nothing to disk until a run ends,
  so it was writing back the file as it stood before the command, over
  everything the installers before it had put there. Nothing of ours and
  nothing of Ash's: `ash_authentication_phoenix` had patched the source
  and said so. The cartridge now queues `mishka_chelekom` first, where
  there is nothing for it to drop and every installer after it stacks on
  its write. Marked WORKAROUND wherever it shows, to remove when the
  installer reads the source; the issue is drafted at
  `ISSUE-mishka_chelekom-app-css.md` and not filed yet, so the link is
  a TODO in the four places that carry it. ash v0.9.0.

- **The Deploy tab's three cards stand the same distance apart.** The
  author saw the gap over Deployments wider than the gap over Danger
  (2026-10-03). The stack's spacing is written once per card, as the
  following card's `margin-top: 14px` — but New Project also carried a
  `margin-bottom: 18px` of its own, and adjacent margins collapse to
  the larger of the two, so the first gap came out 18px and the second
  14px. The margin-bottom goes; the only margin New Project keeps is
  the gap inside it. There is no spacing scale in `assets/design/` to
  hang this on — the design system holds colour, roles and type — so
  the rule stays where the other two are, in `console.css`. Measured
  in the browser: 18/14 before, 14/14 after.

- **A long insert subject no longer stretches the Files screen.** The
  author found the cartridge detail's Files screen scrolling sideways
  when the commit's subject was long (2026-10-03). The subject's cell
  and the file paths both carried an ellipsis and neither ever reached
  it: `.install` is a grid, and its implicit `auto` column sizes to
  max-content, so the column grew to whatever the longest line asked
  for and took the screen with it — `ash`'s insert, whose subject
  carries every option it was given, is 365 characters, and the column
  came out 3061px wide inside a drawer of 1088. The column is
  `minmax(0,1fr)` now, and each row shortens its own way: a path to the
  ellipsis it already had, and the subject, which is the one cell whose
  length nothing bounds, over as many lines as it needs, so it is read
  whole rather than cut. Its title is dropped with the cut — a tooltip
  repeating what is already in view is noise. In the heading that names
  an insert's own sheet, `Files · sha subject`, the subject moves into
  the `small` the screen already had for a reading off the machine:
  mono, lower case, soft ink. 365 characters of condensed uppercase
  over four lines were a shout. Measured against the author's console
  on `_001`.

## v0.17.0 - (2026-10-02)

### Added

- **A background is drawn, and reverse video.** `Console.ANSI` turned a
  line's colours into classes for the text alone: a background's code
  was read and dropped, and what a tool printed white on red arrived
  white on nothing. The author asked how one stood (2026-10-01). A
  background is kept beside the text's colour now and said as
  `ansi-bg-N`, the sixteen, which `console.css` paints in the same
  colours of the terminal's theme the text wears — so a theme picked
  changes both. Reverse video (`\e[7m`) is the two changed over in
  those same classes, the terminal's own ink and ground standing in
  for one that was not set; the ground as a text's colour is taken
  without the opacity the reader gave it. It reaches whatever the
  module feeds: the terminals, the jobs, the logs.
- **The miniature's terminal shows the sixteen as a scale.** Its lines
  are real logs, each colour where a tool puts it, and tools leave
  colours out: blue, magenta and most of the brights were on no line,
  so a theme was judged on half its palette. The author asked for a
  service of the miniature's own (2026-10-01): *color*, in the
  job's violet, whose lines are the palette itself — black to
  white through red, yellow, green, cyan, blue and magenta, a line
  the eight and a line their brights. With a background to draw, the
  scale is a blend: each colour comes up over the one before it,
  `░▒▓█`, its own on the other's ground, so a shade is the two mixed;
  the first comes up over the terminal's ground and the last goes
  down to it, `▓▒░`. It is written as a terminal would be sent it
  and read by `Console.ANSI`, so the line is what a tool printing it
  would leave. Under a face that draws the blocks — Greybeard, Flexi
  IBM VGA, Fira Code: `blocks` in `hooks.js`'s `FACES`, said on the
  root — the scale is set in that face. Under one that does not it is
  set in Fira Code at the size that gives its characters the cell of
  the face in force, because Tamzen, the terminal's default, has no
  block characters (nor box-drawing ones: the `│` and `└─` of a
  compiler's warning come from a face of the browser's choosing), and
  that stand-in is wider than the cell; IBM Plex keeps the stand-in
  too, what Google Fonts serves of it not having been checked. Its
  chip sorts its lines like any service's. Seen on a running console,
  both grounds, in the Terminal part and in Overlay's.
- **The README shows the Interface tab.** Two captures the author
  asked for (2026-10-01), both on the dark ground: the Terminal part
  with Selenized worn, its twenty-two pickers in view and the sample
  logs down to the colour scale, and the Code part with House's, its
  twenty pickers beside the Elixir file — each cut to the drawer, the
  screen behind it being none of the matter. They stand side by side under
  the shelf's, with a sentence on what the console lets a reader set.
  Side by side is a Markdown table and not `<img>` tags: the console's
  Manual drops a paper's raw HTML, on purpose, and the first take, in
  HTML, showed on GitHub and not here. And in the Manual a table whose
  cells are pictures now splits its width evenly (`console.css`): left
  to their content, two pictures of one size came out a column wider
  than the other.
- **Greybeard, a bitmap face that draws the shades, the blocks and the
  boxes.** Looking at how the faces show in the terminal, the author
  saw `░▒▓█` blurred under Tamzen (2026-10-02): Tamzen has none of
  them, so they come from a face of the browser's choosing, off the
  pixel. The ask was not Tamzen mended but a face on the list that
  draws them itself. Seven open ones were measured as they ship
  and set in Chromium at their own size, counting the pixels that are
  neither ink nor ground: Greybeard, Departure Mono, Unscii, Spleen,
  Cozette and Fairfax came out with none, Terminus TTF with a few;
  Greybeard was taken. It is UW ttyp0 (Uwe Waldmann) turned into
  outlines by Andy Walker, MIT, and it is built as Tamzen is here — a
  family a pixel height, a hundred units a pixel, regular and bold in
  one cell — so it entered the same way: nine sizes, 11 to 18 and
  22 px (6x11 to 11x22), a pair of files each, `"GreybeardWxH"` in
  `console.css` and `greybeard` in `hooks.js`'s `FACES`, a bitmap like
  the other two. It brings all of U+2500 to U+259F, Powerline's
  marks, and at 15 to 18 px an italic of its own, declared too, so a
  comment on the Files sheet is drawn and not slanted by the browser.
  The files are the WOFF2 of its release v1.0.0, renamed to the
  house's `WWxHH` and nothing else (1.5 MB the twenty-six; the TTF
  were 7.5 MB the eighteen), `LICENSE-greybeard.txt` beside them, and
  Credits has its card: four faces travel with the console now. The
  house's default stays Tamzen. Seen on a console on the host, chosen
  in the drawer at 15 px and a leading of 1: shades, blocks and
  single and double boxes join cell to cell and line to line, in
  regular and bold. The author then saw the shades
  no different under it: the miniature's colour scale was set in Fira
  Code whatever the face in force, a vector face at a size off the
  pixel. It is left to a face that draws them now (the scale's entry,
  above).

### Updated

- **The layer on an address is a drawing, and a service has one face
  everywhere.** In Services, Doors & Pages a page's green square stood
  beside its cartridge's mention, whose dot is green when it is in,
  and the two read as one mark (2026-10-02). The colours were moved
  first — a canary yellow for the page, tried and left at 1.1:1 on
  the light paper; then violet for a service, blue for a door and grey
  for a page, committed that day — and the author then saw what colour
  could not mend: the square is the logs' service swatch, on purpose
  since 2026-09-08, the same 8 px and the same corner, and it was
  taken for a service of Logs or of the Terminal. Four drawings were
  proposed, and they were set beside the squares on `lorem_ipsum`'s
  own rail and Deployments rows in
  `assets/design/iconos-en-las-direcciones.html` (retired), five ways:
  the squares; the proposal, in the layer's colour with a red dot for
  the network; in one ink with the red dot; in one ink with the dot in
  the link's blue; in one ink, solid for published and hollow for
  inside. The fourth was taken, with the rack solid: red is `bad` in
  the house and a red dot on every published service reads as an
  alarm. Seen working, the blue dot did the same in small: a dot of
  colour in a corner is the language of state, it read as *active*,
  and on a plate that was down it stayed blue. The page was written
  again for that question — how the trade says a thing is reachable
  from outside (Docker Desktop and Portainer by the port made a link,
  OpenShift by a decorator on the node's corner, VS Code by a lock or
  a globe, Render and Kubernetes by the type's name: none by a
  colour) — with six takes on the same rows, lit and unlit: the dot;
  the letters HTTP, the author's thought, which the console cannot
  vouch for, a compose publishing ports and not protocols; an arrow
  leaving by the corner; solid and hollow; a padlock on the one
  inside; the dot in ink. The arrow was taken, at 15 px. So a plate
  wears a rack for a service's port — with an arrow leaving by its
  corner when the host reaches it; alone inside the pod — a globe for
  a route, the house's own, and a sheet for a page (`rack-net`,
  `rack`, `page` new in `assets/design/icons/`, in the sprite).
  `door_ref` draws it by its kind where the `::before` was.

  Then its colour. Violet while the plate is lit and the label's ink
  on an unlit one came first — colour on the channel it belongs to,
  the state — in the app's own violet of Logs and the Terminal; the
  gold of what is picked was weighed and left, being the mark of a
  choice and a neighbour of `warn`. And the author took it one step
  on: the rack on the service buttons of Logs and of the Terminal
  too, where the swatch was, and on a plate the colour each service
  wears there, its role's. Two objections were set down on a third
  writing of the page — the pod's role is grey and would read as
  unlit; pgAdmin's, Grafana's and Prometheus's are greens, back beside
  the cartridge's dot — and the author asked for both built, to weigh
  them working. On the dark ground the pod, lit, stood off the unlit
  plates well enough; no green service was in the project to be seen.
  It stays: a service has one face wherever it is named — the rack,
  in its role's colour — in the Logs' filter and the miniature's
  (`hooks.js`, the drawer), on the Terminal's buttons, and on its
  plate while it is lit (`svc`, said by the Record off
  `ConsoleWeb.Services` and worn as `--svc`); a door and a page, which
  are no service's, wear the app's violet (`addr-lit`); an unlit
  plate, the label's ink. How what answers is doing stays the
  reading's. The three layer tokens (`addr-port`, `addr-route`,
  `addr-output`) are retired, having no reader left. The plate is one
  component, so it reaches the rail, the Record, the box, the
  Deployments sheet and Docker's containers. Seen on a console on the
  host: the plates on both grounds, the buttons on the dark. The
  globe is also the mark of a site in Credits: a door is a local
  route, and the two were left to share it. That day's glitches on
  Logs and the Terminal were not the drawings': sixty of them on the
  page and none redrawn in fifteen seconds of lines; the card had
  240 MiB of memory left, and a new session gave it back.
- **The rail's cartridge mentions stand at its right edge.** In
  Services, Doors & Pages a mention trailed its plate, at a different
  distance on every line; the author asked for them aligned right
  (2026-10-02). Each row is a flex pair now and the mention takes the
  margin left over, so the mentions are a column of their own to read
  down, the plates another; a mention that drops a line under a wide
  plate keeps the edge. Seen on the rail of a project with thirteen
  mentions, the house's faces loaded.
- **The README's four captures are taken again.** The plates and the
  service buttons wear drawings now, the rail's mentions stand at its
  edge, and the project has grown, so the pictures of 2026-09-29 and
  10-01 no longer showed the console as it is. The author took the
  four again (2026-10-02): Deploy and the shelf at 1440 wide on the
  light ground, the Interface tab's Terminal and Code parts on the
  dark, Selenized and House's, cut to the drawer. The shelf's picture
  is the Inserted list, twenty-two covers: one box is left on offer in
  `lorem_ipsum` today, and a shelf with one box says nothing of what
  the boxes are; its caption says so.

### Removed

- **The design's decision pages leave the repository.** Four stood in
  `assets/design/` — `chapas-y-menciones.html`,
  `estado-en-la-banda.html`, `fuente-claro.html`,
  `puertas-y-sondas.html` — each the page a question of the house's
  notation was settled on, weeks ago, and each kept after its answer
  was built. A page is retired once decided and this file is the
  record: the author took the four out on 2026-10-02, with the one of
  that day on the addresses' drawings. What they found stays where it
  was written — the design's README, the tokens' uses, the entries
  here — and those now say *retired* where they cited a page as
  standing.

### Fixed

- **House's sheet no longer turns the terminal theme's colour.** The
  author saw the Code part's sheet green with House's picked, and
  could not make it happen again (2026-10-02). It happens to a browser
  that has never picked a code theme: nothing is kept for the sheet,
  and the sheet with no ground of its own stood on the terminal's —
  `--term`, which wears the terminal's theme — so Selenized on the
  terminal turned House's sheet its teal, on the Files sheet and in
  the miniature alike; picking House's once keeps its `#2d1d3a` and
  the fault goes, which is why it would not come back. The sheet has
  a token of its own now, `sheet` in `tokens.json`, the terminal's
  colour and not the terminal's; `sheetGround` falls back to it, read
  with the reader's value taken off the root first. Seen on a console
  on the host, a fresh browser session: Selenized picked for the
  terminal, the sheet stays `#2d1d3a`; Catppuccin picked for the code,
  its own `#1e1e2e`.
- **The Record's `mix phx.new` command wears the terminal's ground
  again.** The author missed the ground set in the drawer on it
  (2026-10-02). It had been the box's own since the Record was written
  (2026-09-09); on 2026-09-29 the ground moved to the `term-box`
  family, and the plain `.cmd` rule — the surface, for a command at
  the foot of a form — being the console's own sheet and later in the
  cascade, won over the family's at the same weight: the box had
  shown the surface since. `.cmd.term-box` says the terminal's ground,
  line and dim now.
- **The Record's `mix phx.new` command is set in the Files face.** The
  author set a face for the files in the drawer and the command box of
  Birth kept the page's mono at 12 px (2026-10-02): its rule named the
  font itself, the one block of the Record the drawer did not reach.
  It reads the Files group's face, size and leading now, as the
  papers' blocks and the `.env` do; a command is read, not run. Seen
  on a console on the host with Greybeard at 16 px kept for the files.
- **A service on the rail carries the mention of the cartridge that
  brings it.** In Services, Doors & Pages a door said who opened it
  and a service said nothing of who brought it, though pgAdmin is
  `db_admin`'s and Grafana `monitoring`'s as plainly as the mailbox is
  `mailer`'s (2026-10-02). `ConsoleWeb.Services.bringer/2` answers it
  off the cartridges' compose, the way their colours are answered,
  and the plate wears the mention; the app, the project's own, wears
  none. Seen on the rail of a project with four brought services.
- **A background outside the sixteen no longer leaves a style of its
  own.** `48;5;N` and `48;2;R;G;B` were read a number at a time, the
  `48` dropped and each parameter taken for a code: a blue ground of
  the 256 came out underlined, `48;5;1` bold, and an RGB's three
  numbers as whatever they fell on. They are read whole now, with the
  underline's colour (`58`): the first sixteen of the 256 are the
  sixteen and are painted; one beyond, and one in RGB, is no colour
  of the theme's and is left unpainted, taking the place of the
  ground before it.
- **The Docker screen's Specs wear the opacity once.** The author
  thought the box did not take the 40 % set for the terminal's ground
  (2026-10-01), and it did not: it took it twice. The daemon's lines
  are a `term-box` inside the viewport, which is one too, and each
  painted the ground, so 40 % over 40 % read as 64 %, on either
  ground; Logs, Jobs and the terminals paint it once. The lines no
  longer paint a ground of their own (`console.css`). Looked for on
  every screen: it was the only box that did.
- **Docker's events no longer break a long name over its lines.** The
  author saw `lorem_ipsum_workbench_term_4163` on three or four lines
  (2026-10-02). A line's column of who did it is as wide as
  `--svc-w`, which the Logs hook sets to its longest service and the
  miniature to the names it draws; the events never said it, so the
  column stood at the stylesheet's 72 px, and a container of no
  service — a terminal's — shows by its whole name. The events say it
  now, the longest name in view in the face's own characters
  (`docker_screen.ex`), so every name is one line and the messages
  still start in one column. With the real stylesheet the name went
  from four lines in 72 px to one in 31 ch.

## v0.16.0 - (2026-10-01)

### Added

- **Four more code themes on the shelf: Catppuccin, Dracula, Gruvbox
  and Tokyo Night.** The code's shelf had two, the house's and
  GitHub. On 2026-10-01 six of the best known were drawn side by side
  on a page, `temas-de-codigo` — Dracula, Solarized, Catppuccin,
  Gruvbox, Tokyo Night and Monokai, each in its own colours on the
  Interface tab's sample, by the sheet's own rules — and the author
  chose four. All are MIT and all have both grounds: *Dracula* (Zeno
  Rocha), its dark from the theme for VS Code (2.25.1) and its light,
  Alucard, from Dracula's own theme for Cursor (`dracula/cursor`
  1.0.1), since the VS Code extension carries no light; *Catppuccin*,
  Mocha and Latte of its four flavours (`@catppuccin/vscode` 3.18.1);
  *Gruvbox* (Pavel Pertsev), dark and light at medium contrast as
  jdinhify's port has them (`jdinhlife.gruvbox` 1.29.1), a pair for
  the terminal shelf's Gruvbox; *Tokyo Night* (enkia), with Tokyo
  Night Light (1.1.2). Solarized, the one of least contrast, and
  Monokai, which has no light ground, stayed out. A theme of VS Code
  says rules by scope, not the console's twelve roles a language, so
  each role takes the colour VS Code would give its leading scope, by
  TextMate's precedence — the most specific rule, the later of two
  alike: for Elixir the scope most of the role's characters wear
  (the module after `defmodule` for modules, so they take the theme's
  colour for a type), for the other languages the colour most of the
  role's scopes share, but for four roles where that is not the
  role's own thing (TypeScript's keywords, Godot's names, functions
  and annotations). The same method on GitHub's theme gave 61 of the
  73 rules of `github.code.json` before those four. The sheet is the
  theme's editor — ground, ink, line numbers — and the diff's two
  grounds its own, laid over the sheet; a changed line's number takes
  the theme's gutter mark without its alpha, or the first of its own
  greens and reds that reads on the line. Writing them found a fault
  in the console's reader, put right the same day (Fixed, below).
  Checked with the reader cut out of `hooks.js`, every role of both
  grounds of the four as meant, and on the running console, each
  theme worn on both grounds. *One Atom* — Atom's One Dark and One
  Light as near as twelve roles can say them, built beside *House's*
  the same day to compare the two — was not kept: the house's stays.

### Updated

- **A theme's part switches the ground beside its shelf.** A theme has
  two grounds and a card shows both, but to see the other one worn
  the reader had to leave the part for Overlay, or reach the band. The
  name of the group *Color Themes*, in Terminal and in Code, carries
  the house's small square right beside it, with the band's own mark:
  a press turns the ground, light to dark and back, and it is kept as
  the band's is. The square says the ground it is on whoever set it,
  and the band's cell hears the drawer now: its `repaint` was sent and
  never listened to, so its title stayed on the ground before. Asked
  by the author on 2026-10-01; checked on the running console, both
  parts, pressed from the square and from the band.
- **Download Custom is *Download Current*, and gives what is worn.**
  The button gave three things under one name: Custom when it was
  worn, the theme in force when there was no Custom — which the name
  did not say — and, with Custom put away, the Custom and not the
  theme on the sheet. It is named for what it does now and does one
  thing: the file is this surface as it is worn, both grounds, a
  theme bare or Custom on one. A Custom put away is worn first, a
  press on its card. *Load Custom* and *Clear Custom* keep their
  names: a file loaded is a Custom, and Custom is what is cleared.
  Proposed by the author on 2026-10-01; checked on the running
  console, the file read as it left, in the three cases.
- **Clear Custom: a Custom can be forgotten.** Since Custom is kept
  when another theme is picked, nothing took it off the shelf again:
  its card stayed, worn or put away, for good. Under the shelf, in
  Terminal and in Code, there is *Clear Custom*, anyone's — Download
  Current and Load Custom beside it stay dev's — and there only while
  there is a Custom, as its card is. Pressed with Custom worn, the
  theme it stands on goes on whole, as it is on the shelf; pressed
  with Custom put away, it is dropped and what is worn stays. Either
  way the card and the button go, at once and with no asking: it is
  what the theme's own dashed card did before Custom was kept. Where
  the row has no button to show it takes no room. Asked by the author
  on 2026-10-01; checked on the running console, worn and put away.
- **The house's code is read on the terminal's ground.** The dark
  sheet of *House's* was `#120B17`, the terminal's ground of before
  2026-10-01; it is `#2D1D3A`, the violet the house's terminal took
  that day, so what runs and what is read stand on one ground again.
  The inks are One Dark's still, and read a step softer on it: 7.3:1
  the code's (9.1 before), 2.6 the comments' (3.2). The numbers'
  plate, `#2C2036`, is next to the same colour as the new ground, so
  the ruler no longer stands apart from the line; left as it is.
- **The house's terminal is the author's on both grounds, and the
  theme is named for it: *House's*.** The dark of v0.15.0 — the
  author's twelve on a near-black `#08010E` — was a first take; the
  second came the same day, 2026-10-01, set in the drawer and handed
  over as a theme file: a violet ground, `#2D1D3A`, ink `#E1DBEB`, and
  softer rows (red `#EE3F65`, green `#87C738`, yellow `#F1CB65`, blue
  `#4A7EF7`, magenta `#E690FE`, cyan `#60C7D7`, and the brights
  `#FC7391`, `#B7DD88`, `#F7E3AB`, `#94B2FA`, `#F2C2FF`, `#9CDDE7`),
  with the two line washes its own too (an error's `#FE0B3C`, a
  warning's `#F2A436`). Nord's blacks and whites and the dim stay. The
  light was still the Nord light of the house's making, a stranger to
  the new dark, so it is the author's too, in two steps of the same
  day. First a take derived from the dark by the method that Nord
  light was made with: each of the twelve keeping its hue and its
  saturation, its lightness dropped to 6:1 on paper the normal row
  and 4.5:1 the bright, the two washes the same way at 4.5:1
  (`#E90130`, `#A7660B`), and the dark's own ground for ink on paper
  (`assets/design/palette.py`, `house_light`). Then the author tuned
  that take by hand in the drawer, lighter and livelier, and handed
  it over as a theme file: the red stays the derived `#C11137`, with
  green `#508A05`, yellow `#C47608`, blue `#347CEF`, magenta
  `#AD61C2`, cyan `#1F8D9E`, and the brights `#EF486C`, `#6DBB07`,
  `#F5B60A`, `#639AF2`, `#C086D0`, `#28B3C8`; the washes and the ink
  stay the derived ones. Chosen by eye, and below the derived take's
  targets on paper: 6.0:1 the red, 3.4 to 4.1 the rest of the normal
  row, 1.8 to 3.5 the bright; `palette.py` prints both, the take and
  what was set, each with its contrast. The one
  source is `assets/design/tokens.json`; `build.py` writes the tokens;
  the theme (`console/themes/default.terminal.json`) says the same,
  checked value by value; `console.css` carries the washes' defaults
  and the Overlay's ground thumbs. The theme's name was *Default*,
  which said where it stands and not whose it is, and the code
  shelf's *Default* — Atom's One Dark and One Light, the house's
  choice — is *House's* with it; the key of both stays `default`,
  what the shelf and a reader's kept choice know them by. As *House's*
  no longer sorts first, `Console.Themes` puts the house's first on
  its shelf and the rest by name. The code theme's card points at One
  Dark inside Atom's own repository (`atom/atom`,
  `packages/one-dark-syntax`), the address the author gave, in place
  of `atom/one-dark-syntax`, and it no longer reads as Atom's theme,
  which it is not: its author was *Atom* and its line *One Dark and
  One Light*; it is *the house, after Atom*, and *based on* them. What
  it is was checked against Atom's sources that day, the legacy
  styles of both themes (`colors.less`, `syntax-legacy/_base.less`,
  `elixir.less` and the other languages'). Three findings. The colours
  are theirs: all eleven of One Dark's, plus one of the house's, the
  functions' `#60ACEA`, a step off One Dark's blue since the author's
  first jsonc; and One Light's, with the ambers of its standalone
  repository (`#986801`, `#C18401`), which Atom's own has since
  moved. Elixir is Atom's own Elixir, rule for rule — `elixir.less`
  is where the blue numbers, the amber operators and separators, the
  grey brackets, the yellow modules, the red `#{}` and the second
  red of a regex come from — but for that blue, for an escape (cyan here, as
  Atom's older rules had it; green by its newer) and for the
  parameters, which Atom also sets in italic. And everything else is the house's:
  the other seven languages are coloured by Elixir's twelve roles and
  not as One Dark has them (a number blue where it is orange, an HTML
  tag and a JSON key yellow where they are red, a class selector red
  where it is orange, a CSS property purple where it is the text's),
  and the sheet, its gutter and the diff's grounds are the house's
  own (`#120B17` on the dark, the terminal's ground of before
  2026-10-01, which the line used to claim it still was; the sheet
  took the terminal's new ground the same day, above).
- **A reader who has chosen no face gets the house's: Tamzen at 15 px
  and a leading of 1.0 for the terminal, Fira Code at 13 px and 1.2
  for the code.** Until 2026-10-01 a reader with nothing kept read
  both in the page's own mono, IBM Plex, at the size and leading each
  surface was drawn at (12 or 12.5 px, 1.5 to 1.6). The default is
  the author's now, a face a surface: what runs — the terminals, the
  logs, the jobs — in the bitmap, a line on the next as a terminal
  sets them; what is read — the Files sheet, the diffs, the papers'
  code — in Fira Code, tighter than it was. It is `DEFAULTS` in
  `hooks.js`, beside the faces, and it is only what stands in for a
  choice: a choice a browser has kept, IBM Plex included, stays; IBM
  Plex is still on the list. Credits says whose face each surface
  wears by default. Checked on a running console from a browser with
  nothing kept.
- **Custom is kept when another theme is picked.** Custom was what
  was set on top of the theme in force, and picking any theme put
  that theme on whole and lost it at once — the theme's own card,
  dashed, was "the one way back", and it was a way with no return.
  The author asked on 2026-10-01 for the other reading: a theme
  picked puts Custom away and keeps it — its card stays on the shelf,
  saying the theme it stands on, and pressing it wears it again as it
  was left, both grounds. There is still one Custom a shelf, so what
  replaces it is a new one and nothing else: a colour touched, or a
  file loaded, while another theme is worn makes that theme and the
  touch the new Custom, and the one put away is gone. The shelf's
  kept state (`wb-console-theme-terminal`, `-code`) carries it, the
  stores as they were and the key of its theme, so it is there after
  a reload; Download Custom gave it whether it was worn or put away,
  until the button was named for what is worn (*Download Current*,
  above).
  Walked on a running console, the terminal's shelf and the code's:
  touch, pick another, come back, touch on another, reload.
- **A theme's part shows its surface and no frame.** The Interface
  tab's miniature is the console at a fifth — the band, the rail, the
  screen's tabs, a terminal and a file — and since 2026-09-30 a
  theme's part lit one surface in it, Terminal the lines and Code the
  file, with the frame still standing around. The frame is Overlay's
  to show, being what Overlay sets; a theme is judged on the terminal
  or on the file, not on where the band sits. So in Terminal and in
  Code the band, the rail and the tabs are gone (2026-10-01,
  `console.css`): Terminal is the lines under the chips that sort
  them, Code the file, each filling the miniature's box, which keeps
  the page's ground under the surface as the screen has it. Overlay's
  is as it was. Seen on a running console, the three parts.
- **The sheet's ground has its opacity too.** The terminal's ground
  has worn the reader's opacity since v0.15.0, a slider and a
  number in its part, 40 % until the reader says otherwise. The code
  part has the same now (2026-10-01), for the sheet's line
  background: its own key (`wb-console-sheet-alpha`), the reader's
  like the face, over any theme and never written to a theme's file.
  It is laid over the sheet's own colour, the theme's or the
  reader's, or over the terminal's when the sheet has none — a sheet
  with no ground of its own stood on the terminal's, opacity and all,
  which is why the default is the terminal's 40: a reader who has
  touched nothing sees what was there. What changes is that the two
  are apart: the terminal's slider no longer moves the sheet, and a
  code theme picked from the shelf, which was opaque, wears the 40 %
  until the reader moves it. The line numbers' ground stays as it
  was. Walked on a running console: the slider, the number, the
  terminal's beside it, a theme picked.
- **A colour that is yours says so on its name.** With Custom on, the
  fold's head counted what the reader had set on top of the theme —
  "2 set by you" — and said nothing of which two; finding them was
  comparing swatches by eye. The author proposed the accent on the
  name (2026-10-01), and it is so: in a part's Adjustments, the name
  of every colour that differs on this ground from the theme Custom
  stands on is drawn in the gold, by the same test the count makes,
  so the two always agree. It follows what is done: a colour set back
  to the theme's value loses it, a theme picked clears them, Custom
  pressed brings them back, the other ground shows its own, and of
  the languages the palette shows the one the select names. The
  count had a fault this uncovered: it was drawn at the first touch
  and not again while Custom was on, so a second colour set left it
  at one; any touch draws it now. Walked on a running console, the
  terminal's part and the code's.
- **A function's parameters are set in italic.** The check of the
  house's code theme against Atom's One Dark left three differences in
  Elixir, and this was one: Atom slants a parameter as well as giving
  it the operators' amber. The sheet does now (2026-10-01,
  `console.css`, the `nv` of a `def`'s head). In the console an italic
  is a trait of the sheet and not of a theme, as a comment's is, so
  every code theme on the shelf wears it; what a theme can do is say
  it for where the file goes next, and House's does: the parameter
  leaves the operators' rule for one of its own, with `fontStyle`, in
  `default.code.json`, and Download Custom writes it apart the same
  way (`rulesOfRole` in `hooks.js`, the role's `italic`), so the file
  carried to VS Code slants what the sheet slants.
- **A service's colour has a value a ground.** The seven `svc-*`
  colours — a role a colour, what tells a line's service apart in the
  logs, Docker's events and the sessions — were one value each, chosen
  when the terminal was dark on both grounds. It follows the theme
  since 2026-09-07, and on paper they were pale: 2.1 to 3.0:1, a
  service's name being text. The author saw it on 2026-10-01. The
  dark keeps the seven as they were (5.1 to 7.3:1 on the terminal's
  ground); the light is each one's hue and saturation dropped to
  4.5:1 on paper, by the method of the terminal's light
  (`assets/design/palette.py`, `svc_light`): compute `#9559C8`,
  database `#2E78BC`, devtools `#34816D`, observability `#598033`,
  network `#7D6F88`, balancer `#B06021`, job `#9F55C1`.
  `tokens.json` holds both and `build.py` writes them; nothing that
  wears a service's colour changed, each reading `--svc-*` as before.
  The diagram profile's series follow: its light column was the same
  pale value as its dark.
- **A theme's part opens under a head, *Style*, and every head
  folds.** Overlay's two sections stand under theirs, *The frame* and
  *The ground*; the
  Terminal and the Code parts began with no head, straight on the
  small *Font*, and had one only further down, on the fold,
  *Adjustments*. The author asked for the first (2026-10-01): *Style*
  is over what the reader chooses — the face, the opacity, the theme —
  and *Adjustments* stays over what is set on top of it. And every
  head folds, for the same reason the head was added, that the parts
  be made alike: *Adjustments* and Credits' groups had the chevron,
  *The frame*, *The ground* and now *Style* did not. They are groups
  with the one head (`fold_head` in the drawer, which Credits' groups
  take too), open as the part opens — *Adjustments* alone opens
  folded, as it did; a fold is the page's and is not kept. *Style*
  holds its sets at the 18px they had between them. Walked on a
  running console: every head of the four parts has its chevron, and
  *Style* and *The frame* fold and unfold.
- **The frame is chosen on cards, as the ground and the themes are.**
  The band and the rail were two segmented controls, each segment a
  word under a small pictogram, beside a ground and two shelves that
  are cards with a thumbnail; one part, two idioms. The author asked
  for the one (2026-10-01). Each position is a card now — Top and
  Bottom under *The band*, Left, Right and Hidden under *The rail*,
  the two named in the small head a theme's part names *Font* and
  *Opacity* with, and set apart as those are —
  the size of a ground's, with the same thumbnail: the page at a
  glance, in the ground in force, with the band and the rail where
  the card would put them and the other axis as it stands, so every
  position is in view and the pressed one is the frame in force, as
  the pictogram had it. One rule for the five, the author's: what a
  card acts on wears the colour of the card's own selection border,
  the accent — the band on Top and Bottom, the rail on Left and
  Right — and the rest is drawn as it is. Hidden has nothing to fill,
  so it draws the place the rail now has, on its side, as a dashed
  outline in that colour. And the ground's three cards, the same
  thumbnail under them, are drawn in the frame in force: the band at
  the bottom, the rail on the right or gone, as the frame's cards set
  them — a page being one thing, they no longer show a frame the
  reader has left. Checked one against the other, the two kinds of
  card differed in one more thing, the terminal: the frame's drew it
  through `--term`, the reader's theme and opacity, and the ground's
  in the house's colour, opaque. The ground's take the reader's now,
  each card the theme's colour for its own ground (what is kept, as
  the page may not be on that ground), at the opacity chosen. The
  rest was the same already, colour by colour against `tokens.json`.
  The
  segments' styles and the pictogram's drawing (`pict` in `hooks.js`)
  are gone with them. Walked on a running console: the five cards,
  the thumbnails following each choice.
- **System's card is cut on a slant.** Of the ground's three cards,
  System's thumbnail was the light half and the dark half side by
  side, a straight cut down the middle, each piece of the drawing
  painted in two colours to meet it. It is the two thumbnails now,
  the light one whole and the dark one over it, cut like a "/" —
  light to its left, dark to its right (2026-10-01, `console.css`, a
  `clip-path`) — which reads as *either* where the straight cut read
  as *half*.

### Fixed

- **A role is read in its own rule's colour, not in a neighbour's.**
  The console read a theme's rule onto every role that shared one of
  its scopes, the later rule winning (`coloursFromRules`, `hooks.js`),
  and roles do share scopes: a template's assigns are Elixir's module
  attributes, a template's numbers Elixir's, and the shell's `$` is
  among its quotes and its variables. So a file said one colour and
  the sheet showed another: in *House's* the shell's quotes and braces
  were read in the variables' red and not their own grey, in *GitHub*
  the same and Elixir's embedded — `use`, `@max`, `#{}` — in a
  template's plain ink where the file says GitHub's red. Found on
  2026-10-01 writing the four new themes, whose colours for those
  roles differ more than the house's do. A role takes the rule that
  covers the most of its scopes now, and of two that cover as many,
  the later: a role's own rule covers them all, so a shelf file reads
  as written, and a VS Code theme pasted in gives a role the colour
  most of its scopes wear in place of whichever rule came last.
  Checked with the reader cut out of `hooks.js` — every role of both
  grounds of the six code themes reads as its rule says — and on the
  running console.

## v0.15.0 - (2026-10-01)

### Updated

- **The house's terminal on the dark ground is the author's own: a
  near-black ground, `#08010E`, and six colours of its own with their
  brights.** Since 2026-09-16 the dark terminal was Nord's sixteen on
  the house's `#120B17`, chosen among five on
  `console/temas-de-terminal.html`; the author set the ground and the
  twelve chromatic rows on 2026-10-01 (red `#D52A50`, green
  `#38C751`, yellow `#D5BC2A`, blue `#372AD5`, magenta `#D52AD5`,
  cyan `#2ABFD5`, and the brights `#E4758E`, `#7EDB89`, `#E4D975`,
  `#8375E4`, `#E475E4`, `#75DAE4`). Nord's blacks and whites, the
  dim, the foreground and the light ground stay. The one source is
  `assets/design/tokens.json`, with the date on each token's use;
  `build.py` writes the tokens; the Default terminal theme
  (`console/themes/default.terminal.json`) says the same, as it must,
  and its card no longer stands on Nord: the house is its author, the
  workbench's repository its site, and its *about* says what it is
  now; and the Overlay's ground thumbs draw the new ground. The miniature's terminal shows the sixteen on what they
  colour, so a theme is judged on logs: to the compiler's warning and
  the boot it adds Logger's levels (debug cyan, warning yellow, error
  red, a line whole, as Logger paints them), an Ecto query, a `dbg`
  value in `IO.ANSI.syntax_colors/0` (atoms cyan, numbers yellow,
  strings green, booleans and `nil` magenta, the variable light cyan),
  and an ExUnit run — the dots green, the failure red, a skip yellow,
  the `code:`, `left:` and `right:` labels cyan, the diff's deletions
  red and insertions green, the count red — each colour read off the
  tool's own source.

- **The Interface tab is parts under a ribbon, not three folds.** Its
  controls folded in three since 2026-09-15 — Overlay, Terminal and
  Files, with *As a file* outside them — all open at birth: the column
  measured 2274 px in a pane that showed 641, three and a half screens
  until the reader folded two, and what was folded lived in the
  browser alone. They are parts now, one in view, under a ribbon
  across the pane below the drawer's own, as a box's papers sit under
  a screen's tabs: Overlay, Text, Terminal, Files and Credits that
  day — Overlay, Terminal, Code and Credits since the 30th, below. The
  part is in the URL (`?wb=ui&part=`) and kept as Manual keeps
  its paper, so Config and back returns to it; and the miniature
  lights the surface the part sets: the band and the rail, the tabs,
  the lines, the sheet. The pane is
  `phx-update="ignore"`, so the part travels as `data-part` on it and
  `console.css` reads it; the Frame hook only rewinds the column and
  forgets `wb-console-ui-folds`. Settled on 2026-09-29 among three
  compositions on the tab's real DOM (`las-subpestanas-de-interface`,
  retired): the folds, a ribbon in the column's head — where six parts
  wrapped to two lines in 320 px — and this.

- **Text: the pages' own type is the reader's too.** A part of the
  Interface tab for the three faces every page is drawn in — the
  display, the text and the mono, the tokens `--cond`, `--serif` and
  `--mono` — each the house's or another the console carries, and a
  scale of the whole, 90 to 150 %. Kept in this browser
  (`wb-console-text`) and carried by the jsonc under `dew.interface`,
  as the overlay is. A face chosen is its token set on the root, the
  house's is the token absent, as the code's and the files' faces
  work; the bitmap faces are not offered here, a page being set at
  many sizes and a bitmap face right at one. The scale is `--scale`
  on the root, applied as `zoom` to what the page lays out and to
  what each overlay holds — never to an overlay's frame, sized in
  viewport units: zoomed, the drawer left the viewport at 125 %.
  Retired the next day, 2026-09-30, the rest of the interface not
  being offered to customise yet: the part left the ribbon, and what
  it kept, `wb-console-text`, is forgotten when the page boots — a
  face nobody can change any more must not stay on. The three faces
  stay credited in Credits, and the pages' type stays a thing a theme
  file may name under `dew.interface`, for the day it comes back.

- **Credits: every face the console draws with, credited in one
  place, each set in itself.** A part of the Interface tab, a face a
  card: its head the name composed in the face — Tamzen looks like
  Tamzen, at its pixel body — the link to where it lives, whose it is
  and under which licence as chips, what it draws under. Settled on
  2026-09-29 in `console/las-fichas-de-credits.html` (retired) among
  the list it was, the card and a ficha with the accent edge of the
  box's need block, on the real part: the card, because a ficha that
  shows what it credits has something to frame and the link is its
  verb — the rule of three families gains that line in
  `components.css`. The themes were not credited here that day — a
  theme's credit is its file's `dew.theme`, and where it showed was
  the theme's chooser's matter; since the 30th they are, on the same
  ficha, below. Barlow Condensed (Jeremy Tribby), Source Serif 4 (Frank
  Grießhammer, for Adobe) and IBM Plex Mono (Mike Abbink and Bold
  Monday, for IBM) come from Google Fonts as the page loads; Fira
  Code (Nikita Prokopov and the project's authors), Flexi IBM VGA
  (VileR, The Ultimate Oldschool PC Font Pack) and Tamzen (Suraj N.
  Kurapati, after Tamsyn by Scott Fial) travel with the console. The
  notes under the face selectors of Terminal and Files say what a
  face does now — ligatures on, a bitmap, one drawing a size — and no
  longer whose it is. Two things put right on the way: the fonts'
  README and the Tamzen note credited Scott Fial, who drew Tamsyn,
  the face Tamzen is after; and the licences now travel with the
  files, `LICENSE-fira_code.txt`, `LICENSE-flexi_IBM_VGA.txt` and
  `LICENSE-tamzen.txt` beside the `.ttf` in
  `console/priv/static/assets/fonts/`, as the SIL Open Font License
  and CC BY-SA 4.0 ask of a copy that is redistributed — a table in a
  README did not meet either.

- **A theme is a surface's: two shelves in `console/themes/`,
  `<key>.terminal.json` and `<key>.code.json`.** For a day
  (2026-09-29) a theme was the interface whole, one file on one shelf:
  the pages' type, the terminal's colours, the diff's, every language's
  palette, picked from a select in Overlay, *Custom* first as the
  state of anything touched on top. Settled again on 2026-09-30, part
  by part, on three pages on the tab's real DOM
  (`los-temas-en-el-cajon`, `el-tema-y-sus-partes`,
  `la-estanteria-a-la-vista`, retired), after the select, cards under
  it, a theme card that opens, and three arrangements of one part
  called Themes had each been drawn and measured. What was settled:

  *Two themes, one a surface.* Terminal schemes and editor themes are
  published apart out there — iTerm2's, Windows Terminal's, Ghostty's
  and Gogh's on one side, VS Code's and tmTheme on the other — and a
  reader will want Dracula in the terminal and GitHub in the code, so
  a terminal theme and a code theme are two files, told apart by the
  suffix, and `Console.Themes` reads two shelves (`kind`, `shelf/1`);
  a file that wears neither suffix is left out with a warning. A
  terminal theme carries, a ground each, `terminal.*`,
  `dew.terminal.*` and `editor.lineHighlightBackground`; a code theme carries the
  sheet — `editor.background`, `editor.foreground`,
  `editorGutter.background`, `editorLineNumber.foreground`, keys the
  console had never read: the sheet took the terminal's ground, a dark
  editor theme on the light sheet was broken, and a file with no
  language was read in a constant of the house's that no theme reached
  — the diff's four and the `textMateRules`. A theme is colours: the
  face, size and leading of each surface are the reader's own, the
  group *Font* above the shelf, no theme's — a theme changed does not
  change the letter, and the letter changed does not make a theme
  Custom — as iTerm2 and Windows Terminal keep appearance and scheme
  apart. `console.css` draws the sheet on `--sheet` with
  `--term` in reserve, a file with no language in `--sheet-ink`, and
  the gutter on `--sheet-num-bg` and `--sheet-num`. A theme with no light ground
  carries no `light` block, and on that ground the house's shows.

  *The shelves.* The terminal's opens with *Default* — the house's,
  credited to it *after Nord*, whose sixteen its ANSI are (2026-09-16)
  on the house's ground, with a Nord light of the house's making on
  paper — and five as their sources give them: *GNOME* and *Tango*,
  GNOME Terminal's two palettes with their light and dark grounds as
  it draws them (`terminal-schemes.hh`; GPL-3.0 and the public
  domain); *Nord*, the original (Sven Greb, Arctic Ice Studio, MIT),
  dark alone; *Selenized* (Jan Warchoł, MIT) and *Gruvbox* (Pavel
  Pertsev, MIT), each with its dark and light variants — every value
  checked against its source on 2026-09-30 (`terminal-profile-editor.cc`,
  Nord's and Selenized's own GNOME Terminal and Alacritty ports,
  gruvbox-contrib's xresources): GNOME's black, white, bright black and
  the two schemes' foregrounds had been an older palette's, and
  Gruvbox light's black too. Dim, which no scheme names, was each
  one's bright black for a day, and read at 1.7:1 on Tango and Nord —
  timestamps gone; it is the foreground halfway to the background now,
  the way a terminal draws faint text, 3.3 to 3.9 on every dark
  ground, except on Selenized, which names a dim of its own, `dim_0`.
  The terminal's ground takes an opacity, to blend with the
  interface's colours behind it: the reader's, like the face, a group
  *Opacity* under *Font* above the shelf with a slider from 0 to
  100 % and the number beside it, 40 % until the reader says
  otherwise, kept as `wb-console-term-alpha` and composed onto the ground
  of whatever theme is on — or the house's — as it goes on the root,
  `#rrggbbaa` under 100 %; a theme's file never carries it, a theme
  being colours. The `alpha` attribute of `<input type="color">` was
  tried first, and the Chromium at hand sanitised it away. The code's opens with
  *Default*, One Dark and One Light (Atom, MIT), and *GitHub* (Primer,
  MIT), which leaves the terminal's shelf: GitHub's terminal colours
  are on the shelf no more, its sheet is, `#0d1117` and `#ffffff` with
  their line numbers, from the theme's source. A theme is credited as it credits itself:
  `dew.theme` carries `about` too, what the theme is in a sentence,
  which Credits prints whole — the house's two say what they are
  after — and a theme that says nothing is credited with what its
  blocks say, which surface and which grounds.

  *The ribbon is four: Overlay, Terminal, Code, Credits.* Terminal and
  Code are the two themes, a part each, in the place Terminal and
  Files had; Text is retired for now (above). A theme's part is *Font*
  first, then the group *Color Themes* — a card a theme, its
  thumbnail drawn by the hook from the file, both grounds, the
  ground's colour and five lines of the theme's: the terminal's ANSI,
  the code's tokens — then *Download Custom* and *Load Custom*, then
  one fold, *Adjustments*. The thumbnail is the preview:
  a card worn on hover, drawn and tried, was taken out again the same
  day. *Custom* is a card that appears at the first touch of anything
  the theme carries, *Custom · on GNOME*, and the theme's own card
  goes dashed: pressing it is the one way back, whole — no reset by
  section (drawn, and found to be noise), no accent on a touched
  section, no dot beside a touched value; what is yours is a count on
  the fold's head, *1 set by you*, this ground's, and nothing else.
  The pick and the state are kept, `wb-console-theme-terminal` and
  `-code`, and a shelf hears only its own surface's touches. *Download
  Custom* writes this surface's file, `my-theme.<kind>.json`, the
  theme in force under what is set on top, both grounds, read off the
  stores and not off the page (reading the page on the other ground
  for a moment toggled `data-theme`, and an observer of it re-drew in
  a loop the first time it was tried); *Load Custom* takes a file onto
  the shelf it belongs to by what it carries, and a VS Code theme onto
  this ground by both shelves, what each finds of its own. Both
  buttons are the console's in dev alone (`config :console,
  theme_files`, `dev.exs`): writing a file for the shelf is a
  developer's move, and in prod the shelf is what it is.

  *Adjustments.* The fold's head is the house's `h5` with the count
  and the small fold square at its end, the same head Credits' groups
  wear — one way of folding in the drawer — and inside it there are
  groups alone, in the `h6` of The terminal, ANSI and Highlights:
  *The terminal*, *ANSI*, *Highlights*; *Sheet*, *Diff*, *Language
  Syntax*. *Font*, the three selects, stands above the shelf, outside
  the fold; its sizes are numbers now, 12 px and 1.5 selected as what
  the house draws — *as drawn* said no number, and hid that the house
  draws each surface at its own size, 12 or 12.5 px. The hints and the section heads went: the part's
  hint explained the preview and Custom, which the first touch
  teaches; the sections' enumerated the labels the controls carry;
  the heads said what the groups say. The one thing the controls did
  not say, that a colour table edits the ground on view, the ground
  switch says.

  *The colour roles, one component.* Every colour table is a table of
  name | colour pairs, the colour 20 px, the pairs repeated across the
  row while every name fits on one line — the hook measures a box's
  longest name into `--role-w` (`fitRoles`), `data-pairs` caps the
  pairs a row takes, and one gap, 5 px, both ways. On a row of two
  pairs or more the even pairs are mirrored, colour then name, and the
  names align towards their colour, so the row reads towards its axis
  and two colours meet in the middle: ANSI is one table of sixteen,
  each colour beside its bright, *green* and *bright green*. A null in
  a box's list is an empty record that ends a row early, so
  *background* stands alone and *foreground · dim* follow (a box at
  one pair a row has no axis, and draws no empty record); Diff is
  four rows with the side in the name, *+line background*, *+line
  foreground*, *-line background*, *-line foreground*; *red · errors*
  and *yellow · warnings* are *red* and *yellow*, what they mark in
  the title; and the lines' grounds are *Highlights* — *error*,
  *warning* and *hover*, the one under the pointer. The words are VS
  Code's: background and foreground, never ground and ink, on a
  control that writes VS Code's keys. A box that is hidden measures nothing and is fitted when it
  comes into view; and a box draws itself only after putting its set
  on the root, because the ground hook mounts first and an observer
  registered after a change never hears it — on the dark ground the
  swatches showed the light's values until they did.

  *The language.* The language is a native select, as the face is.
  For a day it was a combo of the house's own, so that its button and
  every option could wear the technology's mark beside the name
  (Simple Icons' drawings, in one colour the ground's), and the same
  mark stood on a sample's file header; the mark was a pleasant detail
  and no function, and the listbox it needed — opened upward when the
  column ended before it would, closed on a click outside, its option
  copied onto the button, and the clicks a `label` forwarded to it —
  was a cost paid for that detail alone, so both went on 2026-10-01
  and the sprite lost the `lang-*` drawings. The list ends with
  *Other*, a file with no language — `config/room.toml` as its sample,
  plain — whose only colour is the sheet's foreground, and says so
  where its palette would be.
  Picking a language scrolled the column up, to the first colours of
  the new palette or near it: fitting the pairs table measures the
  names with the grid's minimum at zero, which lays the table out many
  pairs a row and a fraction of its height, and the column's scroll,
  clamped to that height, was never put back — Chromium's scroll
  anchoring repairs it sometimes, which is why it was not always
  seen. The fit keeps the column's scroll and puts it back.

  *Credits, one ficha.* What is a credit's — whose a theme is, under
  which licence, where it lives — left the theme's part for Credits,
  which credits the themes and the faces on one ficha (`.card.credit`):
  the name as its head (a face set in itself), author and licence as
  chips, the site with the house's mention, what it draws; the theme
  in use says *In use* and wears the accent, unless Custom is on,
  when nothing on the shelf is. Credits takes the whole pane, no
  miniature (it lights nothing), one centred column cut by three groups — *Terminal
  themes*, *Code themes*, *Faces* — each with the fold square, read
  down like a film's credits: one list with the role over each name,
  one list by group, and three columns side by side were drawn, and
  the list by group chosen. The mention is `.site-ref`
  (`assets/design/build.py`, `ConsoleWeb.Refs.site_ref/1`), the
  `.pkg-ref`'s rules with a mark that says where it goes — GitHub's
  Invertocat and `owner/repo` for a repository there, as the packages
  table names one, or the house's globe (`icons/globe.svg`) and the
  host for any other — the one link of a ficha; a face's name is a
  link no more. The two bitmap faces are set bigger, Flexi IBM VGA at
  24 px and Tamzen at its 10×20, so a specimen shows the drawing. And
  the drawer's *Kept in this browser. Nothing here touches
  config.conf* line, Overlay's first since the tab was three folds, is
  gone from Overlay, Terminal and Code: the shelf and the frame say
  what they are, and nothing on the tab ever touched the file. A
  bitmap specimen centred on a fractional pixel is a blur; the
  Credits column was centred by a margin rounded to the pixel for an
  afternoon, and is centred as any column is: the specimen takes its
  half pixel.
  In Terminal and Code the miniature shows the part's surface alone —
  the lines taking the sheet's height, the sheet without the toolbar
  and the lines — and Overlay shows both, the frame being the whole;
  the accent outline that lit the surface a part set, since the parts
  were folds, went with that: with a surface a part it said what the
  miniature says. The miniature's ground cell is a control now, as
  the band's is: it switches the ground, and the click stays off the
  band, which a click moves.
  The language samples (`Console.Highlight`, `@samples`) grew from
  eight or twelve lines to twenty to thirty-eight each, in the same
  room, so the sheet fills what the pane gives it and scrolls; each still touches
  every rule of its palette, and the changed line is where it was.

- **The tests that read a third party are a group of their own,
  `:network`, and the check against ash-hq.org is its first member.**
  `mix workbench.ash.site` fetched the site's installer and compared
  it with the ash cartridge, on a runner of its own and a weekly job
  (`.github/workflows/ash-site.yml`). It is now three tests in
  `ash_hq_test.exs`, tagged `network: :ash_hq`, and the task is gone.
  The igniter's `test_helper` excludes `:network` beside
  `:exhaustive`, so `mix test` and CI stay off the network; the tag's
  value names the resource, so `mix test --only network:ash_hq` runs
  one third party's tests and `--only network` runs them all, which is
  what the weekly job runs now: `ash-site.yml` is
  `.github/workflows/network.yml`, the group's job, and a new third
  party is a test file with its tag, never a workflow. The group takes
  no credentials: what needs a key gets a job of its own. The next members are the ones the shelf
  already reads by hand — the Elixir image's tags, hex.pm for
  Phoenix's version. The precommit cartridge's `test` check stays
  `mix test`: which groups a project's suite leaves out is its
  `test_helper`'s business, not the hook's. ash CHANGELOG v0.8.1.

### Removed

- **`console/elixir_color_theme.jsonc`, archived.** The twelve One
  Dark rules for Elixir, as first written for VS Code, were the seed
  of the console's colouring; every one of them — scopes, colours,
  the comments' italic — has lived in `hooks.js` (`LANGS.elixir`) and
  `console.css` since, and since today in `console/themes/` too —
  `default.code.json` — in the same VS Code form with One Light's
  beside. Checked rule
  by rule before it went. Out of git, in `_archived/`; the two
  comments that cited it say so.

- **`RELEASE_PLAN.md` and `SCRIPT.md` leave the repository for
  `_local/`**, where `reference/` went the day before: the three are
  the author's own papers — the release checklist with the series and
  the site it plans, and the reference project's script, which
  summarises the design that left and links to it. A reader of the
  public repository gets the workbench and the record of why it is
  shaped so (the CHANGELOG, the cartridges' papers), not the author's
  plans; the papers that cite `SCRIPT.md` as "the author's selection"
  (exdebug, toolchain, version_manager, test_doubles, the
  `project-design` skill) cite it as it was, a paper that lives outside
  the repository now. The `project-design` skill goes with them — the
  author's design process, written from that project and carrying it
  as its example — to `_local/skills/`, out of Claude Code's reach on
  purpose: it is still being worked on, and comes back to
  `.claude/skills/` when it is done; `cartridge-covers` stays, the
  house's own. All of it goes out of the history with `reference/`
  at the cut.

### Fixed

- **The console colours Elixir as VS Code does with the same theme,
  where the theme has a rule.** The author, reading the archived theme
  against the sheet on 2026-09-30, found a comma drawn as a bracket
  while a dot was an operator, and `@moduledoc` with its string drawn
  as any attribute with any string. The theme was whole — both scopes
  sit in the right rule in `LANGS.elixir` — and the loss was one step
  later: the palette is written in a grammar's scopes and painted on
  Makeup's classes, and the lexer sorts coarser than the grammar, or
  just otherwise. A comma is `punctuation` like `(`; the dot was right
  only because the lexer lists it among the operators; a doc is not a
  thing it knows. A first repair that day took the cases the author
  named. The rest were found by measure on 2026-10-01 and not by eye:
  the same code through `vscode-textmate`, the library VS Code colours
  with, and through `Console.Highlight`, compared a character at a
  time. The grammar is `mjmcloug.vscode-elixir` 1.1.0's — of the three
  installed that answer to `source.elixir`, the only one all forty-six
  scopes of the theme are found in (ElixirLS 0.31.1 has forty-two, and
  the first repair, checked against it, had `&1` wrong) — and the
  theme the archived rules over One Dark Pro, which paints whatever
  they do not name. The corpus: `igniter/`, `console/` and the
  console's dependencies, 1,241 files and 6.8 million characters that
  are not a space. 89.6 % came out one colour on both sides; the
  differences fell into twenty-four kinds, laid out with real lines
  painted both ways on a decision page,
  `console/elixir-contra-vscode.html`, retired once seen and never
  committed. Fifteen were the console leaving the theme,
  and are repaired; with them it is 94.0 %. Two repairs, by where the
  loss is. Where a class already tells the token apart, `console.css`
  moves the rule for Elixir alone, as it did for CSS and Godot:
  `alias`, `import`, `require` and `use` (`kn`) and `__MODULE__` and
  its kin (`bp`) are the theme's *embedded*; `when`, `and`, `or`,
  `not` and `in` (`ow`) are keywords and not operators; a date's sigil
  (`ld`), which had no rule, is a string. Where the class is shared,
  `Console.Highlight.ElixirTokens` re-sorts Elixir's tokens before
  they are drawn, a scope of the grammar a case: a comma, `=>` and a
  binary's `<<` `>>` are operators, and so is the dot inside `Foo.Bar`,
  which the lexer hands as one name — but not in the name a module is
  defined with, one name to the grammar; the colon of an atom and of a
  keyword, and the quotes of `:"a b"`, are cut from the name into
  `sa`, the constant's mark; `:erlang` before a dot is an atom and not
  a module; a capture's `&` is a variable's mark (`nd`) and only the
  `1` of `&1` a keyword; `_` is a comment like `_from`; `?a` is a
  number; the `~w(` and `)a` of a word list are brackets; a name in a
  `def`'s head is a parameter (`nv`, the operators' colour, as the
  theme has it) — the head being the bracket pair Makeup already
  matched, so nothing is parsed; `@doc`, `@moduledoc` or `@typedoc`
  with its string, its heredoc or `false` is `sd`, drawn as a comment,
  an escape inside keeping its colour and a `#{}` hole read as code;
  `\x1f` is one escape, where the lexer stopped at `\x`; and a keyword
  after a dot (`Mix.raise`, `range.end`) is a name, the one case where
  the lexer was simply wrong. What is still apart, 6.0 %, is left on
  purpose. 5.2 % is VS Code leaving the theme, not the console: a
  heredoc and a sigil are `string.quoted.double.heredoc` and
  `string.quoted.other.literal`, a one-line doc
  `comment.documentation.string`, `_` `comment.wildcard`, none of
  which the theme names, so One Dark Pro gives them its own green and
  grey, a shade from the theme's, which the console uses for all of
  them. 0.8 % is the grammar's gaps, which VS Code leaves in the base
  colour and the console colours: the brackets of a `def`'s head and
  the `%` of a map, `^` and `!`, `defguard`, a head's names after a
  nested `)`, where the grammar closes the head early. The rest,
  0.04 %, is VS Code misreading — a doc given with a sigil, a variable
  named `exit` — and one-file oddities. A template's Elixir is left as lexed:
  it reads with HTML's palette.
- **A regex is on the sheet again.** Pygments' class for a regex is
  `sr`, and `sr` is also the design system's screen-reader label
  (`components.css`: one pixel, absolute, clipped). Every regex a
  lexer found — `~r/^[a-z_]+$/` in the Interface tab's own sample —
  was given its colour by `.src .sr` and hidden by `.sr`: the line
  read `Regex.match?(, p.name)`. Seen on the screenshot taken to check
  the first repair above, on 2026-10-01. `.src .sr` now undoes the label's
  clipping; inside a `.src` the class is only ever the token.

## v0.14.0 - (2026-09-29)

### Added

- **The console checks `NODE_VERSION` the way it checks the stack and
  the installer.** The field is a select over the Node majors, read on
  the button and never on its own: where each stands today from Node's
  own release schedule (`nodejs/Release`, `schedule.json`), grouped
  with the active LTS line first, and whether NodeSource has a
  repository for it, one call per major (`Console.Nodes`, in this BEAM
  like `Console.Installers`). A major NodeSource has not got is listed
  unlit and says so, since the images' build stops at apt on it; the
  major config.conf names is marked when NodeSource has not got it or
  the schedule does not know it, and otherwise carries its standing
  (`lts · until 2028-04-30`).

- **A paper's fenced code is coloured as the Files sheet colours a
  file.** The papers a box carries, the project's own and the
  workbench's were rendered with every fenced block in plain terminal
  ink, while the Files sheet next to them coloured the same Elixir
  with Makeup and the reader's palette. `Console.Highlight` gains a
  registry by the name a fence opens with (` ```elixir `, `heex`,
  `css`, `ts`, `json`, `markdown`, `gd`, `sh`…), the same treatments as
  the one by extension, and `Console.Papers.to_html/1` passes MDEx's
  output through it: a block whose name a lexer answers to is read back
  off the page, lexed, and put back as `pre.src[data-lang]`, so the
  palette the reader set on the Interface tab reaches it; a fence named
  nothing, or named something no lexer answers to, stays as it came.
  Nothing about the renderer's HTML policy moves: the block's text was
  escaped by MDEx before and is escaped again by Makeup after. The
  shell, the most written fence on the papers (48 of 96 named ones),
  had no lexer: no `makeup_*` on hex lexes a shell (checked
  2026-09-29), so it reads through `makeup_syntect`'s grammar like
  Markdown does, as the eighth palette of the Interface tab, `Shell`,
  with its sample, its scopes for a pasted VS Code theme and its
  twelve custom properties.

### Updated

- **exdoc v0.9.1: the placeholder logo is 256 px.** It was 1254 px
  and 1.9 MB — the reason `--app-logo` is off by default said so —
  and is 73 KB now, the same picture at the size a sidebar shows it.

- **A tab leads back to where its screen was left.** Project on Mix,
  a look at Docker, back to Project: it opened on Birth, and Docker
  came back on Containers, while the shelf alone kept its filter — not
  by design but because it read none from a bare URL. The socket
  already remembered each screen's place (`ppaper`, the Docker
  document, the ribbon's filter); the tab strip's links now carry it —
  `/project?paper=mix`, `/docker?doc=images`, `/shelf?doc=archived` —
  through the one `screen_query/2` that Put back and Close already
  used to come back to a paper, so the URL stays the screen and the
  browser's back stays the trail. A default says nothing in the link.
  The same one level down (found by the author the same day): inside a
  box, Installation's link names no paper and the Manual came back on
  README; in the workbench drawer, Config's link did the same to its
  Manual. The box in hand and the open drawer keep the paper they
  were on when the URL names none. Not a subtab, and not remembered: a
  compose file open on Deploy and a box put back, which are sheets
  over the screen.

- **The README's first screen, and the manual told against the
  workbench as it is.** The README opened as a 267-line operating
  manual whose first sentence called the whole thing "a script"; a
  reader with ninety seconds got no picture and no path. It opens now
  with what it is in one sentence — the script, the cartridges, the
  console — a screenshot of the console with a project up, a
  Quickstart of three commands (the ones the release rehearsal
  walked, with the times they took), the same path from a shell, and
  the shelf with its covers, since a feature that is a box is the one
  thing a screenshot says better than a sentence, and "Why it is
  shaped like this": the pod pattern, the cartridge as one commit with
  its papers, the console that reads and never asks, the CHANGELOG as
  the record, each a link. The manual under it was read
  against `wb.sh help`, the catalog and the console, and corrected
  where it had drifted: the pod service is `pod`, not `network`; `up`
  and `build` take `--deploy`, never `--env`, which the script refuses
  now; `new` bakes the three compose files, not one; `--replicas` and
  `--no-balancer` are `bake`'s alone since the three files are born
  with the project; `add k6` and `add monitoring` no longer need a
  `bake` after them, since an insert bakes its services in its own
  commit; db_admin's `--admin` has no default; the cluster's remote
  shell is `./wb.sh iex --deploy scaled app1`; the feature list is the
  shelf of today — sixteen offered, seven base, two pending, twelve
  archived (it said ten, and listed a box that is archived among the
  offered); the console's checks start with `mix assets.build`; and
  the verbs the manual never named — adopt, stacks, engine, config
  set, expand, restart, prune, `--yes` — have a line each.

- **The release, rehearsed on a fresh clone.** The path a reader
  takes from GitHub, walked with Docker emptied of images first: a
  clone in a scratch directory, `./wb.sh console`, a project created
  from the browser, Up dev, the app on its port, Delete. It holds.
  The console's image built in four minutes and the console answered
  the moment it was up — the image carries a release, nothing compiles
  on the first run; Create project took 142 s, Up dev 44 s with the
  app answering 36 s later on the first free port, Delete 11 s. Found
  and fixed on the way: `wb.sh` and `build.py` tracked without their
  executable bit, and CI running the console's suite without the
  bundle it reads. The README's first step, "give execution
  permissions to `./wb.sh`" with a `sudo`, was the patch for that bit
  and is gone. One thing found and left open: run from the console,
  `delete` removes the files, the containers, the images and the
  database's volume, and leaves the two build volumes the console
  itself mounts for its resident (`<name>_deps`,
  `<name>_workbench_build`) and their two empty mount-point
  directories in the workspace — a running container's volumes cannot
  be removed from inside it, and the errors are swallowed, so the job
  ends with exit 0 and the Danger card's "its volumes" is not the
  whole truth there. From a shell, with the console down, everything
  goes. An issue, with the release.

- **A door follows the page when the project moves it.** exdoc's
  docs door named `doc` and coverage's report door named `cover`, so a
  project that wrote its docs elsewhere — tunez, to `priv/static/doc`,
  where the app serves them itself — read *nothing built* in the
  console, with a build button that built and still did not see it.
  Where a page lands is now an option of each box, in the tool's own
  words — exdoc v0.9.0 `--output`, coverage v0.12.0 `--output-dir`,
  with the directory they always wrote as the default — and `state/1`
  reads the value back off `mix.exs` and `coveralls.json`, so a project
  that moved the page by hand reports it like one that asked. The door
  is `{output}` / `{output_dir}`, and the console fills it the way it
  already fills health_probe's `{path}`: nothing changed on its side,
  and the Record's parameters column shows the flag like any other,
  marked when it is the default. A directory inside the project is a
  format now (`:dir`, beside `:url`, `:route`, `:version`): relative,
  no `..`, since the console serves it off the workspace. exdoc's
  `--coverage` copies the report from where coverage's state says it
  is, where it assumed `cover`.

- **A pending box says it is not built, in no word the console uses
  for something else.** *Installer* is the Phoenix generator across the
  console — the New Project card's row, the Record's, the drawer's
  list — and a pending box said "its installer is not done yet",
  meaning its own Igniter installer, which the package calls that and
  the reader never sees. Two things, one word, two screens apart. The
  five strings (the *not done* chip, the Files sheet's reason, the
  default summary on the box and the shelf, the Insert button's
  reason) now say what the reader needs: designed, not built, nothing
  inserts it yet — in the house's own verb. The package keeps its
  vocabulary: a cartridge's *installer* is its installer and its
  *task* is `task.ex`, so "its task is not written yet", the wording
  the plan had in mind, would have named another piece of the same
  box.

- **The console's boxes are three families, and two of them are the
  house's.** The question was whether Project › Mix should sit in a
  card like the Deploy screen's; the answer came from an inventory of
  every box the console draws (`_archived/inventario-de-contenedores.html`,
  2026-09-27, retired with this entry as its record). The boxes were
  not scattered: a *card* frames what is acted on — a form or a row of
  verbs: New Project, Deployments, Danger, Commit — a *sheet* is what is
  read and wears no frame — Birth, Mix, History, README, Docker,
  Cartridges, Jobs — and a *terminal box* frames what came out of a
  process or a file: Logs, Terminal, a job's output, the .env, the
  daemon's specs. Twelve boxes, a rule of three lines nobody had
  written, no exception. **Mix stays a sheet.** What the inventory also
  found: the card was declared four times in `console.css` (three head
  sizes, a hand-written list of what folds) and the terminal box three
  — eight, counting the ones outside the screens: a paper's code
  block, `config.conf` in the drawer, the birth command, the daemon's
  specs, a container's env. Both are notation now, in the design
  system: `.card` and `.term-box` in `components.css`, declared once,
  and `ConsoleWeb.Card` is the one place that writes the class
  (`<.card name key folded danger tag class>`, with `:head` for what the
  head carries beside the name) — New Project, Deployments, Danger,
  Commit, a container's ficha and the box's specs call it. The commit
  form's head is a card's head now, at the card's size. `.target`, a
  card no template wrote, is gone. The name was taken twice: the box's
  cover in hand is `.cover`, the drawer's ground pickers are `.swatch`.
  `ConsoleWeb.BoxesTest` is the ten-line grep the page asked for: the
  two frames appear once, in the generated file; `console.css` never
  draws them; no template writes `class="card"` by hand; and the copies
  the console serves are the ones `build.py` wrote. Two tests learned
  that LiveView marks a slot's first element `phx-r`, and stopped
  matching a whole opening tag. The fold is a state and wins over
  whatever a card's content says its display is — the Danger foot's
  grid outranked the first version of it, and the card would not fold. One box the rule does not settle yet:
  the box's specs, a framed reading in the drawer, keeps its frame as a
  card without a head.

- **The README asks for Docker, not Docker Desktop.** Its first
  sentence and its first step named Desktop as the one thing to
  install. On Linux that is the worst route — the CHANGELOG's own
  verdict when the builds left the bind mount — so the step now says
  which: the native Engine on Linux, Desktop on macOS and Windows.
  Two typos of the same screen with it ("his directory", "scalated"),
  and the licence year runs to 2026.

- **A paper's headings carry GitHub's ids, and the index is a link to
  them.** Every `h1` to `h4` of a rendered paper — a box's, the
  workbench's, the project's — has for id its own words as GitHub
  writes them (`MDEx.anchorize/1`, GFM's algorithm: lower case,
  punctuation out, a hyphen a space; a repeated heading counts from the
  second on, `repeated-1`), in place of a number on the `h2`s alone
  (`h-0`, `w-0`, `p-0`). So a link an author wrote for the repository,
  `(#what-it-installs)`, `(#7-what-it-replaces)` — three of them on the
  papers today, leading nowhere in the console — lands on its section
  here, and the index at the right is those anchors and nothing more.
  The section goes into the address, so a place in a paper can be
  copied and opened, and a booklet opened on one lands there. Two
  papers can be on the page at once, a box's manual under the drawer's,
  each with its *What it installs*: the booklet's hook looks inside its
  own article before the document.

- **The New Project card asks nothing `config.conf` already answers.**
  The *project name* field is gone from the card (its markup stays as a
  comment in `new_project.ex` for now): the name is `config.conf`'s,
  and a field beside it was noise, and one more way to end with a
  project called one thing and its images and compose project called
  another. The *node* row goes too: Node serves one option of one
  cartridge, and whoever opens the configuration for any other reason
  finds the field explained there. The stack the card shows reads
  debian, elixir, erlang, installer.

- **`config.conf` reads in the order it is filled.** `NODE_VERSION`
  stands after `PHX_NEW_VERSION`, at the end of the stack, and the
  service images stand under four sub-headings — database (ecto), DB
  admin, balancer, monitoring — each above the block it heads.
  `wb.sh`'s notice for a `config.conf` from before `NODE_VERSION` says
  where the line goes now.

- **The daemon's Specs: the disk in columns, and one colour that means
  something.** The Docker screen's box set its in-use ratio in the
  source palette's blue and every size's unit in its gold (`--t-const`,
  `--t-mod`, since 2026-09-24): One Light's and One Dark's, the code
  editor's set, on a reading that is not code, and gold eight times a
  block on the piece that matters least. A first pass put the keys in
  the accent, as the .env paper's are, and the ratio in the terminal's
  blue; it did not read better. Seven takes on the real daemon, side by
  side on both grounds (a decision page, retired with the decision),
  settled it: the machine's five lines are set by weight alone — key
  and qualifiers dim, the figure bold, the rest ink — and the disk is a
  table, as `docker system df` prints it, a dim head over four columns
  (in use, size, reclaimable, its share) instead of the same sentence
  four times, the widths in `ch` so the bitmap faces keep them whole.
  The one colour is the house's warn on a reclaimable share of half or
  more, with the title saying where to prune: the one thing the box
  says that asks for an act, in the voice the chips say it in. The
  template is a component a line, `spec_line/1`, in its four shapes,
  and the pieces of a value one component, in place of a `for` written
  without a line break between its spans.

- **GitHub's mark is vendored like hex's.** A package from a
  repository on GitHub wore the Invertocat from the house's sprite
  (`assets/design/icons/github.svg`, since 2026-09-23): a tracing of no
  recorded provenance, painted in whatever ink held it, alongside the
  bell and the cog — everything `vendor/README.md` says a third party's
  mark is not. The sprite symbol is gone. The mark is now the two files
  GitHub itself hands out (`brand.github.com/GitHub_Logos.zip`), black
  and white, vendored at `console/priv/static/images/vendor/` with
  their provenance beside hex's, and shown as `<img>` like hex's: the
  mention carries both, and the house's `.pkg-ref` shows the one the
  ground calls for, switching under the same three guards as the
  tokens, so neither is ever recoloured.

- **The console's image is `dew-console:WORKBENCH-HASH`.** The stack
  and the installer are no longer in its name: the hash in the tag
  now covers the workbench image the release is compiled on, along
  with the sources and the path, so a stack changed in `config.conf`
  is a new tag as a source changed is, and the base's name is a label
  on the image (`org.opencontainers.image.base.name`). One repository
  to list, and `prune_console_images` now also drops the consoles of
  this version built on another stack, which the stack in the name
  kept out of its sight. The images with the old name are not seen by
  the new prune: `docker rmi` them once.

- **The console's logs come out in colour.** `config :elixir,
  ansi_enabled: true` in the console's `config.exs`: Elixir turns
  colour off when its output is not a terminal, and the console's is
  a pipe — its container's log — so `./wb.sh console` and `console
  logs` showed Logger's lines plain. Forced on, they read as they do
  under `mix phx.server` on a terminal.

- **The mark is redrawn in Inkscape, with rounded corners.** The
  bench's legs and top, the screen's plate and the three drawers now
  end in a 25-unit radius, in a 900-unit box; DEW and the prompt are
  the same pixel letters, and the silhouette at 16 px is the same
  tab. `logo.svg` stays what the console inlines: the drawing alone,
  in `currentColor`, no ids, no editor namespaces, no hidden layer —
  the Inkscape export carried a `fill:#000000` on every shape, which
  would have painted the mark black on the band's violet, and eight
  path effects plus the text the letters were drawn from before they
  were made paths. The editable file comes along beside it as
  `logo.inkscape.svg`, the way the GIMP source of the first mark did;
  that source (`logo.xcf`) and its PNG go, since they draw the old
  mark. `favicon.svg` is regenerated by `build.py` and `favicon.ico`
  by the command it documents; `--check` is green.

- **Node from NodeSource, by the major `config.conf` names.** The
  shared first step of the two Dockerfiles (`scripts/Dockerfile.seed.local`,
  `scripts/Dockerfile.workbench`) took Node and npm from Debian since
  2026-09-17, for the `npm install` ash_typescript's installer hooks
  into `assets.setup`. Debian's `npm` unpacks every dependency of npm
  as a package of its own: measured on the base image on 2026-09-28,
  the step went from 111 packages, 112 MB and 140 s without Node to
  658 packages, 239 MB and 521 s with Debian's `nodejs npm`, and the
  layer from 582 MB to 1.2 GB — most of a fresh workbench build. The
  same node with npm inside is one package on NodeSource, which
  makes the step 124 packages, 158 MB and 103 s (the difference with
  140 s is the network between runs); the whole workbench image, from
  scratch on an idle machine with the base pulled, builds in 102 s,
  the shared step 64 s of it. Node stays in the shared step,
  in both images from the start, because the workbench cannot know
  whether the project to come picks `ash --api typescript`, and
  `mix setup` runs `assets.setup` at every boot of the app's
  container. Its major is `NODE_VERSION` in `config.conf`, the fourth
  part of the stack and the one that is not hexpm's tag (24, LTS
  until April 2028; NodeSource names its repositories by major and
  rolls the rest, so it is a major, not an exact version): stamped
  into the workspace's `Dockerfile.local` as `ARG NODE` beside the
  other three, passed to the workbench image's build, and in that
  image's name — `dew-exELIXIR-erlOTP-nodeNODE-phxVERSION:WORKBENCH` —
  so a change in the config builds a new image instead of doing
  nothing until someone removes the old one. The console names the
  image the same way, reads `NODE` off the stamp beside the other
  three, and shows it on the New Project card. A `config.conf` from
  before the line is told what to add when a build or a bake reads
  it. The production `Dockerfile` ash patches for `--api typescript`
  still takes Debian's `nodejs npm` in Phoenix's builder: Phoenix's
  file, for its own session.

- The mailer's README shows how to see the mailbox work: a mail sent
  from IEx on the node that serves the page (`./wb.sh iex`, or the
  console's Terminal on `app`), read at the *mailbox* door — and why
  a VM of its own (`iex -S mix`) would show nothing there.

### Fixed

- **CI builds the console's bundle before its tests.** `HooksTest`
  reads `priv/static/assets/js/app.js`, the bundle esbuild writes and
  git ignores, to check every hook the components ask for is in what
  the browser gets — and the workflow never wrote it, so that test
  fails on any fresh checkout (found on an extracted tree,
  2026-09-29). `mix assets.build` runs for the console before its
  suite.

- **`wb.sh` is executable in a clone.** The repository has
  `core.fileMode` off since the mock's `+x` troubles, and `wb.sh` and
  `assets/design/build.py` had been tracked as plain files (`100644`)
  all along: a fresh clone got a `./wb.sh` the shell refused, and the
  console's suite on such a checkout died of `:eacces` the moment the
  bench ran it (39 failures, found rehearsing the release on an
  extracted tree, 2026-09-29). The two carry the bit in git now, as
  `scripts/entrypoint.sh` and `assets/covers/covers.py` already did.

- **A choice's default starts checked.** coverage's `--ignore-files`
  boxes and `--html-theme` radios, exdoc's `--module-groups` once the
  project said `layers`: the form tagged the default and left it
  unchecked, on the rule that a default is shown and never filled in
  — right for a text field, whose empty state *is* the default, and
  wrong for a radio, where nothing on beside a *default* tag read as a
  question the reader had to answer. The root: a choice was checked
  only when the reader had picked it or the project reported it. It
  is checked now when the form holds nothing else — the reader's pick
  first, then what the project reports (a box in from birth on mysql
  shows mysql, not postgres beside it), then the default — and the
  line still leaves the flag out while the pick is the default, the
  default set of boxes included, so pressing Insert at once gives
  what the checked values promised. Every box unticked is the default
  again: the installer has no value for "none". Checked on the whole
  shelf off the package the console carries (`BoxInstallTest`): every
  choice with a default, in every box that is not archived or pending,
  starts checked on it.

- **A paper's code blocks ignored the Files face.** `.md pre` read the
  reader's face for files, and its text did not: the block's `<code>`
  took the inline chip's `font-family` from `.md code`, so a README
  under Tamzen kept every block in Plex. The code inside a block now
  inherits the block's font whole (`.md pre code{font:inherit}`).

- **The code/drawing switch on an SVG's diff stood against the top
  edge.** The source pane has no padding of its own — a row paints its
  band edge to edge — and the switch brought room on its left and under
  it only, so it sat pressed to the top of the box; and its sticky
  offset was the scroller's edge itself, so a patch scrolled sideways
  pressed it against the left. It now brings room over it too, as the
  drawing keeps under, and sticks at the same distance from the left
  it stands at in rest (`console.css`, `.impl .src .switch`).

### Removed

- **`./wb.sh demo`.** It ran `new`, `up`, `logs` and `delete` in a
  row, with a trap so that Ctrl+C on the logs moved on to the teardown:
  the way to show the workbench when the workbench was a script alone,
  and the most destructive verb it had, since it began by deleting
  whatever project was there. The console is that demonstration now,
  button by button, and the release rehearsal walked it that way
  (2026-09-29). Gone from the script, its help, the README and the
  console's list of verbs.

- **Two papers of the package.** `igniter/la-estructura-de-los-cartuchos.html`,
  the decision page of the cartridge-structure review (its first phase
  landed on 2026-09-11: `state/1` on every cartridge, the composes, the
  conformance suite), goes to `_archived/` with the other settled pages.
  `igniter/lib/mix/tasks/SETUP2_INVENTORY.md`, the inventory that guided
  the dissection of the retired `workbench.setup` and said of itself it
  was kept as a record, is removed: the record is the CHANGELOG's and
  chiefs_setup's DESIGN, whose reference to it now says where it is
  (git history).

- **`IGN_IMPROV.md`, archived.** The paper of 2026-09-24 that read what
  Igniter already solves against what the workbench does, and planned
  four phases from it. What it settled stays decided: an installer
  refuses with `Igniter.add_issue`, never `raise`, and the workbench
  keeps its own recovery — `undo_failed_insert` over git — instead of
  Igniter's prompt, and its own `add` instead of `igniter.install`'s
  Hex round trip. Its first phase, `mix workbench.ash.site` checking
  the site both ways every week, was done the day it was written. The
  three that were not — the insert preview, the upgrade of an inserted
  cartridge, and a small hygiene — go to `RELEASE_PLAN.md`, Phase 2, as
  issues to be, under the rule that nothing is built until a chapter
  asks for it. Out of git, in history at the root.

- **`CONFIG.md`, archived.** It was a second copy of what `config.conf`
  says above each of its lines, and the copy had drifted: no
  `JOB_NICENESS`, two image versions the file no longer carries,
  examples from 2024. The file is the documentation of itself — the
  console's drawer reads each comment block as its field's help
  (`Console.Config`) — so the README points at the file and the drawer
  now, and the one mention with the typo goes with it. What the paper
  had on its own, how `new` weighs the installer against the stack, is
  in `config.conf`'s note on `PHX_NEW_VERSION` in short and in this
  changelog in full.

- **The reference project's papers leave the repository.** `reference/`
  — the design of the project the series is built on, a light CMMS:
  candidates, stories, events, rules, glossary, ADRs, domains and their
  diagrams — is the author's own guide, not the workbench's, and goes
  to `_local/` (ignored) with its diagram script, which finds
  `assets/diagrams/build.py` from one directory deeper. What cited it
  (`CLAUDE.md`, `SCRIPT.md`, `RELEASE_PLAN.md`, the `project-design`
  skill) says the papers live outside. The move hides them from the
  tree and not from the history, where they have been since
  2026-09-16 on the published branch: `RELEASE_PLAN.md` gains, before
  the merge into `main`, a review of the whole history — the papers
  filtered out, and a sweep for anything sensitive — to be done once,
  before the tags.

- **The mock, archived.** `mock/` — the console's static maquette,
  its generator and the captures of test_28 it was built from — was
  retired on 2026-09-05 and stayed tracked: ten files, 7.6 MB, most of
  it the built page with the covers in base64, in every clone for
  nobody. It goes to `_archived/`, out of git, which keeps it in
  history; the plan that read it as a specification is archived beside
  it. With it goes `mix console.highlight`, whose only caller was the
  mock's build, and every mention that spoke of it as alive: the design
  tokens' consumers table, the diagrams' notes, the root layout's and
  the policy's comments, the console's README. The papers' historical
  mentions — what the mock got wrong about escaping, how it drew the
  terminal — stay as the reasons they are.

- **`scripts/PLAN.md`, closed and archived.** The compose plan of
  2026-09-06 — the bake moved from `sed` in `wb.sh` to a plan rendered
  by templates in one Mix task, the services declared by the cartridges
  — is done: its five steps landed on the 6th and the 7th, and the
  three things its record left for later are done since by the service
  cartridges (pgAdmin's `configs` block in db_admin's own fragments, the
  console drawing the services off `Compose.brought/2`, the grep gone).
  Its sixth step, umbrella, never started and goes to `RELEASE_PLAN.md`
  as an issue to be. The living home of what it settled is
  `WorkbenchIgniter.Compose`'s moduledoc and the shelf's index, which
  the six citations point to now; the one line it owed the root README
  — hand edits go to `docker-compose.override.yml`, the bake never
  touches it — is written. Archived beside the console's plan, out of
  git, in history at `scripts/PLAN.md`.

- **`console/PLAN.md`, closed and archived.** The console's port plan
  (2026-09-02 to 2026-09-27) is done: the six steps of its order, the
  volumes and the release all landed, and what it still called open is
  settled in its last section — the third step, the node, is retired,
  as *The resident stays* (2026-09-06) had already decided and the
  release's section forgot; the *Which* of its first section and the
  two the first step left open were decided in practice or the same
  day; the covers, the single stylesheet, `docker events` and NEED's
  four parts are done or moot. Two things stay open and go to
  `RELEASE_PLAN.md`, Phase 1: the word *installer* for a cartridge's
  installation, and where a project moved its docs' or coverage's
  output. The paper goes to `_archived/` with the retired decision
  pages, out of git, which keeps it in history. What the code cited
  from it — the pieces, the four fixed rules, the resident over
  `:erpc`, the console as the toolchain, the project's pages on their
  own origin, the release, what belongs to the client — is now
  `console/README.md`, *The architecture, as settled*, and the ten
  citations point there. The README also drops what was no longer
  true: the Cluster module and screen (retired 2026-09-26), the mock as
  a living thing, and *Not verified yet*.

- **The *Detail* link on the New Project card's workspace row.** The
  `existing project` chip stays and says what Create would overwrite;
  the Record is the Project tab's, and the card that asks for the next
  project no longer points at the one it would replace.

## v0.13.0 - (2026-09-28)

### Added

- **The console runs as a release.** `./wb.sh console` and `console
  up` start the console on an image of its own,
  `console/Dockerfile`: the workbench's image with the console
  compiled into it as a release (`MIX_ENV=prod`, `mix release`), built
  once for the sources as they are and started in seconds — nothing
  fetched or compiled at start, and no code of the console compiled
  through the bind mount any more, which was the first of the fixed
  rules of `console/PLAN.md` (the second step of its order: volumes,
  release, node). The image is named off the workbench's
  (`dew-console-STACK-phxVERSION:WORKBENCH-HASH`), the hash over what
  `.dockerignore` lets into the context — `console/` and `igniter/`
  without tests, build output or the cartridges' papers, which the
  console reads off the mount, so a paper edited costs no build, and
  over the workbench's path, which the image is good for alone; a
  source that changed is a new tag, built on the next start, and the
  old tags of the same version go once the new console runs. The
  sources are compiled at the workbench's host path, where the console
  mounts them: the package reads a cartridge's version and need at run
  time off the directory it was compiled in. The release carries
  `:mix` (the catalog is a Mix task called in this BEAM), reads its
  origin check and the reports port from `config/runtime.exs`, and no
  longer forces SSL: it serves 127.0.0.1 over plain HTTP. `console
  dev` keeps the mode the console ran in until now, `mix phx.server` on
  the mounted sources with its build and deps volumes, for work on the
  console or the package; the start-again from inside comes back in the
  mode it was started in. `console build` builds both images. Found on
  the first `new` from the release (2026-09-28): ERTS puts the release's
  own `erts-*/bin` first on the BEAM's PATH and exports where it lives
  (ROOTDIR, BINDIR, EMU, PROGNAME), so the job's `mix` found the
  release's `erl`, whose root has no `start.boot`, and died booting
  ("cannot get bootfile"). `Console.Application` now scrubs the
  release's runtime from the environment at boot — those four, the
  RELEASE_* variables and the PATH entries under RELEASE_ROOT — since
  every process the console starts inherits it; under `console dev`
  nothing is set and nothing is touched.

- **`JOB_NICENESS`: the compile cedes the CPU.** With the console in
  its container, an `add` compiles *inside* that container, beside the
  console (`toolchain_here`), with nothing between it and every core:
  an `add ash` held seven to nine of twelve for two and a half minutes
  (measured 2026-09-25 on a probe console), then the resident compiled
  again for the status. On a host already at work — the browser, an
  editor, the compositor — the page reading the job went slow and its
  socket dropped; the server never did (navigation 19–42 ms through
  the job, no long tasks), and the reconnect that followed fetched the
  backlog of every open pane again, which is what looked like the
  console being slow. `config.conf` now says how a compile is
  scheduled, `JOB_NICENESS` (0–19, 10 by default): wb.sh puts `nice
  -n N` in front of what compiles here (`entrypoint_here`: new, add,
  expand) and the same proportion as `--cpu-shares` on a run in a
  container of its own, and the console's resident does the same for
  its own `deps.compile` and `workbench.serve`. The readers — status,
  git — stay at 0: short, and waited on. 0 is the old behaviour. The
  drawer shows it under Git, "every compile".

- **`--brief`: the two readings in the words a tool keeps.** An agent
  driving the workbench from a shell reads the workspace before it
  acts, and the shelf before it picks a box, and pays for both by the
  token: `status --json` was 153 KB and a minute (the raw rows of
  `compose ps` with every label of the project, then Mix booted in a
  container for `project`), `catalog --json` 134 KB and half a minute
  (every NEED, every option's doc, every menu, the covers). The weight
  is not the transport, it is the shape: the same JSON through an MCP
  would cost the same. So the contracts grew a projection, not a
  door. `status --json --fast --brief` answers in tenths of a second
  with the containers as service, state, health, status and ports and
  without `addresses` and `homes`, which only the console's terminals
  read: 2 KB, measured on a project of four containers.
  `catalog --json --brief` (`Mix.Tasks.Workbench.Catalog.brief/1`) is
  one line of name, version, the facts, the need's line, `requires`,
  and each option as name, type, default, values and `multiple`:
  20 KB. Its half minute stays, being the Mix boot and not the
  answer; the reading that is fast is the console's resident, and a
  door on the console for agents (an MCP, which also gates the
  destructive verbs) is the next step if one is wanted, not this one.
  The `:erpc` road of `console/PLAN.md` was checked and stays retired
  (2026-09-06): the resident answers with the app down, and the
  distributed dev node it needed is the wrong shape. `CLAUDE.md` names
  the two readings for the agents that work here.

- **`./wb.sh adopt` takes in a project made elsewhere.** A Phoenix
  project copied into a workspace — `pitchers`, from 2024, the first
  one — had no `docker-compose.yml`, and everything reads the
  workspace off that file: its name, its image, its ports. Nothing
  could be done with it. `adopt` does what `new` does after `phx.new`,
  on the project as it is: it commits the project as found when it has
  no repository (`Import APP as found`), then registers the package,
  runs `workbench.setup`, writes the production `Dockerfile` only when
  there is none — and only warns when it cannot: phoenix 1.7's
  `phx.gen.release` asks hex for `debian-bullseye` images alone, which
  the newer OTPs are not built on, and only `up --deploy prod` needs
  that file — stamps `Dockerfile.local` and bakes the compose, as
  one commit (`Adopt APP`), undone whole if a step fails. The
  workspace is named by the project's own `app:` in `mix.exs`, never by
  `config.conf`'s name for the next project, and so is a workspace
  with no compose yet in every other command. The stack is
  `config.conf`'s, weighed against the `elixir:` the project asks for;
  below the 1.18 floor `adopt` warns and asks instead of refusing,
  since a project written for 1.17 may compile on nothing newer, and
  the risk (two `deps.get` at once on the shared `deps/`) is one the
  reader can keep clear of.
  The phx_new the base cartridges take their delta with is unknown for
  a project born elsewhere. It is read off the phoenix `mix.lock`
  locks, which is the Phoenix the delta will be merged into, and it is
  stamped like a generated project's (`--phx-new` names another).
  `workbench.setup` leaves an existing `.env` alone, and now its
  `.env.sample` too: both files are the project's own.

### Updated

- **Changes is the Project tab's last paper.** Birth, History, Mix,
  .env, README, CHANGELOG, Changes. History stays beside Birth, where
  the two git papers went on 2026-09-10 — what has happened to the
  project belongs beside what it is — and Changes alone goes back to
  the tail: it is not a record but the one paper about what has not
  happened yet, the tree git does not have, with the verb that puts it
  there; and its count of files is a notice, which reads at the edge
  of the row and not in the middle of it. A reader who thinks "git"
  finds the two apart, and each says on its sublabel what it is read
  off — HEAD's sha, the tree's count — and a commit in History or a
  job still opens Changes by its address.

- **The three compose files are born with the project, and `up` writes
  none of them.** `new` baked and committed `docker-compose.yml` alone;
  `docker-compose.prod.yml` and `docker-compose.scaled.yml` were born
  on their first `up --deploy`, which baked them on its way and left
  them uncommitted — and a cartridge inserted before that first up
  carried its services into the dev file only, since `add` and `eject`
  rebake the files that exist. `new` and `adopt` bake all three now
  (`bake_release_composes`), in the birth commit, so every Insert
  carries its services into the three and every eject takes them out
  of the three, and `compose_is_ours` already owned a file whose last
  commit is the birth. With that, `up` and `build` stop writing: each
  deployment goes up or is built as baked, as dev always was, and
  `--replicas` and `--no-balancer` are `bake`'s alone — `up --deploy
  scaled --replicas 3` is refused with the bake line to run first.
  Unasked, a bake keeps the scaled shape the file has, read off it
  (`read_scaled_shape`, which the message after an up reads its ports
  with too); a file that is behind is what the status and the
  console's Deploy tab already say, with Bake on its row. A workspace
  born before this has no prod or scaled file until `bake --deploy`
  writes it, and `up` says so with that line (it said `up --deploy`).
  The console's Up and Build lines lose the shape; Bake keeps it, and
  the reason on an unbaked row is "Bake writes it".

- **A box's Brings is the plate every address wears.** The Specs of a
  box said the containers it raises in a face of its own — the rail's
  Services dot in the role's colour, the port inside beside it — while
  the Inserted list drew the same pgAdmin as a blue door on
  `localhost:5051`, open while its container ran. Two faces for one
  address, and only the list could open it. Brings now draws each
  container with `Refs.door_ref/1` off the same `Record` reading the
  list uses (`Record.service/2`, the row's builder, made public as
  `Record.door/3` was for Opens): a door on the host where the compose
  publishes it, a hollow port inside where it does not, its reading on
  the plate, and shut with the plate's reason when it is not there —
  "the deployment is down", or, for a release's one-shot while dev
  runs, "not in the dev deployment", which the row had called down.
  The colour follows the door's rules, blue for a port, and the role's
  colour goes: the same container was two colours in two places. What
  the row alone said stays — the deployments each enters, after the
  plate, and on the shelf the menu of `offers`, lit by the switches the
  form holds and shut with the switch that would bring the rest. The
  shelf's list gains the same distinction: a service the compose does
  not publish was a door there whichever, and is a port inside now, as
  on the Inserted row.

  The two tables show every service now, too. The shelf's list read
  the catalog's `compose` — what comes with nothing chosen — and ecto
  and db_admin, whose every container hangs on a choice, showed none:
  it reads the menu (`offers`) as Brings does, each shut with the
  switch that brings it after "not inserted" (`Record.only_with/1`,
  one wording for both). The Inserted row kept to the dev deployment,
  on the argument that a release's one-shot is not something the
  project has running beside it; but ecto's migrate is a container the
  cartridge brings, and a reader who did not see it wondered where it
  went. Every one is on the row, and the rail's Cartridges section,
  shut with the deployment it is in.

- **A flag on the New Project card stops costing the whole screen.**
  Every tick of a checkbox goes to the server, because the server is
  what decides which of the others go dark — `--database` with ecto,
  `--live` with html — so the round trip is inherent. What was not is
  what it dragged: the card was part of the Deploy screen's template,
  so each tick re-rendered the deployments sheet and the Danger box
  too, and that render read the workspace off disk — `Project.born/1`
  (the project's `Dockerfile.local`, **6.5 ms** measured against a real
  project) and `Record.deployments/1` (the three compose files).

  Both are read now when a status arrives, which is when those files
  can have changed — a bake, a new, an up — and carried as `off_disk`.
  And the card is a component of its own, `ConsoleWeb.NewProject`: the
  form answers to it, so what the reader is composing never leaves the
  card and the rest of the screen is not touched. Measured on the same
  page: **5 ms → 385 µs** in the server, 29 ms → 6–19 ms from the click
  to the line changing.

- **The Record's link stands with the chip that says there is a
  project.** It was *what it is* in the New Project card's head; it is
  *Detail* on the workspace row, after the `existing project` chip. The
  two come and go together — both are rendered exactly when the
  workspace holds a project — so the chip says there is one and the
  link opens it, on the row that is about it, instead of a head that is
  about creating the next.

- **The Deploy screen's three cards fold, and the base cartridges read
  down.** New Project, Deployments and Danger fold to their head — the
  rail's fold at a card's size, the same `fold_section` event, the same
  set on the server and the same memory of it in the browser, so a
  reader who has met one has met them all (`ConsoleWeb.Folds`). Each
  key is its own: the rail's Deployments section and this sheet are two
  things with one name, and fold apart.

  A folded card keeps the box it had, 16 all round: the fold took the
  rail's `padding-bottom:10px` with it at first, which reads right where
  a section has no border and wrong inside a frame, where the head then
  sits off-centre — more air over it than under (measured 17 against
  11).

  *Danger zone* is **Danger**. The box is the danger; *zone* was a
  second word for the border it already has.

  And the eight base cartridges are one per line, each cartridge's flags
  following the cartridge itself. Nothing lines them up: they belong to
  the box before them and to nothing on the lines above. They ran on as a
  paragraph of boxes that wrapped wherever the card's width ended, so
  finding one meant reading them all. What shares a line now is what
  belongs to that cartridge — ecto's `--database` and `--binary-id`,
  html's `--live` — because those are its own switches and not
  cartridges of their own, and reading them apart would say they were.

- **The console started for another project says so across the frame.**
  It is the one condition true of the whole console at once — every mix
  and git of a job runs in a container of its own, which is why a job
  that took seconds takes minutes — and it said so in a `.note` inside
  the rail's Workspace section, a local place for a global thing, where
  it was missed. It is a row against the band now, in the house's
  `--bad`, with *Start again* at its edge: under the band when the band
  is on top, over it when the reader put the band at the foot
  (`body.band-bottom`), so it always faces the screen. It says the
  consequence first and the mechanism after, and the rail's note is
  gone: one voice for one condition.

  And it says *which* of the two it is, because they are not the same
  thing and only one of them is about volumes. Another workspace: the
  console has that directory bind-mounted and this one is not in the
  container at all. The same workspace under another name — what a
  reader meets after creating a project from the card — and it holds
  that name's build volumes, `<name>_build` and `<name>_deps`, which
  the compose of the project it was started for owns; the project here
  owns others. The band names them. The comparison is made in
  `Workbench.rebind/0`, which already had both values, and travels as
  `moved`.

  Nothing is disabled with it. In this state the console works whole —
  Docker, Logs, Terminal, the papers, the shelf, the status, every
  verb — and what changed is *where* a job's mix runs. Grey out what
  still works and the unlit rule runs backwards: it is for a verb the
  reader cannot have, not for one that is merely slower. A test counts
  what cannot be pressed with the warning up and without it, and the
  two are equal.

- **`./wb.sh new --name "My App"`, and the name moves up beside the
  workspace.** The creating command takes the name for one creation;
  without the flag, `PROJECT_NAME` in `config.conf` names it as it
  always did. The card's line says which — it read `./wb.sh new` bare
  before, without a word about what it was going to create — and the
  card asks for the name in a field that opens with the file's value.

  The line itself moves out of the creation section and up under
  `WORKSPACE_PATH`: where the next project goes and what it is called
  are one thing. What is left takes the title it always deserved,
  **Workbench images** — the four settings name and build the image
  every command runs on, `dew-ex{ELIXIR}-erl{ERLANG}-phx{PHX_NEW}:{workbench}`,
  and the project's own dev image is built from the same stack.
  *Project creation configuration* said less than they do.

  It was taken out of the file altogether for a day, and put back: the
  console needs the name **before** there is a project. It mounts
  `<project>_build` and `<project>_deps` — the volumes the compose will
  own — so that mix and git run in its own process, and started for a
  workspace with no project it cannot know the name the project is
  about to get. Every creation from the card then ended with *this
  console was started for another project*, which is true and was
  unavoidable. The setting is the same shape as its neighbour
  `PHX_NEW_VERSION`, which the file already defends in those words: it
  says what the next project gets, and the workspace remembers what it
  got.

  A name is checked before anything is built (a letter first, then
  letters, digits, spaces, `-` or `_`), and the derivation is unchanged:
  `Lorem Ipsum` is `lorem_ipsum` and `lorem-ipsum:local`. The name is
  the one argument with a space in it and `Verbs.parse/1` splits a line
  on spaces, so Create runs a list of arguments while the line on the
  card says the same thing with the name in quotes; six tests hold the
  two forms together.

- **A page's button says which of the two presses it is.** It read
  *build* whether or not the page was there, so a reader looking at
  `coverage cover/ 2026-09-25 15:32` was offered a verb for a page that
  is in front of them. *build* while there is none, *rebuild* once
  there is — and the title follows, *writes this page in the
  workspace*, *…again* only when there is one to write over. The stamp
  beside it is what says it: a page's reading and its button come off
  the one `built` in `Record.route/6`, so a page with a stamp is a page
  on disk.

- **New Project opens with the workspace, and the compose file's strip
  says only its name.** The card asked for a name and then said where
  it would go; it says where first, with the chip that tells the reader
  whether anything is there — `empty`, or `existing project`, which is
  what Create would overwrite. The name follows. And the strip over a
  compose file dropped *read only: wb.sh alone writes the workspace ·
  secrets masked*: a box with nothing to type in does not have to say
  it cannot be typed in, and the masking shows itself, on the line it
  masks.

- **The rail's Deployments is which one is up, and the one act on it.**
  The compose file's column — baked, out of sync, not baked — and Bake
  came off that table: whether each file is written, what it has
  drifted from, the file itself under its row and the Bake that writes
  it are the Deploy screen's sheet, which has the width to say it. The
  section's own head still counts them (`3 baked · scaled up`), so the
  fact stays on the rail; only the column goes. Three columns left of
  four, and with Stop and Down already on the row that owns the
  containers, a row now reads: the name, what it is doing, and the one
  verb it has. The head row went with them: `status` was the one column
  title anywhere on the rail — Containers and Cartridges have none —
  and of the three cells that row held, two were already empty.

- **The eye of the compose file column is the small square.** It stands
  on a line of a table beside a chip, not on a field of its own, which
  is the size the jobs bar and a card's row cogs already use: 22px
  where it was 28.

- **One width for every verb at the foot of the Deploy screen.** Create
  project, Up, Stop, Down and Delete the project are the same gesture
  five times down one screen — a line of `wb.sh`, and the button that
  runs it — and each was as wide as its own words: 111, 170, 170, 170,
  134 (measured 2026-09-26). They share a floor now, `--verb`, so the
  commands before them end at one edge and the buttons read as one
  column. 170px holds even the longest label the screen can produce,
  `Replace scaled with dev`, on one line. The New Project card's inset
  came down to the `16px 18px` the two cards under it wear — it was
  `18px 20px`, so its button stood 2px left of theirs and the three
  right edges of the screen never quite met.

- **The three verbs of a deployment read down at the foot, each with
  the line it runs.** Stop and Down were on every row of the
  Deployments sheet — four buttons on each of three rows, of which at
  most one pair could ever do anything, since only one deployment is up
  at a time and Stop is lit on that one alone. And `down` never was a
  row's verb: `wb.sh` runs it with `--remove-orphans`, which *"clears
  the project, orphans of other deployments included"*, so pressed on
  the `prod` row with `scaled` up it took `scaled`'s containers with
  it — a button standing in a row whose name the command does not
  honour. The foot now holds the three, one line each, the command on
  the left and the button at the right edge: `./wb.sh up --deploy
  scaled`, `stop`, `down`. Two subjects live there, so each button
  names its own — Up is the row picked above, Stop and Down are
  whatever is up (`Replace scaled with dev`, `Stop scaled`, `Down
  scaled`). Bake and Build stay on the rows, which is what they are:
  one file and one image each, and they work on a row that is not up.
  The rail follows — Stop was already on the running row alone, and
  Down joins it there — with the same rule: not unlit on the other
  rows, because unlit is for a verb a row could have, and this one
  would act on another row's containers.

- **One reading, one element: the state of a container is written the
  same way everywhere.** The rail's Containers table wore a `.chip` and
  a service's plate an `.read`, and both came off the same function
  (`Cartridges.container_reading/1`), so a reader met `healthy`,
  `exited 1` and `stopped` in two faces and learnt the vocabulary
  twice. There is one component now, `Refs.state_read/1`, in three
  places: the Containers table, the plate of a service or a door, and
  the containers a cartridge raises on its own screen — where the row
  said only *which* containers the box brings and now says what each
  one is doing. Docker's own `Status` line, which only the chip
  carried, comes with it in the title. In the design system `.read`
  splits in two: free-standing it keeps its own hairline, and inside a
  door it gives it up for the box's, as it always had.

- **A deployment that is not up says what its containers are doing.**
  A service's plate read its container only while its own deployment
  was the one up, so a `stopped` row — a Stop, a deployment that came
  down badly — went silent and said *the deployment is down*, a word
  about the deployment and not about that service. It reads them
  whenever they are its own: the row that is up, or, with nothing up,
  the row whose leftovers they are (`Record.mine?/3`). The guard was
  doing a second job, and that one is kept: the service names repeat
  across the three files — `database`, `app` and `pod` are in all
  three — so with `dev` up the `prod` row must not read `dev`'s
  container as its own. `of_deployment/1` cannot tell them apart here,
  since it goes by the image and would put the scaled deployment's
  nginx and postgres in dev.

- **The rail reads what is up before what answers.** Services, Doors &
  Pages stood over Deployments and Containers; it reads under them
  since 2026-09-26. An address answers because something is up, so the
  rail says what is baked and up first and what that opens after it —
  and the reader who came to press a door passes the row that tells
  them why it is dark. The sections fold by their own key, so nothing
  a reader had folded away moved with them.

- **The row's verbs read down, not across.** Bake, Build, Stop and
  Down folded onto as many lines as the cell had width for, so the same
  four buttons broke differently on each row of the deployments sheet
  and the column's edge moved as a row grew or shrank. They are a
  column now, one width, the same shape on every row and at every
  window — and the cell is as narrow as the widest word, which the
  services column gets back.

- **The rail's Services & Doors is Services, Doors & Pages, and
  says so in its head.** The section had three kinds of row and named
  two: the ports the compose publishes, the routes the cartridges
  declare, and the pages on disk the console serves — which its
  summary counted as doors. The head now counts each on its own, `3
  services · 2 doors · 1 page`, and the rows come in that order: the
  services, the routes, the pages, each in the cartridges' own order
  (a page was among the routes of its cartridge). The addresses column
  of the shelf's Inserted table, and the Record's row, keep the same
  order within each cartridge. Two changes go with it. A service's
  web face at its root — pgAdmin, Adminer, CloudBeaver, Grafana — was
  listed twice, as its port on the Services line and again as a
  violet door `/` on that port, knocked over HTTP: the door is gone.
  The rail lists only what a cartridge declares (`console: doors:`),
  and the cartridge's row — the shelf's Inserted, the Record — writes
  the service as the Services line does, whether it is reachable or
  not: `pgadmin localhost:5051`, a blue port, open while its container
  runs and read off that container, beside `database :5432`, the port
  inside. And a page's
  **build** stays once the page is built: it was the reading's
  stand-in while nothing was there, and now it sits after the stamp
  as the rebuild, since a page is written again as often as the
  project moves. A button may not sit inside an `<a>`, so the door's
  plate is a span and the link is its name and address, laid flat on
  it (`display: contents`); the reading and the button are the plate's
  own. The page's stamp drops its offset, `2026-09-25 16:25` and not
  `2026-09-25 16:25 -0600`: the mtime is read on the machine's own
  clock, which is the reader's, so the offset said nothing they did
  not know and took a third of the plate. Two holes in the plate go
  with it: the second reading (build after the stamp) gives the flex
  gap back, so the two share one edge, and a service with no port to
  write no longer renders an empty address that took a gap of its
  own. Nothing else about the door changes: the four layers, the
  attached reading, unlit with its reason.

- **coverage v0.11.0: ExCoveralls' own report by default, and `deps`
  and `test` are groups.** `--html-theme` grew `default`, which plants
  no template and writes no `template_path`, so the report is the one
  the tool renders; it is the new default, and `custom` and
  `exdoc-ish` are asked for by name. `--ignore-files` lost `none` and
  gained `deps` and `test` as its first groups, both in the default:
  they were written always and were not options, and the form's note
  about them was the one thing it said that was not about
  `coveralls.json`.

- **An Ash data layer builds on the project's Ecto database.** `add
  ash --data-layer postgres,sqlite` on the SQLite workspace `_003`
  stopped at *Repo module LoroIpsum.Repo existed, but was not an
  `Ecto.Repo` or an `AshSqlite.Repo`*. Both installers default to
  `<App>.Repo` and turn it into their own. The Postgres one runs first
  and turns it, so the SQLite one no longer recognises it. `--repo`
  cannot tell them apart, since one argv goes to every installer. The
  cartridge took the site's checkboxes as independent. Now `postgres`
  requires `{"ecto", database: "postgres"}` and `sqlite` requires
  `{"ecto", database: "sqlite3"}`, the per-value requirement pgAdmin
  already uses. At most one holds on a project, the other shows unlit
  with the reason, and a layer on the wrong database is refused before
  anything is fetched. This also closes `postgres` on a SQLite project,
  which went through and left an `AshPostgres.Repo` with no Postgres
  configured. Reproduced on a `phx.new --database sqlite3` probe:
  `ash_sqlite` alone turns the repo cleanly; after `ash_postgres` it
  fails with the same issue. ash v0.7.0.

- **`ash_events` brings Postgres.** `--data-layer sqlite` with
  authentication went through on its own, but with `--automation
  ash_events` it stopped at *lib/loro_ipsum/repo.ex: File already
  exists*. ash_events depends on `ash_postgres` without `optional`.
  Once it is loaded, ash_authentication's installer takes its Postgres
  branch, finds no `AshPostgres.Repo` and creates `<App>.Repo` over the
  SQLite one. The site gives ash_events no requirement. The cartridge
  now makes the value build on ecto with `postgres` and bring the
  `postgres` data layer, in the command's data-layer place, so
  `ash_postgres.install` turns the repo before authentication looks for
  one. Reproduced on a SQLite probe; on a Postgres probe `--automation
  ash_events --auth password` exits 0 with the repo turned.

- **ecto's line after the insert says what happens.** It, the task's
  doc, the cartridge's README and the workbench README sent the reader
  to a `./wb.sh setup` that `wb.sh` never had, and the README to a
  separate `./wb.sh bake`. `wb.sh add` bakes the database server into
  the compose in the insert's own commit (`rebake_composes`), and the
  app container's `mix setup`, which runs `ecto.setup`, creates the
  database at the next `./wb.sh up`. ecto v0.3.1.

- **The drawer is 50px wider.** The box's and the workbench's drawer
  (one `.drawer`) grew from 1040px to 1090px, 25px on each side. The
  left column keeps its 320px, so the air goes to the papers, their
  code and the diffs. Below a viewport of about 1160px nothing
  changes: `94vw` still rules there. The change itself rode in with
  `3d01bf4`, which does not mention it; this entry is its record.

- **An insert form's help is one voice, under what it helps.** An
  option with values said itself twice: each value's gloss on its
  line, then the option's own line under them all, which listed the
  same values again. That line is the command line's (`option_docs/0`
  renders `mix help`'s "## Options"), and the form had grown it
  alongside the glosses case by case. Now each value's doc sits under
  its input, in the doc's own face, and the option's line is gone from
  the form. What an option says that no value can goes in a new,
  optional `option_notes/0`, shown under the values: four options have
  one (ash's `--data-layer`, coverage's `--ignore_files`, precommit's
  `--checks`, db_admin's `--admin`), and the catalog test holds that a
  note belongs to an option with values. An option with no values
  keeps its doc under its one field. A doc's `code` reads as code and
  its addresses are links, the papers' links, named by their host:
  ash's `oauth2` points at its DSL, to be configured by hand.

- **Ash opens the doors its packages write.** The console showed one
  Ash door, `/admin`. The routes that Ash's own installers write are
  now doors too, each behind the option that brings it: `/oban`,
  `/sign-in`, `/api/json/swaggerui`, `/api/json/open_api`,
  `/gql/playground` and `/ash-typescript`. A door's condition can now
  name a value, `{:option, key, value}`. It reads the value off the
  cartridge's `state` the way a requirement does: one of a list's
  values, or a value in a `:csv` option's list. That condition replaces
  `{:with, value}`, which was its special case. A shut door says the
  flag that opens it (`only with --api json_api`). `/sign-in` asks for
  a strategy with pages, so ash's `state` now reads the strategies off
  the user resource. While checking `/ash-typescript`, a probe showed
  that `ash_typescript` 0.18.2's installer writes its RPC routes with
  an empty path. The ash README records it with the two-line fix.

- **A switch can say what it works fully with, without refusing.**
  html's `--live` on a project without esbuild configures LiveView and
  leaves the browser nothing to connect with: the `LiveSocket` lives in
  `assets/js/app.js`, which only esbuild brings. That was said in a
  notice in the job's log, after the insert, where it is easy to miss.
  Making esbuild a requirement would refuse what `phx.new --no-esbuild`
  makes, and what another bundler serves, and would turn `add html`
  (live on by default) into a refusal on such a project. A cartridge
  now declares it as advice (`advises/0`: the cartridges, and why). The
  installer says it in one shared notice (`Feature.advise/3`), the
  catalog carries it on the option as `advises`, and the console shows
  it beside the switch while the project lacks it: a dashed *works
  with* tag, the cartridge, and the reason on the line under it. The
  switch stays lit.

- **The daemon's Specs read by weight.** The Docker screen's box was
  plain ink under dim keys, `docker system df`'s columns in its own
  order (`35 · 18.16GB · 9 in use · 9.891GB (54%) reclaimable`). The
  machine comes first — os, kernel, docker, host, storage — and a blank
  line parts it from the disk, which now reads as a sentence: `9/35 in
  use · 18.16GB with 54% reclaimable (9.891GB)`. The figure that
  matters is bold, what qualifies it dim (the OS's edition in parentheses, the kernel, the
  platform, the storage), the in-use ratio blue and a size's unit
  golden and not bold, from the source palette so both themes have them. The build
  cache is the one kind `system df` gives no percentage for; it is
  worked out of the two sizes and truncated, as `docker` does the
  others. `Console.Docker.daemon/0` returns the daemon's fields as they
  come, and the screen sets them. Bold is 700: Fira Code and Tamzen
  carry only 400 and 700, and a 500 fell back to their 400, so no face
  showed it; IBM Plex Mono is now loaded at 700 too, and Flexi IBM VGA,
  which has one weight, gets the browser's.

- **`mix workbench.ash.site` checks both ways, and runs every week.**
  It compared each feature of ash-hq.org with what the ash cartridge
  would put in the command, going from the site to the cartridge only:
  a package the site dropped went unsaid, and it did not read sections,
  which are now what the options are named after. It reads the home
  page's sections too and reports a package a section added, stopped
  listing or moved, a section opened or closed, and a strategy the site
  offers that `--auth` does not know. What the site marks "Installer
  coming soon" (appsignal, opentelemetry) is reported as waiting and no
  longer fails the run, so `.github/workflows/ash-site.yml` runs it
  every Monday and on demand, apart from the build. The map's `order`
  field is not compared: it repeats numbers and puts Money at 999. The
  ash README says what the check is for, how to run it, how to read its
  three marks and what to do with a difference.

- **ash's Advanced Options are six options, one per section of the
  site.** `--with` took any package, with the site's fifteen as
  suggestions, and the form showed them in six groups with a free field
  at the end. `--ai`, `--finance`, `--automation`, `--security`,
  `--dev-tools` and `--components` are the site's sections, each closed
  on the packages the site offers there. A package a section does not
  offer is refused, naming the ones it does. The free field went with
  `--with`: `mix workbench.ash.site` found that the site offers nothing
  the cartridge lacks but `appsignal` and `opentelemetry`, whose
  installers it marks "coming soon". A package the site does not offer
  is `mix igniter.install`'s job, not the Ash cartridge's. The doors
  read the new keys (`admin` on `dev_tools`, `oban` on `automation`),
  and SCRIPT.md's reference project uses them.

### Removed

- **The cluster's reading, whole: the box, its two probes, and
  `Console.Cluster`.** It was the Cluster tab, then for a day the box
  the `scaled` row opened, and it is gone. Of the five things it
  showed, four are already elsewhere in the console: the replica
  addresses and their published ports on the Docker screen and on the
  Deploy sheet's own rows, the `rpc console` button on Terminal, and
  `Node.list()` two keystrokes into an `app1 · rpc` session there. The
  fifth — four requests through the balancer, reading the `X-Served-By`
  nginx adds — has no other path in the console, but it is a
  demonstration and not a reading: it says nothing until a scaled
  deployment is up, which is exactly what the reader it was meant to
  convince does not have. What convinces them is the clustering
  cartridge's own papers.

  What goes with it is worth more than the screen: `Console.Cluster`
  was the one place the console ran commands of its own — an
  `:httpc` round and a `docker compose exec` — outside the jobs it
  hands to `wb.sh`. That exception is now closed. `host/0`, its only
  part with a second reader, moved to `ConsoleWeb.Doors`, which is what
  called it. The `probe` event, its two `handle_async` answers and the
  `probes` assign go too, and `/deploy?cluster=1` is no longer a URL.

- **The Cluster tab, and the `tabs:` contract under it.** It was the
  eighth row of the rail and the only one a cartridge lit — clustering's
  `console: [tabs: [:cluster]]` — so it was also the only one dark
  unless a box was in, which is what a screen at the top of the rail
  should never be: the other seven are the bench's, there before any
  project is. Half of what it said the `scaled` row of the deployments
  sheet already said — the services, their ports, up or down — and its
  one button was that row's *Up scaled* a second time. What only it had
  are the two probes, which are the whole point: that the replicas
  answer one by one behind the balancer (`X-Served-By` off four
  requests) and that they found each other as nodes (`Node.list()`
  through the release's `rpc`). Those now read where the reader just
  pressed Up — a box under the `scaled` row, opened by a square beside
  the file's eye, unlit with the reason while that deployment is not up
  — and one box at a time under the table, so a file's eye closes it
  (`/deploy?cluster=1`, as `?compose=scaled` already worked). The
  `tabs:` key is gone from `Feature.console/0`, from the catalog
  (`Features.console/1`) and from the Box screen's *Lights* row: a
  cartridge contributes doors and nothing else, which is eleven
  cartridges' worth of one contract instead of two, one of which had a
  single user. `Console.Cluster` — the two probes the console runs
  itself — is unchanged.

- **The Mix paper's Specs.** `def project` in a code box over the
  packages table, keyword by keyword and coloured as Elixir, is gone:
  the paper is the packages table. `Project.render(_, "mix")` reads
  only the dependencies' options now, and the formatting and colouring
  that served the Specs alone went with them.

### Fixed

- **The first iex of a freshly booted app came out plain.** Before a
  remsh attaches, an rpc tells the app's node to colour IEx's results,
  `IEx.configure(colors: [enabled: true])`. That call goes through
  IEx's config server, and a node booted by `mix phx.server` does not
  run it until the first remsh starts `:iex` there: the rpc exited
  with `no process`, silenced by its `>/dev/null`, and the first
  session was plain while every later one, on a node the first had
  left with `:iex` running, had colour. The rpc starts `:iex` first
  (reproduced against a bare named node: the old call exits, the new
  one leaves `colors: [enabled: true]` on it).

- **The terminal's prompt stayed where the session began.** It was
  derived from what the image or the compose declare — `/app/src` for
  the dev app, the image's workdir for a service — and a `cd` left it
  saying so. A pipe has no prompt and bash on one prints none, so where
  it stands is known only from inside: the session's bash now defines
  `cd`, `pushd` and `popd` to print where they land on a line the
  session reads and never shows (on fd 9, so `cd x >/dev/null` still
  says it; the main shell's moves only, not a subshell's or a script's),
  and says where it starts. The session keeps it in its Registry entry
  and tells the pages, and the prompt, the echoed line included, reads
  it. The functions reach the bash that reads the lines by `export -f`,
  which the `sh` wrapper (dash) would strip, so bash defines them and
  execs bash on the same PID. A service whose only shell is `sh` keeps
  the declared directory.

- **Create project submitted nothing.** The button stands outside the
  form and names it to submit it, and the form's id changed when the
  card became a component: the card took `new-project` for its own
  wrapper, so the button was naming a div. Nothing was wrong with what
  it would have run — the line under it was right all along — and
  nothing happened when it was pressed. Both ends say
  `new-project-form` now, and a test holds the button to the form's id,
  which is the one thing a rename like that breaks silently.

- **A base cartridge left out kept its switches ticked.** They went
  dim, which is right, and stayed on, which is not: the flag is not in
  the command at all, so a ticked box was saying the opposite of what
  would run. It happened because the switch was still live at the
  moment the cartridge was unticked, so the form sent it on and the
  card stored it. They read off with their cartridge now.

  Two things had to move with that, and the second only showed up on
  the way back. A switch and its hidden `off` both go quiet when the
  cartridge is out — disabled, so neither is sent — and the card merges
  what the form sends over what it remembers rather than replacing it,
  because a disabled field sends nothing and the memory is all there
  is. For the merge to be safe every switch carries an `off` of its
  own, not only those on by default: what the form does not send has to
  mean *nobody touched me*, never *off*, or a switch turned off would
  come back on. Walked through in the browser: html out, `--live`
  reads off; html back, it returns as it was, including a `--no-live`
  the reader had chosen; and `--binary-id`, which is off by default,
  still turns on and off and survives the round trip.

- **The screen was as tall as its content, and the rail ended with it.**
  The row the warning band took was added to the frame's grid without
  placing what was already in it, so the screen auto-placed into that
  row — height auto — and the fraction went to an empty row beneath:
  with little on the screen the rail stopped mid-window and read as
  cut. The three are placed now, and an absent warning takes no row
  (measured: `56px 0px 844px` in a 900px window, and `844px 0px 56px`
  with the band at the foot). The two placements tie on specificity, so
  the foot's are written in the same shape rather than left to which
  rule comes last.

- **A card's chevron did not turn.** The rule asked for a `section h2`,
  which is the rail's head; the Deploy screen's cards are an `h3`, so
  their fold had no transition and no rotation. It asks for the square
  itself now, wherever it stands — the rail's head, the Interface
  groups', a card's — and the two copies of it went.

- **A status read while a project was being born was not JSON.** A
  project has a `mix.exs` before it has a compose — the window inside
  `new`, between `phx.new` and the bake — and `compose_project_name()`
  ran `sed` over the file that is not there yet, unguarded: its
  complaint goes to stderr, which a reader captures along with the JSON
  it asked for, and the console said *not JSON:* with the message
  inside it. In the same reading `baked.dev` was printed `true`
  outright, because a project was there; it is read off the file now,
  like its two neighbours. Both are older than the flag that surfaced
  them — `wb.sh` at HEAD fails the same way on the same workspace.

- **A door's plate was pressable on its two words only.** The whole
  plate lit on hover — `.door-ref:hover` puts the ink in its border —
  and then most of it did nothing: the link inside is
  `display:contents`, so that its name and address sit in the plate's
  own flex row, which leaves it no box of its own and so no hit area
  beyond those two children. The padding, the 8px gap, the coloured
  square that says what kind of address it is, and the reading attached
  at the right edge were all dead, under a border that said otherwise.
  The link's name carries the hit area now, stretched over the plate
  (`>a>b::after`), and only the build button rises above it — the one
  thing on a plate that does something other than open it. Measured
  with `elementFromPoint` on every corner of a plate: the square, the
  corner, the border and the name all open it, the build button is
  still its own, and an unlit plate stays dead throughout. It is five
  screens' worth of one component: the rail, the Deploy sheet, a
  cartridge's box, the shelf and Docker.

- **"Ask four times" raised on every answer it was written to read.**
  The cluster's first probe asks the balancer four times and names the
  replica each request landed on, off the `x-served-by` header nginx
  adds. `Console.Cluster.served_by/1` read it as `to_string(v) |>
  Enum.join(", ")` — which is `Enum.join/2` given a binary, since
  `:httpc` hands each header value over as a charlist and `to_string/1`
  had already made it a string. It raised for every answer that carried
  the header, and for no answer that lacked one: with the balancer down
  the comprehension was empty and the line read `HTTP 200`, so the only
  run that could fail was the one the probe exists for. The join is
  over the headers now, not over a value, and `served_by/1` is public
  with four tests on it — three over the wire, against a server that
  answers as the balancer does, with the header, without it, and not at
  all. It had never been seen against a scaled deployment up
  (`console/PLAN.md`), which is exactly how it survived. Both probes
  were run against one on 2026-09-26, four replicas behind the
  balancer: the four requests landed on four different replicas
  (`172.25.0.3` through `.6`), and `Node.list()` on the first answered
  with the other three.

- **Ash's TypeScript RPC routes come out with their paths.** `_004`'s
  prod compile warned that `post "", AshTypescriptRpcController,
  :validate` could never match: ash_typescript's installer had written
  both RPC routes as `post ""`. It reads `:run_endpoint` and
  `:validate_endpoint` off the application env, values it writes to
  `config.exs` in the same pass, so unloaded, so `nil`; the generated
  client's POSTs to `/rpc/run` and `/rpc/validate` had no route.
  Upstream knows: ash-project/ash_typescript#95, open since
  2026-09-15, the fix agreed and unwritten, 0.18.3 (2026-09-25) still
  has it. ash 0.8.0 writes the two entries, the installer's own
  defaults through its own `configure_new`, in its patch set, ahead
  of the queued command: that command is a mix process of its own,
  loads `config.exs` at boot, and the installer finds them. **A
  workaround, marked so in the code, the test and the papers, to
  remove when #95 closes and hex resolves the fixed release.** `_004`'s
  router was corrected by hand.

- **`up -e prod` with Ash's TypeScript: the release image builds
  again.** `_004`'s `migrate` service stopped at `RUN mix assets.setup`
  with `:enoent` on `npm`. ash_typescript's installer hooks `npm
  install` into `assets.setup`, and Phoenix's production `Dockerfile`
  runs that step on a builder with no node, before `COPY assets` (on
  purpose: in a phx.new project it only downloads the esbuild and
  tailwind binaries, so the layer caches ahead of the code). The dev
  image and the workbench's carry node and npm; the release's
  Dockerfile is Phoenix's own and took nothing. ash 0.7.1 patches it
  with `--api typescript`: `nodejs npm` in the builder's `apt-get
  install`, and `COPY assets/package*.json assets/` before `RUN mix
  assets.setup`, so the npm layer caches on the manifests alone
  (`WorkbenchIgniter.Dockerfile.npm/1`, the file's owning module). A
  Dockerfile that is not Phoenix's is left alone with a notice. A
  project that already carries the insert needs the two lines by hand.

- **An Ash insert whose installers failed is no longer committed as
  done.** `add ash` on the workspace `Lorem Ipsum 2` said the insert
  landed, and its commit held only `mix.exs`, `mix.lock` and
  `.env.sample`. ash queues `mix igniter.install`, and when one of the
  installers it runs reports an issue, Igniter prints the issues,
  writes none of their files and exits with zero:
  `Igniter.Util.Install.install/2` drops the `:issues` it gets back.
  The packages were already in `mix.exs` by then. `add` read the zero
  as success. `WorkbenchIgniter.Task` already fails the workbench's own
  tasks on issues; the queued command was Igniter's and got around it.
  ash now queues `mix workbench.igniter_install` with the same argv. It
  runs `igniter.install` under a shell that passes everything through
  and notes Igniter's `Issues:` list, then exits with 1, so `add`
  undoes the insert and makes no commit. Tried on a phx.new probe: exit
  1 with the issue, exit 0 for `ash ash_phoenix`.

- **`add ash --components mishka_chelekom` finishes from the
  console.** It died with `exited in: GenServer.call({:via, Registry,
  {Owl.WidgetsRegistry, :my_spinner}}, {:stop, …}, 5000) … time out`.
  The console runs `wb.sh` on a pipe with `WB_ANSI=always`, which
  turns on Elixir's `ansi_enabled` for colour. mishka's installer
  starts an Owl spinner whenever `IO.ANSI.enabled?()` is true. Owl
  starts its `LiveScreen` only when `:io.columns()` answers, which a
  pipe does not, and the spinner's stop waits for a render from that
  missing process until the call times out. Turning ANSI off would
  have taken the colours from the whole Ash install, since every
  installer runs in the one `igniter.install` process.
  `workbench.igniter_install` instead starts a `LiveScreen` of its own
  when ANSI is on and there is no terminal, on a device that reports
  80×24 and discards what it gets. The spinner draws nowhere, and
  everything else prints as before, in colour. Reproduced with Owl
  0.13.1 alone, then tried on the phx.new probe: `mishka_chelekom`
  with ANSI forced over a pipe installs and exits 0.

- **`add ash --api typescript` says why it cannot go in, before
  anything is fetched.** The issue in that insert was ash_typescript's
  (0.18): *Required lib/lorem_ipsum2_web/components/layouts/root.html.heex
  but it did not exist*. Its installer finds the web layer at `lib/` +
  the underscored web module, and phx.new puts it at `lib/<app>_web`.
  The two part when the app has a digit after an underscore:
  `:lorem_ipsum_2` is `LoremIpsum2Web`, which underscores back to
  `lorem_ipsum2_web`. The cartridge compares the two and refuses the
  value with the paths in the message. The console does not yet show
  the value unlit on such a project: the refusal comes when the insert
  runs.

- **A footnote's mark no longer lifts the drawer off its frame.**
  Clicking a mark in a Packages table (`¹`, a jump to
  `#box-pkgs-note-1`) scrolled every container between it and the page,
  the drawer too: it had `overflow:hidden`, which clips but is still a
  scroll container, so it rode up 160px, left a gap at its foot and had
  no scrollbar to come back with. The frames that must never scroll —
  the drawer, its Interface pane, the screen and the full-height panels
  — clip with `overflow:clip` now, which is no scroll container: the
  jump moves only the pane that scrolls, in the drawer and on the
  Project tab.

- **A box's Packages table says where each unlisted package came from,
  in the box's own words.** A box that declares no package has its
  packages read off its insert commit, and the table marked them with
  `*`. The line under it always said they came with phx.new. That is
  true of a base cartridge. It is false of ash: ash queues `mix
  igniter.install`, and a package's installer can add more
  (`bcrypt_elixir` from ash_authentication's password strategy,
  `picosat_elixir` from Ash's policy authorizer when the user resource
  takes it). Only the cartridge knows what it ran, so a
  cartridge now says it: `origins/2` takes the options the insert went
  in with, as its commit subject carries them, and what the commit
  added, and returns one note per origin with the packages it covers.
  The default is the base cartridges' (the `phx.new` delta, at the
  version stamped at that commit). Ash gives two: *its options name
  it in the `mix igniter.install` it runs* (the command, not its argv:
  the row and the insert's line say the rest), and *added at the request of
  the installer of a package that command named* (its own `add_dep`,
  its `installs`, or a hook of Ash's its `ash.extend` sets off; the ash
  DESIGN §2.6 has the table). A package no note covers gets a plain
  sentence, so no row goes without one. `Feature.origins/3` parses the
  argv against the installer's schema and is what `Console.Diffs`
  asks, per insert. The marks are superscript numbers now, one per
  note, numbered in the order the rows first carry them, and each note
  is said once under the table with its command set as code. Each mark
  is a link to its note, and the note it lands on takes the ink. `*`,
  `**`, `***` stop reading well past two, and `[1]` beside a version
  reads like its syntax.

- **The console reads the project again after an insert that brings
  dependencies.** After `html --live` on a fresh project, the aside
  said `the project could not be read: exit: {:shutdown, 1}`, and kept
  saying it. The resident, the BEAM that answers `status` and `expand`,
  had loaded the dependencies the project booted with. The insert
  added `phoenix_live_view` and its compiler to `mix.exs`, and every
  recompile before an answer failed on what that BEAM never loaded.
  Only a change of workspace restarted it. Now it keeps a stamp of
  `mix.exs` and `mix.lock` and starts again when either changed,
  whether an insert, an eject or a hand edit changed them. The
  questions it held, the one in flight included, go to the new one.
  A box that brings no dependency keeps the warm resident.
- **One code box, one indent.** The daemon's Specs stood 31px in and
  the Mix paper's 18px: `.ln` is also the log's line, and brought the
  log's padding into every `.code-box` but the Mix paper, which had
  taken it out for itself. The shared rule now takes it out, and holds
  the key column as a grid for both, so a value that wraps stays under
  its value. Each screen only says how wide its keys are (`--key-w`:
  13ch for the daemon, 17ch for `def project`).

- **The resident no longer compiles what it then fails to see.** The
  console's resident ran `mix do deps.get, deps.compile,
  workbench.serve` in one BEAM. After a stack change, when that run
  had to rebuild the dependencies, Elixir 1.18 answered `module
  Igniter is not available` with every `.beam` on disk, and the
  resident answered that to every question until it was restarted:
  `pitchers` "could not be read". The dependencies are now compiled by
  a Mix of their own, with its stdin closed, before `exec mix
  workbench.serve`. That costs one Mix boot more, once per resident.

## v0.12.0 - (2026-09-23)

### Added

- **The project's Mix paper.** Project gains a paper between Changes
  and .env: `mix.exs` read as what it is (`MixFile`, the module that
  owns the file). On top, **Specs**: every keyword of `def project` in
  a code box, the key dim and the value coloured as Elixir, laid out
  the way `mix format` writes it. Under it, **Packages**: every
  dependency the project carries, in the Box's own table — now one
  component, `ConsoleWeb.Packages`, that both draw. Here it carries
  each package's options as `mix.exs` writes them, one to a line; the
  version its cartridge asks for, with mix.exs marked where the project
  pins another; and last, who brought it — the cartridge, read off what
  a box declares or off a base box's insert commit, or where it came
  from when none did: born with the project, or by hand. Who brought
  it is read off git apart from the page, and the paper reads again on
  every status, so an insert shows without leaving it.

- **GitHub is asked what hex is asked.** The table's one button asked
  hex.pm for the latest release, its day and the downloads, and left a
  package from git unlit. It asks GitHub now for the ones that come
  from a repository there (`Console.GitHub`): the latest release, or
  the newest tag, dated by its commit, for a repository that publishes
  none — heroicons is one. Downloads stay unlit with the reason: GitHub
  counts none of a repository. Without a token GitHub allows sixty
  requests an hour, and a row whose allowance ran out says until when.

- **A box says what it puts in the project's `mix.exs`, and the box
  shows it.** The packages a cartridge installs lived in eighteen
  `add_dep` calls scattered through the installers, plus a table in the
  features index kept by hand — which had already drifted. A box
  declares them now, `deps/1`, with the shape `services/1` has: given
  the project's state it answers what that project carries of it
  (test_doubles' `--double mimic` is one package, `mimic,mox` two),
  given `:any` every package it may ever bring. The suite reads each
  installer's own source and holds the two together, so a package added
  and not declared fails the build.

  The console's **Box** screen gains a third panel under Specs,
  **Packages** — where the box already says what it opens and what
  containers it raises, since a package it puts in `mix.exs` is the
  same kind of fact, and the Installation screen stays about the act of
  installing. It is named for what it lists and not for the callback
  that answers it: Specs already says *brings*, of the containers, and
  two panels on one screen cannot wear the same word. Each package's
  name opens its page on hex.pm and the version the lock resolved opens
  that version's documentation, which costs no reading at all: they are
  addresses, not answers.
  Before the box is in, the panel is what an insert *would* add, read off the
  manifest — the answer to "what does this cost me" without inserting
  anything. Once it is in, it is what the project does with it: what
  the box brings, what `mix.exs` pins today and what `mix.lock`
  resolved, the last two read off the project by `mix workbench.status`
  where it already runs. A pin that is not the box's wears the house's
  warn and says why — *an insert older than the box* — which is exactly
  the drift that left exdoc pinned to `~> 0.38` while its papers quoted
  0.40.4. Nothing here reaches the network: what hex.pm says of a
  package (its latest release, how long since, how many downloads) is a
  reading of the ecosystem and not of the project, and it belongs to
  the console at read time, never to an installer — the shelf archived
  a box for reaching the network at insert time.

  That reading is here too, on a press. Beside each package the section
  now has what hex.pm says of it: the latest stable release, **how long
  since it was published** — the fact that says whether a dependency is
  alive — and how much it is downloaded, with the release that is the
  version the project runs marked so nobody compares two versions by
  eye. It is `Console.Hex` over `:httpc`, the client the console
  already uses for the same host — the call being a function `read/2`
  takes, so the suite holds what is read out of hex's own answer,
  captured from its package endpoint, without a test ever calling
  hex.pm: a test that reached the network would fail when a train goes
  into a tunnel, and would tell somebody else's service how often this
  suite runs. The double earned its place on its first run, catching a
  `Jason.DecodeError` struct going into the reader's message where a
  sentence belongs. The readings are held in `Console.Bench` by package
  name under the rule the stacks and the installers follow: no clock,
  nothing at mount, only a reader pressing, and a package another box
  already brought answered from memory. Unasked the column is unlit;
  when hex does not answer it says *not read* with the reason. Checked
  against hex itself: `ex_doc` 0.40.4 19 days ago, `excoveralls` 0.18.5
  a year ago, and a package nobody publishes carrying its 404.

  The panel is a **table with a header**, not a line of prose per
  package: every column is a fact read off a different place — the box,
  `mix.exs`, `mix.lock`, hex.pm — and a reader who wants to know
  whether anything here is stale compares down a column, which prose
  does not let them do. What was a tooltip is a cell. Each name wears
  **hex's own mark**, as its owners drew it, so the link says where it
  goes before it is read: vendored at
  `console/priv/static/images/vendor/hex.svg` with its provenance
  beside it, never hot-linked, because hex serves that asset under a
  content-hashed URL that will stop resolving. The press that costs the
  internet is the same **reload square** the configuration's Docker and
  phx_new fields already use — one gesture for "go ask", wherever the
  console asks. In a narrow drawer the table keeps its names whole and
  scrolls sideways inside the panel, instead of breaking `ex_doc` into
  `ex_do/c` and pushing the versions one under the other. The columns
  are the same whether the box is in or not: what the box asks for and
  what the project pins are two different readings and never share a
  cell, so **mix.exs** and **locked** stand unlit with their reason —
  *the box is not in: nothing pins it yet* — instead of leaving the
  table for a reader to compare against one they saw a moment ago. The
  two version cells carry a class of their own, `asks`: the sheet's
  `.req` is a flex row, and a `display:flex` on a `<td>` takes it out
  of the table's columns — which is what put the pin under the box's
  requirement in the same column and left *downloads* empty, every
  value one place to the left of its header. Each header is **where its
  reading comes from** — `cartridge`, `mix.exs`, `locked`, `latest` —
  because four version columns beside each other are four different
  questions, and a column named after the callback that answers it
  says nothing to the reader. A version is all a cell carries: the
  tuple's own options (`only: [:dev, :test], runtime: false`) are
  noise in a table of versions, and the panel wears no legend either.
  The newest release says itself against the one the project runs
  (*hex.pm's newest release — and the one this project runs*, or
  *…; this project runs 0.38.2*), where before the
  cell claimed to be the version installed and left the reader to
  guess what the other three were.

- **A form asks only for what a second insert can still put in
  (`adds/0`).** The box in hand offered every option of a cartridge
  that was already inserted, and *Add to cartridge* with it: the reader
  set coverage's minimum, pressed, and the job came back saying
  `coveralls.json` already exists and nothing was done. The shell has
  always known better — the installer's guard refuses on arrival — and
  an interface that offers what the tool refuses is lying to the hand
  that presses.

  `rerun: :adds` was too coarse to fix it: coverage does add on a
  second run, but only the `mix cover` task and the hook block; the
  theme, the minimum, the ignored files and the column width were
  fixed when it went in. So the box says which, in a word of its own:
  **`adds/0`** — `:none`, `:all`, or the option keys a second insert
  still adds — and `rerun/0` is derived from it, so the two can never
  disagree. The suite holds it against each box's own schema: a key
  that is no option of it would lock a field nobody can see, and a box
  with no options at all can only answer `:none` or `:all`.

  The form follows: locked whole, with no verb to press, where nothing
  can be added (which is what the reader asked for); open on the named
  pieces alone and locked on the rest, with the line saying *what it
  went in with is fixed; `--md-report` && `--githook` are the pieces it
  still adds*; and open as before for a collection, for ash and for a
  box with no options, where inserting again inserts what is missing.
  The eleven that answer something other than `:none`: ash, changelog,
  chiefs_setup, coverage, credo, dashboard_extras, db_admin, html,
  precommit, test_data, test_doubles.

- **What `mix.exs` pins, read off `mix.exs`.** The Packages panel said
  *the project pins nothing* of a package the project plainly pins:
  excoveralls, inserted after the console's resident
  (`mix workbench.serve`) had started. The pins were read from
  `Mix.Project.config()`, which is the project as it was when Mix
  pushed it — in a process that answers for hours, that is the project
  of hours ago, and everything inserted since reads as pinned by
  nobody. They are read off the file now, through the module that owns
  it (`WorkbenchIgniter.MixFile.requirements/1`), as the lock already
  was. The lock's own reading learns the same lesson from the other
  side: a package from git is locked to a commit, not to a version, so
  `heroicons`' sha no longer poses as one — nor as a hexdocs page that
  does not exist.

- **A base cartridge's packages, read off its own insert commit.** The
  seven base boxes declare no package and cannot: what `mailer` or
  `ecto` brings arrives inside the `phx.new` delta, at whatever version
  that installer writes, so a list kept in the manifest would be a
  second opinion drifting one Phoenix release at a time. The insert
  wrote those lines into `mix.exs` in a commit of its own, and that is
  where they are read — `Console.Diffs.packages_of/2`, the additions of
  the commit's `mix.exs` minus the names its own removals carry, which
  is the comma the insert put after the dep that used to be last. What
  the project does with them is the same two readings every other box
  gets: `mix workbench.status` now reports the project's whole
  dependency list, `mix.exs`'s pin and `mix.lock`'s resolution, and the
  panel matches the commit's names against it — so a package the
  project no longer carries is not claimed. The cartridge column wears
  a `*` and says it was read off the insert, never declared.

  It follows from where the packages are: **a base box in because it
  was born with the flag has no insert commit, and so nothing to
  read**. The panel says exactly that — *born with the project: no
  insert commit to read them off* — rather than standing empty, which
  the reader would take for "this box costs nothing". Checked against
  the workspace: gettext, tailwind (with `heroicons` and `daisyui`,
  which are git deps and carry no requirement), esbuild, html, mailer,
  ecto and dashboard each answer their own packages, and none answers
  another's.

- **A dependency is named one way, everywhere: `.pkg-ref`.** The
  packages table drew its own link — hex's mark, the name, the address
  — and a mention of a package anywhere else drew whatever the page
  felt like: the Phoenix installer's help line ended in a bare URL, the
  Birth paper wrote `phx.new 1.8.14` as text. A dependency is a thing
  of the world the reader can go and read about, exactly as a cartridge
  is a drawer they can open, so it gets the house's notation beside
  `.cart-ref` and `.door-ref`: the mark, the name in mono, the page on
  hex.pm — or, given a version, that version's documentation on
  hexdocs. The mark is what says it is a link, dimmed until it is
  hovered so a column of them does not shout, and it goes bare where
  the line already wears one. It lives where the notation lives
  (`assets/design/build.py` → `components.css`, both projections) and
  is `ConsoleWeb.Refs.pkg_ref/1` in the console, so a page that names a
  package cannot name it a second way. In: the Packages panel, the
  `PHX_NEW_VERSION` field's help, and the Birth paper's installer.

- **coverage v0.7.0: `--file-column-width`, defaulting to 80.** How
  wide the file column of ExCoveralls' terminal table is. It looks
  cosmetic and is not: a path longer than the column is cut, and with
  `--exdoc` the `mix cover` task reads that table to build the report's
  own, so a cut path is a file the report loses. The box wrote 128
  always — never cutting, at the price of a wide terminal in every
  project. 80 holds a stock project's longest paths
  (`lib/<app>_web/components/core_components.ex` is in the fifties) and
  a project whose modules sit deeper raises it. A whole number from 40
  to 999 is its declared shape, refused before the file is written;
  below 40 there is nothing to gain over ExCoveralls' own default.
- **coverage v0.6.0: `--ignore-files`, what the report leaves out.**
  The box asked the wrong question: `--interface rest|graphql` decided
  one entry of `skip_files` — an API specification's folder — which
  made a coverage box reason about an API it does not install, and left
  the reader nothing to say about the rest of the report. The option is
  what is left out now, comma-separated, each value a **group** the box
  knows or a path of your own: `boilerplate` (the wiring `phx.new`
  writes and no test asserts: the application, `<app>_web.ex`, the
  endpoint, the router, telemetry, gettext, the repo, the mailer, the
  release, the socket), `components`, `mix_tasks`, `open_api`, or
  `lib/my_app/legacy` — an entry is a regex excoveralls matches against
  each file's path, so a path of the reader's own is as good as a
  group's. Default `boilerplate,components`; `none` counts every file
  the project compiles; `deps` and `test` go always, as before. The
  groups come from reading what Elixir projects skip in the wild, which
  the box's DESIGN now cites, and two of them it refuses to invent:
  `priv/repo/migrations` is compiled before `cover` starts, so it is
  never in the report, and `test/support` is already under the blanket
  `test`. **Only the paths the project has are written** — a project
  with no socket gets no line for one — so `coveralls.json` reads as
  the project it belongs to and `state/1` says the groups back.

- **An option's shape is a fact of the box, checked in one place.** A
  value's *type* was all the workbench knew — a switch, a list, a
  string — so a URL, a version and a percentage were all «text»: the
  form asked for them with the same field, and each cartridge checked
  its own, or did not (exdoc wrote whatever was given as its
  `source_url`). A cartridge now declares `formats/0` — `:url`,
  `:version`, `:dns_name`, `:route`, `{:integer, range}` — and the
  shape is read twice. The installer refuses a value that does not hold
  it before anything is written, in one place and one sentence for
  every box (`--repo-url takes a URL (https://example.com/page), and
  "github.com/acme/app" is not one.`): every `task.ex` now calls
  `WorkbenchIgniter.Feature.install/2`, the shell where a cross-cutting
  check belongs, so a cartridge's own installer stays what it writes.
  And the catalog carries it, so the console's field is a URL field, a
  number takes a numeric keyboard, and the line under the flag says
  `url` or `integer 0..100` where it used to say `text`. An empty field
  is not checked: empty is unasked, and what unasked means is the
  cartridge's own. coverage's and clustering's hand-written refusals of
  this morning are gone, replaced by the shape they were checking.

- **dbschema: the database's page is a box of its own** (*archived*,
  v0.1.0). What a project showed of its database was split across two
  boxes that had no business with it: exdoc planted and listed
  `guides/database.md` for any project with Ecto, and the archived
  enhancements planted the `mix db` task, its test and the DbSchema
  export. One box owns it now — the task that turns a
  [DbSchema](https://dbschema.com) export into an ExDoc page, the
  sample export to start from (`--combo`, the shapes the Phoenix line's
  boxes gave that database) and the page with its model diagram. It
  builds on ecto, not on exdoc: the page is written either way, and
  listed in the site only when the project has one, the way changelog
  lists its own — so exdoc knows nothing about databases and
  enhancements composes this box when the project has one, which leaves
  what it installed unchanged. Archived on arrival: DbSchema is a
  desktop tool outside the workbench and this only dresses its export,
  and the reference project is on Ash, whose diagrams come from Ash.
  The page now names two images with GitHub's own URL fragments, so
  each theme hides the other's.

- **A default read off the project is shown as its value.** Five
  options have no fixed default: the installer reads it off the project
  — changelog's `--init-version` (the version `mix.exs` has),
  clustering's `--dns-query` (`<app>.default.svc.cluster.local`),
  exdoc's `--project-name`, `--repo-url` and `--module-groups`. The form
  said *read off the project* where the value should be. A cartridge now
  says how each is found, `detect/1` beside `detected/0`: the value the
  option takes on this project, `nil` where the project says nothing.
  The installer takes its defaults from it, `mix workbench.status`
  carries it per cartridge as `detected`, and the console puts it in the
  field as the placeholder with a *read off the project* tag (a choice
  wears the *default* tag), so the default a reader sees is the one the
  insert writes. Where nothing is read — exdoc's repository with no
  `source_url` and no git origin — the field still says where it would
  come from. The catalog test holds every cartridge to exactly its
  `detected/0` keys, none of them with a fixed default.

- **The knock bell is lit for the pages on disk too.** A page a tool
  writes (exdoc's `doc/`) is served by the console, not by the app, so
  it answers with the app down. Services & Doors and the shelf's
  Inserted table used to grey out the bell with "nothing is up" all the
  same. Now it is lit while the app is up or any green page is there
  (`Record.knockable?/2`). A knock with the app down calls no route. It
  still renders the pages again, and each is read off the disk as it
  renders, so a build made outside the console shows up. The pages are
  never called over HTTP: the file is the truth.

- **The console's jobs remember their workspace, and a delete takes
  them along.** Each job records the workspace `config.conf` named when
  it was started. When a `delete` succeeds, `Console.Jobs` drops the
  finished jobs of that workspace, output included. It cancels any that
  were still waiting, since their project is gone. The delete job
  itself stays: it shows the project was deleted and anything left
  behind. A failed delete drops nothing, because those jobs explain the
  failure. "Clear done" still only clears the current page's view.

- **exdoc v0.3.0: `--readme`**, on by default. `--no-readme` leaves the
  project's README out of the extras and the Project group and drops
  `main: "readme"`, so the site opens on ExDoc's API reference instead.
- **Two boxes that build on ecto now say so.** Adminer's value in
  db_admin v0.2.0 carries `ecto` as a requirement: it serves any
  database, but only when there is one. test_data v0.1.1 declares
  `requires: ["ecto"]`. Before, its installer refused a project without
  ecto_sql, but the catalog didn't know, so the console showed the box
  as available there. db_admin v0.2.0 also drops the default for
  `--admin`. It used to pick the database's own admin, and now
  running it without `--admin` is refused with the four names.
  chiefs_setup's recipe names `--admin pgadmin`.

- **exdoc v0.2.0: the project serves nothing.** The `ExDocController`
  and its test, the `:exdoc` pipeline and the `/dev/docs` routes are no
  longer planted — `mix docs` writes `doc/` and the console serves it —
  and with them go the dummy pages under `doc/`, `--version` (it only
  stamped them) and `--auth0` (the token page needs the app's origin,
  and auth0 is archived). The mark is the site's config, which every
  edition planted, so a project carrying v0.1.0 reads as exdoc still.
  The cartridge has its `DESIGN.md`, with ExDoc quoted from its source.
  coverage v0.4.0 goes with it: the report and the Test Suite Report
  link each other by relative paths (exdoc copies the report into the
  site's root), which hold under the console and under an old
  project's `/dev/docs` alike. Verified in a probe project, the three
  pages opening each other through the console's listener. Two more
  exdoc changes ride along: **`--app-logo`**, off by default (the
  placeholder was 1.9 MB with somebody else's name, committed always),
  and **the changelog listed only when the project keeps one** — listed
  always, `mix docs` stopped on a project without it. changelog v0.5.0
  covers the other order: opening the file, it lists it in a docs block
  that is already there, through `Exdoc.list_page/4`, which guidelines
  uses too. And **`--module-groups`**: `layers`, `ash`, `contexts`
  (a group per directory under `lib/<app>/`, read when the docs are
  built, for the large project) or `none`, read off the project when not
  given. The presets tell a live view or an Ash change by the behaviour
  it declares, through the functions ExDoc accepts as group patterns;
  checked with `mix docs` on the probe and on tunez. **`--homepage-url`**
  is the website the sidebar's name and logo link to: v0.1.0 wrote the
  repository there, and the logo opened GitHub. The site's name, unasked,
  is the `name:` mix.exs has or the app's name in words (`lorem_ipsum`
  as *Lorem Ipsum*, not *Lorem_ipsum*), and its repository the
  `source_url:` it has or the `origin` of the project's own git
  repository — never the workbench's, which a workspace without a `.git`
  of its own would otherwise answer with — the placeholder only when
  neither says it, and then commented out, so the site's source links
  are absent rather than broken.
- **The docs' sources leave `assets/`.** exdoc's config, theme script
  and logo, guidelines' page and enhancements' database page and
  diagrams move from `assets/exdoc/` to `guides/`, layout unchanged:
  `assets/` is a Phoenix application's release build input — the
  Dockerfile copies it, tailwind scans it — and these are a dev tool's
  files. exdoc still recognises a project that has them in the old
  place. coverage's report templates follow them out, to
  `test/coverage/template/`: `test/` is outside the Dockerfile's context
  by phx.gen.release's own `.dockerignore`, and nothing compiles a
  loose `.eex` there.
- **A default is a field's placeholder, never its value.** The
  installation form filled each text field with the option's default,
  so changing it meant deleting it first, and a default could not be
  told from a value typed. The field starts empty and shows the
  default in grey; empty is the default (the flag is left out of the
  line). An option whose default the installer reads off the project
  (`detected/0` in the manifest, `detected` in the catalog) says *read
  off the project* instead.

- **The console serves the project's pages: a door of a third kind,
  green.** ExDoc's site and the coverage report were served by the
  project — a pipeline, a controller and `/dev/docs` routes exdoc
  planted in its router, only in dev, only with the app up: the
  workbench's reading carried by the project. Now a cartridge declares
  what its tool writes on disk, `{label, {:output, dir, index}}` —
  exdoc `doc/`, coveralls `cover/` — and the console serves it off the
  workspace (`ConsoleWeb.Reports`) on a listener of its own, the port
  beside the console's, which `wb.sh console` publishes on `127.0.0.1`.
  Another port is another origin: the project's JavaScript never runs
  where the page that runs `wb.sh --yes` lives, and ExDoc keeps a real
  origin — search, `localStorage`, the theme work as on HexDocs.
  Read-only, loopback names only, and only the dirs the inserted
  cartridges declare: `.env` is in the workspace too. The door is
  green (`addr-output`, the terminal's moss beside `good`'s sea green,
  a layer and not a verdict), written as the dir it is read from, its
  reading when it was built; it answers with the app down and is never
  knocked. The rail, the Record and the box read it through one
  function now — the box had a copy of its own that painted every door
  violet. What stays open (moved outputs, building from the door, the
  two boxes dropping their routes) is in `console/PLAN.md`.

- **exmachina becomes test_data: the records a test needs, on either
  line.** The old box added `ex_machina` to the deps and stopped there.
  There was no factory module to import, nothing in the test helper,
  and no word about the trap everyone meets: ExMachina writes with
  `Repo.insert!` and never runs the schema's changeset. The box is now
  named for the need, beside `test_doubles` (that one replaces a
  collaborator, this one builds the data), and it reads the project's
  line. On Ecto it installs ExMachina with **Faker**. It writes
  `test/support/factory.ex` with no factories but four rules in its
  documentation: defaults minimal and valid, unique columns by
  `sequence/2` and never Faker, associations by `build`, and Faker only
  for what nobody asserts. It adds a test that finds every
  `*_factory/0` and inserts it inside the sandbox, so a factory the
  database refuses fails by its own name. On **Ash**, where ExMachina
  would bypass the actions, validations and policies, it writes an
  `Ash.Generator` module whose generators run the action, with Faker
  inside `StreamData.repeatedly/1` the way Ash's own docs use it. Both
  libraries' helper lines go in the cartridge's block of
  `test_helper.exs`. A project with neither Ecto nor Ash is refused,
  and a project that took the old box gets the rest on a second run.
  DESIGN.md grounds each decision in the libraries' own papers, the
  patterns (Object Mother, Test Data Builder, Meszaros' smells and
  *Generated Value*) and the sandbox's lock. Verified in two `phx.new`
  probes. On Ecto, a factory that broke a foreign key failed by its
  name and the rest inserted. On Ash, a generator went through a
  validating action. On both, Faker's values repeated under `mix test
  --seed`.

- **githooks becomes precommit: the box that owns the hook, not the box
  that installs a dependency.** The shelf's plan had this box absorbed
  into credo and coveralls, an option each. The absorption would have
  left the checks that come with **Elixir** with no owner at all — the
  formatter, the compiler's warnings, the suite, the lock file with
  something stale in it: no cartridge installs them, and they are what
  a pre-commit hook is for. So the box stays, named for the moment it
  acts on rather than for the package it installs, and grows into the
  three things this environment actually needs. Its own `--checks`
  installs those Elixir checks (`format` by default, then
  `unused_deps`, `compile`, `test`); a second run adds what it is
  given.

  The first is **the crossing**. `git commit` runs on the host, and the
  host of a workbench project carries Docker and nothing else, so a
  hook calling `mix` there calls nothing: `.githooks/mix` is `docker
  compose exec app mix` on the running container, `run --rm` when the
  workspace is down — the workbench's own two paths, in the ambient
  Docker context — and it goes through the project's own compose file,
  never through `wb.sh`, because the project owes the workbench
  nothing. `project_path: "."` is the other half of the same problem:
  `git_hooks` writes `File.cwd!()` into the shim it installs and
  installs it from inside the container, where that is `/app/src`, a
  path the host cannot enter. A dot is true on both sides of the mount.

  The second is **the file**. The checks live in
  `.githooks/pre-commit`, a shell script with `set -e` where every
  cartridge owns a delimited block (`WorkbenchIgniter.BlockFile`,
  written last week for exactly this and for the test helper), and
  `config/dev.exs` carries one hook whose one task is that file — so no
  cartridge ever edits somebody else's nested keyword list to add a
  line. `Precommit.check/4` is the way in, `forget/2` what an eject
  owes, `checks_of/2` what a cartridge's own `state/1` reads. A new
  block is born at the stage its caller asks for, either side of the
  comment line dividing the cheap checks from the ones that compile the
  project or run the suite, and a block already there is replaced where
  it stands: a project that moved it meant to. `sh
  .githooks/pre-commit` runs the lot without committing.

  The crossing is also the box's one figure, in the DESIGN (`assets/diagrams/precommit/the-crossing.svg`):
  a sequence over the two grounds, with the commit's status walking back
  to abort it, and an `else` region holding what the same commit does
  configured the way the library's README shows it — the arrow stops on
  the host, which is the comparison the prose was carrying in two
  paragraphs.

  Verified end to end in a scratch project, not only in the suite: the
  shim installed from inside the container with `cd_path="."`, a `git
  commit` **on the host** refused by the formatter running in the
  container, and the same commit passing once the file was formatted.
  Two things only a real run could show, both recorded in the box's
  DESIGN: `--check` is one of Igniter's own global switches, so the
  option is `--checks`; and the version hex resolves for `~> 0.7` is
  0.9.0, which already resolves the working tree at run time —
  `project_path` is written all the same, for a project that resolved
  an older one.

  The third is what the box refuses to be. A hook runs for the person
  who installed it and `--no-verify` skips it; the wider names the
  author weighed — a "definition of done", a pull-request gate — would
  promise a team something only CI can keep, which is the `ci`
  cartridge still to come. The NEED says so in its *Not for*.

- **credo and coveralls run before the commit, each in its own block.**
  `credo --githook` (cartridge v0.1.0) puts `mix credo` in the hook —
  not `--strict`, because a hook that refuses the developer's first
  commit is a hook they turn off within the hour, and `--strict` is one
  word away in a file the project owns. `coveralls --githook`
  (v0.3.0) puts `mix coveralls` there, off by default and saying why:
  the suite plus its instrumentation is the slowest thing a commit can
  wait for. Each composes the precommit cartridge and takes a block of
  its file, so the two stand in one hook, in order, and ejecting either
  leaves the other's checks standing. credo gets the two papers the
  anatomy owes a cartridge on its next change, and with them its first
  option, its `state/1`, and a `DESIGN.md` that says why Dialyzer,
  `mix format` and Sobelow are not it.

  The two blocks land on **opposite sides of the hook's divider**, and
  that is the option's whole argument made concrete: credo's is born
  `:fast`, because Credo reads the source and never compiles the
  project, and coveralls' `:slow`, after every check that can refuse a
  commit in a second. A commit Credo is going to reject is rejected
  before anything compiles.

  And **coveralls' insert learns to be run twice.** It was a no-op once
  `coveralls.json` existed, which turned `--githook` on a project that
  already had coveralls into a silent nothing: the flag was asked for,
  the notice said *skipping*, and no hook appeared. The json, the
  themes and the report stay fixed at the insert — they are the
  project's to edit afterwards, and a second run must not undo an edit
  — but the hook block is a piece the installer adds when it is
  missing, so the block is written and the notice now says which of the
  two happened. coveralls gets its `DESIGN.md` with the rest: why a
  dependency at all when `mix test --cover` is built into Elixir (a
  terminal summary is not a page a reviewer opens), why the minimum is
  80 and not Mix's 90 or ExCoveralls' 0, why the report is planted as a
  template the project owns in one of two themes, and why a column
  width of 128 in `coveralls.json` is load-bearing.

- **exdebug's box, at v0.1.0: the probe a pipeline can keep.** The
  cartridge still installs one dependency and writes nothing — `as it
  is`, the script's crossing said — and now says what that buys. The
  library's whole point is *where a call may stay*: `IO.inspect/2` and
  `dbg/1` print in every environment, so they are written, read and
  deleted, while `ExDebug.console/2` prints a framed, labelled,
  timestamped look at one point of a pipeline in `:dev` and `:test`
  only and hands the value on untouched everywhere else. Two facts
  follow, and both are now written down instead of being folklore: the
  dependency carries no `only: [:dev, :test]` **on purpose**, because
  the guard is inside the function and a call left in a pipeline has to
  compile in `:prod`; and the silence rests on a *runtime* read of
  `MIX_ENV`, which the runner stage of the Dockerfile `phx.gen.release`
  writes sets to `prod` — so the no-op holds where the workbench's
  releases actually run, and a release started by hand without that
  variable takes the print path and raises on a `Mix` it does not
  carry. Verified in a probe project, in all four places (dev, prod,
  the release with the variable and without it), and quoted in the
  paper. No `config :ex_debug` block is written: every key it holds
  already defaults inside the library and is accepted per call, so a
  generated block would be a file to maintain that says what the
  library says. The paper also states plainly whose library it is — the
  workbench author's own, one release, 171 lines read in full for it —
  and names the alternative that needs no box, `dbg/1`.

  The box's **back was re-set** from those papers, on the same plate:
  its copy still sold the cartridge as `PART OF --enhance`, a world
  retired with `setup`. Four features in place of the old four, the
  flash carrying what the cartridge was verified on, and — because
  `covers.py back` reads the version off the cartridge's changelog and
  there was none until now — the line `cartridge v0.1.0 · 2026-09-20`
  under the legal strip, the first thing this box says about its own
  version.

- **A fourth state for a box: `archived`, the retired that stay for the
  reading.** A cartridge that is no longer a pick for a new project was
  until now only deletable, and deleting it sent the reasoning that
  made it — its NEED, its README, its CHANGELOG, the choices its
  DESIGN argued — to the git history, where nobody reads it. Archiving
  keeps the whole box where it is and changes one thing: what the
  workbench offers. `archived/0` is the new manifest answer, one line
  opening with the date (`nil` while a cartridge is current), and
  `use WorkbenchIgniter.Feature` derives `archived?/0` from it so the
  fact and its reason cannot disagree. The catalog carries the line;
  the table's facts column says `archived` beside `pending`, `base` and
  `inserts N`, which are independent and joined, not chosen between.
  It is the mirror of `pending`: that one is *not yet*, with no
  installer to run, and this one is *no longer*, the installer still
  working — so this refusal names a way through. `./wb.sh add NAME`
  refuses with the line and points at `./wb.sh add --archived NAME`,
  which the shell takes out of the argv and hands to `expand`, never to
  the installer, whose switches it is not one of (`expand` takes it
  too, for the plan alone). The console never forces one: `serve`
  refuses the ask, and the box's Installation screen shows the command
  with its flag and an unlit button beside it. Nothing changes for a
  project that already carries an archived cartridge — it reads as
  inserted, and ejects — because archiving is a fact of the box and
  being inserted is a fact of the project. The shelf's ribbon gained
  *Archived* as its fourth state, last and counted: not hidden, one
  click away, because the papers are why the box stays.

- **coveralls' tests stand on Mimic, and run concurrently again.** The
  `mix cover` task's unit tests double `File.write!/2` to read the
  report they would have written; with `mock` that replacement was
  global to the VM, so the file could not be `async: true`. It is now,
  and the five `with_mocks` blocks are five `stub(File, :write!, …)`
  calls. The cartridge composes `test_doubles --double mimic` in place
  of `mock` and registers `File` in **its own block** of
  `test/test_helper.exs`, so another cartridge's copies can stand in
  the same file and either can be ejected without touching the other.
  `File` is nobody's module to declare a behaviour for, which is why
  this side of the box is Mimic's. Verified in a generated project: the
  block in the helper, the dep behind it, nine tests green and the
  suite's sync column at zero. The first of the five cartridges that
  `mock` still holds; chiefs_setup picks both boxes while the migration
  runs.

- **The `mix cover` task stops warning in a project without a docs
  `source_url`.** `@source_ref` was read only inside another attribute,
  behind an `&&` that never reached it there, so every such project
  compiled with *module attribute @source_ref was set but never used*.
  The ref is read where it is used.

- **test_doubles: what a test puts in the place of the real thing.**
  A box for the two maintained double libraries, the choice not a
  preference but a question about whose module is being replaced:
  `--double mimic` copies a module out of the way and answers in its
  place — any module, `File`, `System`, an HTTP client — and asks
  nothing of the code; `--double mox` replaces nothing, builds a new
  module against a behaviour the project declares, and needs the code
  to ask its configuration whom to call. Both, comma-separated, is a
  normal answer, and a second run adds the other. Without the option,
  mimic. `--type-check` is one switch with two implementations:
  Hammox in Mox's place, `type_check: true` on every Mimic copy.

  The box is the dependency **and the way in**, which is what `mock`
  never had: `copy/4` and `defmock/4` register what a cartridge's
  tests replace into that cartridge's own block of
  `test/test_helper.exs`, so several can stand in one file and be
  ejected apart. It takes over from `mock`, whose library has not
  released since December 2024 and whose pin (`meck ~> 0.9.2`) locks
  out the meck that compiles on OTP 29 — the fix exists upstream and
  cannot arrive. The eight generated files that `import Mock` move one
  cartridge at a time; `mock` stays on the shelf until the last of
  them has.

- **A cartridge owns its block of a file it shares.** `.env` and
  `.gitignore` are sets, so an entry goes at the end and a merge can
  reorder freely; `test/test_helper.exs` and a git hook are not —
  every `Mimic.copy/1` has to stand before `ExUnit.start()`, and a
  hook runs its commands in sequence. Appending is wrong there, and
  rewriting the file whole means the second cartridge erases the
  first. `WorkbenchIgniter.BlockFile` gives each cartridge a block
  of its own, delimited and named, and puts it where an anchor says:
  a re-run with other options replaces the block where it stands
  instead of adding a second, an eject takes one away and leaves
  every other, and the file can say who wrote in it. The anchor
  decides where a block is born, never where it lives, so a project
  that moved it keeps it moved; an open sentinel without its close
  raises, naming the file and the owner, rather than rewriting a
  file somebody half-edited. The delimiter is never a mark: no
  cartridge may answer `installed?/1` or `state/1` by looking for
  one.

- **A box says which containers it brings.** The Spec of a box in hand
  gained a **Brings** row, beside Needs and Opens: the compose services
  the cartridge raises, each with its role's colour, the port it
  listens on and the deployments it enters. Once the cartridge is in,
  the project says it and the row repeats it, engine and all. While it
  is on the shelf there is no project to ask, so the row reads the
  catalog's new `offers` — every container the cartridge could raise,
  each with the choices it comes `with` — and lights the ones the form
  is holding, which is why the row moves with the switches instead of
  promising all four databases to a reader who has picked one. What no
  switch can bring is still shown, unlit, with the reason: a cartridge
  whose form is locked blames the state it went in with («ecto is in
  with database sqlite3»), not a switch nobody can move.

  `offers` is derived, never written down twice: the manifest asks the
  cartridge for `services(:any)` and then asks again one choice at a
  time, so the answer is the cartridge's own. That matters because the
  name in the compose is not the name of the choice — ecto's four
  engines all arrive as one `database`, and `--database sqlite3` brings
  no server at all, SQLite being a file, but the one-shot that makes a
  place for it. Where the choice decides something the service does not
  — the image and the port of `database` differ per engine — the menu
  says nothing rather than the first engine's, and the project that has
  the cartridge says it.

  The rows that name cartridges or containers — Needs, Inserts, Brings,
  Opens — now stand one item per line. Thirteen picks of a collection
  were a paragraph that wrapped; they are a list, and read as one.

- **A cartridge's promise about its own services is checked.**
  `services(:any)` is each cartridge's word that these are all of its
  containers whatever you choose, and two readers stand on it —
  `Compose.images/0`, which tells the workbench's images from a
  daemon's, and the catalog's `offers`. Neither would notice it broken:
  add an engine, forget the `:any` line, and the new image quietly
  stops being the house's while every test passes. A conformance suite
  now walks the real shelf and holds the promise to what the cartridges
  actually answer, in both directions.

- **The Record's flags cite their source.** The head of the «in
  phx.new's words» column is a link to `mix phx.new`'s page on hexdocs,
  which the column quotes — at the version that generated the project,
  off the Dockerfile's `PHX_NEW` stamp (phx_new and phoenix share a
  number, and hexdocs keeps a page per release), so the options read
  there are the ones this project had; the current page when there is
  no stamp. One link on the head, not one per row: every row points at
  the same page.

- **db_admin: the database admin in the browser, one box, four
  admins.** The fourth box of the shelf's migration (`SCRIPT.md`, the
  author's selection: db admin). pgadmin and adminer were one need —
  look at the database without its shell client — split by mechanism,
  the second written as the consolation for the first's refusal off
  Postgres. The box takes the admin as its option, `--admin`, one or
  several, a second run adding another (`rerun: :adds`), and brings two
  more: **phpMyAdmin**, MySQL's own, and **CloudBeaver**, DBeaver in
  the browser. Each admin declares which of ecto's databases it serves
  as a requirement on its value — `pgadmin` on postgres, `phpmyadmin`
  on mysql, `cloudbeaver` on postgres, mysql or mssql, `adminer` on any
  — read off ecto's `state/1`, so the catalog carries it per value and
  the console's form shows what the project's database does not serve
  unlit, with the reason; asked for anyway, it refuses the run with
  what the project has. For that a **requirement's state takes a list,
  met by any one of its values** (`database: ["postgres", "mysql",
  "mssql"]`), said as one ("ecto with database postgres, mysql or
  mssql") in the resolver and in the console, and the refusal of a
  chosen value is one function (`Feature.refuse_values/2`, ash's too).
  Without `--admin` the box is shaped by the database, as
  dashboard_extras is: the database's own admin where it has one,
  Adminer on SQL Server and SQLite, which have none. Every admin is a
  file the project owns — who signs in, on which driver, off the
  adapter — and a container the compose carries, told where the
  database is: phpMyAdmin's `config.user.inc.php` on the server its
  image has just made, its Apache moved to 8081 since the pod is one
  network namespace; CloudBeaver's `data-sources.json` mounted
  read-only where the image keeps the seed of a fresh workspace —
  because the server rewrites its live one — with three variables that
  skip its setup wizard, the connection granted to whoever opens the
  page, and its own switch for environment variables in a connection,
  so the compose says host, port and database. Not on SQLite, a driver
  its server ships disabled with no variable to enable it: the
  requirement says so and the DESIGN keeps what it would take. The
  project's files do not move, so a project that got pgAdmin or
  Adminer from the old boxes reads as carrying this one. Measured
  beside MySQL, Postgres and SQL Server in one network namespace, and
  in a copy of a live workspace: pgAdmin from the old box read as
  `admin: [pgadmin]`, phpMyAdmin refused on Postgres, Adminer and
  CloudBeaver added in one commit with the compose, the three
  answering. `PHPMYADMIN_IMAGE_VERSION` and `CLOUDBEAVER_IMAGE_VERSION`
  join `config.conf`. chiefs_setup picks it bare in place of pgadmin,
  and no longer stops there off Postgres (db_admin v0.1.0,
  chiefs_setup v0.5.0, 2026-09-18).

- **dashboard_extras: LiveDashboard's two dark pages, one box.** The
  third box of the shelf's migration (`SCRIPT.md`, the author's
  selection: dashboard enhancements). osmon and psql_extras were one
  need split by mechanism — an OTP application, a Hex dependency — and
  the second was closed to every database but Postgres while
  LiveDashboard had a library for three. The box lights OS Data
  (`:os_mon` in `extra_applications`, always) and Ecto Stats by the
  extras of the database the project is on, read off ecto's `state/1`:
  `ecto_psql_extras`, `ecto_mysql_extras` or `ecto_sqlite3_extras`.
  It is the state requirement read the other way: **shaped by the
  state, not refused for it** — with no database, or on SQL Server
  (which LiveDashboard has no stats for), it installs OS Data alone and
  a notice says why, and a second run adds the extras once there is a
  database (`rerun: :adds`). What it does require is `dashboard`:
  without it no sentence on the box comes true. The extras lose
  psql_extras' `only: :dev` — they go where `phx.new` puts the
  dashboard itself, every environment, so a dashboard taken to
  production is not dark there for a reason buried in a dependency's
  options. Two console doors, `os data` and (with ecto) `ecto stats`.
  What the research found, and the README says: `os_mon` does not only
  answer, it watches, and on a machine past 80% of disk or memory the
  app boots with `:alarm_handler` notices in the log; and the slowest
  queries on Postgres (*Calls*, *Outliers*) need `pg_stat_statements`,
  a server setting no dependency brings, so the NEED does not promise
  them. Verified on a real `phx.new` project against Postgres: before,
  OS Data greyed and Ecto Stats a card asking for a library; after,
  both pages with data, 31 queries on the repo. MySQL's and SQLite's
  extras verified as a patch and as a resolution beside LiveDashboard
  0.8.7, not on a running project. chiefs_setup picks it in place of
  the two, fourteen picks, and no longer stops there on MySQL
  (dashboard_extras v0.1.0, chiefs_setup v0.4.0, 2026-09-18).

- **version_manager: the host's pin is a box of its own.** The first
  box of the shelf's migration (`SCRIPT.md`, the author's selection:
  asdf/mise). toolchain held two capsules of knowledge — the
  `.tool-versions` a version manager reads and the `/.elixir_ls/` a
  language server leaves — and a project may want either without the
  other. The pin is `version_manager` now, with the manager as its
  option: `--manager asdf` (the default) writes `.tool-versions`,
  asdf's file, which mise reads too; `--manager mise` writes
  `mise.toml`, the file mise recommends over it. The option changes the
  file, so the file is the state: `state/1` says the manager back off
  the one that is there, and any version file of either manager
  (`.mise.toml` included) is the mark — never overwritten, and a
  project on mise is not handed an asdf file beside its own. What the
  split found: toolchain wrote `elixir 1.19.6`, and both managers
  install Elixir precompiled, where the bare version is the build
  against the *oldest* OTP that Elixir supports (asdf-elixir's README),
  not the Erlang pinned on the line above. The installer knows the OTP
  it runs on, so it writes `1.19.6-otp-28`. toolchain's `--elixir` and
  `--erlang` did not come along: typing the versions contradicts the
  file's one claim, and another pin is an edit of a file that is the
  project's. Read back by a real mise
  (2026.9.11, in a container) from both files; the names checked
  against asdf's listings. toolchain keeps the language server's
  ignore, its mark now that entry, its name and scope to settle in its
  own session; chiefs_setup inserts both, fifteen picks (version_manager
  v0.1.0, toolchain v0.2.0, chiefs_setup v0.3.0, 2026-09-18).

- **A requirement can name the state it needs.** `requires/0` took
  names, and a cartridge that needed more — pgadmin and psql_extras, on
  Postgres and nothing else — checked it by hand after the names, each
  with its own refusal. Now a requirement is a name or `{name, state}`:
  `{"ecto", database: "postgres"}`, read off the required cartridge's
  own `state/1`, the project as it is, born with it or inserted, never
  what an insert was asked. One resolver (`missing_requirements/2`)
  reads names and states alike and says what is absent and what is in
  but short; one refusal (`Feature.refuse/3`) writes the issue every
  cartridge used to write for itself, seven copies gone: "live builds
  on html, not in the project yet. Insert that first: ./wb.sh add
  html"; "pgadmin builds on ecto with database postgres, and this
  project's database is mysql". The remedy carries the state as the
  installer's switches. The catalog carries the names as `requires`,
  as before, and the states as `conditions`; the console's box says
  both under Needs and unlights Insert for a state the project lacks.
  The road to live as an option of html, and to a dependency on
  "html with live", is this (pgadmin v0.1.1, psql_extras v0.1.1,
  2026-09-18).
- **healthcheck2's option is tested by what the plug answers.** There
  is no phx.new to measure this cartridge against, so the rod is what
  it is for: the plug the installer writes is compiled and called
  (`Plug.Test`), under a name of its own per test. Every way of
  spelling `--path` — none, `/status/`, `status`, `/api/v1/healthz`,
  `//up//`, `/` — answers 200 at `<prefix>/live` and `<prefix>/ready`,
  with `no-store`, and nowhere else: not a deeper path, not another
  prefix, not the default's once it moved, not a POST. Readiness is
  the repo's answer — 503 when the query fails, raises or the pool is
  gone, never a raise — and liveness looks at nothing. The repo checked
  is the project's own on a project born with Ecto, none on one born
  without (phx.new's own `--no-ecto`, not a file removed by hand). And
  whoever reads the prefix back reads the same one: the project's
  state, the plug's own words, the test the project is given — which
  is parsed, on every shape and prefix. A second insert with another
  prefix leaves the first.
- **Every option of ecto is measured with phx.new's own flag.** A
  cartridge's tests looked for the strings someone thought of looking
  for (`binary_id: true` in `config.exs`, `:ecto_sqlite3` in `mix.exs`);
  now `add ecto --database mysql --binary-id` onto a project without
  Ecto is compared, whole and file by file, with the project phx.new
  makes with `--database mysql --binary-id` — the four databases, with
  and without binary ids, onto a project with everything else and onto
  a bare one, and no option at all against phx.new's defaults. And what
  an option means to the workbench, which phx.new knows nothing of, per
  database: what the project reports (`state/1`), the service it asks
  the workspace for, what that service is (image, port, its own client
  as the first shell), the `.env` line with the credentials the compose
  gives the server, the dev compose with the app waiting for it —
  SQLite asking for no server but a volume in a release, and
  `--binary-id` changing nothing of it. The rod is shared now
  (`WorkbenchIgniter.Grown`, in the test helper): born, add, grow and
  what may differ, said once for every cartridge that is to be
  measured this way.
- **Born bare and grown is born whole, as a test.** The experiment made
  by hand on 2026-09-17 — `./wb.sh new` with every `--no-*`, the eight
  base cartridges added one by one, against a plain `./wb.sh new` —
  which found a production Dockerfile without assets, a release
  without `bin/migrate` and a compose without its database, runs with
  the igniter's suite now (`grown_vs_born_test.exs`, seconds, no
  Docker): phx.new's own generator makes both projects, the installers
  run as `wb.sh add` runs them, each applied before the next, and the
  trees are compared file by file — then the project's shape, the
  services it asks for and the dev and prod composes. The eight go in
  in 13 440 orders (live and the dashboard build on html), so four
  layers, each at its price: a **covering set** worked out when the
  test compiles — every three cartridges in every order they can go
  in, since a conflict is born where cartridges write into one stretch
  of a file — with the orders that failed once pinned beside it; **five
  orders drawn by the run's seed**, so every run looks somewhere new
  and a failure prints the order to pin; **one step from a shape** —
  phx.new makes any subset outright, a cartridge goes onto it, against
  the next subset born: sixty of the 560 steps by the seed; and
  **all of them**, the whole tree of orders walked on every core with
  a shared beginning grown once, and the 560 steps, behind a tag —
  `mix test --only exhaustive`, before a release or after touching
  `PhxDelta`. What
  may differ is written down in the test and nowhere else: the secrets
  phx.new draws, how a file ends, the order of `mix.exs`'s lists and of
  `.gitignore`'s patterns, and the environment files a birth gets from
  `workbench.setup`. The igniter's test environment has
  `phoenix_live_view` and `ecto_sql` now: without what a grown
  project's `.formatter.exs` names, Igniter could not read that file,
  fell back on the default formatter and wrote `plug(:accepts)` — nine
  tests had been asserting that artefact, and assert what a real
  project gets.
- **`WorkbenchIgniter.ComposeFile`: the compose files have a module of
  their own**, as `mix.exs` has `MixFile` — the first step of giving
  each service back to the cartridge that needs it. Today a service is
  a name in its cartridge (`services/1`) and everything else somewhere
  else: its block in two central templates, its port and version in
  `Compose.Plan`, a flag of its own in three bakes of `wb.sh`, a
  variable in `config.conf`. The module holds both halves of working
  on that file as text (Igniter has nothing for YAML, and a parse and
  an emit would lose the comments a baked compose explains itself
  with). **Read**: `services/1`, the names a file declares
  (`Deployments.declared/1` delegates to it); `published/1`, the ports
  each service publishes, which the console's Record had a parser of
  its own for and now asks here; `host_port/2`, the host port a file
  publishes a container's port on. **Written**: `ComposeFile.Service`,
  what one service contributes — its block, the ports it publishes
  with their comments and defaults, what the app waits for because of
  it, its top-level volumes and configs, the deployments it enters —
  `slots/3`, which gathers the contributions of a deployment's services
  into the text of each slot of a skeleton, and `host_ports/3`, which
  keeps each port where the file already has it and asks the host for a
  free one only for the new.
- **A service is defined in the cartridge that needs it, whole.** A new
  callback, `compose/1`, beside `services/1`: for the names the
  cartridge asks for, what each is in the file being rendered — a
  `ComposeFile.Service`. The YAML lives with the cartridge, under
  `priv/features/<name>/compose/pod/` and `scaled/` (`embed_compose/0`,
  which trims nothing: a fragment is the file's text). **ecto** owns the
  three servers, the release's one-shots (`migrate`, MSSQL's
  `create`, SQLite's `volume_init`), what the app waits for, the
  data volume and the `DATABASE_URL` of the bridge network; **pgadmin**
  and **adminer** their block, their port on the pod and pgAdmin's
  config; **k6** its block on both topologies; **monitoring** Prometheus
  and Grafana, their configs, Grafana's port and what the app owes it
  (the wait, `GRAFANA_HOST`). A fragment reads the whole context
  (`Compose.context/1`), so a service sees its neighbours: k6 writes to
  Prometheus when it is there, Adminer opens the engine the project has.
  The two templates under `priv/compose/` are skeletons now — the pod
  and the app, the replicas and the balancer — with seven slots
  (`ports`, `services`, `app_waits`, `app_volumes`, `app_environment`,
  `volumes`, `configs`); `position` orders the services in the file.
  `Compose.service_names/2` is read off the same contributions instead
  of a list of names kept beside the templates. Not one byte of any
  compose changed: the 40 golden files pass as they were, and a bake of
  a workspace born whole said "nothing to bake".
- **No service is named outside its cartridge any more: ports and
  versions are generic.** `mix workbench.compose` lost its eighteen
  per-service flags (`--pgadmin-port`, `--grafana-internal-port`,
  `--postgres-version`…) for two, as many times as there are:
  `--port NAME=PORT` and `--version NAME=TAG` — the cartridge has the
  default tag, in its fragment, and the port its service listens on.
  A port lives in the file that publishes it: `--keep-ports-of FILE`
  keeps the ones the deployment's file already has, so a bake moves
  nothing, and one that comes from nowhere is a **need** — the task
  writes nothing, prints `need> NAME DEFAULT` and exits 3 — because
  free is a question for the host. `wb.sh` answers it in one place,
  `compose_render`, which the three bakes go through: the first free
  port from the cartridge's default on, then the task again. Its
  `version_flags` hands over every `NAME_IMAGE_VERSION` that
  `config.conf` sets, so that file reads as before. Gone from the
  script: the three `*_INTERNAL_PORT`, `workspace_pgadmin_port` and
  its two siblings, the ports of `compose_ports` and of `new`. The
  status's `ports` is `{"app": N, "published": {"5050": 5051}}`, by the
  port each service listens on, and the report for a person labels a
  door with the file's own word for it — a cartridge opens the comment
  over a port with what it is (`# pgAdmin port, …`). What
  `WorkbenchIgniter.Compose` knew of databases went to **ecto**: one at
  most, none on SQLite for replicas (`compose/1` may refuse a set of
  services, with its reason), and `Ecto.database/1`, which Adminer asks
  to say where the database is. `ComposeFile.Service` has `listens`, the
  port a service answers on inside; `Compose.brought/2` says, per
  cartridge, the services it brings with that port and the ones
  published — in the catalog (`compose`, whatever the state) and in the
  status (as the project has them: ecto's `database` on 3306 for MySQL).
  The console's Record reads them there: its table of internal ports,
  which said `:5432` of any database, and its list of which cartridge
  has which service are gone. Verified on a copy of a workspace:
  pgAdmin inserted and baked took 5050 through the need; moved to 5077
  by hand in the file, it stayed there through the next bake, which
  gave Adminer 8080. The 40 golden files still pass byte for byte.
- **One module per project file Igniter has nothing for.** Beside
  `MixFile` and `ComposeFile`: `WorkbenchIgniter.EnvFile` (`entry/4`, a
  cartridge's variables into `.env` and `.env.sample`, the secret and
  its blanked-out line), `WorkbenchIgniter.IgnoreFile` (`entry/3`,
  `merge/3` — the set merge that ended the `.gitignore` conflicts — and
  `ignore_file?/1`) and `WorkbenchIgniter.Dockerfile` (`stack/1`, the
  stack read back off the production Dockerfile, and `binding/2`, as
  each Phoenix's template names it), over `WorkbenchIgniter.TextFile`,
  the append-once the first two share. They were `env_entry/4` and
  `gitignore_entry/3` in the package's root module, and `merge_set/3`,
  `docker_of/1` and a private binding inside `PhxDelta`, which is back
  to what it is about: asking phx.new what a capability is. No
  delegates left behind; the cartridges call the modules. Each has its
  own test file now. No behaviour changed.
- **A cartridge's commit carries the services it brings, and its
  eject takes them away.** The old script wrote the compose in the same
  act as the project, knowing what it had; since the cartridges, an
  insert committed and the compose waited for a `bake` nobody
  remembered (a project grown cartridge by cartridge came out without
  its `database`, 2026-09-17). `wb.sh add` now renders the workspace's
  compose files again — dev, and prod and scaled when they are baked,
  the scaled one with the replicas and the balancer it has — after the
  installer and before the commit: one commit is the whole cartridge.
  `eject` stages the revert, renders them again for the project without
  the cartridge, and commits the two as one `Revert "Insert …"`. A
  compose is a derived file, so it is never reverted as text: a
  cartridge inserted since wrote its block right beside, and the revert
  conflicted — a conflict on the workbench's own composes alone is
  settled by keeping the file and rendering it. **A compose the reader
  edited is left alone**: `compose_is_ours` asks git, and no container,
  whether the last commit that touched the file is the workbench's
  (`New project:`, `Bake`, `Insert`, `Revert "Insert`); one that is not
  is named in a note at the end, when it is behind, with the way out —
  `bake` writes it again, keeping its ports and nothing else of the
  edit, and the file is the workbench's from then on. A render that
  fails leaves the file as it was and does not undo the cartridge. The
  scaled bake keeps its ports too now, as the other two did, while it
  is asked for the same shape: a bake moves nothing, and a deployment
  that is up is not handed ports it does not hold. The cartridges'
  after-insert words no longer send the reader to `bake`. Verified on a
  copy of a workspace: pgAdmin and Adminer each in one commit with the
  compose; pgAdmin ejected from between them, the conflict settled by
  the render; a hand-edited compose left alone by `add k6`, then taken
  back by `bake`; k6 ejected from the dev and the scaled file at once.
- **The console knows no cartridge's service by name: a service says
  what it is, and a colour is a role's.** What was left in the console
  was not presentation but knowledge kept by name — which containers
  take a session and with what, their order, their colour, which
  images are the house's — and a service from a cartridge nobody here
  has seen would have had none of it. `ComposeFile.Service` carries it
  now: a `title`, the `shells` a session can be (a label and the
  command; none for k6, which runs to completion) and a `role`, one
  word of the vocabulary the clouds sort their own services by
  (`ComposeFile.roles/0`: compute, database, cache, storage, messaging,
  search, network, observability, identity, devtools, job). The image
  is not declared: it is read off the service's own block
  (`ComposeFile.image/1`). `Compose.brought/2` hands all of it over,
  per cartridge, across the three deployments (`deploys`), and
  `Compose.images/0` is every image the house may run — the skeletons'
  and each cartridge's, whichever name a project asks by
  (`services(:any)`: ecto answers one per engine). In the console,
  `ConsoleWeb.Services` is the one place that answers: the terminal's
  targets, shells and argv, the order of Docker's containers, the
  house's images and their Hub links, and the colour of a service in
  logs, events and sessions. **A prompt is derived, never declared**:
  for `sh` and `bash`, the user and the directory the container's
  image says (`homes`, new in `wb.sh status --json`, off `docker
  inspect`; no user is root, as `docker exec` has it); for anything
  else, the command's name (`psql> `). The `svc-*` tokens are by role —
  `svc-compute`, `svc-database`, `svc-devtools`, `svc-observability`,
  `svc-network`, `svc-job`, and the balancer's own — several roles on
  one token until one needs telling apart, the plainest for a role or
  a container the console has not heard of; the logs' hook reads the
  answer off the page (`#svc-colors`) instead of a list of its own.
  Fixed on the way: a MySQL or MSSQL project was offered `psql` and
  shown `postgres=#` (ecto now says `mysql`, `sqlcmd`); Prometheus and
  Grafana asked for colour tokens that did not exist; the events
  still matched the pod by its old name; every `*_IMAGE_VERSION` but
  two was labelled "new" in the config drawer, where all take effect
  at every bake. The console names three services still, on purpose:
  the skeleton's `app`, `pod` and `balancer`, which are no cartridge's.
- **Remove on the Docker screen's images and volumes.** Each row of
  Images and of Volumes has a Remove, `./wb.sh prune NAME…` — every
  name an image wears, a volume's — confirmed in Jobs like the other
  prunes; unlit, naming them, while a container uses or mounts it —
  the console's own on the workbench's image and build volume — since
  docker would refuse it too, and while a removal is already asked. A
  volume's title and confirmation say what an image's need not: its
  data goes with it and does not come back; that is the way to start a
  project's database clean without deleting the project, after a
  `down`, since a stopped container still mounts it. `prune NAME…` is
  the verb, refused on the same ground from the terminal, and an
  image's row knows its users off `container inspect`.
- **The console restarts itself.** Restart on its own row of the
  Docker screen was refused ("./wb.sh console starts it again, from
  the host"); it runs `docker restart workbench_console` now, sent to
  the daemon from a process of its own so it is carried out whether
  the console lives to see it, and the page reconnects when it is
  back. The container keeps its image, mounts, env and port: a new
  image or another workspace is still `./wb.sh console` from the host,
  as the console says where it applies.
- **The `project-design` skill.** How a project the workbench hosts is
  designed before it is generated, from the business to the shelf:
  the criteria that hold across the steps in its SKILL.md — every step
  opens with its terms, its shape and one example; the author knows
  the floor and is asked through scenarios; the glossary is the door
  and the process a loop; the drawer of questions no story names;
  ownership and language; where the workbench stops — and one brief per
  step in `references/steps.md`. Written from `DESIGN_PROCESS.md`, the
  draft of the first run, which retires with it (2026-09-16).
- **The reference project's design, run once end to end.** Plant
  maintenance, a light CMMS on Ash for the industry around Querétaro:
  its papers are in `reference/` — the stories and the glossary in the
  plant's Spanish, the events, the rules with their examples, five ADRs,
  the three Ash domains with resources, actions and policies, and two
  entity diagrams drawn with the workbench's script from a script of
  the project's own. `SCRIPT.md`, at the root, is the crossing with the
  shelf: twenty-four steps against the box that answers each, what is
  domain code, what is missing, and the nine chapters of the series.
  Its findings went to RELEASE_PLAN.md: no collection for the Ash
  line, `ash --with ash_oban` for the reference, the shelf to say which
  line a box is on. Every step's finding is in `DESIGN_PROCESS.md`,
  the draft the design skill is written from (2026-09-15/16).
- **The terminal's colours are the reader's.** Under the Interface
  tab's Terminal fold, beside its face: the terminal's ground,
  ink and dim, and the six ANSI colours a line wears — red an error's,
  yellow a warning's — and the lines' grounds, the wash under a line
  of error and one of warning on Logs and the tint of the line under
  the pointer (the diff's hunk head wears it too), each a hex the sheet
  lays at its share: twelve swatches a ground, kept in this browser
  (`wb-console-term`) and written on the root over `tokens.css`, so
  every terminal surface takes them: the jobs' output, the logs, the
  Terminal screen, Docker's events, and the miniature's terminal, where
  the change shows. They travel in the interface's file under
  `workbench.colorCustomizations` by VS Code's own names
  (`terminal.background`, `terminal.ansiRed`,
  `editor.lineHighlightBackground`, …; the two washes under
  `dew.terminal.errorLine` and `dew.terminal.warningLine`, which are
  this console's), so a VS Code theme pasted in dresses the terminal
  too.
- **The interface as a file.** The jsonc that was the syntax
  palette's, under Language Syntax, is the whole interface's now, in a
  section of its own under the three folds: the overlay under
  `dew.interface` (the band's side, the rail's, the ground), the
  diff's four and the terminal's nine under
  `workbench.colorCustomizations` by VS Code's names for them, and
  every language's palette under
  `editor.tokenColorCustomizations` as before. Read mine reads it out
  for this ground; Apply takes what a pasted one has — this file's, or
  a VS Code theme's `tokenColors` and `colors` — the ground first, so
  the colours land where the file meant them.
- **The Interface tab folds in three, one a surface.** Its controls
  sit under three heads that fold as the rail's sections do, the
  chevron square at the end of each: Overlay, the frame and the
  ground; Terminal, its face and its colours; Files, the files' face,
  the syntax palette and the diff's four. Which are folded is kept in
  this browser (`wb-console-ui-folds`).

- **Restart on the rail's containers.** A second button on each
  container's row, beside Logs — the shell's went (2026-09-16: the
  Terminal is where a session is opened, the rail says what runs) and
  the row's columns size themselves now, the name taking what the
  chip and the two buttons leave — the Docker screen's one act on a
  single container brought
  to the rail: `./wb.sh restart --deploy
  DEPLOY SERVICE`, the same service and image up again with the
  deployment whole. Unlit with the reason while the container is not
  running, while a job on the deployment runs — a restart counts as
  one now, for the Deploy tab's buttons too — and on the pause
  container, whose network namespace the others share.
- **The diff's colours are the reader's.** A Diff section under the
  Interface tab's Files fold, after the syntax palette, in two groups, Added and
  Removed, of two swatches each: the code's ground, and the colour of
  its line number, which the sign wears too. Four a ground, kept in
  this browser as the palettes are (`wb-console-diff`) and applied as
  `--diff-<key>` on the root, which the Files sheet's diffs and the
  tab's own sample read. The code wears its ground at 66%, the
  terminal showing through, and the number's plate wears it whole,
  where the plate wore the line's wash at half strength and the sign
  the house's good or bad. The dark ground's four are set: code
  `#00212d` and line number `#529fc7` for an added line, `#3f0600` and
  `#db5a5a` for a removed one; the light ground keeps the two numbers
  and washes the code pale, `#c0eeff` and `#ffd6d2`.
- **Ctrl+C interrupts in the Terminal tab.** With nothing selected, the
  key stops what the session runs: under bash, sh or rpc every process
  the shell started gets SIGINT and the shell stays, as a terminal
  signals its foreground job; iex opens the BEAM's BREAK menu, `c` to
  go on and `a` to leave, and psql cancels its query. With text
  selected, in the input or on the screen, Ctrl+C is still Copy, and
  Ctrl+Shift+C and ⌘C always are. A session is a pipe, with no terminal
  to turn the key into a signal: its command now prints the PID `exec`
  hands it on a line the screen never shows, and the console signals
  that PID with a second `docker exec` in the same container, finding
  the processes under it through `/proc`, since the slim images carry
  no `pkill`. The workbench's one-off container has a name for that. A
  session opened before this has no PID to signal, and the key does
  nothing there (2026-09-15).
- **A release plan.** `RELEASE_PLAN.md`, at the root, is the plan to
  publish the workbench as a portfolio piece and the checklist of what
  is left: land the branch on `main`, prune the shelf, the `ci`
  cartridge, the README for the 90-second reviewer, the profile site,
  the console in exhibition mode over a recorded workspace, and the
  series. It retires with the release: what is still open then moves
  to issues, and the file goes. Its Phase 0 (2026-09-15) is a
  reference project, a multi-tenant SaaS on Ash in a domain of the
  author's, whose script — each step, its need, the box that answers
  it — the shelf is pruned against; it already names three cartridges
  for after 1.0: a collection for the Ash line, stripe finished, and
  `agents`. `DESIGN_PROCESS.md`, beside it, is the draft of the design
  process that project is run through: one dated entry per finding,
  the raw material of a design skill written after the first run. Its
  first entry: a step opens with its terms, the shape of its
  deliverable and one filled example, before any creative work — the
  three senses of *domain* told apart, and the candidates table.
- **Insert and Eject on the shelf's rows.** The last column of the
  Inserted list ejects the row's cartridge — the bare `eject NAME`,
  unlit with the reason when the tree is dirty, when another cartridge
  builds on it, when it came in from birth or by hand and left no
  commit to revert, or when it is a collection, whose eject is its
  box's — and On the shelf and Not done lead to theirs: the row's
  Insert opens the box on its Installation screen, where the options
  are picked and the box's own Insert says what it runs, or why it
  cannot. It sent the bare `add NAME` for a day (2026-09-10), unlit with
  the reason; a verb with options to pick is pressed where they are,
  and the screen reads for every box, the one without an installer
  included. The rows are no longer links, as the Inserted rows were
  not: the mention opens the box.
- **On the shelf and Not done read in the Inserted list's table**,
  columns included: the parameters each cartridge takes with their
  type — or their values, when the cartridge declares choices
  (`postgres | mysql | mssql | sqlite3`; an open choice ends in `…`, a
  long one shows four and the count, the whole list in the title) —
  and the addresses it would open, shut, `not inserted` for the
  reason. The summary rides on the name's title.
- **Every job wears its number**, `#7`, first on its row and on the
  tray's bar: this console's jobs from 1, in the order asked. The id
  names the job in the DOM and the queue; the number is what the
  reader counts by.
- **A conformance suite for the cartridge contract**, beside the
  catalog test that already installs every cartridge and checks its
  mark lights for it alone. Every cartridge with options is inserted
  with values none of which is the default and asked what the project
  carries: `state/1` must answer with exactly the schema's keys and say
  each value back, or `nil` for an option that leaves no mark, listed
  in the suite with its reason (`--build` runs once and its output is
  gitignored; exdoc's `--version` stamps the gitignored `doc/` dummies
  only; guidelines' `--url` is kept nowhere once the page is
  downloaded; auth0's and openai's `--project-name` are read by no
  template; enhancements' `--stripe` plants the auth0 diagrams). A
  cartridge with options and no run in the suite does not compile it.
  The composition side: the installer's source is scanned for every
  `compose_task("workbench.install.…")`, which must be declared, and
  what lights up beside a cartridge must be accounted for by its
  `requires` and `composes` — the hand-kept list of who brings whom
  is gone. And `mix workbench.dependents` has a test at last, on an
  in-memory project, through its walk made public
  (`Mix.Tasks.Workbench.Dependents.dependents/2`).
- **The adminer cartridge**, à la carte beside pgadmin as healthcheck2
  is beside healthcheck: Adminer on the workspace's database whatever
  the adapter — Postgres, MySQL, MSSQL, SQLite — on its own port, the
  first free one from 8080. The project owns the login it opens with,
  `adminer/login.php`: one Adminer plugin fixing the server and the
  driver off the adapter, filling the user and the database in, and
  holding the password Adminer checks itself (`pass`; on MSSQL, sa's
  own) — which Adminer 6's own rule makes necessary, since Postgres
  trusts 127.0.0.1 inside the pod, MySQL's root has no password and
  SQLite none at all. Where the database is and which one to open are
  the deployment's, handed over by the compose as `WORKBENCH_SERVER`
  and `WORKBENCH_DATABASE`; on SQLite the container mounts the file and
  runs as its owner. `ADMINER_IMAGE_VERSION` in `config.conf`,
  `--adminer-port` and `--adminer-version` on `mix workbench.compose`,
  the container in the console's lists and the Record's ports. The
  login was measured through the image on all four servers (the
  cartridge's DESIGN.md).
- **The Record paper, first on the Project tab.** What the project is,
  drawn off the status and nothing else, in three tenses. *Birth*: the
  toolchain and installer stamped in Dockerfile.local, the `mix phx.new`
  that generated it, and each flag with whether it was given, its
  argument, phx.new's own words and the base cartridge that owns it —
  all read off the first commit (`project.birth`), with a warn `now …`
  on any fact that moved since and `installer now …` when the
  toolchain's phx_new is not the generator. *Cartridges*: the shelf's
  own row — cover, mention, origin, edition — with the installation
  parameters as the flags `add` took (a default dimmed) and every
  address the cartridge opens, a route on the app's port with what it
  answered when the console called, or the port of the service it asks
  for with what `docker compose ps` says of it; the reload button in the
  column's head calls every route again. *Deployments*: dev, prod and
  scaled, each with its compose file
  baked, out of sync or not baked, the in-sync check with what is stray
  or missing, up or down, and its services as ports. `ConsoleWeb.Record`
  is the plan, `ConsoleWeb.RecordSheet` the sheet; Doors, the paper,
  retires into it, and `ConsoleWeb.Doors` keeps only the call. The
  ribbon reads Record · .env · README · CHANGELOG, Record's sublabel the
  first commit's sha. The layer classes on `.door-ref` are `door-route`,
  and `door-port`, prefixed because `.console` is the
  LiveView console's own root.
- **`mix workbench.status` publishes the birth and the deployments.** Two
  more facts the Record paper reads, both from what the project already
  has. `birth`, off the first commit and never inferred
  (`WorkbenchIgniter.Birth`): the sha, date and subject, phx.new's shape
  as generation left it — the same marks `PhxDelta.facts/1` reads today,
  now also readable off text, `facts_of/3`, for the files `git show`
  hands over — and Dockerfile.local's four stamps then; null for a
  project not born in a workspace. `deployments`
  (`WorkbenchIgniter.Deployments`): each compose file beside the
  project, baked or not, the services it declares, and whether it is in
  sync with what the cartridges ask for now — the names
  `Compose.service_names/2` renders for those asks, off the templates'
  own conditions — with what is stray or missing when it is not. Asked
  of test_001 it says what nobody had seen: the prod file still declares
  prometheus and grafana after monitoring's revert, which `compose_behind`
  cannot see because it bakes and compares the dev file alone. The text
  report says both in a line each.
- **A decision page for the Project tab's Record paper.**
  `console/el-estado-del-proyecto.html`, drawn on `_workspaces/test_001`
  as it stood on 2026-09-08, settles where a project's state is read and
  shown. The finding: there is no state file — the truth is the
  project's own code and git, Dockerfile.local, the baked composes and
  Docker, joined only by `status --json` — and the Deploy card had been
  mixing that with config.conf's intention. The paper, **Record**, first
  on the Project ribbon and drawn off the status like Doors was: *Birth*,
  read off the first commit and never inferred (the toolchain and
  installer stamped in Dockerfile.local, the `mix phx.new` command and
  each flag with its value, phx.new's own words and the base cartridge
  that owns it, a warn `now …` where a fact has moved since);
  *Cartridges*, the shelf's own row plus the installation parameters as
  `add` flags and every address the cartridge opens; *Deployments*, the
  console first and then dev, prod and scaled with their compose file's
  state, whether it is in sync with what the cartridges ask for, and
  their services. What it decided on the way: doors and probes are one
  face — `probes:` leaves the manifest, since the project owes the
  workbench nothing — with the reading attached inside the border and
  an 8px square for the layer (a port the compose publishes, a route
  the project offers, the console); a `.commit-ref` for every sha,
  opening History on that commit; Git's two documents fold into the
  Project tab; the service is named by its role, `database`; and
  test_001's prod compose is out of sync for real — it still declares
  prometheus and grafana after monitoring's revert, which
  `compose_behind` cannot see because it only compares dev.
- **Monitoring: PromEx, Prometheus and Grafana.** Step 5 of
  `scripts/PLAN.md`, the **monitoring** cartridge. In the app, `prom_ex`
  and a `MyApp.PromEx` module with the plugins the project's shape calls
  for — Application, Beam and Phoenix; Ecto with a repo; LiveView with
  `phoenix_live_view` — first in the supervision tree, its `/metrics`
  served by the endpoint before `Plug.Telemetry`, off in test, and the
  Grafana client read at runtime off `GRAFANA_HOST`. In the workspace,
  the `prometheus` and `grafana` services the compose renders: Prometheus
  on the app's `/metrics`, Grafana on Prometheus, published beside the
  app's port (the first free one from `3000`), anonymous as admin so the
  door opens without a form, and healthy before the app starts, so the
  dashboards PromEx uploads on start find it there. Each container opens
  with a file the project owns, `monitoring/prometheus.yml` and
  `monitoring/grafana/datasource.yml`; what is the topology's the
  compose writes — Prometheus's targets file (`localhost` in the pod, one
  line per replica by name on the scaled network), `PROMETHEUS_URL` for
  the datasource, `GRAFANA_HOST` for the app — so one insert serves the
  three deployments. With k6 in, its results go to Prometheus by remote
  write (`K6_OUT`, and the receiver flag on Prometheus). `./wb.sh status`
  and the console's board and Doors show Grafana's address; the terminal
  and the Docker screen open a shell on both containers.
  `PROMETHEUS_IMAGE_VERSION` and `GRAFANA_IMAGE_VERSION` join
  `config.conf`. Run live on 2026-09-08 on a fresh Postgres workspace,
  dev and prod, k6 included: Grafana's first start on a fresh volume
  ran its 813 migrations for four and a half minutes beside the app
  compiling, past a 30 s start period, and the app's `depends_on` then
  failed the whole `up` — its healthcheck allows five minutes now, as
  SQL Server's allows three. No cover yet.
- **Doors, a paper of the Project tab.** The plan of every address the
  project answers to, drawn off the status: the workbench's own app and
  pgAdmin; the doors the inserted cartridges open, each called once with
  what it answered beside it as a chip; the doors an inserted cartridge
  keeps shut, unlit with what would open them — `--with ash_admin`,
  exdoc inserted — which the rail's Doors section, filtered to the open
  ones, could never say; the probes the cartridges have the console
  call; and the doors of the cartridges not in yet. The rail stays the
  bell, this is the map. Its ribbon tab wears the app's port where the
  others wear a file's name, and it is never unlit for want of a file.
- **A palette a language.** The colours of the Interface tab are kept
  per language as well as per ground: Elixir; HTML and its templates;
  CSS and SCSS; TypeScript and JavaScript; JSON; Markdown; and Godot,
  whose scripts, shaders, scenes and project file share one — each
  naming only the rules it has (JSON has keys and no keywords), each
  with a sample of its own, and each stamped on the Files sheet's
  `.src` as `data-lang`. A pasted jsonc sorts itself by the language
  its scopes name, a scope with no language reaching every language
  that lists one under it, and reads back out with every language at
  once. Three lexers come in for it: `makeup_ts` for `.ts`,
  `makeup_css` for `.css`, and `makeup_syntect` — the Rust NIF the
  highlighter's notes named as the escape hatch — for `.md`, `.scss`,
  `.gd`, `.gdshader` (through GLSL), `.tscn`, `.tres` and
  `project.godot` (through INI), so the README, AGENTS.md and guides a
  cartridge writes read coloured on the sheet. Numbers moved from the
  operators' rule to the constants', where the jsonc has them, and
  types to the modules'; CSS's properties and Godot's annotations take
  a rule of their own where their class would have meant another thing.
- **The code follows the ground.** The terminal — jobs' output, the
  logs, the Terminal screen, `.env` and `config.conf`, the papers'
  blocks, the Files sheet — was dark on both grounds; on the light one
  it is paper now. `term`, `term-ink`, `term-dim`, `term-line` and
  `term-scroll` carry a light value in `assets/design/tokens.json`,
  `term-tint` washes a hovered line or a diff's gutter, and six
  `ansi-*` roles replace every colour the console wrote by hand on a
  terminal surface. The Files sheet's twelve are One Light on the light
  ground, One Dark's pair; the Interface tab keeps a palette a ground
  and edits the one being read. `assets/design/fuente-claro.html` is
  the page the palette was chosen on.
- **The colours are the reader's.** The Interface tab of the workbench
  drawer gains *The colours*: the twelve rules of
  `console/elixir_color_theme.jsonc` as swatches, a sample of Elixir set
  in them, and a box a VS Code jsonc pastes into — its
  `editor.tokenColorCustomizations`, a theme's `tokenColors`, or the bare
  rules, matched to the twelve by scope — and reads back out of, in the
  same shape, to carry to VS Code. The twelve are properties of the root,
  kept in this browser like the faces, so the Files sheet and the sample
  change as they are set. One palette for every language the console
  colours: every Makeup lexer speaks the same classes.
- **Every push runs the checks.** A GitHub Actions workflow
  (`.github/workflows/ci.yml`) puts the two scripts through ShellCheck
  and each Elixir package — `igniter/`, `console/` — through
  `mix format --check-formatted`, `mix credo --strict`, `mix dialyzer`
  and `mix test`, on the Elixir and OTP the package's own
  `.tool-versions` names. Credo and dialyxir are dev/test dependencies
  of both; each package has its `.credo.exs`, the igniter gains the
  `.formatter.exs` it never had, and the PLT lives in `priv/plts/`
  (ignored, cached by CI). One check is off, in the igniter only:
  `AliasUsage`, because Igniter's API is spelled by its full path by
  convention and a cartridge calls a dozen of its modules. The README
  says how to run the same checks before pushing.

### Updated

- **Birth's cartridge column closes the row at the right edge,** as
  the Mix paper's brought by does.

- **The daemon's box is headed Specs,** as the Mix paper heads what
  `def project` says: the reader knows what the box is before reading it.

- **A base box's packages say where they come from, under the table.**
  The version a base cartridge brings is read off its insert commit,
  since the box declares none, and the cell marked that with a `*`
  whose meaning lived only in its `title`. The mark stays, a space
  from the version, and a line under the table reads it: the box does
  not install the package itself, it comes with phx.new, and the
  version is the one that installer writes — naming the phx.new, read
  off the `PHX_NEW` the project's `Dockerfile.local` stamped at that
  same commit, since the stamp moves when the project upgrades and the
  insert does not. The house had no footnote: `.fn` is the mark, muted
  mono and never the accent, and `.fn-note` the line that repeats it.

- **A package from GitHub is its repository.** heroicons and daisyui
  come from git, and the Packages panel showed them as nothing — no
  version, a lone mark, links to hex.pm pages that do not exist. The
  insert commit is now read as code (`MixFile.diff/2` on `mix.exs`
  before and after it) instead of line by line, so a dependency written
  over several lines is read whole; `MixFile.sources/1` says where each
  git dependency comes from, and `mix workbench.status` reports it as
  `git` beside each package, pinning and locking its tag — the lock
  still never passes a commit's sha off as a version. In the panel the
  name opens the repository and the tag its tree, with GitHub's mark
  from the house's sprite in place of hex's; the three columns only hex
  can answer stand unlit with the reason, and hex is not asked of them.

- **`./wb.sh console` stays in the terminal; `console up` leaves it
  running.** Bare, the console started detached and returned, and its
  output was one more command away (`console logs`), its end another
  (`console down`). Now bare `console` starts it and follows its output
  here, and Ctrl+C — or the terminal closing, or the container stopping
  on its own — takes the container down with it. `console up` is what
  bare used to be: started, the address printed, the prompt back, as
  the workbench's own `up` does. The two starts that never have a
  terminal — the helper container that starts the console again from
  inside it, and the page's **Start again** button — ask for `console
  up`, and the page's hints name it. A failed `docker run` or a
  workspace directory that could not be made now stops with an error
  instead of passing in silence.

- **exdoc v0.8.0 and the two papers, read against the tools as they are
  today.** The boxes changed a great deal this week and their DESIGN
  papers had grown by accretion — a paragraph per change, each with its
  version — so they read as a second changelog instead of saying what
  the box is and why it has this shape. Both were read back: coverage's
  abstract still said that what the report leaves out is *read off the
  project rather than asked*, the opposite of what `--ignore-files`
  does, and exdoc's was framed around what v0.2.0 decided and cited a
  database page that is dbschema's since Monday. They now open on the
  decisions that hold — for exdoc, *a page is listed when its file has
  an owner*; for coverage, five, including that the Markdown report is
  this box's to name and own.

  Checked online against hex.pm and both repositories, which corrected
  one claim and turned up one staleness. The claim: `mix docs` stops on
  an extra whose file is missing (true, an unrescued `File.Error`), but
  a `main:` naming a page nobody listed is **not validated at all** —
  the index quietly redirects to a page that is not there. The rule the
  box follows is unchanged; its reason is now the right one. The
  staleness: the pin was `~> 0.38` while the paper quoted 0.40.4.
  exdoc installs `~> 0.40` now, verified in a probe — the site builds,
  and `mix docs` adds a Markdown tree and `llms.txt` beside the HTML,
  which are ExDoc's defaults and stay as its author set them. Also
  written down where a reader will need them: ExDoc's themed-image
  fragment is undocumented outside its stylesheet, and ExCoveralls has
  not shipped since January 2025 — which does not change the choice,
  but is why the exit is written down beside it.

- **coverage v0.10.0: `--ignore-files` takes the groups the box knows,
  and no other value**, and its options are tried both ways. The option
  also took a path of the reader's own, which made the form offer a
  free text field beside the four groups for a value the box could
  neither check nor explain: an entry of `skip_files` is a regex, and a
  regex the box did not write is one it cannot say anything about. A
  project that wants another path out of the report edits its own
  `coveralls.json`, and `state/1` still reads that path back as the
  path it is — the reading of the project never depended on the option.
  Reading coverage's and exdoc's options one by one afterwards turned
  up what the day's rewrites had swept away with the text they sat in:
  `--minimum-coverage` had lost both its cases, and `--md-report` its
  negative. They are back, with `--coverage`, `--app-logo` and
  `--project-name` answering `state/1` both ways.

- **coverage v0.9.0: `--exdoc` is `--md-report`, and the report page is
  coverage's.** The flag named another cartridge, which is the one thing
  a box's papers never do — and it named it in the place a reader looks
  first. What it plants is the task that writes the report **as
  Markdown**: `TESTING.md` at the project's root, which any reader of
  the repository opens, site or no site. The page that waits until the
  first run moved here with it, since the file is this box's. Whether a
  documentation site *lists* that page is the site's business, and
  exdoc's `--coverage` decides it the way it decides the README's:
  listed live when the report is there, its two entries commented out
  when it is not. Its requirement follows the rename
  (`{"coverage", md_report: true}`). And the theme option is
  `--html-theme`, since the box writes two reports now and a bare
  `--theme` no longer said which it dresses: it defaults to `custom`,
  the workbench's own report, which reads on its own wherever it is
  opened, with `exdoc-ish` — the ExDoc pages' look, for a report read
  inside a site — second, the default first as every list here reads.
  `exdoc-ish` was the default while the box assumed there was a site,
  the same assumption its other option's name carried.

  The report's own name stays `TESTING.md`: a name says what the file
  is for whoever opens it, not which command wrote it, and that page is
  the suite's report — the execution board, the per-module tables and
  the failures — with coverage as one section inside it.

- **coverage v0.8.0: `--exdoc` builds on test_doubles instead of
  inserting it.** The `mix cover` task's own tests stand on a double of
  `File` — Mimic's side of that box — and until now this cartridge
  composed `test_doubles --double mimic`: a box nobody picked rode
  inside coverage's commit (the confusion the origin chip had to explain
  this morning), and the choice of doubling library was made for the
  reader by a box whose subject is coverage. The option carries
  `{"test_doubles", double: "mimic"}` as its requirement now, so a
  project without that box — or with Mox alone — is refused naming the
  box and the double, with `./wb.sh add test_doubles` as the line that
  fixes it. It is the same move `--githook` made onto precommit: one
  insert is one cartridge and one commit, the choice belongs to the box
  whose option it is, and what a project carries of a box is that box's
  to report. What coverage keeps is registering `File` in its own block
  of the test helper. A requirement can now read a state a box answers
  with a list (`double: ["mimic", "mox"]` carries `mimic`), which
  db_admin's admins will read the same way.

- **exdoc v0.7.0: a page is listed when its file has an owner.**
  `--changelog` lists a file another box writes, so it asks for that
  box the way credo's `--githook` asks for precommit: without the
  changelog cartridge in, the run is refused naming it, and the console
  draws the option unlit with a door to that box. It is **off by
  default**, so `add exdoc` still works on any project, and with it on
  the file is there — the commented slot v0.5.0 wrote for a changelog
  that was not there yet is gone with the case that needed it. The
  other order is the changelog box's own (v0.5.2): built after the
  site, it lists its page itself, as it did before the option existed.
  `--coverage` follows the same rule one box further out: it lists the
  Test Suite Report page, which `mix cover` writes, which the coverage
  box plants with *its* `--exdoc` — so the requirement carries that
  state (`{"coverage", exdoc: true}`) and the refusal says which half
  is missing, the box or the flag. `--readme` keeps the slot instead,
  because nobody owns `README.md` —
  `phx.new` writes it and the shelf deliberately has no box that would
  — so with none there the two entries and `main: "readme"` wait
  commented out, and `mix docs` builds.
- **The command a verb would run wraps instead of scrolling**, and
  holds the line and nothing else. The box under the install form was
  the one place where the command was written across the markup, so
  once the box began to respect what it is given — it has to, to wrap —
  the template's own newlines and indentation became part of the
  command as it read. The line is built whole and interpolated once,
  the way every other command box in the console already did it, and a
  test fixes the exact line so it cannot drift back. The box
  under the install form kept one line and grew a scrollbar, so a long
  option — a `--repo-url` — pushed the rest of the command out of
  sight, and the reader pressed Insert on a line they could not read
  whole. It keeps the width it has and breaks at the spaces between the
  words now, inside a word only when one word is wider than the box,
  with the wrapped lines hanging clear of the `$`.

- **The form's fields wear the house's face whatever shape they take,
  and a url field writes its own scheme.** The rule was keyed to
  `input[type=text]`, so the URL field the declared shapes brought in
  came out with the browser's own face — a different font, a different
  box — beside its neighbours; it is keyed to the field now, boxes
  aside, and a field the browser judges wrong while it is being written
  wears the house's `bad` (`:user-invalid`, so an untouched field is
  never red). The url field opens with `https://` and takes it back
  when nothing else was written, so a reader who tabs through leaves no
  half-address behind; neither move is sent, since `https://` alone is
  not an answer, and an address pasted with its own scheme replaces the
  one waiting instead of doubling it. Its `pattern` is the rule the
  installer holds it to — http or https with something after — because
  `type="url"` alone takes `ftp://` and the browser would pass what the
  insert then refuses.

- **credo's README sends the reader to the guide.** What the tool
  flags is argued in prose in the [Elixir Style
  Guide](https://github.com/rrrene/elixir-style-guide), Credo's own —
  its author's, "the basis for Credo" — and its sections are the four
  the tool reports under. The box now says so: when a check fires and
  the reason is not obvious, that page is where it is settled, with the
  example beside the rule.

- **exdoc v0.5.0: `--changelog`**, on by default. The site's changelog
  page was a reading — listed if `CHANGELOG.md` happened to be there —
  and is a decision now: on with a changelog, the two entries are
  written live as before; on without one, they are written **commented
  out**, the slot a changelog opened later takes, as `source_url` and
  `homepage_url` are; off, the site leaves the page out whatever the
  project keeps. The changelog box reads that decision instead of
  guessing (v0.5.1): it fills the slot when it opens a changelog, adds
  nothing to a site that said no, and says which flag said it.

- **A page on disk says when it was built, and offers to build itself.**
  The green doors — exdoc's `doc/`, coverage's `cover/` — read *built
  18:18*, an hour with no day: a page on disk is read against the
  project of the moment it was written, and yesterday's report looked
  like this morning's. The reading is the whole stamp now and nothing
  more, `2026-09-22 18:18 +0200` — the word *built* was the same fact
  said twice, since a stamp is there or the button is; the offset is
  the one the machine read it in,
  summer time included, since whoever reads the page need not be on
  that clock. And where there is no page yet, the door
  stopped at *nothing built in doc/ yet*; in the reading's place it now
  carries the one thing to do, **build**, which runs the command as a
  job. The command is the cartridge's to name, never the workbench's to
  invent: a door on disk declares `build:`, the project's own Mix task
  — exdoc `docs`; coverage `cover` where *it* went in with `--exdoc`,
  which is what plants that task, and ExCoveralls' own `coveralls.html`
  otherwise, the first whose condition holds — and the console runs
  `./wb.sh mix <task>`. A door's conditions gain that third kind,
  `{:option, key}`: the cartridge's own option as `state/1` reports it,
  beside `{:with, value}` and `{:cartridge, name}` — coverage's
  `mix cover` is planted by its own `--exdoc`, and whether the exdoc
  cartridge is in says nothing about that file. The env is the
  project's: its `cli/0` already prefers `:test` for both tasks. console/PLAN.md had it open since the doors
  were drawn; it closes here.

- **exdoc v0.4.0 and v0.4.1: the theme script is gone, and the database
  with it.** ExDoc hides an image whose URL carries `#gh-dark-mode-only`
  in the light theme and one with `#gh-light-mode-only` in the dark one
  — GitHub's own fragment — and has since v0.27, so the
  `guides/js/themedImage.js` this planted in every project, the
  `before_closing_*_tag` functions that loaded it and its asset entry
  are out: what ExDoc does already is not worth a file in every
  project. The script also named one pair of files, the database
  model's, so it served one page and no other. v0.4.1 hands the
  database page to dbschema.

- **Every option is tried both ways.** The shelf was read option by
  option against its tests, and what only had its positive case got the
  negative one: `--build` (coverage and exdoc) queues `mix docs`,
  `mix cover` and, with Ecto, `ecto.create`/`ecto.migrate`, and queues
  nothing unasked; without `--exdoc` coverage plants no `mix cover`
  task, without `--coverage` exdoc lists no report page; test_doubles
  unasked brings neither Mox nor Hammox; changelog's badge is `nil`
  where there is no README to carry it, and says so; exdoc's
  `--module-groups` asked for wins over the line the project is on, and
  `--no-readme` on a project with no changelog keeps the Project group
  as the slot a changelog opened later is listed in. db_admin answers
  for phpMyAdmin through `state/1`, refuses a list with one unknown
  admin whole, and takes the same admin twice as one. Three refusals
  are new, each where a value was taken and written unchecked:
  coverage's `--minimum-coverage` (a whole 0..100, or `coveralls.json`
  is not JSON) and `--interface` (`rest` or `graphql`), and clustering's
  `--dns-query`, where a quote or a line break would break the `.env`
  line it goes in; an empty `--dns-query` is a field left blank, so the
  default stands. And one fix: `--double mimic --type-check` left no
  mark at all — Mimic keeps type checking on each `Mimic.copy/2`, so
  the run types the copies the test helper carries, which is what
  `state/1` and later copies read, and says so when there is no copy
  yet to keep it on.

- **A box's Files show every insert of it, not the last.** A cartridge
  whose options add pieces (`rerun: :adds`: changelog's `--mix-task`,
  db_admin's second admin) goes in more than once, a commit each, and
  the Files screen read only the newest, so what the first insert wrote
  was missing from the box that wrote it. `Console.Diffs.inserted/2`
  reads each of the cartridge's standing inserts: the summary has a row
  per commit, and the files come under a heading per commit, each its
  own sheet — the commits sit apart in the log, so no range reads them
  as one.
- **clustering, health_probe, exdoc and coverage draw their Contents as
  the tree**, the table with 📁 and 📄 the features index describes
  (ecto is the model); clustering had none. coverage's named a test file
  that was renamed with the box.
- **exdoc v0.3.1: `--homepage-url` unasked is a placeholder,
  commented**, as `source_url` is when no repository is found: the key
  waits in the `docs:` block where it goes.

- **A box's options are one component, and a need is a door.** The
  install form drew an option two ways: a switch or a text as `.field`,
  with what the option needs (credo's `--githook` on precommit) inside
  the flag's 150px label, where a long need broke the line; a list as
  `.choices`, with what a value needs (db_admin's `pgadmin` on ecto with
  postgres) after the value. One `<.option>` in `box.ex` now draws all
  six shapes of the shelf's 33 options (switch, text, one of, several,
  and several with values of their own, grouped or not). The key is the
  flag, with the kind of answer under it (`switch`, `text`, `one of`,
  `several`, `· or others`, which nothing said before). The answers are
  one line per control, always control · name · tags · — note, and a
  tag sits on the line of the control it shuts, whether the option or
  the value asks for the cartridge. `needs` is followed by each
  cartridge's own `.cart-ref`, a door to its box with its real dot, and
  the state it asks beside it (`with database mysql`), so the form
  shows how the cartridges hang together. The default is a tag in every
  shape (`default`, `default off`, `default /health`), and a list of
  several shows it too (ash's `--data-layer postgres`). Also: a hairline
  between options (the old rule aimed at a `#d-fields` that no form
  had), text fields capped at 40ch, «other» as the list's last line,
  and a group a caption inside the answers instead of a 96px column.
  What the project has is still said by the box checked and shut, with
  no tag. The manifests' «Default: …» sentences stay, since `--help`
  reads them. Settled on a decision page with today's form and two
  candidates, the tags on the control's line or in a rail at the
  right; the rail put `needs precommit` ~600px from its box. Verified
  in the console on db_admin, ecto, ash, changelog and health_probe.

- **coveralls is `coverage`: the box named for the need, not the
  dependency.** The old name was ExCoveralls', and it also read like
  the coveralls.io service, which the box never talks to. With the
  need's name, a later move to another tool (Elixir's own
  `mix test --cover`, say) is a new version of the same box, not a
  box with a new name. The task is `workbench.install.coverage`, and
  the blocks the box owns in the test helper and the pre-commit hook
  are `# >>> coverage`. exdoc's `--coveralls` is `--coverage`, and
  chiefs_setup's recipe follows. What the box installs is unchanged:
  `coveralls.json` (still the mark), `mix coveralls` and ExCoveralls
  are the library's names and stay. The cartridge's older CHANGELOG
  entries, and the cover records where "coveralls" was the name at the
  time, keep it.

- **The two health boxes are `health_endpoint` and `health_probe`.**
  `healthcheck` and `healthcheck2` were one need read twice, and their
  names said only which one got the word first: the `2` made the
  newer box look like a version of the older, when it is the other
  answer to the same question. Each is now named for what it writes.
  `health_endpoint` (was `healthcheck`, archived the same day) writes
  the controller behind the router — JSON that grows in dev, an entry
  in the Swagger page, a route a person reads. `health_probe` (was
  `healthcheck2`) writes the plug mounted first in the endpoint —
  `/health/live` and `/health/ready`, what a platform polls, and no
  log line for it. The shelf keeps its own order — `health_endpoint`
  in the Phoenix line it belongs to, `health_probe` among the
  production boxes — but the names no longer read as a box and its
  sequel, and each NEED.md's *Not for* points at the other by a name
  that says what it is. `wb.sh add
  health_probe`, `wb.sh add --archived health_endpoint`, `mix
  workbench.install.health_probe`, `mix
  workbench.install.health_endpoint`, the boxes at
  `features/health_probe/` and `features/health_endpoint/`, their art
  at `assets/covers/health_probe/` and
  `assets/covers/health_endpoint/`.

  What either installs is unchanged, options included. The generated
  code keeps the names it always had — `MyAppWeb.HealthcheckController`
  and `MyAppWeb.OpenApi.Schemas.Healthcheck` are what a project already
  carrying the endpoint has, and renaming them would break it for
  nothing — so the only generated text that moved is the comment
  `health_probe` leaves above its plug, now `# Workbench health probe`.
  Cartridge versions: `health_probe` v0.2.0; `health_endpoint`, whose
  papers predate the per-cartridge changelog, has none to bump.

  The box follows. `health_probe`'s front carries its title painted
  into the hero, not typeset over it, so the lockup was asked for as
  a logged change and came back on the first turn: the face reads
  `HEALTH PROBE`, on a scene the generator repainted around the word
  — a larger bell lit anew, the title a fifth taller. The line
  `VERSION 0.1.0` the hero carried was asked off in the same turn and
  ignored; the second turn, the one that paints the margins, took it
  off instead, and dropped the embossed frame and its rounded corners
  with it. Cut at correlation 0.97 and stamped with the take's own
  options. The back is stamped text and was recomposed as it stood —
  the install lozenge reads `./wb.sh add health_probe` and the strip
  v0.2.0, which the front no longer contradicts. In the cover record
  the takes keep the name they were made under (`healthcheck2-1`,
  `healthcheck-2`), since that is what the files in `_archived/` are
  called.

- **Ten boxes archived: the Phoenix line, and the two a newer box
  covers.** The first use of the state, and the pruning SCRIPT.md
  asked for (Phase 2). `chiefs_setup`, `rest`, `graphql`,
  `enhancements`, `auth0` and `openai` are the Phoenix line's —
  enhancements' Ecto generators and auth0's `users` table fight Ash's
  domain, the two APIs are `ash --api json_api|graphql` there, and
  auth0 and openai need an outside account a portfolio project cannot
  carry; the collection retires with the line it collected, so there is
  no collection on either line now. `mock` goes because test_doubles'
  box covers it, and the last two cartridges that composed it —
  enhancements and healthcheck — retire beside it, so nothing reaches
  it through the back door of `composes` either. `healthcheck` was one
  of two boxes for one need and healthcheck2's probes are the one the
  reference takes. `ansi` is out of the reference's selection, and
  `toolchain`'s two halves parted: version_manager carries the host's
  versions and the `.gitignore` entry comes back under a name of its
  own. Every one of the ten keeps its papers, with the line saying why
  at the head of its README — which is the whole reason the state
  exists. The shelf a new project is picked from is now the Ash line's
  and the boxes for both; of the Phoenix-line boxes only `exmachina`
  is still offered. SCRIPT.md's rows 2 and 15 and README/CONFIG's
  `add chiefs_setup` lines were corrected with them.

- **Colour on the plank says what you can have, not what you already
  took.** The shelf greyed every box that was not in the project —
  `grayscale(.92)` at `.6` — which spent the room's strongest mark on
  its most reversible fact, left the Cartridges screen a grey wall with
  two boxes lit, and made the cover art, which is most of the work a box
  carries, unreadable on the one screen that exists to show it. Now the
  whole shelf is in colour — inserted, on the shelf and not done alike —
  and the black and white is kept for the box that genuinely cannot be
  picked: the archived. That grey does not lift under the pointer, where
  the old one did: dimming that clears on hover reads as a state of the
  view, and this is a state of the cartridge. The list's thumbnails and
  the box picked up read the same grammar. And the accent ring is back
  on the inserted box: it was dropped when colour against grey was
  already the loudest thing on the plank, and with colour no longer
  saying what is in, that reason went with it — inset, so the covers
  keep their grid.

- **The versioning cartridge is `changelog`.** `wb.sh add changelog`,
  `mix workbench.install.changelog`, the box at
  `features/changelog/` and its art at `assets/covers/changelog/`. The
  box is named for what it puts in the project — a `CHANGELOG.md`,
  which is also the mark it looks for — instead of for the discipline
  around it: it cannot install SemVer, and the one part of versioning
  that cannot be automated, deciding when `0.1.0` becomes `0.2.0`, is
  the part its own NEED.md already says it does not do. On the shelf it
  no longer sits beside `version_manager` reading as its pair, which it
  never was: one opens a record of changes, the other writes
  `.tool-versions`. What it installs is unchanged, options included
  (cartridge v0.4.0).

  The box follows. The back is stamped text throughout and was
  recomposed as it stood — the install lozenge reads `./wb.sh add
  changelog` and the strip says v0.4.0 — but the front's lockup is
  painted into the art, not typeset by `covers.py`, so the hero was
  generated again with **one word** of the prompt changed, the title,
  and everything else left as the take that worked had written it. The
  word in the ship's log on the page stays `CHANGELOG`: there it is the
  file, in the lockup it is the box. What came back was not that one
  word: it is a new render of the same scene, lighter, the master lit
  from the front, a bookshelf and a pewter cup where the rope coil was.
  Kept, and the misses recorded beside it. The first take is archived
  as `cover-1`.

  The back's two screenshots are still real output of the old task
  name, and are the one thing on the box left to redo.

- **ecto's release one-shots are named for what they do: `create` and
  `volume_init`.** They were `database_init` and `data_init` — three
  letters apart, and variants of one word for two different jobs.

  MSSQL's is now **`create`**, which is what it is: an idempotent
  `CREATE DATABASE` run before the migrator, the other half of Ecto's
  own pair beside `migrate`, which has been called that all along and
  runs `bin/migrate` from `phx.gen.release`. Two verbs a reader already
  knows, in the order they happen. It shares a word with `docker
  compose create`, which is cosmetic: a service name is always in
  argument position, and `wb.sh` wraps the commands anyway.

  SQLite's is now **`volume_init`**, because `data_init` initialises no
  data — it hands `/app/data` to `nobody`, a named volume mounted where
  the image has no directory coming up owned by root while the release
  does not run as root. It stays a noun deliberately: `create` and
  `migrate` are Ecto operations, and this one is not, so the asymmetry
  says something true.

  Both named by the job and not by the engine, as ecto's `database` is
  — db_admin's adminer waits on `volume_init` because the volume has to
  be ready, not because the project is on SQLite.

- **A cartridge's Contents is a tree of its files.** The table at the
  foot of a cartridge's README draws the cartridge's own files as a
  tree — its directory, its `priv/`, its test, each a root after an
  empty row, 📁 for a directory and 📄 for a file — with each file's
  role beside it, kept to one line. Files the old tables left out
  (`NEED.md`, `CHANGELOG.md`, ecto's compose blocks, the shared
  `base_cartridges_test.exs`) are in it. Drawn in version_manager,
  versioning, dashboard_extras and the seven base cartridges; the rule
  is in the features README's anatomy. The console reads such a table
  as a tree (`Console.Papers.mark_trees/1`): the branch keeps its
  spaces and loses its code chip, and the rows close up so `│` runs on
  from one to the next. **The paper fills its column**: the Markdown
  block no longer stops at 68ch, and reaches the index — text, tables
  and code at one width.

- **A box's needs are the cartridges alone, and what is in says it by
  its box.** The mentions under the specs' Needs and a value that builds
  on what the project lacks both wore the `need` class — the one the
  need paper's panel is drawn with — so each came framed in its accent
  edge; they are `req` and `lacks` now, and the paper keeps its own. A
  value the project has lost its `in` tag: a box checked and shut says
  it, as it already did when the whole form is locked, and the only tag
  left is the one that says why a shut box is not checked (`needs ecto
  with database mysql`). A cartridge that adds on a second run (`rerun:
  adds`) with nothing left to add — every value in, or out of the
  project's reach, as db_admin with every admin its database serves —
  has its Add unlit, and the note says why.

- **The box's Manual comes before its Installation.** The drawer's row
  of screens read Box, Installation, Files, Manual — the papers last,
  after the form they explain. It reads Box, Manual, Installation,
  Files now: what the box is, what it says about itself, how it goes
  in, what it wrote. Only the order of the row; the URLs and the
  screens are the same.

- **versioning starts where the project is.** Its README said the
  generator's `0.1.0` was nobody's decision and defaulted the project
  to `0.0.0`; its DESIGN, written now with the sources, found that
  `0.1.0` is the start SemVer's own FAQ recommends — and that on a
  project already released the default took the number back. The box
  is told again from the problem it solves — a project with a version
  number and no versioning, new or two years in — and the option is
  `--init-version`, defaulting to the version `mix.exs` has, which is
  then left untouched; the rest (`--mix-task`, as `--task` is called
  now, and `--readme-badge`) are amenities. `state/1` reads where the history opens off the
  changelog's oldest title, and the opening entry no longer says
  "Brand new project created." of a project that may not be. The same
  research fixed three things: a version Mix would not compile is
  refused by the installer and by the planted `mix version` before
  anything is written; `version: @version` is read — by the shelf's
  `mix_project_value/2`, so exdoc's `@source_url` reads too — and
  written; and a pre-release's dash is doubled in the shields.io badge,
  which it used to break. A probe in a real project found a fourth:
  releases were dated by UTC's day, and are by the developer's now. A
  chiefs_setup project is born at `0.1.0` now, not `0.0.0` (versioning
  v0.3.0, 2026-09-18).
- **A cartridge does not name the collection that picks it.** Twenty
  READMEs and ten moduledocs said "a chiefs_setup pick", "not a
  chiefs_setup pick", or the argv the collection hands them. The
  knowledge runs one way: the collection names its members and their
  argv (`members/1`, its README), and the shelf's README says who picks
  what; a box says what it is, what it needs (an account, a URL) and
  what it excludes (rest and graphql), which is its own. ash's README
  names the two boxes it fights with, enhancements and auth0, instead
  of "the chiefs_setup picks". The CHANGELOGs keep theirs: history.
- **`--no-ecto` stands before `--database` on the Record's flags.** Ecto's
  own flag first, then the two that only mean something with it.

- **LiveView is html's option, not a box.** The `live` cartridge is
  gone into html as `--live`, on by default as in `phx.new`: `wb.sh add
  html` brings both, `--no-live` leaves LiveView out, and html run again
  on a project born `--no-live` adds it (`rerun: :adds`). In the
  generator live is `html && live`, a condition inside html's templates
  with no file and no dependency of its own — a decision that only
  exists inside another's is that other's option. `state/1` reads it
  back off LiveView's configuration, the block that was the box's mark;
  the esbuild notice moved with it; ash's `--auth` strategies and
  `--with ash_admin` require `{"html", live: true}`, and the refusal's
  remedy is `./wb.sh add html --live`. The shelf has seven base
  cartridges; the console's new-project card offers `--no-live` as
  html's switch, the way it offers ecto's `--database`, and the box's
  form can turn a switch that is on by default off. Cost, written in
  html's paper: LiveView is no longer ejected alone (html v0.2.0,
  2026-09-18).
- **Both images carry node and npm.** `ash --api typescript` failed
  inside the workbench's container with `:enoent` on `npm`: ash_typescript's
  installer, handed `--framework react`, hooks `npm install` into the
  project's `assets.setup`, and neither image had node. Debian's
  `nodejs` and `npm` join the shared first step of the project seed and
  the workbench's Dockerfile — the one apt line both open with, so the
  layer stays shared — rather than the workbench's alone, because
  `mix setup` runs `assets.setup` at every boot of the app's container
  too. The workbench image is rebuilt when missing, so an existing one
  is removed to take it; a workspace takes the seed on its next `bake`
  and `up`. The production Dockerfile is Phoenix's own and still knows
  no node: a project on TypeScript adds it there itself (2026-09-17).
- **`mix version` is versioning's, on request.** The task lived in
  enhancements, where it was a lodger and, worse, its mark: it moved to
  versioning as `--task`, since the version is that cartridge's
  decision and the task is the decision's tool, and was rewritten for a
  stock project — it writes the number into `mix.exs`, closes the
  changelog's `Unreleased` as that version under the commented
  template line, and updates the README badge only when there is one;
  it used to fail on any README without the badge the retired setup's
  template put there. `--readme-badge` puts that badge under the
  README's title. Both are pieces (`rerun: :adds`) and off by default,
  so a chiefs_setup project no longer gets the task: a recipe may not
  pass a member's switch, a limit to revisit. enhancements' mark is
  `test/support/fixtures.ex` now, the one file every shape of it
  writes (versioning v0.2.0, enhancements v1.0.0, 2026-09-17).
- **An eject that does not apply says where, and who wrote there.**
  `eject ecto` on a project that took seven cartridges after it said
  only that files had changed since. Now, before the revert is
  abandoned, it names each file in conflict with the lines the markers
  enclose and who wrote there after the insert — the cartridges that
  came later, newest first, which is the order to eject them in, or a
  commit of the reader's own by its subject. On that project:
  `.formatter.exs` by html; `AGENTS.md` by live, tailwind, html;
  `mix.exs` and `mix.lock` by six. Not one of them an edit by hand —
  a cartridge appends where the one before it ended, and git's revert
  cannot tell that apart from an edit. Ejecting what came after first
  is the way for now; a base cartridge undone as it was done, the
  delta the other way round, is the next.
- **Stop stands before Down on a deployment's row.** Bake, Build, Stop,
  Down: the one that keeps the containers before the one that removes
  them. Down stood first since the order turned on 2026-09-10.

- **The terminal's sixteen are Nord's, and a Nord light of the
  house's making on paper.** `Console.ANSI` told the sixteen colours
  apart already; the sheet painted the bright row with the normal
  row's and gave black and white nothing. Each has its token now, a
  ground each. Nord was chosen among the five most ported terminal
  themes on `console/temas-de-terminal.html` — Catppuccin, Tokyo
  Night, Gruvbox, Nord, Dracula, against the house's own, each with
  its contrasts on the console's grounds — for its sobriety and its
  fit with the console; its red reads 4.7:1 on the dark ground, just
  over the line. Nord has no light, so the house derives one: Nord's
  hues deepened on paper to 6:1 the normal row and 4.5:1 the bright,
  with a floor on saturation so the muted hues do not turn to mud,
  and Polar Night and Snow Storm for ink, black and white
  (`assets/design/palette.py`, `nord_light`). Dim (SGR 2) is opacity
  now, so a dim red stays red. The- **The Docker screen's controls are the daemon's box's,** in a strip
  under its lines, the way the Logs screen and a job's output carry
  theirs: This workspace, The daemon and, on Containers, Stats, one
  framed box over every document. And on Images a name links to its
  page at the registry where there is one: Docker Hub's official
  images (`postgres:16`) and repositories (`hexpm/elixir`), Microsoft's
  registry for SQL Server; a local image, the workbench's own, or a
  registry with no page stay names.
- **The disk is in the daemon's box.** The four rows of `docker system
  df` — images, containers, volumes, build cache, each with its count,
  size, how many are in use and what is reclaimable — were a table
  under Volumes; they are four lines of the daemon's box now, over
  every document of the Docker screen, after the storage line that
  names the root. Measured once per visit, saying so until it lands —
  seconds, tens of them on a daemon with a hundred volumes — and again
  after a job of the verbs that move the disk: up, build, bake, new,
  delete, prune, a removal, an insert or eject, mix.
- **A container's ports on the Docker screen wear no square.** The
  address kept the rail's shape but its square was painted in the
  service's colour, the same mark with another meaning; the table is
  Docker's view, every port a published one, and the service is the
  row's first column. The square goes, the address stays.
- **The pod's service is `pod`.** The pause container that owns the
  workspace's network namespace was the service `network`, the word
  Compose and Docker use for a network: `network_mode: service:network`
  read as a riddle, and a `network` row on the console read as a
  network. It is `pod` now, in the compose template, its fixtures, the
  console (the container's order, its shell-less row, its restart's
  reason, the colour its log lines wear, `svc-pod` in the tokens) and
  the igniter's README. A workspace baked before keeps `network` in its
  files until its next `bake`; a deployment that is up then must come
  down before the next `up`, since its old container holds the ports
  the new `pod` publishes — `up` says so and refuses, rather than
  failing on the ports after the build.
- **The door on the host is the app's.** A port the compose publishes
  belongs to the service that listens on it, not to the one that
  declares it: in the pod the `network` container owns the network
  namespace and so declares every port, and Services & Doors and the
  Record's deployments said `network localhost:4000` with `app` inside.
  Now `app` wears `localhost:4000`, and Services & Doors lists only the
  doors on the host — the ports the compose publishes and the routes;
  a port inside the pod (`database :5432`), the pod itself and the
  one-shot `migrate` are on Containers and on the Deployments sheet,
  the whole map, where an inside port wears the hollow square. The
  Docker screen keeps Docker's own view. A port no service claims
  stays with its publisher.
- **A port inside the pod wears a hollow square.** On Services &
  Doors and the Record's addresses, a service the compose publishes on
  the host (`localhost:4001`) keeps its solid blue square, and one
  whose port lives inside the pod only (`:5432`) wears the same blue as
  an outline: the layer kept, the opening not. It was one solid square
  for both, told apart only by which could be pressed. A third kind of
  address, `inside`, beside `route` and `port`.
- **Project before Cartridges in the tab row.** The two swap places:
  Deploy, Jobs, Logs, Terminal, Project, Cartridges, Cluster, Docker,
  in the miniature of the Interface tab too.
- **`./wb.sh help` reads like a CLI's.** One line of summary a
  command, in the imperative, and its options in an aligned list with
  their defaults; the reasons and the history went where they were
  already, the README and this file. Every command and option is
  still there, in 170 lines where there were 284, and the entries
  written first — `login`, `demo`, `delete`, `help` — read in the
  same voice as the rest, each body indented under its command as a
  man page does. The headings are the usual ones (SYNOPSIS for
  SYNTAXIS), and 'Defalut' is spelled at last. And the script's colour
  codes go out only when a terminal reads them — stdout a tty,
  `NO_COLOR` unset, `TERM` not dumb — or when `WB_ANSI=always` asks,
  as the console's jobs do; `help | less` and a script capturing
  `status` get plain text.
- **The workbench and the project have an image each, from a
  Dockerfile each.** The workbench's is
  `dew-exELIXIR-erlOTP-phxVERSION:WORKBENCH` — the stack and the
  installer name the repository, so `docker images` lists one line per
  pair, and the workbench's own version is the tag, so a new workbench
  builds its own and an old one keeps what it ran on (it was
  `dockerized-elixir-workbench:exELIXIR-erlOTP-phxVERSION` until
  2026-09-15) — built straight from `scripts/Dockerfile.workbench` with
  the stack and the installer as build arguments: the toolchain,
  phx_new, and the Docker CLI with buildx and compose. Everything the workbench does in a
  container of its own runs there, `add`, `expand`, git and the
  catalog included, and so does the console; its image is built on the
  first command that needs it. The project's `Dockerfile.local` keeps
  only what the app uses: no phx_new, no Docker CLI, no workbench
  directories, no default-branch setting, and the `ARG PHX_NEW` line
  stays as the record of its generator. Its compose builds it on the
  first `up`, from the same first steps, so the two images share those
  layers. There were two images before as well, `workbench:…` and
  `workbench-console:…` built on it, and they read as two versions of
  one thing: the second named neither its base nor its installer, and
  the project's image was an alias of the first, carrying the
  generator it never runs. `console/Dockerfile` is gone. With no
  project to name an installer, the image is the one config.conf names
  or the newest the daemon has for the stack. And wb.sh runs a command
  in the console's own container only when it asks for the image the
  console runs on: a `new` that resolves another phx_new, or a stack
  changed in config.conf, goes to a container of its own image instead
  of generating with the wrong one (2026-09-14). The Terminal tab's
  one-off target, when nothing runs, is **workbench** and not
  toolchain: a container of the workbench's image with the workbench
  mounted and its build volumes over `_build` and `deps`, as wb.sh's
  own runs have. It was a container of the app's dev image with the
  source alone, so an `iex -S mix` there compiled through the bind
  mount into the workspace's own directory, and since the dev image is
  built on the first `up`, it had no image at all right after `new`.
  The resident, away from the console's mount, runs on the same image
  for the same reason (2026-09-15).
- **A job's verbs are buttons in a strip under its output**, inside
  the frame, the strip the Logs and Terminal boxes have: Run it and
  Drop it while it waits for a word, Drop it while it waits its turn,
  Stop it while it runs — and, asked, Stop it beside Let it finish —
  Run it again when it stopped or failed. They were a line of prose
  with underlined links under the last line of output, inside the pane
  that scrolls under the reader's cap, so on a long job Stop it was at
  the foot of hundreds of lines. The strip stays in sight; its few
  words say where the job stands, the reason at length rides on the
  button, and a job that ended well wears no strip. The same in the
  three places a job is read: the Jobs screen, a cartridge's box, the
  tray (2026-09-12).
- **Every terminal session is its own process, and the buttons switch
  between them.** A session is one per container and shell — `app ·
  bash`, `app · iex`, `database · psql` — under `Console.Terminals`, a
  supervisor of the console's and not the page's: it holds the Port
  and the last 2000 lines of its screen, so reloading the page, changing
  tab or losing the socket leaves the `iex -S mix` where it was. The
  container and shell buttons are never dark while a session runs; each
  wears its sessions — a full dot where the process runs, a hollow one
  where it ended with its trail — and pressing one switches the screen
  to what that session has, its own ↑↓ history with it. A container
  pressed opens on the shell with a session there, else on its first
  shell, so the database opens on psql again. When the process in the
  container ends the session stays with its trail and the exit code
  until Open a session replaces it or Discard forgets it, and a
  container that left the status keeps its button while a session on it
  is there. Ctrl+L forgets the trail, so coming back reads the same. The
  meta line counts the others open, and the Terminal tab pulses while
  any session runs, from every screen (2026-09-12).
- **The Project tab's papers are Birth, History and Changes.** The
  first was Record, a name for the three sections it once held: the
  deployments went to Deploy and the cartridges to the shelf, and what
  was left was the birth, so the paper is called that and its one
  heading reads as a line, *Born 2026-09-08 07:44 at 1a0546c*. The
  third was Pending, a word the jobs tray already uses for a job that
  waits to be confirmed; Changes is what a commit would take, the term
  every git client uses, and the sublabel still says *clean* or how
  many files. History keeps its name: Git left the label on 2026-09-09
  because the repository is the project's, and the HEAD in the
  sublabel says whose history it is. The rail's button follows,
  *Commit changes*; the keys in the URL do not move.
- **The Interface tab is the controls on the left and the console in
  miniature on the right.** It was a column of seven rows, 1647px tall
  in a pane of 695 — two screens and a half for four things: the frame,
  the ground, the type, the colours. Now the column is 320px, the grid
  the drawer's body already reserves, and scrolls on its own; beside it
  a fifth of the console — the band, the rail, a terminal and a sheet —
  drawn from the same body classes and root properties the screen
  reads, so what is set on the left lands on the right where it will
  land on the screen. The frame's three toggles, each a sentence to
  read before clicking, are two segmented controls with a pictogram per
  position, the band's two and the rail's three — hidden is a position
  of the rail, not a setting of its own — the way DevTools docks its
  panel; the miniature's band and rail are controls too. The ground is
  three cards with a thumbnail, Light, Dark and System, and the third
  puts back the state the console boots in, which once a choice was
  made could not be had again. The type's two profiles keep their
  picks; their samples are now the miniature's terminal, real lines —
  a warning of Elixir's compiler as a terminal colours it, a Phoenix
  boot, a request, an error of Bandit's — drawn as the Logs screen
  draws them, and the miniature's sheet, the Files sheet's own drawing
  of the tab's sample, gutters and all: the old sample was a `pre` with
  three colours that looked like no surface of the console. The
  colours' twelve roles read in two columns under their language, and
  the jsonc box — 96px and three buttons always in view for what is
  done once — folds behind the house's `.fold`. Decided on 2026-09-12
  among four compositions drawn on the real content: the sibling
  Config's row grammar, three docked tabs, this, and a booklet with an
  index; this one shows the most, at the cost of a second drawing of
  the frame that has to follow the first.

- **The square icon button is one component, and its drawings are
  files.** Six squares sat in five rules of the console's CSS — the
  knock's bell on the rail and the shelf, the eye on a compose file,
  the cog on a given, the reload of a fetch, the `×` of the jobs bar
  and the rail's toggle — four with a drawing inline and two with a
  character set in the body face, and `.go` named both the squares and
  the golden GO. Now `ConsoleWeb.Square` draws every one: a mark from
  a sprite, `console/priv/static/images/icons.svg`, that
  `assets/design/build.py` gathers from one file a drawing under
  `assets/design/icons/`, and a name for the screen reader that the
  component will not go without. What a square is — `.sq`, 2em of its
  neighbour's type — is the house's, in `components.css` and
  the design README; where each stands stays the console's. Its size
  is the field's height, 2.5em of the field's type in whole pixels,
  which the reload had and every square has now, so the mark sits
  centred; a section head with a bell is as tall as the bell and
  centres on it. A second size, small, is a line's, 2em of 11px: the
  jobs bar's `×`, the cogs on New Project's rows, the two knocks, and
  the folds of the rail's sections, which were a caret on the head and
  are a small square at its edge now, the caret drawn from its
  `aria-expanded` and turned when folded; the head still folds where
  it is pressed, since it carries the same click itself — LiveView
  fires only the binding closest to the click, so the knock's bell
  keeps its own. (A hit layer over the head did this for an hour and
  sat over the bell whatever its z-index said.) The `×`
  is a drawing now, at the weight the other marks have.

- **On History, the commit whose diff is open folds it when pressed
  again.** The mention led to the same address twice, so a second press
  did nothing; open, it now leads to History without a commit, wears
  `aria-pressed`, and its title says so.

- **The terminal's and the Logs screen's controls are inside their
  box.** What to open a session on, with what, and the opening sit in a
  strip under the terminal's command line; the services, the level,
  the search, Following, Timestamps and Clear in a strip under the
  lines of Logs; the services alone in a strip on top of each box,
  Logs' chips and the terminal's containers. The row above each box is gone, and so are the two
  boxes' words for being empty. On the Files sheet the file's row no
  longer draws a line under itself: the row's ground is the edge. And
  the rail's toggle is two squares, Left then Right always, each
  drawing the frame it would set with the rail's column solid: the
  other side moves the rail, the side it is on puts it away, and
  either brings it back on its own side; the one in force is pressed. A file's
  row on the Files sheet carries its caret at the far end, past the
  counts, as a job's row does, and folds wherever it is pressed but on
  a cartridge's mention. And a changed line tints its number plates too, a
  shade deeper than the line, as GitHub does, so the ruler shows where
  the changes are when the code has scrolled off to the right.

- **The Jobs screen lists its jobs in the framed list a box's Runs
  are.** The rows were one component already — the same chip, number,
  fold, grip and words at the foot — but the box framed them, a
  hairline and a rounded corner hugging the rows, and the Jobs screen
  ran the same rows unframed across its viewport, 28px in from either
  side, a table without an end. The frame is `.jobs-list` now, in both
  places, flush with the command line and the count above it; the
  viewport keeps the pane's air above and below. And on the
  Files sheet the line numbers' plate is the file row's own ground,
  so ruler and row read as one furniture around the text.

- **The rail's air is 22px on both sides.** Its right padding gives
  back the gutter the rail keeps for its scrollbar, measured by the
  Rail hook, so the content no longer stood 37px from the right edge
  and 22 from the left; the rail's toggle and the section heads' squares
  share that edge. And the danger zone on Deploy wears its red on the
  left edge, as the house marks a block, not along the top.

- **The Logs screen's service column is as wide as the longest service
  name**, in the face's own characters — it was 72px whatever the
  names, so every message stood a hand's width from a short one — and
  the Interface tab's miniature draws the same column: its terminal now
  carries lines of the database and of pgadmin beside the app's, each
  in its service's colour, with the Logs screen's own service chips
  above them, pressed to show, and its Timestamps button, as on the
  screen; its band is the band — the mark, the name, the state, the
  clock, the two cells — and its tabs are the screens' (2026-09-12), and between its terminal and its sheet the Jobs screen's
  grip, which splits the screen between the two and keeps the split
  in this browser; and its sheet shows
  every language's sample as a patch, one line changed — a removal and
  an addition, the Files sheet's colours — with the hunk and the count
  on the file's row, as the sheet has them. And the sheet's two
  number columns, on the Files sheet and in the miniature alike, are
  as wide as the file's widest line number — they were 3.4em for any
  file, a plate three digits wide beside a file of twelve lines — and
  never narrower than two digits, the way GitHub sizes a gutter; the
  number sits centred in its plate, a size smaller than the code, and
  the plates run to the sheet's edges, with no air above the first
  line or under the last. The tab's sections read Terminal, Code
  Files and Language Syntax (2026-09-12). And the rail has a toggle in
  its corner, the way hexdocs folds its sidebar: the same square puts
  the rail away and, from the screen's corner, brings it back — the
  tab's Hidden, kept the same way, and the two agree whichever was
  pressed.

- **The jobs tray is on every screen but Jobs**, once anything has run
  — it kept to the screens that start jobs, and a job's answer went
  unseen on the others — and the bar's link to Jobs is a square that
  puts the tray away until the next job. Its fold is the last job's:
  kept while the tray is put away, and what the Jobs screen opens that
  job to on arrival; folding the last job there folds the tray. The
  chip on the bar is the job's own, as its row wears it (`exit 0`,
  `exit 2`, `running`), no longer a count of the list, and the bar's
  title is gone. The box sits to the bar as a job's output sits to its
  row, 7px, and a row on the Jobs screen ends as close under its box.
- **A flag in ink, what follows it dimmed.** The installation
  parameters read `--endpoint` with `/health` dimmed after it — on the
  shelf the type or the values in its place — and the Birth table's
  arguments the same; a flag at its default is said in its title, no
  longer by dimming the whole flag. The `in` mark beside a choice goes
  when the box is locked: everything checked is in.
- **The rail's Containers section drops its note** — *No deployment is
  up and these are still here: Deploy → Down removes them* — written
  when the Deployments section could only say `down`. It reads
  `stopped` on the deployment whose containers are there, with Up and
  Down lit, and the note only offered the destructive one.
- **`state/1` is what the project carries of a cartridge's options,
  and every cartridge with options answers it.** The contract called
  it optional — "for an `:adds` cartridge", `%{}` by default — while
  four readers depended on it: the status, the console's Inserted
  list, a door's `{option}` path and `services/1`. A silence read as
  an answer, and eight cartridges with options were silent: rest,
  coveralls, exdoc, guidelines, enhancements, auth0, openai and
  clustering. The contract (`WorkbenchIgniter.Feature`, the features
  README) says now: required of every cartridge whose `info/2`
  declares a schema, exactly the schema's keys, each with what was
  found — a string, a list, `true`/`false` — or `nil` for an option
  that leaves no mark the project keeps, said beside the read. Every
  read is off a mark the project has for its own sake, never a record
  kept for the workbench: rest reads the title, the bearer scheme and
  the tags off its `OpenApi.Spec`; coveralls the minimum and the
  skipped folder off `coveralls.json`, the `mix cover` task, and the
  theme by matching the planted report template against its own;
  exdoc the name and `source_url` off `mix.exs`, the `cover` action,
  the token page; enhancements the key and timestamp types and
  `@before_compile` off `MyApp.Schema`, the interface off the error
  view's shape, auth0 and openai off the model's tables or the Postman
  collection's sections, health off the collection; auth0 and openai
  `rest` off their controller; clustering the query off `.env`, or
  `.env.sample` when `.env` is not there. healthcheck says `open_api:
  false` now instead of leaving the key out, and versioning reads its
  version through the new `WorkbenchIgniter.Feature.mix_project_value/2`,
  which exdoc shares; `file_content/2` is the other helper the reads
  share. Two options turn out to be dead — auth0's and openai's
  `--project-name`, read by no template — and are reported as such
  rather than removed: that is phase 2's.
- **What a cartridge composes is in its manifest: `composes`.**
  healthcheck, coveralls and enhancements insert mock from inside their
  installer, and nothing outside the installer knew: the catalog entry
  carries `composes` now, read off the `composes` each installer's
  `info/2` already declares to Igniter (the collection's members are
  its recipe, not this), and `mix workbench.status --json` prints it.
  It is not `requires`: that says what must be in first and the
  installer refuses without, this says what the cartridge brings along.
- **The compose files read under the Record's deployments, not under
  Docker.** Docker's *Deploys* document — the three files as a YAML
  sheet with the secrets masked, one picked on a toolbar — moves whole
  to the Record, under the deployments table, where each row is
  already the file's summary; the files are the workspace's, not the
  daemon's, and Docker keeps its five documents. The table and the
  file are one sheet, `ConsoleWeb.Deployments`: an eye on every row
  before the file's chip opens that file in a code box under its row,
  wearing its name — pressed on the one open, and pressed again it
  closes; unlit with the remedy while not baked. One box at a time
  and none until the reader asks, named in the URL
  (`/deploy?compose=prod`). The box is as tall as the reader leaves it, with the
  jobs' own grip under it — the `JobOut` hook now rides any pane
  wearing `data-tall`, and the compose box keeps its height across
  papers where a job that has left the tray is forgotten. A status
  arriving reads the files again, since a bake may have rewritten one. In the same round the rail and the Record share
  the deployment row — up, stopped or down; Up or Stop, Down and Bake —
  every sha the console shows is a `.commit-ref`, the rail's Cartridges
  wear the facts chips before the origin, and the rail's Services &
  Doors lists one address a line.
- **The deployments read on the Deploy tab, one card that picks and
  shows.** The table — each compose file baked or not, in sync or
  drifted, up, stopped or down, its services, and Stop, Down and Bake
  on its row — and the file's box under a row leave the Record for the
  Deploy tab, where the reader is when the question is what is baked
  and running; the Record keeps what the project *is*, its birth and
  its cartridges. There it folds the Deployment card into itself: the
  three boxes of the picker were the table's three rows again, so the
  row carries the radio, what the deployment is under its name, and
  scaled's replicas and balancer; Up and Build of the row picked sit
  under the table with the `wb.sh` line they are, and the "nothing is
  up" chip goes, the status column says it row by row. The open file
  is `/deploy?compose=prod`, read when the tab is taken and again when
  a status arrives. The table is the tab's, not the project's: with
  the workspace empty its three rows are there, not baked, every eye
  and button unlit with the one reason.
- **`bake --deploy prod|scaled` bakes that file alone.** The prod and
  scaled composes were written only on the way to their own `up` or
  `build`, so the console's Bake button on those rows had to send
  `build --deploy`, and built the release image to rewrite a YAML.
  `bake` takes `--deploy` now, with `--replicas` and `--no-balancer`
  for scaled, writes that file for the project as it is now — its
  ports kept — and commits it as it commits the dev file; a file that
  already says what the project asks for is left alone. The image the
  file names stays `build --deploy`'s, or up's. The three Bake buttons
  send `bake` and say the same thing. A prod or scaled file an `up`
  left untracked has to be committed before, as any bake asks.
- **What comes off the project is dimmed while it is being read
  again.** A full status boots Mix in a container and takes seconds;
  a fast one lands meanwhile — the daemon's events ask for one — and
  carries the project's facts as they were, so a row said *baked* for
  the seconds between an insert and the reading that knew of it. The
  facts that only a full reading changes — the compose file in sync or
  not and its differences, on the Deploy tab and in the rail, the
  cartridges in the rail and on the Record — wear `.stale` while one
  is in flight: dimmed, with "reading the project again" in the title,
  and pressable still, which is why it is not `.unlit`. Unlit, not
  asserted.
- **A service's web face is a door.** pgAdmin and Grafana publish a port
  on the host, and the status already names it (`ports.pgadmin`,
  `ports.grafana`): the cartridge's row now wears it as a door, `PGADMIN
  :5050/`, opened by the reader and read by the knock like any route —
  the root answers a redirect, which is an answer — and shut with the
  reason while its container is not running. Nothing is asked of the
  cartridge: the compose service it already brings says it all. The
  layer's rule is restated with it (`assets/design/README.md`): violet
  is an address the reader opens and the knock reads by HTTP, whoever
  offers it; blue is a service's port, read off `docker compose ps` —
  what the face does, not who offers it. So the same pgAdmin is a
  violet door on its cartridge's row and a blue port on its
  deployment's. On the way the Record's table of inside ports said
  pgAdmin `:80`, the image's default; the compose has it listen on
  5050.
- **Knock: the doors are called only when the reader rings.** One
  reading for the whole page, shared by the rail's Services & Doors and
  the Record's addresses, and taken only when the reader presses the
  bell on either — the square button of `.fetch`, wearing a bell now,
  ringing while the knock is out. Never on a mount, a status or a
  clock: every call lands in the app's logs, and a line the reader did
  not cause is noise there (an automatic knock lasted a day). A status
  arriving wipes what was heard, since a job changed the world. What
  each door answered goes on its face in both places. Deployments in
  the rail and on the Record gain Bake, Stop and Down beside Up — Stop
  keeps the containers, Down removes them and is lit only while there
  are some — and the rail opens with Services & Doors, the workspace's
  own app link gone since the section's first line is that port.
- **The rail's Inserted is Cartridges, Doors is Services & Doors, and
  Deployments says in sync.** *Cartridges*: the mention, then the
  origin, then the edition, the Record's order. *Deployments* gains the
  in-sync check beside the file's chip — baked, out of sync or not baked,
  as on the paper — under column heads. *Services & Doors* is the old
  Doors section widened: first the services of the deployment that is
  up (dev's file when none is) as ports with what `docker compose ps`
  says of each, then every door the inserted cartridges open, with the
  mention of who opened it — the Record's faces, without a reading on
  the doors since the rail calls nothing. Putting each address under
  its own cartridge or deployment was tried first and does not fit: at
  380px a port face is wider than the columns beside it.
  `ConsoleWeb.Record.addresses/4` and `deployments/1` are the rows,
  lent to the rail and the paper alike.
- **The Project card on Deploy is intention again.** Its rows say what
  the next `new` would use, off config.conf and nothing else: the
  installer row no longer answers with the stamp of the project born
  here, which was the state slipping into the form. What this project
  is has its paper now, and the card links to it — "what it is", the
  Record. One crossing stays, because it is about creating: the warn on
  the stack row when the project was built on another one, since
  creating again would move it.
- **Git's two documents are papers of the Project tab.** The repository
  is the project's, so Pending and History follow Record, .env, README
  and CHANGELOG on the Project ribbon, and the Git tab goes; the top row
  reads Deploy, Jobs, Logs, Terminal, Cartridges, Project, Cluster,
  Docker. Pending's sublabel is the tree (clean, dirty, or the files a
  commit would take), History's the HEAD. `/project?paper=history&commit=SHA`
  opens History on that commit with its diff — where a `.commit-ref`
  lands, the Record's birth first. Without a repository the two are
  unlit with the reason, as CHANGELOG is without its file. The rail's
  "Commit pending changes" lands on Pending. `ConsoleWeb.GitScreen` keeps
  the two documents, `git_pending/1` and `git_history/1`;
  `Console.Project.carried/1` reads the status now, since which papers
  there are depends on the project and its repository, not on files
  alone.
- **The address component: one face, the layer as a square, the reading
  attached.** `.door-ref` in the design system now says which layer
  answers at an address — an 8px square before the label, the mark the
  logs' service filter already uses: violet (`addr-route`) for a route
  the project offers on the app's port, blue (`addr-port`) for a port
  the compose publishes — and carries what the address answered
  *inside* its border, at the right edge, as the chip's plate behind the
  box's own line, so a reading in a wrapping row can never drift to the
  wrong door. A route is written on its port, `:4001/dev/mailbox`. The
  two roles join `tokens.json`; `Refs.door_ref/1` takes `kind`, `port`
  and `read`; the rail's and Doors' own addresses are ports. `.probe-ref`
  is gone from `components.css` with the probe itself, and
  `assets/design/puertas-y-sondas.html` — the page that split door from
  probe on the premise that nobody presses a probe — is superseded by
  the Record paper's finding that the premise was false. New beside the
  two references: `.commit-ref`, a mention of a commit — the short sha,
  boxed because it opens History on that commit with its diff, the
  subject and date in the title — and `Refs.commit_ref/1`, for every
  place a sha was written by hand.
- **The daemon is set as code, a key a line.** Docker's version and
  platform, the host's CPUs and memory, the storage driver and its root,
  the OS and the kernel sat in one sentence, a note at the toolbar's
  right cut with an ellipsis at any width the rail left. They are a
  `.code-box` now — the terminal's ground and face in a row of their own
  under the scope buttons — five lines, `docker`, `host`, `storage`,
  `os`, `kernel`, the key dim in a column of nine cells.
  `Console.Docker.daemon/0` returns those pairs instead of the sentence.
- **The subordinate row's open tab is outlined.** The `docked` ribbon —
  a screen's documents, a box's papers — drew its selected tab as a fill
  that opened into the pane; it now carries the row's own hairline on
  its left, right and top too, a folder tab closed on three sides.
- **Git is the first fold of the rail.** Under the workspace, the
  rail's sections read Git, Doors, Deployments, Containers, Inserted;
  the tree and the branch used to sit fourth.
- **The compose files are rendered by the igniter, not carved by `sed`.**
  Step 1 of `scripts/PLAN.md`: `mix workbench.compose` renders the dev,
  prod and scaled files from EEx templates under `igniter/priv/compose/`
  — one skeleton per topology, the pod and the bridge — off flags
  alone, and `wb.sh`'s three bakes hand it what they still decide: the
  ports, the images, the two facts they grep off the project. The seeds
  and their range deletions are gone; a bake that fails leaves the file
  as it was. The output is the same to the byte: thirteen fixtures
  under `igniter/test/fixtures/compose/`, generated from the bash bake
  before it went (`test/support/compose_golden.sh`), are what the
  templates are tested against. The one cost: a bake is a run of the
  package in the toolchain image, seconds, where it was a `sed`.
- **The compose serves every adapter ecto offers.** Step 4 of
  `scripts/PLAN.md`. Ecto declares its engine as the service it needs —
  `postgres`, `mysql`, `mssql`, or `sqlite` for a place to keep the
  file — and the compose runs the server as `database` with a
  healthcheck of its own: MySQL pinged over TCP, since its image's init
  answers on the socket before the real server listens (the same trap
  `pg_isready -h` avoids); SQL Server through `sqlcmd`, with a one-shot
  `database_init` in the release deployments because its image creates
  no database. Each is configured to phx.new's own dev credentials, so
  the project's configuration stays untouched, and the release's
  `DATABASE_URL` — written by ecto's installer and by `new` off one
  table now — matches; `new --database mysql` used to get a Postgres
  URL. On SQLite the production deployment mounts a `data` volume,
  chowns it for the release's `nobody` in a one-shot `data_init`, and
  migrates as with a server; a scaled deployment refuses SQLite.
  `MYSQL_IMAGE_VERSION` and `MSSQL_IMAGE_VERSION` join `config.conf`.
  Run for real on 2026-09-07, each engine through `new`, `up` and
  `up --deploy prod`: SQL Server's first start on a fresh volume
  outlasted its healthcheck's retries and compose gave up on it, so its
  healthcheck carries a `start_period` of three minutes now, as the
  app's does — and so do MySQL's (90 s: its first start initialises the
  data directory and runs a temporary server first, longer than its
  retries allowed on a busy host, so the job failed and the next `up`
  found it healthy) and Postgres's (30 s). The images run as they come,
  no init switches: the allowance is the whole fix.
- **pgadmin and k6 are cartridges.** Step 3 of `scripts/PLAN.md`: the
  first two cartridges that bring a container rather than Elixir code.
  **pgadmin** installs `pgadmin/servers.json` — the servers pgAdmin
  opens with, which the compose used to carry inline — requires ecto on
  postgres, and asks for the `pgadmin` service; ecto asks for `postgres`
  alone now, so a vanilla `new` brings the database and no pgAdmin, and
  `chiefs_setup` inserts pgadmin among its picks. **k6** installs
  `k6/smoke.js` and asks for a `k6` service under a compose profile
  `up` never starts, with the project's `k6/` mounted as its scripts and
  `BASE_URL` set for the topology — `localhost` in the pod, the balancer
  or the `app` alias on the bridge. `./wb.sh k6 [--deploy TARGET]
  [SCRIPT] [K6_OPTIONS...]` runs one against the deployment that is up;
  the console knows the verb. `K6_IMAGE_VERSION` joins `config.conf`.
  The no-database compose files lose the dangling `configs:` block the
  bash left. Neither cartridge has a cover yet.
- **The cartridges say which services the compose carries.** Step 2 of
  `scripts/PLAN.md`. A cartridge's manifest gains `services/1`: the
  compose services it needs, by name, given its state — ecto on
  postgres asks for `postgres` and `pgadmin` (the latter rides along
  until it is a cartridge of its own), any other adapter for none. The
  status publishes the list (`status --json`'s `project.services`, the
  resident's answer, a `Services:` line in the listing), and
  `mix workbench.compose` reads it off the project when its `--services`
  flag is not given — which is how `wb.sh` calls it now, on the project,
  writing into the workspace with `--out`. The grep over `config.exs`
  and `mix.exs` that decided the database is gone; so is the guess it
  made for mysql and mssql, which got a Postgres they never used. The
  published ports are read back off the file a bake rewrites — the prod
  file's pgAdmin port too, which used to be chosen anew each time — and
  `add` says the compose is behind by rendering it again and comparing,
  not by grepping for a service.

- **The console's LiveView is split by screen.** `ConsoleWeb.ConsoleLive`
  held every screen's state handling in one module of 1 500 lines. Each
  screen's state now lives under its name — `ConsoleWeb.ConsoleLive.Docker`,
  `.Git`, `.Term`, `.Drawer` (the workbench's) and `.Hand` (the box in
  hand) — with `take/2` off the URL, `event/3`, `info/2` and `async/3`,
  and the LiveView delegates by event prefix. The band's state pill and
  the Logs screen are components of their own (`ConsoleWeb.Band`,
  `ConsoleWeb.LogsScreen`). Nothing changes on the page.
- **The scripts are ShellCheck-clean**, style findings included:
  variables quoted where a value is one word, arrays where a string was
  split on purpose (`CONTAINER_ENTRYPOINT`, `DOCKER_TTY_FLAGS`,
  `BUILD_VOLUMES`, `SESSION_COMMAND`), `read -r`, `cd … || exit`, `$*`
  where `$@` sat inside a string, and the unused `REPO_URL` and
  `ENTRYPOINT_COMMAND` gone. The few lines that split on purpose carry a
  directive saying so.
- **Both packages are formatted**, the console's heex included — the
  first time the HTML formatter ran over its components. Three
  interpolations it broke into a stair are helpers now (`probe_word/1`,
  `files_word/1`, the drawer's prose parts), and the igniter's
  `template/2` compiles its EEx and evaluates it apart, since
  `EEx.eval_string/3` hands its options to `Code.eval_quoted/3` and
  dialyzer read every installer that renders a template as code that
  never returns.
- **Credo's refactoring findings addressed.** In the igniter: the
  member's question in `workbench.expand` is a function of its own,
  `.gitignore` and the env files share one `append_entry/4`, the ash
  site comparison judges one feature per function, `PhxDelta` reads a
  file's secrets and merges one changed file in functions of their own,
  and two `cond`s with one condition are `if`s. In the console: the
  long readers — `Docker.card/1`, `Diffs.worktree/1`, `Config.line/2`,
  `Box.argv/2`, the LiveView's mount and status handler — are split
  along the seams they had, `with`s of one clause are `case`s, and
  `Jobs.signal/2` calls `System.cmd/3` instead of `:os.cmd/1`. No check
  was relaxed and no line carries a disable directive.

- **The workbench compiles into its own build.** Two BEAMs compiled the
  workspace into one `_build`: the app service, and the console's
  resident — with every `mix` the console ran in-process, and every
  one-off `add` from the host, which ran as the compose's `app`. They
  were kept apart by Mix's build lock alone, which exists since Elixir
  1.18 and nothing required. Every run of the workbench now compiles
  into `<project>_workbench_build`, a volume of its own labelled under
  the project for `prune`, mounted over `_build` in the console's
  container and in the one-off runs; the app's `build` volume is the
  app's alone. `add` and `expand` from the host run on the workspace's
  dev image directly, no longer as a compose one-off waiting for the
  database they never used. The two sides share `deps/` — sources only,
  and only `deps.get` writes there — so `stacks use` and `new` refuse
  an Elixir below 1.18, where Mix locks that directory too. The price:
  what an insert changes compiles twice, incrementally; a build's worth
  of disk per workspace; the first `up` after `new` compiles the
  project once more. `prune --build` and `delete` remove the new volume.
  The resident stays, and `console/PLAN.md` says why `:erpc` does not
  replace it.
- **A deployment's row keeps its three buttons, in the order the row
  is read.** Bake, Down and Stop — Bake answers the compose file's
  column, Down and Stop answer the status column, so the group no
  longer has to be read backwards to pair each button with its motive;
  the rail's short row does the same, with Up and Stop sharing one
  slot, the state saying which. A verb the row cannot do now is unlit
  with its reason instead of gone: *not baked: Bake writes its compose
  file first*, *not up: nothing to stop*, *nothing to take down: no
  containers of this deployment*. The three slots hold still down the
  table, and a row says what it could do, not only what it can. Three
  buttons in a line is what the row wants, not what it needs: the cell
  asks for the line and settles for less, so as the sheet narrows they
  stack on their own — a column doing what a table column does — and
  the width goes to the services column, which was the one paying for
  them. Narrower than that the sheet measures itself, not the window
  (the grip moves the split under a still window): the target column
  gives a line of prose, the addresses close up and shorten to an
  ellipsis — the whole one is in the title, as always — and last the
  reading drops under the service's name; each address is only as wide
  as what it says, a floor of nine ems having made a short service
  (*migrate*) as wide as a long one for nothing. Stacked, the buttons are
  eight pixels apart, the same air they have side by side — the
  buttons' own margin, since an inline-block gives the line its margin
  box, and not a taller line, which would have padded the whole cell.
  Nothing is cut and nothing paints over the buttons, as the addresses
  did before.
- **The Project card reads in the Record's order, and the workspace
  wears its own reading.** The chip that says whether a project is in
  the workspace — the one that also warns that creating overwrites
  every file in it — leaves the card's heading for the workspace's own
  row, where its subject is. The stack, one line of three versions,
  becomes three rows — elixir, erlang, debian — so the card reads row
  for row like the Record's Birth table, and so the row that has moved
  since birth is the row that says so: `born on 1.17.3` sits on the
  elixir row alone, where it used to speak for the three. The installer
  says `phx.new 1.8.13`, the Record's own words for it, not the hex
  package's `phx_new`, and the flags row is `mix phx.new`, which is the
  command the Record prints above the one it reconstructs. Each row
  ends in a cog — the eye's own square icon button — where it used to
  say "change in config" in words, six times down one card. The
  workspace's own chip is two words, `empty` or `existing project`, on the
  row that names the path — the path is the subject, so the chip need
  not repeat it — and the second is `good`, not `bad`: a project in the
  workspace is the healthy state, the same green as *baked* and *up*,
  and the danger of overwriting it belongs to the Create button, which
  asks before it does it.
- **The jobs tray reads the job, not only names it.** Its bar is now a
  fold: pressed, the last job's output unfurls *upward* from it — the
  tray is `flex:none` under a screen that is `flex:1`, so the screen
  gives the height and scrolls, and the bar stays pinned to the
  window's foot where it was pressed. Nothing is covered, and the
  table you are about to act on is still under your eyes when the
  answer to the last press comes back; `→ jobs` beside the bar is
  still the way to the whole list. It is the same output the Jobs
  screen shows — `job_out/1`, lifted out of `job_row/1` so a job reads
  the same wherever it is met, with its own words about itself under
  the last line: run it again, drop it, stop it. The tray keeps its
  own fold, and reads whichever job is last, so the Jobs screen's list
  stays folded as its reader left it. The pane has the jobs' grip, at
  its top and not under it, since the edge that moves is the one away
  from the bar: `data-grip="up"` turns the drag and the arrow keys
  over for it, and the tray's height is remembered by name across
  papers, as the compose box's is.
- **One button for every line of `wb.sh`, and the line is written where
  it can be right.** `ConsoleWeb.Refs.job_button/1` is the single shape
  behind Bake, Down, Stop, Up, Build, Create, Delete and the Docker
  screen's removals — the unlit with its reason, the command in the
  title, the click that sends it — where five hand-rolled copies had
  already drifted apart (the deploy buttons put the command in their
  title, the prunes put a sentence). `bake_button/1`, `deploy_button/1`
  and `prune_button/1` keep what is theirs, which is deciding *why* a
  button cannot be pressed, and hand the rest over.

  With it, the hazard Create was cured of in its day is cured for the
  rest. A button whose line is composed out of a form — the deployment
  picked, `--replicas`, `--no-balancer` — was rendered with that form
  as it was, so a change and a click in the same instant ran the line
  as it stood BEFORE the change: `--replicas 6` typed, `--replicas 4`
  run. Those buttons now submit the picker (`phx-submit="deploy_run"`)
  with `name`/`value` saying which was pressed, and the line is written
  on the server out of what travelled — `ConsoleWeb.Deploy.line/2`,
  which is a pure function and has its own test. What is rendered on
  the button is only what it *says*. The ones whose line is only itself
  — Stop, Down, Delete, a prune — still travel on the click, and an
  unlit submit is rendered as a plain button so the form cannot leave
  by it either.
- **The Inserted list says what a cartridge went in with, even when
  the cartridge does not.** Its *installation parameters* column is
  drawn from what each cartridge reports of itself (`state/1`), and
  `healthcheck` reported nothing — it had no `state/1`, so it answered
  the default `%{}` and a project inserted with `--endpoint /health3
  --open-api` showed an empty cell. Two fixes, one on each side.
  `ecto` reported its database alone, so a project born with
  `--binary-id` read as if it had not been; it reports `binary_id` too
  now, off the generators entry `phx.new --binary-id` writes. And
  `healthcheck` reads its state back off what its install wrote: the
  endpoint is the router scope that routes `HealthcheckController`,
  and the OpenApiSpex variant is there when its schema module is. And
  the console, when a cartridge reports nothing, reads the parameters
  off the cartridge's Insert commit (`ConsoleWeb.Record.params/3`),
  marking the ones that say the default as the project's own reading
  does. What the project reports wins; the commit is what is left to
  read when it says nothing — a cartridge without `state/1`, or an
  edition from before it had one. And the column now spaces its flags:
  its rules stayed behind with the Birth table when the list moved to
  the shelf, so two flags ran together (`--endpoint /health3--open-api`)
  and broke in the middle of the second; they wrap between flags now,
  never inside one.
- **A cartridge's box keeps what it went in with, and its foot is the
  console's own.** The Installation screen's line said `./wb.sh add
  ecto` of a cartridge inserted with `--database postgres`: it was
  written from the form's live values, and those are empty while the
  form is locked. It reads the insert's own argv there
  (`ConsoleWeb.Box.line_argv/4`), the form's values while the form is
  open, and the bare verb when there is nothing to read — a cartridge
  born with the project, or inserted by a hand that left no commit.
  The fields start from the insert too, and not only when they are
  locked: `ash` and `chiefs_setup` can be run again to add, so their
  form stayed open and went back to its defaults, forgetting what the
  cartridge went in with. What the reader has just said still wins.

  Each verb has its own foot, and only when it is a verb at all:
  Insert while the cartridge is not in — and still while it is, for the
  two that add on a second run, `ash` and the `chiefs_setup`
  collection, which is why a box can have both feet, one under the
  other — and Eject once it is in. A button reading *Already inserted*
  was a state wearing a button's clothes, not an action that cannot
  run: what is in is said by the mention's dot and by the note. Unlit
  is for the verbs that ARE conceivable and cannot run now — a dirty
  tree, a cartridge that has to go in first, no commit to revert.
  Eject gains the line it never showed, which for a collection is the
  chain of reverts in the order they have to happen
  (`./wb.sh eject a && ./wb.sh eject b`), until now only in a title.

  Insert and Eject are `ConsoleWeb.Refs.job_button/1` now, like every
  other button that asks for a line: unlit with the reason in the
  title where they were flatly `disabled` and the reason lived only in
  the sentence beside them. Insert sends the form, since the options
  are in it; Eject is a click, since it takes none. The two shapes
  they had of their own — the big accent `.go` and the outlined
  `.eject` — go with them: the button that does the thing is a
  `.btn.primary` here as it is on Deploy, and the one that undoes it a
  `.btn.danger`.
- **The cartridges the project carries move to the Cartridges tab, and
  the shelf reads one state at a time.** The ribbon was *all /
  collections / base / with a box* — a question the box already
  answers, since what a cartridge is rides on it as a fact (`base`,
  `inserts 4`, `not done`) in both views. It is the state now:
  **Inserted · On the shelf · Not done**, each with its count, and the
  three planks that said the same thing under one another go with it.

  *Inserted* is the state with more to say, and its list is the Record
  paper's second section, moved whole: a row per cartridge with where
  it came from, its edition, the parameters it was installed with, the
  addresses it opens and the bell that calls them all once — columns
  that only exist for a cartridge that is in. Not a column changed;
  what changed is that they are read where cartridges are read, and by
  a shelf that already knew which were in. In the covers view the
  boxes are the boxes, wherever they stand. A row of that list is not
  a link, though every other row of the shelf is: the mention is a
  button that opens the box and the addresses are doors, and an `<a>`
  around all of it closes itself at the first door inside — which
  hoisted the addresses out and dropped them under the row, full
  width.

  The tab opens on what the project carries, and on the shelf itself
  when there is no project (`ConsoleWeb.Shelf.first_doc/2`). The Record
  paper keeps what the project IS — its name and its birth — having now
  given a section to each place its reader already was: the
  deployments to Deploy, these to Cartridges.
- **Build leaves the deployments' foot for each row**, beside Bake:
  the file, then the image the file names, then the status. The foot
  keeps one verb, Up. In the foot Build read as Up without the deploy,
  and on 2026-09-10 it went to the CLI on that reading; the row says
  what it is for. The dev image `up` never rebuilds — Build is the road
  to a new one off the project's Dockerfile.local, and the next Up
  recreates the containers with it — and the release image prod and
  scaled share builds here with nothing going down, where `up --deploy`
  replaces the deployment on its way: a build that fails leaves what is
  up as it was. The button sends the line it says, `build --deploy
  NAME` with scaled's replicas and balancer as the picker has them;
  `--no-cache` and the rest of what `docker compose build` takes stay
  the CLI's, where Tab completes them from the catalog. Unlit with the
  reason while the workspace is empty or a job runs, as Bake is.
- **Git goes last on the rail**, under Cartridges: what has happened to
  the project, after what the project is — the workspace, what answers,
  what is baked and up, what is in it. It sat second, where it landed
  when Git stopped being a tab of its own.
- **The rail says what each section has, and nothing where it has
  nothing.** On the Deploy tab the same head drops its word instead:
  the table under it says what there is row by row, so *Topology*
  named only the section. On the rail, where the section is folded
  shut half the time, Deployments' head said *topology* — what the section is,
  not what it holds — so it was the one head a reader had to open to
  learn anything. It reads like its neighbours now: `none baked`,
  `2 baked · prod up`, `1 baked · nothing up`, beside `3 services · 2
  doors`, `3 of 4 running`, `clean` and `8 in`. And with every head
  saying it, the four paragraphs that said it again under an empty
  section go: *Nothing answers yet…*, *The workspace is empty: Deploy
  → Project.*, *phx.new initialises the repository…*, *Nothing
  inserted yet…*. An empty rail is now a column of heads with their
  readings, and the sentence each of those paragraphs taught is still
  where it is acted on — the Deploy tab's own unlit reasons say it
  where the button is.
- **Delete has a box of its own again, and the first card is named for
  what it does.** The card that creates is *New Project* — it says what
  the *next* creation would use, config.conf and nothing else, so
  naming it after the project that is already there was always a
  little off — and its foot keeps one button, Create. What cannot be
  taken back goes to *Danger zone*, the tab's last box, under
  Deployments, in the foot the other two boxes have: the line it is,
  `./wb.sh delete`, taking the width, the button at its right as Up
  and Create sit at theirs, and under the line what that line takes —
  every file of the project in the workspace, its containers, its
  images and its volumes, the database's data with them, and it asks
  first. The button is a primary in the bad colour, filled and the
  size of Create and Up: what it does is a verb of this tab like the
  other two, and hiding it in an outline would only make it look
  optional. It is centred on the line, not on the line and the note
  together, so a longer note never moves it. Delete had such a box until it was retired for being a
  heading over one button that said only what the confirmation says;
  this one says the scope of the damage before a hand is near it,
  which neither the button nor the confirmation does. It is still
  unlit with its reason on an empty workspace, and it still never runs
  on the first press.
- **The deployments table's third column is `sync diff`**, not
  `differences`: what it holds is the drift between the compose file
  and what the cartridges ask for, which is the same word the row's
  chip uses when the two have come apart.
- **The project's papers in the order they are asked for**: Record,
  History, Pending, .env, README, CHANGELOG. Pending and History were
  at the tail, where they landed when Git stopped being a tab of its
  own; what has happened to the project belongs beside what it is.

### Fixed

- **The console shut an option whose requirement the project met.**
  coverage's `--md-report` asks test_doubles for Mimic among its
  doubles, and a project inserted with `--double mimic,mox` answers
  that state with a **list** — which the console compared to the value
  asked as if it were one, so the switch stayed unlit while the
  cartridge's own mention showed the box in, and the two said opposite
  things about the same project. The installer had learned to read a
  list state; the console keeps its own reader and had not. They read
  the same way now: a state answered with a list is met when it carries
  what was asked.

- **The url field's hook was never handed to the socket.** The field
  carried `phx-hook="UrlField"` and `app.js` imported it, and the map
  the LiveSocket is given did not name it — so the browser ran nothing,
  and esbuild, seeing an import nobody used, kept it out of the bundle
  altogether: the scheme was never written, and no test noticed. A hook
  is wired in two places, and the suite now holds both — every
  `phx-hook` a component asks for is in that map and in the bundle the
  browser gets, which is the check that would have caught this.
- **The url field's caret goes after the scheme it writes.** A click
  places its own caret where the pointer landed, and it does that
  *after* the focus event — so the `https://` written on focus appeared
  around a caret sitting between its characters, and the next keystroke
  landed inside the scheme. The caret is put back at the end on the
  frame after the click, for that moment only: the first keystroke or a
  blur ends it, so a reader clicking into an address they already wrote
  keeps the caret where they put it.
- **The url field says what it wants, in the console's language.** Left
  to the browser, the complaint was the browser's sentence in the
  browser's language — *Introduce una URL* on a Spanish one — which says
  neither the shape wanted nor that only two schemes are taken. It is
  ours now (`setCustomValidity`), and it is the rule the insert will
  hold the value to: *This is a full address, scheme and all —
  http://example.com or https://example.com/page. Only http:// and
  https:// are taken, and the rest cannot carry spaces or quotes.* An
  empty field says nothing, since empty is unasked.
- **A cartridge that rode in with another box is not "inserted by
  hand".** `coverage --exdoc` composes test_doubles (its `mix cover`
  task's tests stand on a double of `File`), so a project can carry a
  box whose files went in inside *another* box's commit — and the
  console read that as a box somebody put in by hand, with its Files
  screen dark for want of a commit that does exist. The origin chip
  says **with coverage** now and names that insert, sha and subject,
  and the Files screen says the same instead of *not inserted yet*. Who
  brought it is read off the manifest, `composes`, which the catalog
  already carried and nothing was asking.

- **coverage v0.6.1: a second run with `--exdoc` plants the `mix cover`
  task the first left out.** The box says `rerun: :adds`, and only the
  hook block was a piece it added: `--exdoc` on a project that already
  had `coveralls.json` was skipped in silence, so the only way to get
  the task was to eject the box and insert it again. A refusal that
  reads *this project's exdoc is off* now has a line that fixes it, and
  the workbench says it: `lacking/1` offers the `wb.sh add` line for a
  box short of a required state when that box adds its pieces on a
  second run, and says nothing where the options are fixed at the
  insert and the line would send the reader nowhere.

- **precommit v0.1.2 writes its configuration at the end of
  `config/dev.exs`.** Igniter puts a new `config` right under
  `import Config` (its `after:` option does not move that), so dev.exs
  opened with `config :git_hooks` above the endpoint. The installer
  opens the block after the file's last statement, and every key lands
  in it.

- **precommit v0.1.1: the dependency compiles in a workspace, and the
  hook runs where the project is.** git_hooks installs the hook while
  it compiles, and Mix compiles a dependency from `deps/git_hooks` —
  in a workspace a Docker volume, another filesystem, where git stopped
  before the project's `.git` (*"Stopping at filesystem boundary"*).
  The dependency did not compile, every Mix task after the insert
  failed with it, and the insert had said it succeeded, because nothing
  in it compiled the dependency; the next `add` showed it, as *Could
  not expand*. `auto_install` is off now and the insert runs
  `git_hooks.install` itself, from the project's root, so the hook is
  in `.git/hooks` when the insert ends or the insert fails. And
  `.githooks/mix` runs `mix` right there when the commit is made inside
  the project's container (the source at `/app/src`, mix on the PATH:
  the console, a terminal), instead of reaching for a Docker such a
  container may not have.

- **An eject takes away what the revert cannot.** Every eject was a
  revert of the insert's commit, and precommit is the first cartridge
  whose insert leaves something no commit carries: its hook, in
  `.git/hooks`. The revert took `.githooks/mix` and left the hook
  calling it, so every commit with hooks after the eject failed. A
  cartridge now says how to undo what it left outside the tree with
  `ejected/1` (`WorkbenchIgniter.Feature`, nothing by default — keeping
  to the tree is the rule), and `wb.sh eject` runs it through `mix
  workbench.ejected` after the revert is committed, printing what it
  undid; if it cannot run, the eject stands and says so. precommit's
  removes what git_hooks installed and puts back the hook it had
  replaced. Checked on a copy of a workspace: insert, eject, the three
  files gone from `.git/hooks`, and the next `./wb.sh commit` through.

- **A switch can build on a cartridge, and credo's and coverage's
  `--githook` build on precommit.** They inserted precommit along, in
  their own commit: precommit then had no insert of its own to eject,
  and their eject took its files and left its hook in `.git/hooks`. Now
  the option refuses while precommit is not in, naming `./wb.sh add
  precommit`, as db_admin's admins refuse a database they do not serve.
  A boolean declares it in `choices/0` (`githook: [{true, doc,
  ["precommit"]}]`); the catalog carries it as the option's own
  `requires`, the console shows the switch unlit with *needs
  precommit*, and `mix workbench.dependents` counts an option the
  project carries — read off the cartridge's `state/1` — so precommit's
  eject waits until credo's block is gone. credo v0.2.0, coverage
  v0.4.0.

- **The workbench's own commits skip the project's hooks.** `Insert`,
  `Revert`, `Bake` and `New project` are the workbench's bookkeeping —
  one cartridge, one commit — and commit with `--no-verify`; `./wb.sh
  commit`, the developer's, runs them. With the hook installed at
  insert time, the insert's own commit ran it, in a container with no
  Docker, and failed; a hook with `--checks test` would have run the
  suite on every `add`, and one refusing an `eject` would have made
  the eject impossible. The container `wb.sh commit` runs git in now
  mounts the project's build volumes, since the hook runs mix there.
  Checked on a copy of a workspace: the insert committed with the hook
  in place, and `./wb.sh commit` refused a badly formatted file and let
  it through formatted.

- **A service the project does not carry wore the wrong colour.**
  `ConsoleWeb.Services.color/2` finds a service's role by asking the
  project, and the project only knows the cartridges it carries, so
  anything else fell through to the plainest token — every container on
  a shelf box drawn in the colour of network, databases and dashboards
  alike. The module's own rule is that a colour is a *role's*, not a
  service's, and that step is now reachable on its own
  (`role_color/1`), for a drawer that already knows the role. `color/2`
  ends in it.

- **A README's badges are drawn in the console, to the byte.** The
  badge the versioning cartridge puts under a README's title is a
  shields.io picture, and the console's policy loads no image from
  another origin (`img-src` is this origin, `data:` and `blob:`), so
  Project → README showed a broken picture with its alt. The policy
  stays as it is. A shields.io static badge says everything in its own
  address — `/badge/<label>-<message>-<colour>`, the style and the
  overrides in the query — and what the service does with it is
  published, so `Console.Shields` does the same: badge-maker's
  renderer followed line by line (the route's expression and its
  escapes, shields' colour names and CSS's, the brightness past which
  the text turns dark, widths looked up in anafanafo's tables of
  Verdana's advances — `console/priv/shields/`, MIT — truncated,
  rounded up to odd and pinned with `textLength`, which is why the
  badge is the same on a machine without Verdana), in the four styles
  those tables cover: flat, flat-square, plastic and for-the-badge.
  The SVG goes in the `<img>` as its own text, a `data:` address,
  asking nobody and needing no network. Checked against the service:
  49 addresses asked of img.shields.io on 2026-09-19 and kept in
  `console/test/fixtures/shields/`, and the 46 of them that are
  drawable come out the same bytes — emoji, CJK, `hsl(1turn,…)` and a
  label colour with no label among them. What is not drawn says so and
  is a link to itself wearing its alt: the social style, a logo
  (simple-icons, a request), a dynamic badge, any other outside image.
  In the shared renderer, so a cartridge's papers and the workbench's
  own README read the same.

- **A cartridge edited while the console is up shows its new options.**
  The shelf is read in the console's own BEAM, off the workbench's
  package as a path dependency, and the re-reading a changed features
  directory sets off asked the same loaded modules again: versioning's
  box went on offering `--version` two hours after it had become
  `--init-version`, beside a README — read off the disk — that said the
  new name. Two gaps: Phoenix's code reloader reloaded `:console` alone
  (`reloadable_apps` now names `:workbench_igniter` too, in dev), and
  the stamp watched the directories' modification times, which an edit
  in place of a manifest does not move (it takes the files in each box
  now). Checked on a console left running: an option added to a
  manifest appeared on the next page, and went when it was taken out
  (2026-09-18).

- **The Record's `--no-live` row points at html.** It named the
  `live` cartridge, gone into html as `--live` on 2026-09-18, so the
  row wore an unknown box's name and never read as inserted. The
  capability's cartridge is html now, as the database's and the ids'
  is ecto.

- **Auth0's mark is its dependency, not the Accounts context.** The
  cartridge read as inserted off `MyApp.Accounts`, the first module its
  installer creates — and the domain Ash writes with its
  authentication, so with Ash in the catalog showed Auth0 inserted and
  `add auth0` skipped itself with «already exists». The mark is
  `auth0_jwks` in `mix.exs` now, which only Auth0 adds, as Ash's is
  `ash`. And an Accounts that is there without it — Ash's, the
  project's own — is refused, naming it, since the templates would
  have planted over it (`on_exists: :overwrite`) once the mark no
  longer stopped them.

- **`add healthcheck2 --path /` answers at `/live` and `/ready`.** The
  prefix was normalised to `"/"` and the plug appended `/live` to it:
  the probes sat at `//live`, which no request asks for, and every
  orchestrator would have seen the app dead. The root is the empty
  prefix now, and the project's state reads it back as such — the
  console fills the cartridge's doors from it (`/live`). Found by the
  tests below, which call the plug.
- **A flag moot at birth speaks again once its cartridge came in.** On
  a project born minimal (`--no-ecto --no-html`) with the base
  cartridges added afterwards, the Record's `--database`,
  `--binary-id` and `--no-live` rows stayed unlit with nothing to say:
  the birth's shape alone decided what was moot, and the row's `now`
  was thrown away with it. It holds only while what makes it moot is
  still out: with Ecto in, `--database` reads not given and `now
  postgres` — the birth's reading carries phx.new's default database
  under `--no-ecto`, which was no database, so today's is the news —
  and `--binary-id` lights, with `now in` when the ids are binary;
  with the HTML views in, `--no-live` reads not given and `now in`
  when LiveView came with them.

- **A formatted project takes the dashboard.** phx.new's router opens
  its dev routes with a blank line after `do`; the formatter — the
  `precommit` alias phx.new itself gives the project — takes it out,
  right where the dashboard writes, and `add dashboard` conflicted on a
  file nobody had edited. The three sides of an Elixir file are now
  merged in the one layout every formatter configuration agrees on — no
  blank line after a line that opens a block (`PhxDelta`) — so they
  differ by what was written, not by how it was laid out. The
  project's own formatter is not asked: after html it wants LiveView's
  plugin, which may not be loaded where the installer runs. Found by
  the test below, on its first run.
- **A base cartridge no longer trips on `.gitignore`.** `add esbuild`
  stopped with an issue on every project: phx.new appends esbuild's
  patterns at the end of `.gitignore`, the workbench had appended
  `.env` there at birth, and a three-way merge cannot order two appends
  after the same line. `.gitignore` is merged as what it is, a set of
  patterns: the capability's lines go in once, at the end, past the
  project's own; what it takes away goes; never a conflict
  (`PhxDelta.merge_set/3`). And an insert with issues is a failed
  insert now: Igniter showed them, wrote nothing and returned zero,
  and `add` took the zero for an insert that landed, committing what
  was on disk — `Insert esbuild` with nothing in it but the
  `.gitignore.phx-new` aside. Every installer's task ends with a
  failure on issues (`WorkbenchIgniter.Task`), `add` undoes the
  half-insert as for any failure and keeps the `.phx-new` aside for
  the reader, saying so. A project that got the empty commit: `eject
  esbuild` reverts it, and `add esbuild` again does the rest.
- **`mix.exs` is no longer merged as text: a base cartridge applies
  what it holds.** At birth the workbench writes its own dependency on
  the project's `deps:` line, `deps: deps() ++ workbench_dep()`, and
  phx.new's html puts `compilers:` on the line right after it: a
  change beside an insertion is a conflict to a three-way merge, so
  `add html` failed on every project. A dependency the project added
  where a cartridge's go did the same. `WorkbenchIgniter.MixFile` now
  reads phx.new's two generations as code — the keywords `def project`
  returns, the list `defp deps` ends in, the keywords of `defp
  aliases` — says what the capability adds or changes, and puts each
  in with Igniter: a keyword or alias where the project keeps it, a
  dependency appended after the project's own, written as phx.new
  writes it (`runtime: Mix.env() == :dev` stays an expression). A
  keyword the project itself changed from what phx.new had is the
  project's: an issue names it and nothing is overwritten. A
  dependency the project already has, in any version, stays. The
  edit of birth stays where it was: Igniter reads the project's
  dependencies off the literal list in `defp deps`, and a `] ++
  workbench_dep()` there would hide every dependency from every
  cartridge.
- **A base cartridge brings its share of what `phx.gen.release` wrote
  at birth.** The workbench runs `mix phx.gen.release --docker` right
  after phx.new, and that generator decides once, off what is there:
  `lib/<app>/release.ex` and `rel/overlays/bin/migrate` only with Ecto
  in the dependencies, the `Dockerfile`'s assets steps (`mix
  assets.setup`, `COPY assets`, `mix assets.deploy`) only with an
  `assets/` directory. A project born bare and grown cartridge by
  cartridge (test_01, 2026-09-17) ended up with a production image
  without CSS or JS and a migrate service (`command: /app/bin/migrate`
  in the pod and scaled composes) with nothing to run, where the same
  project born whole (test_02) had both. `PhxDelta.generate/2` now
  gives each generation, base and theirs, the release's files too,
  rendered from Phoenix's own `phx.gen.release` templates with the
  generator's binding — the stack read back off the project's
  `Dockerfile` `ARG` lines (`docker_of/1`), so no build server is asked
  — and the delta carries them: ecto creates the `Release` module and
  `bin/migrate`, executable once written (`mix workbench.executable`,
  queued by the cartridge); the first bundler, esbuild or tailwind,
  puts the assets steps into the Dockerfile, the second finds them
  there. A Dockerfile that is not the generator's is left alone. Both
  Dockerfile bindings, Phoenix 1.8.13's `debian`-`debian_vsn`-slim and
  1.8.14's whole `debian_vsn`, are served. `phoenix` is a test
  dependency of the igniter now, for the templates.
- **iex on a dev deployment attaches to the node that serves the
  port.** `./wb.sh iex` and the console's `app · iex` ran `iex -S mix`
  on the app container: a second VM, with a Swoosh mailbox, a Repo and
  a PubSub of its own, so a `deliver` from it never reached
  `/dev/mailbox` and nothing evaluated there touched the server. The
  dev image's CMD now boots the server as the named node
  `<app>@<container>` (`elixir --sname <app> -S mix phx.server`, baked
  from `Dockerfile.seed.local` with the app's name, mirrored in the
  compose's comment and the workbench entrypoint's default), and both
  attach with `iex --remsh <app>` — the short name, completed with the
  container's own hostname — as the release's `remote` already did. An
  existing workspace takes it with `./wb.sh build` and `up`, since the
  CMD is the image's. A remote shell that reads EOF stops the node it
  is attached to (measured 2026-09-16 on the remsh, as wb.sh already
  knew of the release's), so wb.sh refuses `iex` without a terminal in
  dev too, with `elixir --sname wb_rpc --rpc-eval <app> 'EXPR'` as the
  one-expression way, and the console closes an iex session by
  SIGTERM to the iex it announced, waiting for it to leave before the
  port — its stdin — is closed: killed so, the local VM shuts down and
  the server stays. The one-off terminal, where nothing runs, keeps
  `iex -S mix`; `bash` and `iex -S mix` there is still the way to a VM
  of one's own. IEx colours its results on the node that evaluates
  them, so a remsh came plain: the app's node is told to colour —
  `IEx.configure`, its own setting, not `ansi_enabled` and the Logger
  lines with it — by an rpc before iex attaches, in the console and
  in wb.sh alike; and the terminal's lines keep their leading spaces
  (`white-space: pre-wrap`), which the page folded before.

- **The containers table's since column no longer repeats the state.**
  It showed `Exited (0) 7 minutes ago`, the state word and the exit code
  the state column already carries, because only a running container's
  `Up 4 hours (healthy)` was trimmed. Every status is now trimmed the
  same way — the state word, its parenthesis, the health — to its time:
  `4 hours`, `7 minutes ago`, `5 seconds ago`, nothing for a container
  that never ran. The `ago` stays: how long it has been up and how long
  since it stopped are different times (2026-09-16).
- **A project made from the console gets port 4000.** `new` asks
  for the first free host port from 4000 by connecting to the
  loopback, and run inside the console's container that loopback is
  the container's own, where the console itself listens on 4000: every
  project made from the console was given 4001, and `up` from the
  console would have refused a workspace baked on 4000 as held by a
  host process. In the console the answer is Docker's now — the host
  ports its containers publish, over the socket the console mounts —
  and on the host the loopback's, as before (`port_held`).
- **Opening a compose file on Deploy no longer widens the rail's right
  air.** The rail's scrollbar gutter, measured by the Rail hook and
  given back by the rail's right padding, was written on the app's
  inline style, which every LiveView patch of the page dropped: 15px
  more air on the right after a compose file opened under its row, or
  a status arrived. It is written on the root now, as the rail's width
  is, where no patch reaches.
- **Opening a compose file on Deploy no longer presses the rail's Left
  square.** The two squares' pressed state and title are the Rail
  hook's, painted from the frame kept in this browser, but the
  template wrote them too, and every patch of the page — a compose
  file opened under its row, a status arriving — put the template's
  back until the hook's next repaint: Left pressed with the rail
  hidden. Invisible until the pressed state had a look (2026-09-15);
  the squares are `phx-update="ignore"` now, so a patch leaves their
  attributes alone.
- **A cartridge pressed on History opens its box over History.** A
  box, and the workbench drawer, open over the screen the reader is
  on, and the screen keeps its place under them: on Project, the paper
  and the commit open on it, which the drawer's links carry along
  (`/project?paper=history&commit=SHA&box=k6`) and which Put back,
  Close and the scrim come back to. Before, opening a box went to the
  bare tab, so pressing a cartridge's mention on History landed on the
  Record paper with the box over it, and closing the box left the
  reader there. A key the drawer's own query names — `paper`, the
  box's manual's and the workbench's — is left out of the URL for the
  screen and kept on the page instead, so the URL names it once
  (`Refs.over/2`).
- **A line's text sits centred in its line by its capitals**, on the
  Files sheet, the Logs screen and the Interface tab's miniature. A
  line box is the font's ascent and descent with the leading split
  above and below, and a face's descent is room most lines never use:
  in Fira Code a line of code sat three pixels high in a twenty-two
  pixel row, plainest on a row with a ground — an added line, an
  error. The line box is trimmed to cap height and baseline
  (`text-box: trim-both cap alphabetic`) and the leading given back as
  equal padding, so the capitals are centred in every face and the
  descenders hang below; the row keeps its height, leading times size,
  and the line numbers are centred the same way. Every width, air and
  line height that places the text is rounded to whole pixels
  (`round()`, as the drawer already rounds its own width), because a
  bitmap face — Tamzen, the VGA — blurs the moment its glyphs land on
  a fraction, and a `ch` or an `em` is a fraction more often than not:
  each row is exactly the rounded leading tall, and a line number is
  centred by arithmetic, the cell's leftover halved and rounded for its
  own count of digits, since `text-align` put a number one digit short
  of the widest on a half pixel — a bitmap digit is an odd number of
  pixels wide. A browser without
  `text-box` keeps the old line box.

- **A lexer that hands a lone codepoint as a token's value no longer
  throws the line cutter.** `Console.Highlight.token_lines/1` took the
  value for chardata; the Files sheet caught it and fell back to plain
  text for the whole file, and the Interface tab's sheet, which does
  not catch, went down with the drawer. The value is wrapped first.

- **A container that exited read `unhealthy`.** Docker keeps a stopped
  container's last health, and the reading put health before state:
  an app that crashed wore `unhealthy` beside its `Exited (1)`. Health
  counts while the container runs; a stopped one reads its exit code.
- **A base cartridge's box showed its fields empty** — `--binary-id`
  unchecked with the project saying true. The locked fields read the
  Insert commit alone, and a cartridge in from birth has none; they
  read what the project reports first (`state/1`), then the commit,
  then the default — the rule the Inserted list already had.
- **The page scrolled under a long screen, and the header went off
  with it** (Deploy). A `.sr` label (`position:absolute`) deep in the
  screen was placed against `.app` rather than the box that scrolls,
  and its 1px past the foot gave the whole page a scrollbar. The
  scroll boxes — the screen's and the rail's — are `position:relative`
  now, so what they hold is placed in them.
- **The output's grip moved nothing until the hand had crossed the
  box.** A drag started from the box's cap (`max-height`), which a
  short output never reaches — past its foot in the tray, past its
  head on the Jobs screen. It starts from the box as drawn.
- **`wb.sh eject mock` left healthcheck's tests without their
  library, and said nothing.** `mix workbench.dependents` read
  `requires` alone, and the three cartridges that compose mock declare
  no requirement on it; eject reverted the commit and no one was named.
  The walk reads `requires` and `composes` both now, in the reach and
  in the eject order: a cartridge that brought another in stands on it
  as much as one that required it.
- **The version and the help's name, empty when wb.sh is called by a
  relative path from elsewhere.** Two readers open the script's own file
  to answer — the version off line 3, the name off line 2 — and they
  opened it as `$0`, which the `cd` to `WORKBENCH_PATH` three lines into
  the script had already made meaningless: `repos/workbench/wb.sh help`
  from `~` printed two `sed: can't read` and left both fields blank.
  `WORKBENCH_SELF` is the script's file, absolute, and the three places
  that want it — those two and `demo` — take it from there. It is read
  off `BASH_SOURCE` and not `$0` now, so it holds when the script is
  sourced rather than run. The string comparisons became `[[ … == … ]]`
  while there: `==` is bash's operator, and `[ ]` only tolerated it.

- **Two warnings and an error at the end of every creation from the
  console.** Mix 1.19 deprecates the commas `mix do` took between
  tasks, and the three places wb.sh chained tasks that way — the
  workspace's igniter runs, in-process and in a container, and the
  package's — said so on every status the console read; they chain
  with `+` now. And `Error opening ETS file ~/.hex/cache.ets: :badfile`:
  Hex rewrites its registry cache in place, and since the workspace
  rides in the console's container the readers of the status opened it
  while the job's own mix was writing it, so Hex threw the cache away
  and fetched the registry again. The readers have a Hex home of their
  own now (`reader_igniter`), under the console's build volume; the jobs
  keep the user's, and no longer share it with anyone.
- **The console warned of the legacy builder on every build.** Its
  image carried Docker's static CLI and the compose plugin, pinned to
  the host's versions, and no buildx: a `docker build` from in there —
  the toolchain image of a new project, `bake`, `console build` — fell
  back to the deprecated builder and said so. The CLI and both plugins
  now come from Docker's apt repository for the image's Debian, no
  daemon, no versions to pin: the client negotiates its API with the
  engine on the socket, so the two build args wb.sh took off the host
  are gone with the warning.
- **Two workspaces made while each other slept were given the same
  port.** `first_free_port` asked only what listened at that moment, and
  a workspace that is down holds its ports as surely as one that is up:
  six workspaces ended up baked on 4001, to meet Docker's "port is
  already allocated" on their first `up` together. A free port is now
  one nothing listens on and no other workspace under `_workspaces/` has
  in a compose file of its own — the scaled files' replica ports
  included. And `up` checks the file's ports before compose does: one
  held by another workspace's containers is refused naming that
  workspace and a free port to move to; one held by a process on the
  host is said so. The fix is the port line in the file, which prod and
  scaled read on their next `up`.
- **A Postgres project without the pgadmin cartridge still published
  pgAdmin's port.** The port line on the pod's `network` service hung on
  Postgres being in, not on pgadmin, so the status read a port and the
  console drew a link to nothing on the rail and among the doors. It
  hangs on the cartridge now; a vanilla `new` publishes the app alone.
  `./wb.sh bake` takes the line out of a workspace baked before.
- **The console's «Create project» ran a stale command.** The line was
  rendered onto the button, and a change of the form and the click in
  the same instant sent it as it was before the change: a `--database
  mssql` chosen, a bare `new` run, a Postgres project born. Create is
  the form's submit now, and the server builds the line from what the
  form carries.
- **`up --deploy scaled` on a project without a database or clustering
  wrote a compose Compose rejects.** The app anchor kept an
  `environment:` with nothing under it but comments, and compose
  requires a mapping. Found when every fixture was put through
  `docker compose config`; the key is left out when nothing goes in it.
- **`up --deploy prod` wrote a truncated compose for a project without a
  database.** The no-database cut removed the app's `depends_on`, which
  was the line the prod cut of the volumes ended on, so `sed` cut to the
  end of the file: no healthcheck, no `configs:`. Found by the golden
  corpus; the rendered file carries everything.
- **A box's doors never read their `when`.** `Cartridges.holds?/3`
  matched any map with its first clause, so a door's `when` was
  unwrapped twice and always held: a door meant only for `--with x` or
  only with another cartridge in stood open regardless. Dialyzer found
  the dead clauses.
- **`app_repo/1` would have split a `nil` image.** The project's image
  can be unset; the repository is read only off a binary now.
- **`psql_extras`'s tests ran on a project without Ecto** and had
  refused since the cartridge learned to require it; they run on a
  Phoenix project now.
- **A box's runs are drawn on whole pixels.** The drawer sat wherever
  `margin:auto` left it — `94vw` is seldom whole, so it landed at x.03 —
  and a bitmap face such as Tamzen, drawn half a pixel off, is a blur.
  The drawer's width, height and corner are now rounded to the pixel,
  and a job's output rounds its leading too: 13px at 1.5 gave 19.5px
  lines that took turns at 19 and 20.

### Removed

- **`--build` is gone, from exdoc (v0.6.0) and coverage (v0.5.0).** It
  queued the command behind the insert — `mix docs`; `ecto.create`,
  `ecto.migrate` and `mix cover` — so the page had something in it on
  first boot. The door builds it now, as a job whose output is read as
  it happens, where the queued task ran inside an insert's log that
  nobody reads for that; `./wb.sh mix docs` and `./wb.sh mix cover`
  were always the other way, and the box names them in `afterwards/0`.
  It was also the one option that left no mark, so `state/1` answered
  `nil` for it: a one-shot action wearing an option's clothes.
- **guidelines is archived** (v0.2.1). It installs a page downloaded
  from a URL only the team has — the reason it was always à la carte —
  and a shelf a project is picked from cannot hand it one. Its papers
  stay on the shelf, and `wb.sh add --archived guidelines --url URL`
  still puts it in for a team that has the URL.

- **The pgadmin and adminer boxes**, merged into db_admin (Added,
  above). Their files in a project are the new box's marks, so nothing
  is migrated: `wb.sh add pgadmin` is now `wb.sh add db_admin --admin
  pgadmin`, or bare on Postgres.
- **The osmon and psql_extras boxes**, merged into dashboard_extras
  (Added, above). A project that carries osmon's `:os_mon` reads as
  carrying the new box, whose mark it is; one with psql_extras alone
  reads as not, and inserting the box adds `:os_mon` and leaves the
  dependency as the project has it.
- **The Docker screen's three prune buttons** — the untagged images,
  this workspace's build volumes, what other workspaces left. What each
  removed is said in a note beside its table, with the `./wb.sh prune`
  line that does it from the terminal; the untagged count and their
  size stay on the note. Removing by the row is what the screen does
  now, and the three sweeps are the terminal's.
- **`probes:` leaves the cartridge manifest.** `console/0` had two kinds
  of address — the *doors* a cartridge opens on the app's port, and the
  *probes* "the console polls and shows on the board", which nothing
  ever polled. The only difference left was a face, `.probe-ref`, the
  door minus its box, and a promise the project would have been keeping
  for the workbench's sake. Decided on 2026-09-08, with the Record
  paper: the project owes the workbench nothing — a health endpoint is a
  route it has for its own reasons, and the console reads it and calls
  it like any other door. healthcheck and healthcheck2 now declare their
  paths as doors; the catalog's `console` carries `doors` and `tabs`;
  `Doors` has no probes row, the box no *Answers* row, `Refs` no
  `probe_ref`. The design system's `.probe-ref` and its decision page
  retire with the address component that follows.
- **The decision pages of the console.** `console/la-segunda-fila.html`,
  `console/docker-en-la-consola.html` and `console/colorear-el-codigo.html`
  are gone: each was made to settle one question of the interface — the
  second row of tabs, the Docker screen, the colour of the code — and
  each is settled, its answer in the console and in this file. They stay
  in the history for whoever wants the candidates.

### Security

- **The console's `check_origin` names the port.** `["//localhost",
  "//127.0.0.1"]` compared the host alone, so any page on another port
  of localhost — the project's app, the pages beside the console —
  could open the console's socket. It mounted nothing, since the
  signed session is unreadable across origins, but the first fence was
  open. The check is the port the browser sees now,
  `CONSOLE_PUBLIC_PORT`, which `wb.sh console` passes.

## v0.11.0 - (2026-09-06)

### Added

- **The production deployment migrates before it boots.** `up --deploy
  prod` used to start the release against whatever the database had:
  `bin/server` runs no migrations, and the dev image's `mix setup` is
  not there. The dev/prod seed now carries the one-shot `migrate`
  service the scaled seed already had — `bin/migrate` from
  `phx.gen.release`, the same image, run to completion inside the pod
  — and `bake_compose` sorts it by Dockerfile: the dev file drops it
  (the dev image migrates itself on boot), the prod file hands the
  app's `depends_on` over to it. It is the release phase every
  platform has under its own name, and now both release deployments
  say so the same way. `logs`, `stop` and the help know the service.

- The postgres service of the dev/prod seed declares `POSTGRES_DB:
  APP_prod`: the image creates it when it initialises the data
  directory, which is the only moment it honours the variable. A
  release deployment migrates into a database `bin/migrate` does not
  create, and prod and scaled share this volume with dev — so it has
  to be there from the first init, whichever deployment does it.
  Verified on `test_83` from a fresh volume: `migrate` exited 0 and
  the release answered 200 on the first `up --deploy prod`.

- **A Git screen.** The rail said `dirty` and offered a commit it could
  not name. Two documents under the row: *Pending*, what a commit would
  take, file by file on the sheet the box's Files screen draws (the
  tracked changes as a diff, every untracked file whole), with the
  commit's title and body above it — the message travels to `wb.sh
  commit --message-file`, since a job's argv cannot carry a line; and
  *History*, the log with the cartridge inserts marked, each commit
  opening its diff on the same sheet. Narrow on purpose: no branches,
  no remotes, no discarding by file — `wb.sh` alone writes the
  workspace and the house's undo is `eject`. What it says that nobody
  did: a dirty tree stops `add` and `eject`, so the commit is what lets
  the next cartridge in. The rail's button now leads here.

- **The console listens to Docker.** `Console.Events` keeps one
  `docker events` open for as long as the console is, parses what
  arrives, drops the healthchecks' `exec_*` at the source, keeps the
  last 500 and broadcasts each one — and, the reason it comes first:
  a life event on a container of the workspace's project (`die`,
  `oom`, `health_status`, `start`, `destroy`…) asks the Bench for a
  fast status, settled over 800 ms. Until now the status was read
  after a job and never on a clock, so a container that died on its
  own went unnoticed until the next job. It has to be a stream and not
  a reading: the daemon holds only its last 256 events, and two
  healthchecks every 10 s fill that in seven minutes — measured on
  2026-09-05, `--since 2h` answered exactly 256 lines, all probes.

- **A Docker screen.** What Docker Desktop showed and the rail could
  not: six documents under the Project screen's row of tabs, settled
  in `console/docker-en-la-consola.html` (2026-09-05). *Containers*,
  the rail's table across the screen with since when, restarts, ports
  and — streamed only while the document is in front — cpu and
  memory, and each published port a door — the rail's notation for an
  address — one per line, opening on the host; the console itself a
  row, marked; the card of the container
  picked under the table: command, user, restart policy, network,
  healthcheck with its last probes, mounts, env with the secrets
  masked. *Images*, one per ID with every name it wears (the app's
  `:local` is the toolchain's, tagged per workspace). *Volumes*, with
  size and who mounts them, and the disk. *Networks*. *Events*, the
  feed, with the badge Jobs has: red, counting what died with a code,
  was killed for memory or turned unhealthy since the reader last
  looked. *Deploys*, each deployment's compose file read like the
  `.env`, the one not baked unlit. Two scopes on every document: this
  workspace, or the whole daemon — where the leftovers of the
  workspaces before this one are. `Console.Docker` reads it all with
  short `docker` commands; nothing starts a container. The two live
  columns do not dance: `.num` joined the design system with its rule
  (one unit per column, fixed decimals, a reserved width), the stream
  is normalised as it is read, and the README says why.

- **`wb.sh restart` and `wb.sh prune`.** The console's one act on a
  single container is Restart — `docker compose restart SERVICE`, the
  deployment left whole; Stop and Start of one are absent, not unlit,
  because the deployment is the unit. `prune` removes what no live
  workspace uses and never this workspace's deployment nor the
  console — nor anything on the daemon that is not a workspace of this
  workbench, which it tells by the seed's first line in the compose its
  containers name, or by the directory being under `_workspaces`: the
  stopped containers of the other workspaces with their anonymous
  volumes, and those workspaces' networks and named volumes, the build
  volumes made before `wb.sh` labelled them included (`prune`); the untagged images a prod bake leaves (`--images`); this
  workspace's two build volumes, refused while the app mounts them
  (`--build`). Always confirmed. `.env` masking learned YAML for the
  composes: `POSTGRES_PASSWORD: postgres` is a secret whatever the
  punctuation.

- **The code's and the files' faces, from the drawer.** Two rows beside
  the ground in the console's UI pane, each with a face, a size and a
  leading, kept in this browser like the frame and the ground: *The
  code* is what runs — the terminals, the jobs' output, the logs,
  Docker's events — and *The files* is what is read — the Files sheet,
  the diffs, `.env` and `config.conf`, the papers' code blocks. Each is
  three custom properties on the root (`--code-face`, `--code-size`,
  `--code-leading`; `--file-…` likewise) that every surface of the
  group reads with its own default in the fallback: the house's IBM
  Plex Mono at each surface's own size and leading is the properties
  absent. A sample under each row's selects — a log line and a line of
  code; a diff hunk — is set in the same properties, so it shows the
  choice before any screen does. The faces travel with the repository, the first that do
  (`console/priv/static/assets/fonts/`, with a README of sources and
  licences): Fira Code (OFL), Flexi IBM VGA (CC BY-SA 4.0) and Tamzen,
  a bitmap face whose seven drawings are the seven sizes it offers —
  the size select takes its options from the face. Chromium was made
  to draw every one at its pixel height before any of this was built.

- **A box's runs read as jobs.** The install screen of a cartridge's
  box showed the last insert or eject as a black pane under an "Output"
  label, always open, with its own stylesheet and its own empty words —
  a second way to meet a job. Now it lists the box's inserts and
  ejects, newest first, as the rows the Jobs screen draws: the same
  chip, command line and duration, the same fold and grip, the same
  words at the foot — confirm it, stop it, run it again. The row is one
  component, `job_row`, that both screens use; the unfold state is
  shared, because it is the same job. The pane `.log` stays for the
  cluster's probes, which are not jobs.

### Updated

- **One Project card on the Deploy tab.** "New project" is "Project",
  and "Delete the project" sits in its foot beside "Create project":
  what the one makes, the other takes away, and the card's chip — *the
  workspace is empty*, or the red *a project exists here* — already
  said which of the two applies. The button had a box of its own under
  "Workspace", the red-edged half of what was once "Database and
  workspace"; with the database errand gone (Removed, above), a heading
  over one button named only what its confirmation already says. The
  board's and the shelf's pointers say "Deploy → Project creates one".

- **The row of documents is one component, and the second row looks
  second.** Six rows of the console said which document of a screen or
  a drawer was being read, each written again with a small difference
  and each setting its own air, ground and margin. `ConsoleWeb.Ribbon`
  draws all six now, with the unlit tab `aria-disabled` in one place.
  And the docked ones — under a screen's tabs, under a drawer's — were
  the first row's grammar ten per cent smaller, which told the reader
  nothing about rank: they are a band of the house's second surface
  now, lower, with the document being read cut into the ground of the
  pane it opens, and the gold rule stays on the row that leads. Settled
  in `console/la-segunda-fila.html`.

- **No container of a deployment comes back on its own after a
  reboot.** The pod and the database carried `restart: unless-stopped`
  (the dev and the scaled compose) and the app and pgadmin did not, so
  a reboot of the host brought half a deployment back and the status
  could only say "no deployment is up and these are still here". The
  rule is that a deployment goes up and down whole, across a reboot
  too: no `restart:` anywhere, a reboot leaves everything exited, the
  status says down, Up raises it whole. What it gives up — a database
  that crashes is not restarted alone — the events feed says, and
  Restart is a click.

- **The scrollbar sits on the edge of the box that scrolls.** The
  console drew it in four places at once: on the panel's edge for the
  document tabs and the drawer's Files and faces, 28px in on Project,
  Git, Docker and the shelf, 32px in on the papers of a box and of the
  workbench, and halfway across the modal on Config and Interface,
  whose panes were also clamped to 860px. All the same cause — when a
  row was docked above a scroller the scroller went down a level, and
  the padding stayed on the wrapper around it. The bottom had the same
  fault: the filled panel kept 22px of ground under the scroller, so
  the last row of boxes was cut a strip above the band and the bar
  stopped short of it while the rail's ran to the edge. The air is now
  on the scroller (or on the row and the content beside it), the
  measure on the form's blocks, and every pane that can scroll says
  `scrollbar-gutter:stable`. Written as a rule of the house, in the
  scrollbar note of components.css and in assets/design/README.md.

- **The box is turned by hand.** A click on the box in the drawer's
  Box screen turns it over, and Enter or Space with it focused; the
  button that stood under it is gone. The cursor had promised a viewer
  since the mock, and the console never wired one: the lozenge a figure
  shows on hover now sits in the box's corner and opens the viewer on
  the side that shows, without turning the box.

- **Every paper with a section has its index.** The column of h2s
  beside a paper wanted three of them; with fewer the paper was read
  full-width, and a changelog — whose h2s are its versions — has one or
  two for most of its life, so it took a different shape from the
  README beside it. The index is there whenever there is an h2, and the
  rule lives once, in `Console.Papers.booklet/3`, where the three
  renderers (a cartridge's papers, the workbench's, the project's) had
  each carried a copy of the number.

- **`wb.sh` inside the console stops starting containers it is already
  in.** The console runs on the toolchain image, and `wb.sh` run in it
  went on starting a sibling container on that same image for every
  `mix` and `git` — about 4N container starts for an `add` of N
  cartridges. `./wb.sh console` now mounts the workspace at `/app/src`
  with the app's build volumes over it, as the app service has them,
  and says so (`WORKSPACE_MOUNT`); the four runners that need nothing
  but the toolchain (`workspace_igniter`, `workspace_git`, and
  `entrypoint_run` for `new`, `add` and `expand`) then run in this
  process, and in a container as before from a host. One command, one
  place that decides where; the verbs know nothing of it. The resident
  works from `/app/src` too, so it adds to the app's build instead of
  compiling the project a second time from the host path (Mix keys its
  manifests on the source path). What stays in a container: `setup`
  and the cold `mix` (the database is in the pod), builds and compose
  (the daemon), and the package's own tasks (they would compile
  through the workbench's bind mount). The mapping is in
  console/PLAN.md, *The console is the toolchain*. The resident makes
  the same check as `wb.sh` — the mount is the workspace config.conf
  names now, and the project's — and, failing it, runs as one container
  on the workspace's dev image with its volumes, as on a host; and a
  resident of a workspace config.conf no longer names is dropped for
  one on the workspace named. Before, a console started for one
  workspace and pointed at another reported the first workspace's
  cartridges on the second, and went on reporting them.

- **The console says which workspace it was started for, and starts
  again for another.** Its container mounts one workspace and that
  project's volumes, and cannot mount another: config.conf named
  another since, the board's workspace section says so and offers
  *Start again* — `console` run as a job. From inside, `wb.sh console`
  starts a helper container on the console's image that runs it from
  outside a moment later, since the console cannot remove the container
  it runs in without ending the job that asked. `wb.sh console` keeps
  the port of the console it replaces, so the address survives and the
  page reconnects on its own. And `wb.sh console` asks for the
  toolchain image only when it has to build the console's: built once,
  the console comes up on an empty workspace too, where `new` is the
  first act and the toolchain of a project not yet born has no tag.

- **Colour without a terminal, in jobs and in sessions.** A `Port` is a
  pipe, and on a pipe mix, hex, git and compose turn their colours off
  on their own while the console's page turns ANSI into spans. `wb.sh`
  takes `WB_ANSI=always` — Elixir by `ELIXIR_ERL_OPTIONS`, git by the
  config it reads from the environment, compose by `COMPOSE_ANSI` —
  and the console sets it on every job; the Terminal tab passes the
  same variables to its `docker exec` and `docker run`, so iex, mix
  and git colour their output there too. From a terminal, or unset,
  nothing changes. BuildKit stays plain: it colours only a real tty,
  and that road — a pseudo-terminal for jobs — is left for later.

### Removed

- **The `setup` command, and the Database zone of the console's Deploy
  tab.** It dropped, created, migrated and seeded the database of one
  `MIX_ENV`, and it was the step the README asked for before the first
  `up`. Both of its jobs have owners now: the dev image creates and
  migrates on boot (`mix setup`), the release deployments migrate into
  the database postgres created (`POSTGRES_DB`, the `migrate` service),
  and a reset with the seeds is `./wb.sh mix ecto.reset`, which the
  `mix` help now says. Its prod variant never fitted — `ecto.setup`
  under `MIX_ENV=prod` from the mounted source, with an entrypoint note
  excusing the "Could not warm up static assets" error — and it was one
  of the two commands keeping `--env` as `MIX_ENV`. The other, `demo`,
  now takes `--deploy TARGET` like every deploy command and runs new,
  up, logs and delete.

### Fixed

- **The box's Installation and Files screens did not scroll.** The
  drawer clips what passes its height, and only the papers and the UI
  pane scrolled inside it: a long options form, or the runs under it,
  ran out of reach on a short window. Every screen of the drawer
  scrolls on its own now, the box's two faces included.

- **A paper's figures opened the viewer only on the first paper.** The
  `Booklet` hook wrapped each figure — the expand hint, the click that
  opens the viewer — when it mounted, and the booklet is one element for
  every paper of a box: turning from the README to the DESIGN patched
  new figures into it, and they stayed bare images. The wrapping runs on
  every patch now, idempotently.

- **The scaled deployment over a dev database.** The clustering paper
  left it open (§5): `up --deploy scaled` recreated the dev `database`
  container carrying its anonymous volume over, so `POSTGRES_DB` was
  never honoured, `APP_prod` did not exist and `migrate` exited 1. With
  the dev seed now declaring the same `POSTGRES_DB`, the database is
  created by whichever deployment initialises the volume first.

- Both seeds' postgres healthcheck asks over TCP (`pg_isready -h
  localhost`). Without `-h` it asked the unix socket, which the image's
  init answers on its temporary server: a fresh volume said healthy
  before the real server listened, and the migrator's first connections
  were refused (Ecto's pool retried, so it only showed in the logs).

- **The console would not start on a clean daemon.** Its image is
  built on the toolchain's, and when that was missing `console` sent
  the reader to `new` — which builds the toolchain — so the first act
  sat behind the very screen that offers it, and `console build` said
  the same. Now `console` and `console build` build what they stand
  on: the installer's resolution and the toolchain's build came out of
  `new` into `resolve_installer` and `build_toolchain`, shared by both,
  so the toolchain the console builds is the one the project to come
  would have built, and `new` then finds it and builds nothing twice.

- **The dev app died by SIGKILL on every `down`.** The image's CMD was
  `sh -c "cd /app/src && mix setup && mix phx.server"`: the shell stayed
  PID 1 and forwarded nothing, so every stop waited compose's 10 s of
  grace and killed the app — `kill SIGTERM`, ten seconds, `kill
  SIGKILL`, `die exit 137`, read off the daemon's events on
  2026-09-05. One word, `exec`, on the last step (the seed Dockerfile
  and the entrypoint's default): the BEAM takes PID 1, gets the
  SIGTERM, stops the application in order and exits 0 — measured at
  3 s with `docker stop`. Prod was never affected: `bin/server` already
  `exec`s the release. Existing workspaces get it with their next
  `new`, or by putting the same line in their compose's `command:`.
  `init: true` on the app service besides, so docker's init reaps what
  the dev server's esbuild and tailwind watchers leave behind. And
  pgadmin had the same disease — its entrypoint is a shell that runs
  `/entrypoint.sh` — which the new events feed showed on its first
  restart from the Docker screen: `kill 15`, ten seconds, `kill 9`,
  `die exit 137`. The same word there.

- **The Cluster screen's "Who answers?" said "no answer" to a balancer
  that did.** The console reaches the app's port by the name it has for
  the host, `host.docker.internal`, and a prod endpoint's `force_ssl`
  leaves only `localhost` alone: under any other name it answers 301 to
  https, which the probe followed to port 443, where nothing listens.
  The probe now asks as the browser asks — the same port, the request
  naming `localhost` — and gets what the reader gets: `HTTP 200 ·
  X-Served-By: 172.26.0.5:4000`, a replica per request.

- **The console went deaf during a `new`.** Every line a job wrote put
  the whole job — all of its lines — on the PubSub topic, and every
  page rendered every line of every job again: quadratic, and two
  thousand lines of `new` left the reader's clicks queued behind the
  renders. `Console.Jobs` holds the output now and broadcasts it in
  batches of at most 50 ms as `{:job_lines, id, from, html}`; a
  `JobLines` hook writes them into a `phx-update="ignore"` element,
  on the Jobs screen and in the box's drawer alike, and asks for the
  backlog when it mounts. The assigns never carry a line again — the
  rule the Logs screen already followed.

- **The Logs screen mistook the `ansi` cartridge's colours for text.**
  With the cartridge in, the app's lines arrive with escapes, and
  `--no-color` only undresses compose's prefixes: the screen showed
  `[22m` and `[36m` as characters, and its level regexes — anchored at
  the start of the line, where the escape now stood — read every
  `[error]` and `[warning]` as info. `Console.Logs.parse` gives each
  line a `text` without escapes, for the level, the filter and the
  search, and an `html` with them as spans; a line that was nothing
  but a closing reset is no line.

- **A terminal session opened before the status arrived went to
  docker with an empty mount.** The tab is judged unlit only once the
  status is here, so before it the button was live, the targets were a
  guess and the source's path was nil: `-v :/app/src`, exit 125. The
  button stays dark with the reason until the status is read, and the
  server ignores the event meanwhile.

- **`up --deploy prod` died on `env file …/build:/app/src/_build not
  found`.** The bake stripped the app's `volumes:` block by deleting
  two lines, the key and the source mount, from a block that now has
  four: the two build volumes were left standing under `env_file:`,
  where compose read them as files. The block goes whole, up to
  `depends_on:`, and the top-level `volumes:` with it — a release has
  no `_build` and no `deps` to keep.

- **A new project would not build its assets.** The first `up` of a
  freshly created workspace ended in `Error: Can't resolve
  'daisyui/packages/bundle/daisyui'`, and heroicons right behind it.
  Since phx_new 1.8 daisyUI is a git dependency of the generated
  project, resolved through the `NODE_PATH` that `phx.new` writes into
  `config.exs` — the conventional `deps/` path, written without asking
  Mix, as `assets/vendor/heroicons.js` writes it too. The workspace
  kept its dependencies in a volume *outside* the project
  (`MIX_DEPS_PATH=/app/deps`), so that path pointed at nothing.
  **The volumes moved instead of the paths.** They now cover `_build`
  and `deps` where Mix looks for them, inside the source mount, and
  nothing is told anything: `MIX_BUILD_ROOT` and `MIX_DEPS_PATH` are
  gone from the toolchain image. Compiled code still never touches the
  bind mount — a volume covers the path, nothing is written through —
  and whatever the generator writes next, if it is where Mix looks, it
  is where the volume is. The reason the paths had been put outside the
  source was that "Mix keys its manifests on those paths"; measured, it
  keys them on the *source* path, and moving `_build` or `deps`
  elsewhere costs nothing. An existing workspace moves over with
  `./wb.sh bake && ./wb.sh up`. Only the console keeps the two
  variables, for its own build: its source is mounted at the
  workbench's host path, which no image can know, so there is no
  directory in its image for a fresh volume to take ownership from.

## v0.10.0 - (2026-09-02)

### Added

- **The console, out of the mock and into Phoenix.** The LiveView
  console (`console/`) now holds what the mock drew: the board, Deploy
  with the New project card and the Deployment card, Jobs with the
  `wb.sh` line and its history, live Logs, the shelf with its planks
  and its list, the box in hand with its four screens — Box,
  Installation with `expand`, Files off the workspace's git, Manual
  rendered with the HTML in it left out — the Project papers, the
  workbench's drawer with `config.conf` as a form, a line-oriented
  terminal, the cluster and the figure viewer. The screen and the box
  live in the URL. What the console knows is held once for every page
  (`Console.Bench`): a page mounting starts no container. The plan and
  the architecture are in `console/PLAN.md`.

- **What `wb.sh` owes the console.** `status --json` answers on an
  empty workspace, says which deployment is up, carries each
  container's address and each insert's argv, and `--fast` leaves out
  the one part that boots Mix; `catalog --json` answers without a
  project, off the package; `expand [--json]` is the planning half of
  `add` on its own; `config set KEY=VALUE` is the one writer of
  `config.conf` besides `stacks use`; `engine` picks which Docker the
  script talks to. The catalog's `need` carries its four parts.

- **`mix workbench.serve`**, the resident: one BEAM with the project
  loaded, answering `status` and `expand` on stdin for as long as the
  console runs, instead of a Mix boot in a fresh container per question.

- **A `specdd` cartridge, designed and pending.** SpecDD — spec-driven
  development with `.sdd` files beside the code — on a stock `phx.new`
  project: what `specdd init` writes (the bootstrap chain, the pointer
  on top of phx.new's `AGENTS.md`, `CLAUDE.md`), off release 1.5's
  files embedded in the cartridge, plus a `bootstrap.project.md` for an
  Elixir/Phoenix project and three starting specs (the project, `lib/`,
  `test/`). The manifest is registered so the shelf shows the box as
  pending; the templates and assets are in `priv/features/specdd/`; the
  installer is not written. The design (`DESIGN.md`) records what the
  CLI writes and touches on update, why the files are embedded rather
  than downloaded, and one thing its `resolve` proved: the root spec is
  found only under the directory's own name, so `--root` exists and the
  README's docker commands mount the project under it.

- **psql_extras says what it builds on, and where it does not belong.** It
  declared nothing and would install on any project: `ecto_psql_extras` is
  an Ecto extension whose queries are Postgres's own, and it would have
  gone into a project with no repo to run through, or a repo talking to
  MySQL. Two rules, kept apart because they are different in kind. Ecto is
  a cartridge, so it is `requires: ["ecto"]` — the machinery was already
  there, and the console now greys the box with *Insert ecto first* before
  anyone presses. The driver is not a cartridge — it is the value of
  ecto's own `--database` — so it is a refusal in the installer, and the
  question is put to the project (`PhxDelta.facts/1`, the same source
  `installed?/1` reads) rather than to the options this cartridge was
  inserted with: what a project's driver *is* now beats what it was told
  once, and for most cartridges the options are not on record at all —
  they survive only in the insert commit's subject, and only for what the
  workbench itself put in.

- **`eject` refuses while something still stands on the cartridge.** The
  insert side has kept this rule from the start — a cartridge whose
  `requires` are missing refuses, naming what to put in first — and the
  eject side had no mirror of it: it reverted the commit and left
  whoever built on that cartridge standing on nothing. `mix
  workbench.dependents NAME` answers the question, and `wb.sh eject`
  asks it: the installed cartridges that declare NAME in their
  `requires`, everything that builds on *those* in turn, in the order
  they have to come out. Both halves come from the project — `requires`
  off each manifest, installed off each cartridge's own `installed?/1`
  — so one inserted by hand or generated at birth counts exactly like
  one the workbench committed. The refusal names the chain to run
  (`./wb.sh eject openai && ./wb.sh eject stripe && ./wb.sh eject
  auth0`). It is asked after the insert commit is found, so an eject
  with nothing to revert costs no container, and a project that cannot
  be asked at all leaves the question unjudged rather than refusing —
  a check that cannot run is not a verdict.

- The console's **Eject** carries the same guard, and a collection grows
  an **Eject N** of its own. A collection leaves no commit under its own
  name, so its button walks its members' commits *newest first* — the
  only order git can revert them in, since a member inserted later may
  have written over an earlier one — running one `wb.sh eject` per
  cartridge, chained, so the run stops at the first cartridge whose
  files changed since. Members with no insert commit are named and left
  in place. Ejecting a single cartridge in the console refuses on the
  same dependents rule, one level deep: the shelf is in front of the
  reader and the next refusal is one click away, while the command line
  gets the whole chain because there it is the difference between one
  answer and five attempts.

- **`PHX_NEW_VERSION` is back in `config.conf`, as a choice and never as
  a record.** Empty — the ordinary case — and `new` resolves it; set, it
  is the standing installer for the projects to come; `--phx-new` still
  overrides it for one run. Nothing writes back to the file: what a
  creation resolved is stamped into the workspace's own
  `Dockerfile.local` (`ARG PHX_NEW`), which stays the source of truth
  for *which generator made this project* — the one the base cartridges
  take their delta with. The setting is captured into `PHX_NEW_SETTING`
  at startup and `PHX_NEW_VERSION` is cleared, so the two never stand in
  for each other: `new` reads the setting, every other command reads the
  stamp, and a workspace's toolchain tag is unaffected by a file that
  has since moved on to name the next project.

- **A named installer hex does not have is refused before anything is
  built.** `--phx-new 1.8.31` or a typo in `PHX_NEW_VERSION` used to have
  no requirement to weigh — `phx_new_elixir_requirement` comes back empty
  for a release that does not exist, and the pairing check stands aside
  on an empty requirement — so the mistake travelled three layers into
  the image build to be reported by `mix archive.install`, about a file
  nobody wrote. `new` now asks hex whether the release is there (a HEAD,
  so nothing comes back but the code) and refuses on a 404, naming both
  ways out. Only a 404 refuses: an unreachable hex judges nothing, as
  everywhere else here. A resolved version never needs this — it came
  out of hex's own list.

- **An unset installer now resolves to the newest `phx_new` the stack
  can run**, not to hex's newest full stop. `new` walks hex's releases
  newest first and takes the first whose declared Elixir this stack
  satisfies — normally the very newest, for the one call the pairing
  check would have made anyway, so the ordinary path costs nothing new.
  It walks only when the stack is behind, which was the case with no
  good answer before: the newest was resolved, then refused. This is a
  deliberate parting from `mix archive.install hex phx_new`, which takes
  the newest and fails loading it. The walk is release by release rather
  than one probe per minor line because the requirement moves *inside* a
  line — `phx_new` 1.8.0 to 1.8.5 ask for Elixir `~> 1.15` and 1.8.13
  asks for `~> 1.17` — so an Elixir 1.15 stack gets 1.8.8 rather than
  being dropped to the 1.7 line. When the answer is not hex's newest,
  `new` says which it took, for which Elixir, and what the newest would
  have needed; a named version is still taken as named and weighed
  against the stack. Twenty-five releases back it gives up and names the
  two remedies.

### Updated

- **Nothing compiles through the bind mount any more.** The toolchain
  image points Mix at `/app/build` and `/app/deps`, two named volumes
  the workspace's compose declares and every one-off run shares —
  compiling through a bind mount is the load Docker Desktop's file
  sharing bears worst, and its VM fell under it. `bake` bakes
  `Dockerfile.local` again when the seed moved, keeping the project's
  own Phoenix installer, and rebuilds the image, so an existing
  workspace moves over with `bake && up`. On Linux the native Docker
  Engine is the one to use; `./wb.sh engine native` picks it.

- One stylesheet for the mock and the console
  (`console/priv/static/assets/css/console.css`), inlined into the
  one and served by the other, and the house's tokens projected into
  both by `assets/design/build.py`.

### Fixed

- Two readers of the igniter at once fought over one container name
  and the second answered nothing; the name carries the pid now.

- **An insert that fails no longer leaves the workspace half-written.**
  `add` runs each cartridge in its own container and commits it when it
  lands; an installer that wrote its files and *then* failed — Hex
  refusing to solve a version, most plainly — left those files behind
  uncommitted, and that alone stopped everything after it, since `add`
  and `eject` both need a clean tree. The workbench was stuck until
  somebody cleaned up by hand. It now undoes exactly that insert's work
  and says where the workspace stands. It asks nothing because nothing
  of the reader's is at stake: `add` begins on a clean tree
  (`require_clean_workspace`, which counts untracked files too) and
  commits each insert as it lands, so whatever is uncommitted at that
  point was written moments earlier by the insert that just failed.
  Ignored paths are left alone — `deps/` and `_build/` are the
  container's work, not the cartridge's. The insert failing and the
  commit failing are now told apart, and end differently: a failed
  insert wrote half of something nobody asked for and goes; a failed
  commit leaves a cartridge that did land, for the reader to commit by
  hand.

## v0.9.0 - (2026-08-31)

### Added

- The console colours the code a cartridge writes, and the box grows an
  **Installation** screen that shows it. `Console.Highlight` in
  `console/` keeps the registry, as data: a treatment per filename and
  then per extension — a Makeup lexer, a drawing, plain text, or left
  out. Adding a language is a line there and its `makeup_*` dependency,
  since every Makeup lexer emits the same token classes and the palette
  (`console/elixir_color_theme.jsonc`, One Dark, on the dark ground the
  Logs screen uses) is written once. What the registry does not name is
  shown plain and never guessed at: the Elixir lexer on an `.eex`
  template does not leave it grey, it colours `in` and `with` as
  keywords inside a CSS comment. `mix console.highlight` answers the
  same for the mock's generator, so there is one opinion and not two.

- The box's **Installation** screen: what the cartridge did to this
  project, off its own insert commit. Nothing new had to be recorded —
  `add` refuses a dirty tree, so one commit is one cartridge's whole
  diff, and its sha already travelled in `status --json` and was already
  named in the eject button's tooltip. It makes eject legible: the diff
  of what pressing it undoes. A patch cannot be handed to a lexer, so
  both faces of each file are coloured whole and the hunks are put back
  together out of them — context and additions off the new face,
  removals off the old — and only the lines a patch renders are kept.
  *Summary* first, one row per cartridge with its commit, its subject
  and its counts, and the collection's own row last with its commit
  cells empty, because it leaves none. Its figures are read off the
  range its picks span, never off the column added up: a file several
  picks touch is one file, and a line one pick wrote and a later one
  took out was never there at the start nor at the end. The range is
  only taken when their commits are contiguous — a second pass, a member
  born with `phx.new`, one ejected in between — and otherwise the screen
  says so. *Files* under it, each naming the picks that touched it.
  `mix.lock` is in: its lines run past a thousand characters, but the
  package and the version are at the front of each one, and the lock is
  the only place a cartridge shows what it drags in.

- One kind of cartridge. `workbench.setup` — the task that composed the
  opinionated project — is retired and reborn as **chiefs_setup**, a
  *collection*: a cartridge whose installer inserts other cartridges.
  Its recipe (`members/1` in the manifest) is the old composition,
  trimmed to the picks that need no external account — the dep-only
  quintet, rest **or** graphql (`--interface`, the one choice the
  collection owns), coveralls, exdoc, enhancements and healthcheck —
  in the old composition order. auth0, openai and stripe stay à la
  carte, their old `implies` turned into `requires`: the installer now
  refuses, naming the missing box, instead of silently pulling it in.
  With setup gone the composed/standalone split dies with it: the
  behaviour loses `flag/enabled?/implies/argv/enabled_by`, the registry
  is one list in shelf order, and the catalog marks `collection` (with
  its members) instead of `standalone`/flag.

- `mix workbench.expand`: the planning half of `wb.sh add` — one
  `plan> NAME [ARGS]` line per install to run. A plain cartridge
  expands to itself; a collection to its missing members, read off each
  member's own mark. `wb.sh add` now expands first and inserts each
  line as its own container run and its own `Insert NAME` commit, so
  `eject` keeps reverting one cartridge alone — a collection leaves no
  commit of its own, and re-adding it only inserts what is missing.

- The design rule for collections, in the features README: a
  collection's option must be a decision the collection itself owns,
  explainable on the box without naming a member's switch; whoever
  needs a member's option inserts the member. The rationale is
  chiefs_setup's DESIGN.md.

- Four cartridges for what the retired setup configured, each the one
  decision it is, the first three joined to the chief's recipe:
  **ansi** (`config :elixir, ansi_enabled: true`, so logs read through
  Docker come out coloured), **toolchain** (`.tool-versions` written
  from the versions actually running the installer — `mix.exs` only
  carries a range — plus `/.elixir_ls/` in `.gitignore`: the two halves
  of working on the project outside the container), **versioning** (the
  initial version in `mix.exs` and the `CHANGELOG.md` opened at it) and
  **guidelines** (the team's coding conventions downloaded from `--url`
  into the docs site). guidelines builds on exdoc and *appends* its page
  to the two lists exdoc's `docs:` block keeps, which takes the only
  network call out of the exdoc installer.

- `--build` on exdoc and coveralls: generate the site, and run the
  suite, once the insert is applied — the `documentation` step the
  retired creation ran, as an option of the cartridges that own it.
  Queued (`Igniter.add_task/3`), off by default, and not in the chief's
  recipe: it needs the dependencies compiled and, for coveralls on a
  project with Ecto, a test database. `afterwards/0` on both names the
  command for whoever leaves it off.

- The generators and migration types (`migration_primary_key`,
  `migration_timestamps`, `generators: [timestamp_type: …]`) are back,
  inside **enhancements** rather than as a box of their own: they are
  the configuration half of its `--id-type` and `--timestamps`, and two
  cartridges writing one policy could contradict each other. Without
  them `mix phx.gen.*` kept emitting `phx.new`'s defaults, so the
  tables drifted from the schemas `MyApp.Schema` defines.

- Changelogs backfilled for exdoc, coveralls and enhancements, as the
  anatomy asks of a cartridge that predates the rule and gets changed.

- The workbench reads its own catalog. Every cartridge declares
  `installed?/1` — off the *same mark its installer's guard reads*, a
  module, a file or a dependency, so a status query and a re-run of the
  installer can never disagree — and the registry now lists the
  standalone cartridges beside the composed ones, so `catalog/0` names
  every one of them, stripe's pending manifest included. Two mix tasks
  read it: `mix workbench.catalog` (name,
  version off the cartridge's CHANGELOG.md, summary off its task's
  `@shortdoc`, flag, implied flags, the installer's options; `--covers
  DIR` adds which sealed box covers exist) and `mix workbench.status`
  (the same, plus what this project carries). Both take `--json`.
  Cartridges whose options take a known set of values say so with
  `choices/0` — ash's `--data-layer` and `--api` closed, `--auth` and
  `--with` open with what ash-hq.org offers, coveralls' `--theme` off
  its template directories — and the catalog carries them, each value
  with the one-line doc the cartridge gives it (the package a choice
  stands for, what a theme looks like), for a form to show beside it. So do
  `option_docs/0` (one line per option, from which the task shell's
  "## Options" section is now rendered — the docs and the catalog read
  one text) and `enabled_by/0` (what turns a cartridge on under setup
  when it is not its own flag: `:enhance` for the trivial group, the
  interface for rest and graphql).

- `./wb.sh catalog [--json]` and `./wb.sh status [--json]`: the front of
  those tasks, run on a bare toolchain container with the source and
  the workbench mounted — no compose, no database. `status` adds what
  the host knows: the workspace's ports, which deployments were baked,
  and the containers of its compose project (dev and prod share their
  service names, so the image is what tells them apart).

- Base cartridges: a capability `phx.new` decides at generation time,
  added after the fact. `WorkbenchIgniter.PhxDelta` generates the
  project twice with `phx.new`'s own generator, on a scratch directory —
  with the flags that describe it today, read off the project, and with
  the capability on — and merges the difference three ways onto the
  project's files (`git merge-file`), so the delta is what `phx.new`
  writes at the installer's version and the project's edits survive; a
  conflict leaves the file alone with `phx.new`'s version beside it.
  Every capability `phx.new` can leave out: `mailer` (Swoosh; mark: the
  `swoosh` dependency), `gettext` (mark: `gettext`), `ecto` with
  `--database postgres|mysql|mssql|sqlite3` (the repo, its
  configuration, the data case, plus `DATABASE_URL` — `DATABASE_PATH`
  on SQLite — in `.env`; mark: `ecto_sql`), `esbuild`, `tailwind`,
  `html`, `live` (mark: `config :phoenix_live_view`, the one thing only
  `--live` brings) and `dashboard`. A default project shows them all
  inserted.

- `NEED.md` in the cartridge anatomy: the developer's need the
  cartridge answers, in their situation and not the mechanism's — one
  sentence, then *Before*, *After* and *Not for*. `need/0` reads it off
  the file the way `version/0` reads the changelog; the catalog carries
  it (`need`), `mix workbench.catalog` and the console's shelf show its
  line instead of the task's `@shortdoc`, and the box art starts from
  it. Every cartridge has one, pending stripe included; the catalog
  test refuses one without. Written because the first eight base
  cartridge covers were proposed from the papers and came out as
  pictures of the engine with nobody's problem in them.

- A `DESIGN.md` for each of the eight base cartridges, written from
  `phx.new`'s generator and templates, the libraries' own installation
  guides and Phoenix's guides, with the engine's argument in mailer's
  and each cartridge's own decisions in its own. The READMEs say what
  each capability is, per those guides, and what the papers measured
  on real projects. Two engine faults the probes found are fixed
  (mailer v0.2.0): a file an earlier insert had written conflicted
  when the next capability appended at its end — Igniter writes one
  trailing newline, `phx.new`'s `AGENTS.md`, `errors.pot` and `app.js`
  do not — so the merge now normalises the three ends and insert
  order no longer matters; and a delta taken by a `phx_new` other than
  the one that generated the project conflicted on `mix.exs` for six
  capabilities out of seven, so the engine now refuses with an issue
  when the archive's version is not the `{:phoenix, "~> x.y.z"}` of
  `mix.exs`, or when `Phx.New` is not loadable at all. And the
  toolchain pins the installer: `PHX_NEW_VERSION` in `config.conf`,
  baked into the workspace's `Dockerfile.local` and into the toolchain
  image's tag (`workbench:<elixir>-<otp>-phx<version>`), so a new
  installer is a new image and a workspace keeps the one that made its
  project. Three smaller things the papers had listed as open are
  closed with them: `--no-agents-md` is read off the project, so a
  project that opted out no longer receives `AGENTS.md` from an
  insert; `phx.new`'s static placeholders under `priv/static/assets/`
  are taken away by esbuild and tailwind when untouched; and on a
  conflict `<path>.phx-new` is written beside the file rather than
  into the patch set the issue withholds. tailwind (v0.1.1) says when
  the build will lack html's LiveView compiler, live (v0.1.1) when the
  browser will lack esbuild's `app.js`.

- `requires/0` in the manifest: the cartridges one builds on, by name
  (live on html — `phx.new` generates live only with html). The
  installer refuses with an issue naming what to insert first; the
  catalog carries the list as `requires`. A choice value can say the
  same for itself (`{value, doc, requires}` in `choices/0`; ash's
  `--auth password` on live and mailer, `--with ash_admin` on live):
  the catalog carries it beside the value and the installer refuses
  the same way.

- `status --json` carries `phx`: the project's shape in `phx.new`'s
  terms — each capability, the database, the adapter, and the flags that
  would generate it today — read off the project as the base cartridges
  read it. The table says the flags too.

- The cartridges that adapt to what the project has of `phx.new`'s
  capabilities read it off the project (`PhxDelta.facts`) instead of
  asking: `enhancements` (the Ecto group; the page, dashboard and
  mailbox tests), `exdoc` (the database page) and `coveralls` (the
  components folder) lost their `--no-ecto`/`--no-html`/`--no-mailer`/
  `--no-dashboard` options, and `setup` no longer passes them. `exdoc`
  also lost `--openai` and `--stripe`, which nothing read. Every option
  left is documented (the catalog and the task docs say what each does).

- The console (`console/`, `./wb.sh console [up|down|logs|build]`): a
  Phoenix LiveView app run as a container with Docker's socket and the
  workbench mounted at its host path. It reads `status --json` and
  `catalog --json`, runs every action as a `wb.sh` job with its output
  streamed to a tray, and ports the mock's board, shelf, box and tray
  with the mock's own styles. First slice: Deploy (up/down per target,
  setup, bake), Cartridges (the shelf, a box's options, insert, eject).

- ash v0.4.0: `--data-layer` takes several, as ash-hq.org's checkboxes
  do; `mix workbench.ash.site` checks that the site still treats them
  as independent.

- The console read once more with the eyes, and the repetitions taken
  out: the Jobs tab said what a job is three times over — the tray
  below, its own meta line, and the empty screen — so the tray steps
  aside while the tab is open and the empty screen says it alone, and
  the meta line that teaches unfolding turns into the way back once a
  job is open (they arrive unfolded, and a few commands are a wall);
  what Tab could not finish comes as a list to read — the candidates
  separated by bullets, standing three times as long as a notice, and a
  toast now cancels the one before it instead of cutting it short; the
  Terminal no longer prints a prompt under "No session. Open one"; the
  Project's documents read README, CHANGELOG, then the masked `.env`,
  not the secrets first; and a tick chip gives its right padding back
  when punctuation follows, which used to read as a space
  (`` `unavailable` ; ``). The board lost the *Probes* section — a poll
  of what one cartridge answers, told again by that cartridge's box —
  and reads its cartridges as a list, a line each, the same rows as the
  sections above it, where a grid of slot cards cost four times the
  height — each name wearing the house's reference (`.cart-ref`, the
  same mention a cartridge gets anywhere), not a label of its own. The
  board also reads in the order the work happens: deployments before
  containers — what you asked for before what runs because of it — and
  git last, after the cartridges whose inserts it records. And the jobs band only stands where a job could have come
  from: the screens that start one (Deploy, Cartridges, Cluster), never
  the Jobs tab itself, never with no job to show — and, running, it
  follows you anywhere. On the shelf, whether a cartridge is in is
  the box itself — the inserted keep their colour and take the accent
  ring, the rest sit grey — instead of a golden stamp that covered the
  cover's own band and part of its art; the caption carries the word,
  with the dot the cartridge chips use.

- Two placeholder boxes where there was one socket, a front and a back
  each. The **socket** (`cover_placeholder`, `back_placeholder`) stands
  in for a cartridge nobody has sealed a box for yet: the bare board,
  and its reverse side, which carries no lettering at all — a stand-in
  asserts nothing, and the workbench's name on a plate is typeset in
  the strip, never drawn into the art. The **empty**
  (`empty_cover_placeholder`, `empty_back_placeholder`) is for a
  cartridge that is not done — the drawing it would have been built
  from, stamped DRAFT and pending review, with the ink showing through
  the sheet when you turn it over. There is no cartridge to stand in
  for, and the drawing says so better than a caption could. The mock
  reads all four, on the shelf and in the hand. Two things the light
  drawing asked for: the caption's scrim turns light and its ink dark
  over it (the dark one written for the socket greyed the sheet and
  buried its stamp block), and a not-done box is no longer dimmed to
  nothing on the plank — the drawing already says what the dimming was
  saying.

- Console mock: the Config form's image row is named `DOCKER_IMAGE` and
  carries the link to the tags it is picked from, like every other
  version field. It is still the one row that is not a key of
  `config.conf` — the three versions under it are — but it is what the
  reader actually chooses, so it wears the same name shape.

- Console mock: the band's right end reads caveat, clock, `wb.sh` — the
  only button up there moved to the corner, where a control is looked
  for, answering the workbench's name at the other end of the band.

- Console mock: the deployment's buttons ask what `wb.sh` asks. All of
  them are refused without a project ("There is no project to build"),
  so all of them are off in an empty workspace, and the row says why —
  Up was offering a command that would have refused. And Build no
  longer waits for the target to be baked: `build --deploy prod|scaled`
  bakes its own compose before building, so a target nobody has baked
  yet is exactly when you would press it.

- Console mock: the box's kicker reads state first — `on the shelf` /
  `inserted` / `not done`, the two faces of it now both said — then the
  version, then what sort of box it is (`collection`, `base`). It no
  longer announces the design paper: the tab row above says DESIGN when
  there is one. Nor how many a collection inserts: the Specs panel
  below names every member.

- Console mock: a *Specs* panel in the box — what the cartridge is, as
  against what you are about to do with it. The mix task behind it
  first — its name in the workbench's own terms; then Kind (cartridge,
  base cartridge, collection) with what a second insert does; Needs,
  the manifest's and what the chosen options add, grouped by the switch
  that asked; Inserts, a collection's recipe with each member's argv;
  Opens, Answers and Lights, the doors, probes and tabs of `console/0`,
  their paths filled by the options; and After.
  Those facts were scattered — a kicker chip, two rows inside the
  insert form, and the console contributions nowhere at all — and the
  ones inside the form read as conditions of the insert rather than
  facts of the box. Empty rows never print, so most boxes show two or
  three. The panel is live: the rows an option moves say which switch
  moved them, rather than a fixed list contradicted below it. What is
  this project's business stays out of it — a value whose requirement
  is missing is disabled and says so, and Insert reads "Insert html
  first".

- The installer and the stack are weighed against each other before
  anything is built. Every `phx_new` release declares on hex the Elixir
  it runs on (`~> 1.17` for 1.8.13, `~> 1.14` for the whole 1.7 line),
  and `new` reads that requirement for the version it just resolved and
  refuses a stack below it, naming both remedies — a newer stack
  (`./wb.sh stacks`) or an older installer (`--phx-new`). Nothing was
  unchecked before: `mix archive.install` stops on the same pair
  ("You're trying to run :phx_new on Elixir v1.16.3 but it has declared
  … it supports only Elixir ~> 1.17"), only three layers into the image
  build, about a file nobody wrote, at the one moment the two versions
  it is talking about can no longer be chosen. Same verdict, said where
  the choice is. It stays a check and never becomes a derivation: the
  requirement is a floor and has no ceiling, so a Phoenix version
  answers *which Elixir is too old*, never *which Elixir*. Only hex's
  `~> MAJOR.MINOR` shape is read; any other form, an unreachable hex or
  a stack this cannot take apart is left to mix, since refusing a good
  stack on a guess is worse than the late error. Erlang never enters
  into it — Phoenix says nothing about OTP, and the Elixir/OTP pairing
  is already settled by the `hexpm/elixir` tag existing on Docker Hub.

- `status --json` carries `phx.generator`: which `phx.new` made the
  project, where that is recorded (`Dockerfile.local` for a workspace
  the workbench made, `mix.exs` for a project generated elsewhere), and
  which installer is at hand. The plain report says it in a line, and
  says what to do when the two differ. The base cartridges refuse on
  that difference, and until now nothing showed it until one of them
  did: a console can put it on the screen before anyone presses Insert.

- `PhxDelta.generator_check/1` reads that stamp instead of inferring the
  generator from `{:phoenix, "~> x.y.z"}`. The requirement was only ever
  a proxy — `phx.new` happens to write its own version there — and it
  said the wrong thing twice: bumping Phoenix, an ordinary thing, made
  every base cartridge refuse on a project it had not touched; and any
  other form of the requirement (`"~> 1.8"`, a pinned version, a moved
  dep) turned the check off silently. The stamp is written, is the
  project's, and survives both. `mix.exs` stays as the fallback for a
  project generated outside the workbench, and the refusal now names the
  remedy that works here — `./wb.sh build`, which rebuilds the toolchain
  from the workspace's own Dockerfile — instead of an `archive.install`
  thrown away with the container.

- One name for the state of a box that does not work yet: **not done**.
  It was `pending` on the chip, "Not ported yet" on the button, "Not
  written yet" on the shelf's plank and "not ported yet" in the box's
  summary — and the last two contradicted each other. Both of those
  words claimed something about where the work comes from, and neither
  is true: a box like stripe is designed from an implementation in
  another project, so it is no port and no blank page. "Not done" says
  only what the reader can act on; where the work comes from belongs in
  the box's own paper, which has room for it. The manifest keeps
  `pending?/0` — the wire name stays, the copy changes. Every surface
  says it now: the mock's chip, button, plank and caption, the
  LiveView console (which printed the state twice, once from `facts/1`
  and once from its own chip — the duplicate is gone), `workbench
  .expand`'s refusal, and the docs of `pending?/0` wherever they
  explained it, stripe's three papers included — whose NEED.md also
  stopped describing a world that ended with `workbench.setup`: what
  there is of the box is a manifest and its papers, and what happens if
  you ask for it is that `./wb.sh add stripe` refuses, naming it.

- `./wb.sh stacks [--json | -n N | use TAG]`: the usable technology
  stacks, asked of Docker Hub itself (recent `hexpm/elixir`
  `-debian-*-slim` tags, no RCs, version-sorted). `use TAG` checks the
  image exists (`docker manifest inspect`) and writes the three
  versions into `config.conf` — whose hand-kept tag list is gone: it
  was a cache that only went stale. The console's Config form shows
  four synced combos (stack ⇄ elixir · erlang · debian): the stack sets
  the three, editing one looks the exact tag back up, and a combination
  without a published image leaves the stack unpicked, the odd value
  saying so.

- `config.conf` is grouped by when a setting takes effect: what both
  creation commands read (name, stack, installer), git, the service
  images — and, at the end, what only the composed line (`new`) reads.
  CONFIG.md mirrors the grouping (and documents `COVERAGE_THEME`); the
  console's Config form tags each field honestly (`new · new2`,
  `every commit`, `every bake`, `toolchain build`, `new only`) instead
  of calling everything "new only". A comment block now belongs to
  whatever follows it with no blank line between — an `export` takes it
  as its help, a blank line leaves it to the section — so
  `GIT_IDENTITY`'s paragraph is the field's again and not the Git
  section's blurb, `POSTGRES_IMAGE_VERSION` keeps its link, and the
  notes a section closes with (there is no ports configuration, and no
  feature configuration either) are read at last, where they were
  dropped. A `# -- Group --` line inside a section is a heading in the
  form, not the help of whatever field came next.

- `console/0` in the manifest — the cartridges light the console up:
  the doors a cartridge opens on the app's port (exdoc `/dev/docs`,
  coveralls `/dev/docs/cover` with exdoc, rest `/dev/swagger` and
  `/dev/openapi`, graphql `/graphiql`, dashboard `/dev/dashboard`,
  mailer `/dev/mailbox`, ash `/admin` with `ash_admin`), the probes it
  answers (healthcheck2 `{path}/live` and `{path}/ready`, healthcheck
  `{endpoint}`), the tabs it turns on (clustering → Cluster). The
  catalog carries it as `console`; healthcheck2 reports the prefix it
  was inserted with (`state`). The console's board has a *Doors*
  section; the mock reads the same catalog instead of a table of its own.

- `afterwards/0` in the manifest: what follows the insert, when
  something does, as one sentence with the command (ecto's `bake`,
  clustering's scaled deployment, ash's `bake` with a database data
  layer). The catalog carries it, with `base` — whether the cartridge
  is a `phx.new` capability, in from birth unless left out.

- Console mock: the *New project* card offers the base cartridges as
  what they are — eight boxes in from birth, uncheck one to leave it
  out (`--no-x`; html takes live with it, as `phx.new` does) — with
  ecto's own options (`--database`, `--binary-id`: `phx.new` flags only
  Ecto reads, so the cartridge's) hanging from its box, and `--adapter`
  as the one generation-only choice. The *Afterwards* row of the box
  reads the manifest. It offers nothing else: `new` is vanilla and the
  card stops at creation — the collection is picked up from the shelf,
  like every other box.

- `./wb.sh bake`: bakes the workspace's `docker-compose.yml` again from
  the seed for the project as it is now, keeping its ports, as one
  commit — what `add ecto` asks for next (`setup` then creates the
  database). The compose drops the database and pgAdmin services on
  SQLite projects too, not only on projects without Ecto.

- Cartridges are commits. `new`/`new2` make the workspace's first commit
  (`New project: …`), `add` refuses a tree with changes git does not
  have and commits what it inserted as `Insert FEATURE …`, and the new
  `./wb.sh eject FEATURE` reverts that commit — refusing when the
  cartridge's files changed since, which is the honest answer. `./wb.sh
  commit [MESSAGE]` commits pending changes. All of it runs git inside
  the toolchain container, where the project's hooks can run mix, signed
  as `GIT_IDENTITY` in `config.conf` says: `user` (the host's identity,
  falling back to the workbench's own) or `workbench`. `status` reports
  the tree, HEAD and the inserts.

- The manifest says what a second run does — `rerun/0`: `:noop` (the
  default) or `:adds` (ash: every option is a package, so running again
  with more grows the install) — and `state/1`, what the project
  carries of an adding cartridge's options, read off the project;
  `status --json` carries both.

- `./wb.sh -y|--yes COMMAND` answers every confirmation (`new` over an
  existing project, `delete`), for scripts and for whatever drives the
  workbench without a terminal; `demo` hands it down.

- `assets/design/`: the house's design tokens, one source for every
  visual thing that is not a cover — a palette of four named values
  (the covers' violet and the seal's gold), roles with a light and a
  dark value (ground, surface, line, ink, muted, accent, the semantic
  three, the terminal, the service colours), and three type families by
  role. `build.py` projects them to `generated/tokens.css`, which the
  console mock now reads instead of a hand-written `:root{}`, and to the
  diagram-design skill's style guide, installed as the `workbench`
  profile the repository's `.diagram-design` marker names; `--check`
  fails when a projection is stale.

- `assets/diagrams/`: the cartridges' figures, one script for all of
  them. The clustering README shows the scaled deployment and the edge
  the cartridge opens inside it (Deployment); the ash README, what its
  queued command wires into the project (Architecture); the ash DESIGN
  §3.1, who writes what and when — why the cartridge's diff is empty
  (Sequence). Drawn to the diagram-design skill's rules with the house's
  skin, as SVGs that theme themselves with `prefers-color-scheme`; the
  console mock puts them in the page inline.

- The clustering cartridge's `DESIGN.md`: DNSCluster kept over
  libcluster and static names, the release pair in `rel/env.sh.eex`
  against `.env`, `vm.args` and the Dockerfile (the boot script sources
  it before applying its own defaults, and only there is the container
  address known), the four `release.init` templates from Mix's own
  functions with `mix release.init` queued as the fallback, the scaled
  compose's shared `app` alias against scaling the pod, why a workspace
  cannot cluster with itself and why one image means one cookie, and
  the mark `installed?/1` and `wb.sh` both read. Read against the
  sources — `dns_cluster` 0.2.0, Mix 1.19.5's release script, the two
  compose seeds, `wb.sh` — and the scaled deployment repeated on
  `test_28` with the output kept. Two README sentences it found
  imprecise are listed as open items. A second figure joins
  `assets/diagrams/clustering/`: the boot as a sequence, and what the
  same boot does without the block. The cartridge gets its
  `CHANGELOG.md` with it — v0.1.0 for what it has installed since
  2026-08-25, v0.2.0 for the manifest additions and the paper — so the
  catalog shows it versioned like the rest.

### Updated

- The README's *Architecture* section — a table of services and a
  diagram of one topology — is replaced by *The workspace*: what holds
  for every project (the workspace owns its orchestration, the pod
  pattern, the ports) and the orchestration files. The shape of a
  project is no longer described in one place, because there is no one
  shape: each cartridge's README says what it installs and wires, each
  deployment what it brings up, and `./wb.sh status` and `catalog` what
  is there and what could be. `assets/arq.svg` goes with the section.

- An existing workspace names itself: every command but `new` and
  `new2` reads the compose project name and the dev image from the
  workspace's own `docker-compose.yml`, not from `config.conf` —
  which may since have been edited to name the next project, and used
  to rename the one-off containers and the `:local` image `delete`
  removes.

- New `healthcheck2` cartridge (`./wb.sh add healthcheck2`): liveness
  and readiness probes as the first plug of the endpoint — the vanilla
  counterpart of `healthcheck`, in the sense `new2` is of `new`. A
  `MyAppWeb.Plugs.Health` answers `GET /health/live` with 200 while the
  VM answers, checking nothing else on purpose (an orchestrator
  restarts the container on that failure, and a restart does not fix a
  database that is down), and `GET /health/ready` with 200 or 503 from
  a `SELECT 1` on the repo with a one-second timeout, so a saturated
  pool fails inside the platform's probe window instead of hanging it.
  Mounted before `Plug.Static`, a probe never reaches `Plug.SSL`, the
  logger, the parsers, the session or the router. No dependency, no
  config, no router change; a `--no-ecto` project gets a readiness that
  answers like liveness. Its README carries the Kubernetes, Fly.io and
  AWS ECS wiring; its `DESIGN.md`, the reasoning behind the split.

- New `ash` cartridge (`./wb.sh add ash`): the Ash framework, with
  the choices of ash-hq.org's *Get Your Installer* for an existing app
  as options — `--data-layer postgres|sqlite|csv|none`, `--api
  json_api,graphql,typescript`, `--auth <strategies>`, `--with
  <packages>` for the site's *Advanced Options*, `--example` — turned
  into the command the site generates and queued to run once the patch
  set is applied: `mix igniter.install ash <data layer> ash_phoenix ...
  <flags>`. Every Ash package carries its own Igniter installer, so
  the cartridge writes no file itself and second-guesses nothing Ash
  does; packages the project already declares are left out of the
  command; with `--auth`, `TOKEN_SIGNING_SECRET` lands in `.env`
  (generated) and `.env.sample` (blank), the variable
  `ash_authentication` makes `runtime.exs` require in `:prod`.
  Standalone, on the vanilla line: the opinionated setup's own users
  table and Ecto scaffolding are what Ash replaces. Its `DESIGN.md`
  says why a queued command and not composed installers, and what the
  real run taught (the Phoenix auth installer's prompt).

- `WorkbenchIgniter.env_entry/4`: an optional body for `.env.sample`,
  so a cartridge can write a secret to `.env` and its blank line to
  the committed sample.

- Two files join the cartridge anatomy, `healthcheck2` being the
  reference for both: a `CHANGELOG.md` per cartridge (Keep a Changelog,
  semver over what the cartridge installs, independent of the workbench
  release), and a `DESIGN.md` — the design rationale in the shape of a
  short paper: problem, background quoting the primary sources, each
  decision against its alternatives, what was verified and what was
  not, open questions, numbered references. Older cartridges get both
  on their next change.

### Removed

- `./wb.sh new` (opinionated) and `mix workbench.setup` (27 options,
  `config.conf`-driven): `new2`/`setup2` take their names — the vanilla
  creation is the only one. `config.conf` loses the whole "composed
  project configuration" section (`INIT_VERSION`, `ID_TYPE`,
  `TIMESTAMPS`, `INTERFACE`, `ENHANCE`, `EXDOC`, `COVERALLS`,
  `COVERAGE_THEME`, `HEALTH`, `AUTH0`, `OPENAI`, `STRIPE`,
  `CODING_GUIDELINES_URL`): features are cartridges now, and a
  cartridge's options are set on its own installer. What those
  variables configured has owners again — `versioning`, `toolchain`,
  `enhancements`, `coveralls` and `guidelines` — reached by inserting
  the box, not by editing this file.

- The retired setup's `README.md` template, with no owner: a generated
  README has to know every cartridge to list what the project carries,
  which is the coupling this structure exists to remove. `phx.new`
  writes one; the project writes its own from there.

- The entrypoint's `documentation` branch, which ran `mix docs` and
  `mix cover` after the opinionated creation: it is `--build` on exdoc
  and coveralls now.

- **No Phoenix installer setting.** `PHX_NEW_VERSION` is gone from
  `config.conf`: `new` asks hex.pm for the newest `phx_new` — or takes
  `./wb.sh new --phx-new VERSION`, for when there is a reason to pin —
  and stamps whatever it resolved into the workspace's own
  `Dockerfile.local` (`ARG PHX_NEW`), which every other command reads
  back to name the toolchain image. Nobody chooses a version, and the
  choice is still written: it is the generator the base cartridges take
  their delta with, so it can be neither a moving target (the same repo
  built twice would give two toolchains) nor one global default for
  workspaces created months apart. A workspace made before the stamp
  names no installer and keeps the bare `workbench:<elixir>-<otp>` tag
  it was built with.

### Fixed

- `status` starts one container instead of four: its git queries run
  with the git at hand when there is one (the console's container has
  it; a host may), the toolchain container's otherwise — writes (commit,
  revert) stay there, where the project's hooks find mix — and the
  igniter query tasks compile the package and run in one Mix boot.

- `status --json` and `catalog --json` are valid JSON even when mix
  has something to compile on the way to the task — a dependency the
  last cartridge brought, the project, the package itself — which it
  prints on stdout before the answer: the readers keep from the first
  JSON line on.

- `add` compiles the igniter package before running the installer: as
  a path dependency on the mounted workbench, Mix did not always notice
  it had changed, and an installer edited since the last run could run
  in its previous form.

- `add COLLECTION` inserts every cartridge of the plan, not only the
  first. The plan reached the loop on stdin, and the container each
  insert runs in attaches to stdin and drank the rest of it: the loop
  then ended on EOF — quietly, and with a zero exit — one cartridge
  into a recipe of thirteen. `add chiefs_setup` had never put in more
  than its first missing member. The plan is read on its own descriptor
  now, so there is nothing on stdin for the container to take.

- The console mock keeps its JavaScript when a cartridge's diff or
  document carries a literal `</script>`, as exdoc's `mix.exs` and
  coveralls' `.html.eex` templates do. The HTML parser ends the block
  wherever it sees those characters, whatever the JavaScript around
  them says, so the page loaded with every function undefined and
  eleven syntax errors. Every JSON payload the page carries escapes the
  slash now — the documents as much as the diffs, since a README that
  writes the tag would have done the same without warning.

- `status --json` is valid JSON when a cartridge's NEED.md travels in
  it. The object was assembled around the task's answer with `echo`,
  which is free to read the `\n` a JSON string is made of, and a raw
  newline inside a string is what makes a reader call the whole answer
  invalid — a `--json` that exits zero and cannot be parsed. Every
  value goes in as a `printf` argument now, never as part of the
  format, and `json_string` escapes the control characters too and not
  only the backslash and the quote.

## v0.8.0 - (2026-08-24)

### Added

- New `new2` command: the vanilla project creation. It generates a stock
  `phx.new` project and applies only what the dockerized workspace
  requires to boot it — the dev endpoint bound to `0.0.0.0` (the compose
  pod pattern delivers the published port on the namespace interface,
  never on loopback), the `.env`/`.env.sample` pair the compose
  `env_file` declaration requires, and the `.env` entry in `.gitignore`.
  The application and feature settings in `config.conf` are ignored, so
  no base config, no `README.md`/`CHANGELOG.md`/`.tool-versions` and no
  feature installer: they are added afterwards with `add`. It is driven
  by the new `mix workbench.setup2` task (6 options, `composes: []`),
  and is the base for the ongoing restructuring of the igniter package.
- New `clustering` cartridge (`./wb.sh add clustering`): boots the
  production release as a named distributed node so DNSCluster can
  connect the replicas. `phx.new` already ships the `:dns_cluster`
  dependency, its supervision-tree child and the `DNS_CLUSTER_QUERY`
  read in `config/runtime.exs`; what it leaves open is the release
  running in distributed mode, which the cartridge writes into
  `rel/env.sh.eex` along with the other three `mix release.init`
  templates — generated from the running Elixir rather than copied into
  this repo — and `DNS_CLUSTER_QUERY` in the environment files. Nothing
  to cluster with inside a single-container workspace: it prepares the
  project for a multi-replica deployment.

- New `scaled` deployment (`up --deploy scaled`): production replicas of
  the release image, baked from `scripts/docker-compose.scaled.seed.yml`.
  It drops the pod pattern on purpose — replicas sharing a network
  namespace would share one IP and one port, so only the first would
  bind the server and every `RELEASE_NODE` would collide — and puts the
  replicas on a bridge network with one host port each and a shared
  `app` network alias, which makes Docker's DNS answer that single name
  with every address. Leaving the pod means the database is reached by
  name, so `DATABASE_URL` is overridden and a one-shot `migrate` service
  runs before the replicas start.
  With the `clustering` feature installed the replicas also form a real
  BEAM cluster, since that alias is what `DNSCluster` queries. Without it
  they run isolated — a valid deployment for a stateless application — so
  `up` and `build` warn and carry on rather than refusing, and the compose
  leaves `DNS_CLUSTER_QUERY` unset, keeping `DNSCluster` out of the
  supervision tree instead of letting it poll for peers a short-named
  release could never reach.
- The scaled deployment puts an nginx balancer in front of the replicas
  (single entry point, WebSocket upgrade for LiveView and Channels, and
  an `X-Served-By` header carrying the address of the replica that
  answered — the same address its node name shows). The per-replica
  ports stay published so a specific node can still be addressed.
  `up` and `build` take `--replicas N` (default 4) and `--no-balancer`;
  both only shape how the compose file is baked, so `logs`, `ps`, `stop`
  and `down` never need them. New `NGINX_IMAGE_VERSION` in `config.conf`.

### Updated

- `new2` no longer runs `mix release.init`. Its four `rel/*.eex` files
  are customization scaffolding whose defaults Mix already carries built
  in, and they now belong to the clustering cartridge. `new` keeps
  running it from the entrypoint, unchanged.
- Deployments are selected with `--deploy`, not `--env`: `up`, `build`,
  `logs`, `ps`, `stop`, `down`, `iex` and `bash` pick a compose file, not
  an environment, and the third value (`scaled`) is a topology rather than
  a `MIX_ENV`. The old spelling is rejected with a message pointing at the
  new one instead of being silently accepted. `setup` and `demo` keep
  `--env`, where the value really is `MIX_ENV`.
- `up` and `down` pass `--remove-orphans`. Every deployment of a
  workspace shares one compose project but not the same services — dev
  has `app`, the scaled one has `app1..N` plus `balancer` and `migrate`, and
  `--replicas`/`--no-balancer` change that set between runs — so the
  containers of the previous shape used to stay up, unmanaged and
  invisible to `ps`. `stop` and `ps` do not accept the flag.
- `new` and `new2` share their body in the `create_project` function,
  and the template planting, the `SECRET_KEY_BASE` generation and the
  new `env_entry/3` (the `.env`/`.env.sample` counterpart of
  `gitignore_entry/3`, so a cartridge owns its own variables) live in
  `WorkbenchIgniter`.
- The `.env` template no longer carries `DATABASE_URL`, `ECTO_IPV6` and
  `POOL_SIZE` in projects generated with `--no-ecto`.
- `DNS_CLUSTER_QUERY`, `RELEASE_DISTRIBUTION` and `RELEASE_NODE` left the
  `workbench.setup` `.env` template, where they sat commented out. The
  clustering cartridge owns them now, each where it belongs: the query in
  `.env`/`.env.sample`, the release pair in `rel/env.sh.eex`.

## v0.7.0 - (2026-08-23)

### Fixed

- Igniter features planted their files under module-derived directories
  (`Macro.underscore/1`), which diverge from the phx.new app-name
  directories when the app name carries digits (app `:lorem_3` →
  `Lorem3Web` → `lib/lorem3_web/` instead of `lib/lorem_3_web/`),
  forking a parallel source tree with duplicated modules whose tests
  mask each other. Every feature now derives `web_dir`/`app_dir` from
  the app name, exactly like phx.new.

### Added

- Igniter cartridges now hold only code: every non-code file — EEx
  templates, verbatim assets, binaries — moved from
  `lib/workbench_igniter/features/<f>/{templates,assets}/` to
  `priv/features/<f>/`, where nothing is compiled, so Elixir assets drop
  the `.asset` suffix (`cover.ex.asset` → `cover.ex`). `embed_templates`/
  `embed_assets` resolve the cartridge's `priv/features/<name>/`
  directory automatically.
- Coverage report themes for the coveralls feature: the excoveralls HTML
  template is now picked from
  `priv/features/coveralls/assets/template/<theme>/` in the igniter
  cartridge, selected with `mix workbench.install.coveralls --theme` (or
  `COVERAGE_THEME` in `config.conf`, forwarded by `workbench.setup
  --coverage-theme`). `custom` keeps the original report; the new
  `exdoc-ish` theme (default) mimics the ExDoc pages (sidebar with project logo and
  tabs, search-style file filter, light/dark synced with ExDoc's own
  setting, Lato and Remixicon reused from `doc/dist/`, coverage vs.
  minimum target cards, lines covered / missed / line hits stats).
- `mix cover`: a failing module is flagged with a leading ❌ in its
  `TESTING.md` heading, so broken modules stand out in the ExDoc sidebar
  (passing modules stay unmarked).
- `mix cover`: `COVERAGE.md` and `TESTING.md` merged into a single
  `TESTING.md` ("Test Suite Report"): execution result board, then the
  coverage section, then the per-module sections. The report links
  (overview and per file) point at the `/dev/docs/cover` route instead
  of `excoveralls.html`, and the report page moved to
  `/dev/docs/testing.html`.

- `wb.sh` lifecycle commands over the workspace compose, Makefile-style:
  `logs [SERVICE...]` (follow, Ctrl+C detaches), `stop`, `down` and `ps`.
- `build [-e, --env ENV] [OPTIONS]` command: (re)builds the workspace's
  app image without deploying it — the dev image from the project-owned
  `Dockerfile.local` (previously only `new` built it, destructively), or
  the production release image with `-e prod`. Extra OPTIONS go to
  `docker compose build` (e.g. `--no-cache`). The production compose
  baking moved into a `bake_prod_compose` function, shared by `build`
  and `up --env prod`.
- `wb.sh` session commands running on the **already running** app
  container via `docker compose exec` (instant, and exiting never stops
  the application): `iex` (IEx shell), `bash`, and `mix [ARGS...]` for
  any mix task (`cover`, `docs`, `test`...). With the system down, `mix`
  falls back to a one-off container, starting the database dependency.

### Updated

- `igniter/` is now the restructured cartridge edition: the legacy
  package and the first cartridge edition (`igniter2/`) were removed, and
  with a single edition left the `IGNITER_DIR` override is gone too.
  - Every cartridge is a directory with its own `README.md` — the
    dep-only ones (credo, mock, exdebug, psql_extras, osmon, githooks,
    exmachina, stripe) split into `<feature>.ex` + `task.ex` like the
    rest; the "single-file cartridge" format is gone.
  - One test file per cartridge: the parameterized `deps_test.exs`
    became `credo_test.exs`, `mock_test.exs`, etc.
  - `priv/assets/` disappeared: the DbSchema diagrams and Postman
    collections are text, so they moved into the enhancements cartridge
    (`assets/{db_schema,postman}/`, embedded like any other asset); the
    setup templates moved to `priv/setup/templates/`. `priv/features/`
    mirrors the cartridges for binary assets only (the exdoc logo).
    `WorkbenchIgniter.asset/1` was removed; cartridges reach `priv/` with
    the local `priv_asset/1` / `plant_binary_asset/3`, derived from the
    cartridge directory name.
- `up` now deploys **detached** (both dev and prod): the terminal stays
  free, and the command prints the application URL plus the `logs`/`stop`
  hints. Previously it followed the containers in the foreground and
  Ctrl+C stopped them.
- `demo` follows the logs between `up` and `delete`: the demo blocks
  while the application is tried out, and Ctrl+C moves on to the
  teardown (a no-op SIGINT trap keeps the script alive through the
  Ctrl+C that detaches the log follower).

### Removed

- `run` command (and its entrypoint branch): it was a workaround to run
  `iex` and mix tasks, superseded by the `iex`/`mix`/`bash` exec
  commands. Its blocking "Press any key" prompt is gone with it.
- `prune` command: it stopped ALL containers on the host and ran
  `docker system prune -a --volumes` — a machine-wide blast radius out
  of the workbench's scope. Workspace cleanup is covered by `delete`
  (`down --volumes --rmi local`) and the new `stop`/`down`.

### Fixed

- The generated `mix cover` task broke the production image build: it
  read `coveralls.json` at compile time (`File.read!` in a module
  attribute) and the production Dockerfile never copies that file. It
  now falls back to defaults when the file is absent — harmless, since
  releases carry no Mix and the task cannot run in them — and declares
  `@external_resource`, so editing `coveralls.json` recompiles the task
  (before, a changed `minimum_coverage` was silently ignored until a
  forced recompile). Fixed in both igniter editions and documented here
  because the asset ships into every generated project.
- Misleading guidance removed: comments in `wb.sh` and the compose seed
  suggested switching the workspace's `docker-compose.yml` to the
  production Dockerfile by hand. That breaks every toolchain command
  (`setup`, `add`, `mix`, `iex` run through the same app service) — the
  production deployment has its own `docker-compose.prod.yml`, baked by
  `up --env prod`. The entrypoint now also fails with a clear message
  when it lands in a mix-less production image instead of a cryptic
  "mix: command not found".
- `workbench.setup` (cartridge edition) now re-resolves the dependency
  lock — `deps.unlock --all` + `deps.get`, queued ahead of every feature
  task — instead of leaving the known phx.new-lock conflict (idna 7.x vs
  the `auth0_jwks`→hackney chain needing ~> 6.1) to the entrypoint's
  after-setup fallback. Igniter's automatic post-apply fetch tolerates
  that resolution failure, but the queued binary-asset task runs `mix`
  in the project and aborted setup on the unresolved deps, so auth0
  projects failed to generate. The moved medicine also fixes standalone
  `mix workbench.setup` runs without the workbench script.
- Binary assets are no longer routed through the igniter rewrite
  pipeline, which normalizes every file it writes
  (`String.trim_trailing/1` plus a final newline) and corrupts binaries
  — the planted ExDoc logo carried an appended byte, and a binary
  ending in whitespace-like bytes would have been truncated. The
  cartridge edition now plants them verbatim: a new internal
  `mix workbench.plant_asset` task copies the file byte-for-byte, and
  installers compose it via `WorkbenchIgniter.plant_binary_asset/4`
  (an `Igniter.add_task/3` after-apply step, so dry-run semantics stay
  intact). The legacy edition keeps the old behavior: it is on its way
  out once the cartridge edition proves itself.
- Internal container ports are no longer magic numbers: the `:4000` in
  the host-port parser and the `:5050` anchors now reference
  `APP_INTERNAL_PORT` / the new `PGADMIN_INTERNAL_PORT`, and the compose
  seed takes pgAdmin's listen port as a `%{pgadmin_internal_port}`
  placeholder.

## v0.6.0 - (2026-08-21)

### Added

- Generated Dockerfiles renamed to the conventional `Dockerfile`
  (production) and `Dockerfile.local` (self-contained local image). The
  local image is self-initializing (`mix setup && mix phx.server` on
  start), accepts `--build-arg MIX_ENV`, runs `mix assets.setup`
  explicitly, and no longer installs the `phx_new` archive; asset steps
  are omitted on `--no-assets` projects in both Dockerfiles.
- `workbench_igniter` Elixir package (`igniter/`): all project configuration
  is now applied semantically (AST-based) via `mix workbench.setup` and one
  `mix workbench.install.*` task per feature, with a 93-test suite.
- `wb.sh`: thin Docker wrapper replacing `app.sh`. New `add FEATURE`
  command to install features on an existing project.
- `WORKSPACE_PATH` (config.conf): projects are generated into a workspace
  directory (default `./_workspace`); the workbench stays permanently in
  its own directory and is mounted read-only at `/app/workbench`.
- Conditional `workbench_dep/0` injected in the generated `mix.exs`: the
  project stays self-contained when the workbench is not mounted.
- Each workspace owns its `docker-compose.yml`, baked with real values
  (name, ports, images) at creation — the source of truth of its
  orchestration. Host ports are auto-assigned (first available from 4000 /
  5050) so several workspaces run simultaneously without conflicts, and
  there is no ports configuration in `config.conf` anymore. The workspace
  services form a **pod**: a minimal `network` holder service owns the
  namespace and the published ports (the role of the "pause" container in
  a Kubernetes pod) and `app`, `database` and `pgadmin` join it — they all
  reach each other through `localhost`, so the project keeps Phoenix's
  default database configuration untouched and the database is not
  published to the host. The images are born with the identity of the
  launching HOST user (`ARG UID/GID` baked at build — they are always
  built locally): everything written into the workspace belongs to them,
  never to root, with no runtime `user:` configuration anywhere. The app image is project-owned (`<app>:local`, buildable from its
  own `Dockerfile.local`); the workbench seeds it as a zero-cost alias
  (`docker tag`) of the shared toolchain image `workbench:<elixir>-<otp>`. pgAdmin is fully self-contained (inline
  `configs.content` servers.json and entrypoint-generated pgpass). The
  workspace compose builds from the project-owned `Dockerfile.local`;
  switching to the production `Dockerfile` is a manual edit of the compose
  file. The workbench tooling (`Dockerfile.app`, `entrypoint.sh`) never
  leaves the workbench. The `setup` and `documentation` container runs no
  longer publish the application port.
- Generated `.env.sample`: same template as `.env` with the secret blanked
  out, meant to be committed (`cp .env.sample .env` flow). The generated
  README was expanded: table of contents, environment variables reference
  (deployment/required/default per variable, including the standard
  Phoenix release variables), asdf/mise setup from `.tool-versions`,
  Docker Compose start/stop instructions and, on `--exdoc` projects, a
  documentation section covering `mix docs`, `doc/` and `llms.txt`.
- `mix cover` now generates a structured markdown report instead of a
  terminal dump: coverage table per file with anchor links into the
  excoveralls HTML report and a totals row, ExUnit run metadata (seed,
  max_cases, timings), a totals summary table, one section per test
  module with per-test rows linking to the source line on GitHub
  (derived from the ExDoc `source_url` config, degrading to plain text),
  failure detail blocks, and skipped-test handling. The report is
  written to `TESTING.md` at the project root (gitignored; a placeholder
  keeps `mix docs` working before the first run) and the runner became a
  `mix coveralls.html` subprocess whose exit code participates in the
  validation. `coveralls.json` widens `file_column_width` to 128 so the
  parsed rows keep full file paths, and the generated `homepage_url` now
  reuses `repo_url` instead of inventing a domain.
- Generated outputs moved to the standard directories: the excoveralls
  HTML report goes to `cover/` and the ExDoc output to `doc/` (the
  defaults, already covered by phx.new's stock `.gitignore` and
  `.dockerignore` — so they neither pollute the repo nor ship in the
  production image, which used to copy `priv/static/doc` via `priv/`).
  `assets/` now holds only source files (the report template lives in
  `assets/cover/template/`), `Plug.Static` and the ExDoc controller
  serve `doc/` relative to the VM cwd (dev-only routes), and the test
  dummy pages are planted in plain `doc/` instead of `_build/test`. The
  gitignored `TESTING.md` entry is added via a shared
  `WorkbenchIgniter.gitignore_entry/3` helper.
- Coverage report template (`_style.html.eex`): added the unprefixed
  `border-radius`, `box-shadow` and `transition` properties (only the
  long-dead `-webkit-`/`-moz-` prefixed forms were present, so modern
  browsers rendered the report without those styles) and removed a stray
  quote inside the `#menu` rule.

### Removed

- `app.sh` and the whole sed/seed approach it implemented: `seeds/` (moved
  to `igniter/priv` as EEx templates and assets), `scripts/contexts/`
  (replaced by direct generation of the final schemas), the legacy `scripts/entrypoint.sh`
  (rewritten for the igniter flow), root `assets/` and `pgadmin/`
  (moved to `igniter/priv/assets` and setup templates), the
  `CUSTOM_SCHEMAS` configuration, the `*_CONTAINER_NAME` settings, and the
  generated `priv/repo/pgadmin/` credential files.

### Fixed

- Latent issues inherited from `app.sh`, corrected in the igniter port:
  healthcheck OpenAPI schema written over `user.ex`, `datbase.dbs` typo,
  helper tests coupled to Auth0, `mix db` failing on fresh projects,
  Finch pool missing on `--no-mailer` projects, Hex lock conflicts
  after feature installs, duplicated migration timestamps when composing
  auth0+openai, the database healthcheck passing the password as the
  database name (`pg_isready -d`), the application healthcheck always
  failing because `curl` was missing from the dev image, and flaky Hex
  fetches during image builds (`HEX_HTTP_CONCURRENCY=1`).
- Generated README no longer embeds the `.env` content — it used to leak
  the generated `SECRET_KEY_BASE` into a committable file; it now points
  to `.env.sample`. The env export instruction became
  `set -a && source .env && set +a` (the previous
  `export $(grep -v '^#' .env | xargs)` broke on values with spaces), and
  `.env` starts with `PHX_HOST="localhost"` instead of a placeholder
  domain that failed WebSocket origin checks locally.
- Markdown tables in the generated README were broken: EEx `:trim` leaves
  stray newlines around block tags, splitting conditional table rows with
  blank lines. Conditional rows are now rendered inline and `plant/5`
  collapses residual blank-line runs.

## v0.5.0

### Added

<!-- # BETTER SERVICE STRUCTURE -->
- remove dev dockerfile even devinvoriment. the image must be compiled in prod, its very dangerous to have dev images with doc and source code in circulation, de docs coverage, monitoring must be run only in local

- ajustar parche en config.dev "localhost"

<!-- # CONTINUE -->
- Configuration file documentation.
- **Remove workbench** command in workbench script.
  - adjust docker-compose to work independently from script
- Workbench script implementation: **Stripe**.
- Workbench script implementation: **GraphQL**.
- Generated all missing documentation for functions in `app` script.

### Fixed

- DB port change breaks pgadmin maybe back?

## v0.4.2 - (2025-11-09)

### Added

- Different Dockerfile generation for `dev` and `prod` deployments.

## v0.4.1 - (2025-08-10)

### Added

- Project configuration completed with `mix release` generation files and suggested `.dockerignore` file.
- **Watchman** was added to the `Dockerfile.dev` configuration since the updated Phoenix version `1.8` uses it.

### Changed

- The **coverage report HTML styles** template was updated, with new CSS styles.
- The sections in **Testing Reports** were reordered.

### Fixed

- ExDoc unlocked from version `0.35` due error on **DomLoaded event listening**. With better understanding of the new front-end framework (`"swup"` and `"exdoc"` events), now the **Get Access Tokens** and **Database** sections in ExDocs does not need to reload the page to get the scripts works properly.
- Adjustments for elixir `1.18` support.
  - Deprecations on **CLI prefered envs**.
  - `lib/lorem_ipsum/application.ex` file changes.

## v0.4.0 - (2025-03-01)

### Added

- Workbench script implementation for **Auth0**.
- Workbench script implementation for **DbSchema** documentation.
- Mix task `mix db` to format _DbSchema_ database files for inclusion in _ExDoc_ documentation.
- Workbench script implementation: **AI Assistant** demo.
- Refinement of migrations and schema files (general post-implementation task).
- Complete unit testing with 100% success and coverage.
- Project code documentation.
- Functional API-REST documentation.
- Multiple _Postman Collection_ JSON files for different project configurations.
- Multiple _DbSchema_ SVG database diagrams for different project configurations.
- A uniquely branded application icon, instead of the temporary _ExDebug_ icon.

### Updated

- Redesigned architectural diagrams for different project configurations.
- Updated `Get access token` interface in _ExDoc_ documentation.
- If the project is configured without an **Ecto** implementation, the _Postgres_ database and _PgAdmin_ services will not be set up in the `docker-compose.yml` file.

### Removed

- Workbench script implementation: **Flame On**.
- Workbench script implementation: **ExMachina**.

## v0.3.0 - (2024-10-24)

### Added

- Generate `.tool-versions` file for [ASDF Version Manager](https://asdf-vm.com/) compatibility.
- Updating the workbench script version at the beginning of the file will update the version badge in the `README.md` file during the next script run.
- Workbench script implementation: **ExDoc**. The pages and content are adjusted following `config.conf` file.
- Workbench script in _ExDoc_ documentation.
- Multiple architecture images and content for different project configurations in the _ExDoc_ workbench documentation.
- Workbench script implementation: **Coveralls**.
- Mix task `mix cover` for test report generation for ExDoc.
- Workbench script implementation: **Healthcheck**.
- Workbench script implementation: **OpenAPI**.
- **Delete** command in workbench script.
- **Demo** command in workbench script.
- **Help** command in workbench script.
- Workbench script implementation: **Flame On**.
- Mix task `mix version` for update project version on `mix.exs` and `README.md` file.
- Workbench script implementation: **Ex Debug**.
- Workbench script implementation: **OS mon**.

### Updated

- `README.md` adjustments.
- Workbench script refactor.
- The workspace script and its files are moved to a subfolder, leaving the new project files in root directory instead of creating the project in a subfolder.

## v0.2.0 - (2024-10-07)

Second version after _Pitcher's_ testing cycle (Untracked changes).
