# specdd — Design

*Revision: design, installer pending (2026-09-02). Sources consulted on
that date; quotations are verbatim from the page or file as read then.
SpecDD release 1.5 (2026-07-16), language 1.2, CLI 1.1.1.*

## Abstract

A `phx.new` project hands a coding agent an `AGENTS.md` that says how
Elixir and Phoenix are written, and nothing about what the agent may
change or where it must stop; that is retyped in every prompt. SpecDD
is a small framework that keeps it in the repository instead: `.sdd`
files beside the code, a bootstrap the agent reads first, and a
path-based resolution rule. This cartridge plants what the framework's
own `specdd init` plants — at a release pinned in the cartridge, off
embedded files, without the network — and then what `init` cannot
know: a `bootstrap.project.md` written for an Elixir/Phoenix project
and three starting specs (the project, `lib/`, `test/`). The mark is
the file the CLI itself keys on, so installer, status and CLI agree.
The one option is the root spec's name, because SpecDD names it after
the *directory* and the installer, running in a container, cannot see
the host's. The rendered specs were verified with the CLI's own `lint`,
`resolve` and `inspect`, which also showed the root-name rule to be
literal: a root spec not named after the directory is not resolved.

## 1. Problem

Since Phoenix 1.8, `phx.new` writes an `AGENTS.md` unless told not to
(`--no-agents-md` [8]): the project's rules, then Elixir and Phoenix
usage rules in fenced `<!-- usage-rules-start -->` blocks [9]. It is
good at what it is for — *how* code is written here: `<Layouts.app>`,
`<.input>`, `mix precommit`. It is silent on what a task may touch and
what must keep holding, because a generator cannot know that, and so
each prompt carries it and each session loses it.

The team wants that written down where the code is, in a form an agent
resolves by itself and a reviewer can read. SpecDD is one such form,
and it is deliberately tool-agnostic: "Specs remain plain text
compatible with any editor and any file-aware AI agent" [1]. Its
installer, though, is a Node CLI (`npm install --global specdd`, Node
22 or newer [3]) or a Docker image, run on the host. The workbench's
promise is that nothing is installed on the host, and that a feature
is one commit `eject` can revert. Hence a cartridge.

## 2. Background

### 2.1 What SpecDD is

The framework's own description [1]:

> "SpecDD is an open-source framework enabling humans and AI agents to
> build software using small, local, human-readable `.sdd` files that
> live beside the code, infrastructure, workflows, or documentation
> they describe."

An agent's contract is the bootstrap file, read first, and its loop
[2]:

> "Resolve -> Read -> Authorize -> Change -> Verify -> Report"
>
> "Do not skip directly to `Change`."

Authority is path-based and implicit upward, explicit sideways [2]:

> "Vertical inheritance is implicit. Other context references are
> explicit."

> "Inherited specs provide context and constraints. The nearest
> relevant local spec provides write authority."

And the bootstrap chain is three files, read in order [2]:

> "`bootstrap.md` defines the general SpecDD framework rules.
> `bootstrap.project.md` defines project-specific rules and overrides.
> `bootstrap.local.md` defines local operator or environment
> preferences."

### 2.2 What `specdd init` writes

The quickstart lists it [4]:

> "This creates the files agents need to start correctly:
> `AGENTS.md`, `CLAUDE.md`, `.specdd/bootstrap.md`,
> `.specdd/bootstrap.project.md`, `.specdd/bootstrap.local.md`"
>
> "`AGENTS.md` is the normal agent entrypoint. `CLAUDE.md` points
> Claude to `AGENTS.md`."

The distribution is a release asset, `specdd.zip`, and release 1.5's
holds exactly those five files [6]; `bootstrap.project.md` and
`bootstrap.local.md` are one heading each (`# SpecDD project specific
overrides`, `# SpecDD user-local overrides`), `CLAUDE.md` is one line
(`Follow instructions in the AGENTS.md file.`), `AGENTS.md` three. The
CLI then adds a sixth file its own spec names [5]:

> "Ensure .specdd/.gitignore exists after init."
> "Preserve an existing .specdd/.gitignore."

with the content `bootstrap.local.md` [5, `constants.ts`]. The guard is
one file [3]:

> "If the directory already exists, SpecDD is added only when
> `.specdd/bootstrap.md` is not already present."

### 2.3 What `specdd update` touches

The applier's spec is explicit, and it decides §3.1 [5]:

> "During update, write a missing zip file entry only when the
> normalized relative path is .specdd/bootstrap.md."
> "Overwrite an existing target file only when the normalized relative
> path is .specdd/bootstrap.md."
> "Leave every other existing target file unchanged."

and the version it compares is front matter [3]:

> "`specdd update` compares the local bootstrap `Version` front matter
> against the latest release and does nothing when the local version
> is already current or newer."

### 2.4 The root spec is named after the directory

The bootstrap [2]:

> "The root project spec must live at the selected content root and
> must be named after that root directory basename."
>
> "Human-facing names and technical identifiers do not override this
> rule. For example, a project described as `Travel Planner` with
> identifiers such as `TravelPlanner` still uses
> `travel-planner/travel-planner.sdd` when the content root directory
> is named `travel-planner`."

The language reference makes the root a tool's choice, preferring
configuration [7]:

> "Content root selection SHOULD prefer explicit configuration when
> available. If no explicit configuration exists, tools SHOULD choose
> the highest project or workspace root that reasonably contains the
> relevant SpecDD files."

The CLI has no such configuration: its config service knows one key
(`log_level` [5, `config-defaults.ts`]), and its README states the
convention as the rule: "Root-level project specs follow the containing
directory basename convention, so a project in `path/to/project` uses
`project.sdd`" [3]. The framework's own example project relies on the
project override to *say* it: "`example.sdd` is the root application
spec." [6, `bootstrap.project.md`].

### 2.5 Where a spec goes, and what that means in Elixir

Two placements, cumulative [2]:

> "Parent-held: a spec in the parent directory with the same basename
> as the governed child directory, such as `src/trips.sdd` for
> `src/trips/`."
> "Local: a spec inside the governed directory with the same basename
> as that directory, such as `src/trips/trips.sdd` for `src/trips/`."
> "Parent-held and local specs for the same directory are cumulative
> context, not ambiguity."

plus same-basename matching for files: "`itinerary.js -> itinerary.sdd`"
[2]. Phoenix contexts are exactly the case both rules meet: a context
is `lib/my_app/accounts.ex` *and* `lib/my_app/accounts/` (its schemas),
so one `lib/my_app/accounts.sdd` is at once the module's same-basename
spec and the directory's parent-held spec. That is a fact worth one
line in `bootstrap.project.md` and would otherwise be rediscovered per
project.

Symbols: "The first symbol character after `@` MUST be an ASCII letter
or `_`. Subsequent symbol characters MAY be ASCII letters, digits, `_`,
`.`, `:`, `#`, `\`, `/`, `?`, or `!`" [7] — so `@MyApp.Accounts.get_user!/1`
is one symbol, arity included.

### 2.6 What the framework asks of a spec

The bootstrap's compactness rules [2]:

> "Prefer many small specs over large ones" [1]
>
> "Specs are local maps, not inventories. A directory spec describes
> the directory concept and the roles of immediate children."
>
> "Do not create specs whose subject is the agent task being
> performed, such as adoption, migration, cleanup, or planning"
>
> "Keep negative requirements local and plausible. Add `Must not` only
> when it separates neighboring responsibilities, prevents likely
> misuse, preserves dependency direction, or captures a real local
> risk."

And a task is legitimate where it belongs to the subject: "`Tasks`:
local implementation and work checklist for satisfying the subject
contract" [2].

## 3. Design

### 3.1 Embedded release files, not a download, not the CLI

Three ways to get the distribution into the project:

* **Run the CLI** (`docker run … specdd/cli init`) from the installer.
  Rejected: the installer is an Igniter task inside the toolchain
  container; reaching Docker from there is Docker-in-Docker, and the
  patch set would no longer be one reviewable Igniter diff.
* **Download `specdd.zip` at insert.** Rejected: guidelines is the one
  cartridge that reaches the network, and it is a cartridge for that
  very reason (inserting should not depend on a URL being up). The
  release is also GPG-signed (`specdd.zip.asc`) and the CLI verifies
  it before applying — "Apply a distribution before signature
  verification succeeds" is in its `Must not` [5]; an installer that
  downloads without verifying would be worse than the tool it
  replaces.
* **Embed release 1.5's files in `priv/features/specdd/assets/`**,
  verbatim. Chosen. The cartridge's CHANGELOG names the SpecDD release
  it carries, so a bump is a cartridge minor. What the project runs
  later is the real CLI, and §2.3 makes that safe: `update` rewrites
  `bootstrap.md` and nothing else, so the project rules and specs this
  cartridge wrote survive, and the front matter `Version` the CLI
  reads is the one `state/1` reads too.

`.specdd/.gitignore` is written by code, not embedded: `embed_assets`
globs with `Path.wildcard`, which does not match dot-files by default,
and the file is one line.

### 3.2 The mark is the CLI's guard

`installed?/1` reads `.specdd/bootstrap.md` — the file `init` refuses on
and `update` requires (§2.2, §2.3). A project initialised by hand with
the CLI shows as carrying the cartridge, which is true, and a project
where this cartridge ran is what the CLI expects. `rerun: :noop`: the
files are fixed at insert; changing SpecDD's version is `specdd
update`'s job, and the rest is the project's own text.

### 3.3 `--root`: the app name by default, the directory when known

The rule in §2.4 is about the directory; the installer runs at
`/app/src` in the toolchain container (a basename that means nothing)
and cannot see the host's `WORKSPACE_PATH`. Candidates for a default:

* **The container's directory basename.** Rejected: `src`.
* **Ask.** Rejected: every other cartridge derives what it can from the
  project (toolchain reads the running VM, health_probe the endpoint).
* **The app name.** Chosen: it is what `mix phx.new my_app` names the
  directory, and what a clone is most likely called. Where the
  workbench keeps the project (`_workspaces/test_50`) it is wrong, and
  `--root` takes the host basename. In either case
  `bootstrap.project.md` states which file is the root spec, the way
  the framework's example does (§2.4), so an agent reading the chain
  finds it whatever the directory is called; only the CLI's `resolve`
  and `inspect` depend on the name (§4).

### 3.4 `AGENTS.md`: prepend, keep phx.new's text

The pointer must come first — its first words are "Before working on
this project, read `.specdd/bootstrap.md`" [6] — and phx.new's rules
must stay, since the specs assume them (§3.6). So: prepend, inside
`<!-- specdd-start -->` / `<!-- specdd-end -->` markers in the style
phx.new uses for its own blocks [9], followed by a blank line and the
file as it was. A `--no-agents-md` project gets the pointer alone,
which is what `init` would have written. Replacing the file was
rejected (it would delete the usage rules); appending was rejected
(the pointer would be the last thing read, after a page of Phoenix
rules that say nothing about reading the bootstrap).

`CLAUDE.md`: created with the distribution's line when absent; when
present, left as it is with a notice. It is the redirect for one agent,
and a project that already has one has already decided what Claude
reads first.

### 3.5 Three starting specs

`init` writes no `.sdd`; the quickstart has the developer write the
root spec and, "when work gets specific", a local one [4]. What a
generator can write truthfully about a Phoenix project it has not seen:

* **The root spec**: `Platform: Elixir/Phoenix`; the top-level
  `Structure` at the level of authority the root has (immediate
  children, no deeper); `Owns` for the files no child spec can
  (`mix.exs`, `config/`, `.formatter.exs`); three `Must` that are true
  of every phx.new project — `mix precommit` (the alias phx.new
  generates: compile with warnings as errors, unused deps, format,
  test [8]), secrets through the environment in `config/runtime.exs`,
  tests mirroring `lib/`. Its `Purpose` is the one thing a generator
  cannot know, so it is generic and the spec carries one task, `[ ]
  Replace Purpose with what MyApp exists to provide.` — a task of the
  subject, not of the adoption (§2.6), and the first thing an agent
  or a reader will see.
* **`lib/lib.sdd`**: the one boundary Phoenix has and agents cross
  most, the domain in `lib/my_app` against the web layer in
  `lib/my_app_web`. Its two `Must not` are the plausible mistakes
  (domain code reading a `@Plug.Conn`; business rules in a controller
  or LiveView), which is what §2.6 asks a `Must not` to be.
* **`test/test.sdd`**: the suite as its own subject, the way the
  framework's example has `tests/tests.sdd` [6] — `Platform: ExUnit`,
  path mirroring, "a spec's `Scenario` has a matching test before its
  task is marked done", `Can read: ../lib`.

Not written: a spec per context or per `_web` directory. A generator
would be inventing subjects; those are the local specs the developer
adds "around the next area you plan to change" [4].

### 3.6 `bootstrap.project.md`: the Elixir facts

The distribution's file is a heading; the quickstart says what belongs
in it: "shared project rules … such as code style, commands, syntax
choices, and where to find things" [4]. Rendered per project:

1. The content root and the root spec's name (§3.3).
2. That phx.new's usage rules in `AGENTS.md` stay in force — the
   division of labour is stated once: SpecDD says *what* may change and
   what must hold; those rules say *how* it is written.
3. Verification: `mix precommit`, one file with `mix test path`, and
   from the workbench host `./wb.sh mix precommit`.
4. The layout (`lib/my_app`, `lib/my_app_web`, `test/`, `config/`,
   `priv/repo/migrations/`).
5. The Elixir placement rule of §2.5, and the symbol form.
6. Generators: files a `mix phx.gen.*` writes fall under the spec of
   the directory they land in.
7. No specs under `deps/`, `_build/`, `priv/static/`.

### 3.7 What is deliberately absent

* **The Agent Skills.** A release of their own (`agentskills.zip`,
  1.0.2), deployed by the CLI into `.agents/skills/` [3]; fifteen
  directories of prompts that would double the cartridge and go stale
  on their own schedule. `afterwards/0` gives the command.
* **A `mix specdd.lint`.** There is no Elixir implementation of the
  language; the CLI's image runs `lint`, `resolve` and `inspect` from
  the project directory (README).
* **A dependency.** SpecDD is files.
* **A console door.** Nothing listens.

## 4. Evaluation

**Verified, 2026-09-02**, with the CLI's own image
(`ghcr.io/specdd/cli:latest`, CLI 1.1.1) on the templates rendered for
an app named `probe` and laid over an empty Phoenix-shaped tree:

* `specdd lint`: `0 errors, 0 warnings in 3 specs`.
* `specdd check-update`: `Local SpecDD version: 1.5.` — the embedded
  bootstrap is read as the release it is, and no update is offered.
* `specdd resolve lib/probe/accounts.ex`, mounted at `/probe`: the
  chain is `probe.sdd` ("Parent context for /") then `lib/lib.sdd`.
  `specdd resolve test/probe/accounts_test.exs`: `lib/lib.sdd`
  ("test/test.sdd can read ../lib") then `test/test.sdd`.
* `specdd inspect --sections all` prints the three specs with every
  section, the continuation lines joined, the task listed.
* **The root-name rule is literal.** The same tree mounted at
  `/workspace` (the image's default) resolves `lib/lib.sdd` alone:
  `probe.sdd` is not found. Renamed to `workspace.sdd`, it is. This is
  what §3.3 and the README's docker commands (`-v "$PWD:/my_app" -w
  /my_app`) answer.

The embedded `bootstrap.md` is byte-identical to the one in release
1.5's `specdd.zip` (checked by SHA-256 after copying).

**Not verified.** The installer (there is none yet), so neither the
`AGENTS.md` prepend on phx.new's real file nor the no-op on a second
run; and no agent was run against the specs — that they *read* well to
an agent is argued from the bootstrap's own rules, not observed.

## 5. Limitations and open questions

* **The host directory's name is unknown to the installer.** The
  default is a guess that is right for a clone named after the app and
  wrong for the workbench's own `_workspaces/test_N`. `wb.sh add` could
  export the workspace basename into every insert container (a fact
  about the environment, like the VM version toolchain reads), and the
  installer would take it over the app name; that is a `wb.sh` change
  and is left open.
* **`specdd update` moves the framework, not the cartridge.** After it,
  the project carries a bootstrap the cartridge never shipped;
  `state/1` reports the real version, and the cartridge's version stays
  what was inserted. That is the same relation ash has with the
  packages its queued installer fetches.
* **A cartridge that writes code could write its spec.** health_probe
  plants a plug and its test; a `lib/my_app_web/plugs/health.sdd`
  beside them (`Owns`, `Must`, two `Scenario`s from its README) would be
  the spec-driven counterpart of what the README already says. Nothing
  in this cartridge stops that; whether each cartridge should carry one
  is a question for the anatomy, not for this box.
* **The bootstrap is 1.5's, and 1.5 is what was read.** A later release
  may add sections or rules the project overrides do not account for;
  the CLI's changelog link after `update` is where that shows.
* **No cover art yet** (`assets/covers/specdd/`), as for every new
  cartridge.

## References

Read in full on 2026-09-02.

1. SpecDD, *home page*. <https://specdd.ai/>
2. SpecDD, *bootstrap.md*, release 1.5 (`.specdd/bootstrap.md` in
   `specdd.zip`; the same text ships in the example repository).
   <https://github.com/specdd/specdd/releases/tag/1.5>
3. SpecDD CLI, *README*. <https://github.com/specdd/cli>
4. SpecDD, *Quickstart* (`QUICKSTART.md` of the specdd/specdd
   repository). <https://github.com/specdd/specdd/blob/main/QUICKSTART.md>
5. SpecDD CLI, sources: `src/constants.ts`, `src/commands/init.ts`,
   `src/services/distribution-installer/distribution-installer.sdd`,
   `src/services/distribution-applier/distribution-applier.sdd`,
   `src/services/bootstrap-metadata/bootstrap-metadata.ts`,
   `src/services/config/config-defaults.ts`.
   <https://github.com/specdd/cli/tree/main/src>
6. SpecDD, *example project*: `example.sdd`, `src/src.sdd`,
   `src/services/todo.sdd`, `src/models/todo.sdd`, `tests/tests.sdd`,
   `.specdd/bootstrap.project.md`, `.specdd/.gitignore`, `AGENTS.md`,
   `CLAUDE.md`. <https://github.com/specdd/example>
7. SpecDD, *Language Specification* 1.2 (`LANGUAGE.md`).
   <https://github.com/specdd/specdd/blob/main/LANGUAGE.md>
8. Phoenix, `phx_new` 1.8.9: `lib/mix/tasks/phx.new.ex`
   (`--no-agents-md`), `templates/phx_single/mix.exs.eex` (the
   `precommit` alias). <https://hex.pm/packages/phx_new/1.8.9>
9. Phoenix, `phx_new` 1.8.9: `lib/phx_new/generator.ex`,
   `generate_agents_md/1`, and `templates/usage-rules/project.md`.

Surveyed by their repository pages, not read in full:

10. SpecDD, *Agent Skills* (release 1.0.2).
    <https://github.com/specdd/agentskills>
11. SpecDD, *Tools* (`TOOLS.md`): the CLI, the agent plugins, the
    editor extensions. <https://github.com/specdd/specdd/blob/main/TOOLS.md>
