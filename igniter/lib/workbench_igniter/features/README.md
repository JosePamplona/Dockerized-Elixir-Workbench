# Feature cartridges

Each workbench feature is a *cartridge*: everything that defines it
lives in this folder, registered in `../features.ex`. There is **one
kind of cartridge** — every one is installed on demand (`wb.sh add
<name>`, one insert commit each) — and a *collection* is just a
cartridge whose installer inserts other cartridges.

## Collections

A collection declares its recipe in `members/1`: the cartridges it
inserts, in order, with the argv each installer gets. `wb.sh add`
expands the recipe (`mix workbench.expand`) and inserts each missing
member as its own commit, so `eject` keeps reverting one cartridge
alone; run directly, the collection's installer composes the members
into one patch set.

**The design rule for a collection's options**: an option must be a
decision the collection itself owns — explainable on the box in one
line without naming a member's switch (chiefs_setup's `--interface`
qualifies; a `--coverage-theme` would not, it is coveralls' `--theme`).
Re-exposing a member's option is how the one-type-of-cartridge
simplification would rot back into a second type: whoever needs the
member's option inserts the member directly. The argv a recipe hands a
member only names the *fellow members* that ride along (exdoc's
`--coveralls`).

[chiefs_setup](chiefs_setup/) is the collection: the picks of the
retired opinionated line — the house's settings ([ansi](ansi/) →
[version_manager](version_manager/) → [toolchain](toolchain/) →
[changelog](changelog/)), the trivial dep
group ([dashboard_extras](dashboard_extras/) → [credo](credo/) →
[mock](mock/) → [exdebug](exdebug/)),
[rest](rest/) | [graphql](graphql/) (its `--interface` choice),
[coveralls](coveralls/), [exdoc](exdoc/), [enhancements](enhancements/)
and [health_endpoint](health_endpoint/) — in the order their marks build on
each other. [auth0](auth0/), [openai](openai/) and [stripe](stripe/)
(*pending*: manifest only) stay à la carte: they need external
accounts, as does [guidelines](guidelines/), which needs the team's URL.

## The house's settings

What the retired setup wrote into every project it created, each as the
one decision it is, so a stock `phx.new` project can take them one at a
time or not at all:

| Cartridge | The decision | What it writes |
| --- | --- | --- |
| [ansi](ansi/) | logs come out coloured through Docker | `config :elixir, ansi_enabled: true` |
| [version_manager](version_manager/) | the host switches to this project's Erlang and Elixir on `cd` | `.tool-versions` for asdf (mise reads it too) or `mise.toml`, off the running toolchain, Elixir with its OTP |
| [toolchain](toolchain/) | the editor's language server stays out of git | `/.elixir_ls/` in `.gitignore` |
| [changelog](changelog/) | a project with a version number and no versioning | `CHANGELOG.md` opened at the version `mix.exs` has (`--init-version` for another); `mix version` and the README badge on request |

The rest of what setup configured did not become boxes, because it
already had owners: the generators and migration types are the config
half of [enhancements](enhancements/)' `--id-type` and `--timestamps`
(one decision, both halves, one cartridge), and `dev_routes` in test is
written by [health_endpoint](health_endpoint/), which needs it. Its `README.md`
template found no owner and is deliberately gone: a generated README
would have to know every cartridge, which is the coupling this
structure exists to remove.

## Anatomy

Every cartridge is a directory `features/<feature>/` holding:

* `<feature>.ex` — manifest (`WorkbenchIgniter.Feature`) + install logic.
* `task.ex` — the `Mix.Tasks.Workbench.Install.<Feature>` shell.
* `README.md` — what it installs, options, contents. **Contents** is a
  table drawn as a tree of the cartridge's own files — its directory,
  its `priv/`, its test, each a root after an empty row: the branch in code in the first
  column (`├── 📄 task.ex`, 📁 for a directory, 📄 for a file, the
  indentation in no-break spaces, U+00A0, so no renderer folds it),
  the role in the second, kept to one line so the branches run on
  unbroken ([ecto](ecto/README.md#contents) is the model).
* `CHANGELOG.md` — the cartridge's own version history (Keep a
  Changelog, semver over what it *installs*), independent of the
  workbench release that ships it. Cartridges written before it was
  part of the anatomy get one on their next change.
* `DESIGN.md` — why the cartridge is shaped like this: the problem,
  the background with its primary sources, each decision with the
  alternatives it beat, what was verified and what was not, open
  questions, numbered references. Paper-shaped, short for a dep-only
  cartridge. Same backfill rule as the changelog.
* `NEED.md` — the developer's need the cartridge answers, in their
  situation and not the mechanism's: a title, **one sentence** (the
  line the shelf, the catalog and the console show — `need/0` reads it
  off the file, as `version/0` reads the changelog), then three short
  paragraphs, **Before:**, **After:** and **Not for:**. Second person,
  one situation, no feature list — a list is the README's. The box art
  starts from it: the register and the hero come from the need, the
  bodies and counts from the README. Every cartridge has one; the
  catalog test says so.

The cartridge directory holds only code. Everything that is not code
lives under `priv/features/<feature>/` (never compiled, so files keep
their final names — `cover.ex`, not `cover.ex.asset`):

* `priv/features/<feature>/templates/` — EEx templates, embedded at
  compile time (`embed_templates`).
* `priv/features/<feature>/assets/` — text files copied verbatim,
  embedded at compile time (`embed_assets`).
* Binaries (e.g. `images/`) — read at runtime with `priv_asset/1`
  (`WorkbenchIgniter.feature_asset/2`) or planted byte-for-byte with
  `plant_binary_asset/3`.

Cartridge test: `test/workbench_igniter/features/<feature>_test.exs` —
one per cartridge, mirroring the directory.

Dep-only cartridges have no `priv/features/<feature>/` directory:

| Cartridge | Installs | Picked by |
| --- | --- | --- |
| [credo](credo/) | `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` | chiefs_setup |
| [mock](mock/) | `{:mock, "~> 0.3", only: :test}` | chiefs_setup (also composed by health_endpoint and enhancements; coveralls moved to test_doubles on 2026-09-20, and the last of the three takes it off the shelf) |
| [test_doubles](test_doubles/) | `{:mimic, "~> 2.0", only: :test}`, `{:mox, "~> 1.2", only: :test}` or `{:hammox, "~> 1.0", only: :test}` with `--type-check`, by `--double` | chiefs_setup (also composed by coveralls, with `--double mimic`) |
| [exdebug](exdebug/) | `{:ex_debug, "~> 1.0"}` | chiefs_setup |
| [dashboard_extras](dashboard_extras/) | `:os_mon` in `extra_applications`, and the extras of the project's database: `ecto_psql_extras`, `ecto_mysql_extras` or `ecto_sqlite3_extras` (none on SQL Server or without a database) | chiefs_setup |
| [githooks](githooks/) | `{:git_hooks, "~> 0.7", only: :dev, runtime: false}` | no one (`wb.sh add githooks`) |
| [exmachina](exmachina/) | `{:ex_machina, "~> 2.8", only: :test}` | no one (`wb.sh add exmachina`) |
| [stripe](stripe/) | — (pending; requires auth0) | no one |

Each cartridge README explains what it brings (mock's carries the pending
migration to Mox).

[clustering](clustering/) adds no dependency: it writes the `rel/*.eex`
release templates with the distributed-node exports DNSCluster needs,
plus `DNS_CLUSTER_QUERY` in the environment files. Installed by hand
with `wb.sh add clustering`.

[db_admin](db_admin/), [k6](k6/) and
[monitoring](monitoring/) bring the workspace a **service**: a container the compose carries because the
project asked for it. A cartridge says so with `services/1` — the names
`mix workbench.compose` renders (`postgres`, `mysql`, `mssql` or
`sqlite`, declared by ecto off its adapter; `pgadmin`, `phpmyadmin`,
`adminer` or `cloudbeaver`, by db_admin off the admins the project
carries; `k6`; `prometheus` and `grafana`) — and what the installer writes is the file
the service opens with: pgAdmin's `pgadmin/servers.json`, phpMyAdmin's
`phpmyadmin/config.user.inc.php`, Adminer's `adminer/login.php`,
CloudBeaver's `cloudbeaver/data-sources.json`, k6's `k6/smoke.js`,
Prometheus's `monitoring/prometheus.yml` and Grafana's
`monitoring/grafana/datasource.yml`. For db_admin and k6 the file is
the mark too; monitoring writes Elixir as well — PromEx, whose module is
its mark — so that what the containers read has something to read.
What is the topology's (where the app is, where Prometheus is) the
compose hands over, so the files serve every deployment. The compose is
baked from what the project carries (`./wb.sh bake` after the insert),
never the other way round; see `scripts/PLAN.md`. db_admin is a
chiefs_setup pick, bare: the admin of the database the project is on.
Each of its admins says which databases it serves, as a requirement on
the option's value. k6 and monitoring are inserted by hand.

[health_probe](health_probe/) is the vanilla counterpart of
`health_endpoint`: liveness and readiness probes as the first plug of the
endpoint, no dependency, no router change. Installed by hand with
`wb.sh add health_probe`.

[guidelines](guidelines/) puts the team's coding conventions in the
project's own documentation, downloaded from `--url`. It builds on
exdoc (`requires`) and **appends** its page to the two lists exdoc's
`docs:` block keeps, the way clustering appends to a release script it
does not own. It is the only installer that reaches the network, which
is why it is a box and not an option of exdoc: inserting the
documentation site should not depend on someone's URL being up.

## Base cartridges

`phx.new` decides some capabilities at generation time — `--no-mailer`,
`--no-ecto`, `--no-html`, `--no-live`, `--no-dashboard`, `--no-gettext`,
`--no-esbuild`, `--no-tailwind` — and has no way to add one later. A
**base cartridge** adds one after the fact without knowing what it is:
`WorkbenchIgniter.PhxDelta` generates the project twice with `phx.new`'s
own generator, on a scratch directory — with the project's own flags
(read off the project) and with the capability on — and merges the
difference three ways onto the project's files. The delta is what
`phx.new` writes at the installer's version, so it is never stale; the project's edits survive; a conflict is
reported, never resolved silently. Their mark is what the flag leaves
out, so a default `phx.new` project shows them as inserted already.

| Cartridge | Flag | Installed by |
| --- | --- | --- |
| [mailer](mailer/) | `--no-mailer` | `wb.sh add mailer` |
| [gettext](gettext/) | `--no-gettext` | `wb.sh add gettext` |
| [ecto](ecto/) | `--no-ecto`, `--database` | `wb.sh add ecto [--database DB]`, then `wb.sh bake` |
| [esbuild](esbuild/) | `--no-esbuild` | `wb.sh add esbuild` |
| [tailwind](tailwind/) | `--no-tailwind` | `wb.sh add tailwind` |
| [html](html/) | `--no-html`, `--no-live` | `wb.sh add html [--no-live]` — LiveView is its option, as in the generator; run again to add it |
| [dashboard](dashboard/) | `--no-dashboard` | `wb.sh add dashboard` |

That is every capability `phx.new` can leave out; what remains of its
flags — `--umbrella`, `--app`, `--module`, `--adapter`, `--binary-id`,
`--no-agents-md` — shapes the generation itself and stays a `new2`
matter. Each of the seven has a `DESIGN.md`; the engine's argument —
why the generator and not a port of it, why `git merge-file`, what a
delta cannot do — is in [mailer's](mailer/DESIGN.md), and the other
six refer to it. A cartridge that builds on another says so with `requires/0`
(dashboard needs nothing; ash's `--auth password` needs html with
LiveView), and when the
name is not enough it names the **state** the other has to be in —
`{"ecto", database: "postgres"}` for db_admin's pgAdmin, which
serves Postgres and nothing else, `{"html", live: true}` for what needs
LiveView; a list of values asks for any one of them (`database:
["postgres", "mysql", "mssql"]`, CloudBeaver's). The state is asked of the required
cartridge's own `state/1`, off the project as it is, never off what an
insert was asked; one resolver reads both (`missing_requirements/2`)
and one refusal (`refuse/3`) says what is lacking and how to get it:
"dashboard builds on html, not in the project yet. Insert that first:
./wb.sh add html"; "--admin pgadmin builds on ecto with database
postgres, and this project's database is mysql"; and for a state a second run can
add, the remedy is that run, `./wb.sh add html --live`. The catalog carries the names as
`requires` and the states as `conditions`, and the console's box says
both under Needs. A single value can say it too — `{value, doc,
requires}` in `choices/0` (ash's `--auth password` on live and mailer,
each of db_admin's admins on its databases) — with the same resolver and refusal, and the list beside the value. A state
can also *shape* a box instead of gating it, when it selects among
equivalents: [dashboard_extras](dashboard_extras/) reads ecto's
`state/1` for the database and installs that server's extras —
none without a database — where a requirement could only refuse, and
[db_admin](db_admin/) without `--admin` gives the database's own admin. And a cartridge
with a step after the insert says it with `afterwards/0` (ecto: `./wb.sh
bake`, then `setup`); the catalog carries it, and marks the base
cartridges as `base`.

A cartridge can light the console up: `console/0` names the *doors* it
opens on the app's port (exdoc `/dev/docs`, rest `/dev/swagger`, mailer
`/dev/mailbox`, ash `/admin` when `ash_admin` is in, dashboard_extras
the two dashboard pages it lights, health_probe
`{path}/live` and `{path}/ready`) and the *tabs* it turns on (clustering
→ Cluster). The catalog carries it as `console`; the console shows the
doors of what is inserted and nothing of what is not. There is no
separate kind for a health endpoint: it is a route the project has for
its own reasons, and the console reads it and calls it like any other
door — the project owes the workbench nothing, and a "probe" it would
carry for the workbench's sake was the one contract running the wrong
way (settled 2026-09-08).

[ash](ash/) is the fourth: the Ash framework, configured with the
choices of ash-hq.org's installer for an existing app (`--data-layer`,
`--api`, `--auth`, `--with`, `--example`) and installed by the command
that site generates, `mix igniter.install <packages> <flags>`, queued
to run once the patch set is applied — every Ash package carries its
own installer, and the cartridge writes no file itself. Installed by
hand with `wb.sh add ash`.

[specdd](specdd/) — *pending*: designed, not installable yet — puts
[SpecDD](https://specdd.ai) on a stock project: what `specdd init`
writes (the bootstrap chain, the `AGENTS.md` pointer, `CLAUDE.md`),
off release files embedded in the cartridge, plus a
`bootstrap.project.md` written for an Elixir/Phoenix project and three
starting `.sdd` specs (the project, `lib/`, `test/`). No dependency,
no network; the framework updates itself through its own CLI, which
rewrites one file. Its `DESIGN.md` records what the CLI does and what
its `resolve` verified.

Box cover art for the cartridges — the fixed elements, the per-cartridge
slots and the prompt template — lives with the art it produces, in
[`assets/covers/`](../../../../assets/covers/). A cartridge that adds a
path at runtime carries a figure of it in its README (the mechanism as
installed) or its DESIGN (a comparison the prose cannot hold); those are
drawn in [`assets/diagrams/`](../../../../assets/diagrams/), which says
which cartridges have one and why.

## The manifest (`WorkbenchIgniter.Feature` behaviour)

* `task/0` - installer mix task name (public interface).
* `pending?/0` - documented, but its installer is not done yet.
* `archived/0` - why it was retired, one line opening with the date, or
  `nil` while it is current: not offered for new projects, its papers
  kept for the reading. The mirror of `pending?/0` — *no longer*, where
  that one is *not yet*.
* `members/1` - a collection's recipe: the cartridges it inserts, in
  order, with the argv each installer gets; may depend on the
  collection's own options. `[]` (the default) means a plain cartridge.
* `installed?/1` - whether the target project carries it, off the same
  mark the installer's guard reads. `mix workbench.status` asks it.
* `choices/0` - the values some options take, for the catalog: a closed
  list (the one the installer validates against), `{:open, list}` when
  other values work too, sections as `{group, values}` pairs; a value
  is a string or a `{value, doc}` pair, the doc being the one line a
  form shows beside it (ash: the package each choice stands for).
* `option_docs/0` - one line per option: the task's "## Options"
  section is rendered from it (`WorkbenchIgniter.Feature.options_doc/1`
  in the task's `@moduledoc`), and so is the help beside a form field.
* `rerun/0` - what a second run does: `:noop` (the guard skips it) or
  `:adds` (every option a piece the installer adds when missing).
* `state/1` - what the project carries of its options, read off the
  project: exactly the schema's keys, each with what was found (a
  string, a list, `true`/`false`), or `nil` for an option that leaves
  no mark the project keeps (a one-shot `--build`, a flag the installer
  no longer reads — say which, beside the read). Required of every
  cartridge with options: `mix workbench.status` carries it, the
  console's Inserted list, its doors' `{option}` paths and
  `services/1` read it, and the catalog test installs every cartridge
  with non-default values and checks the answer against its schema.
  It reads marks the project has for its own sake, never a record kept
  for the workbench.

Derived by `use WorkbenchIgniter.Feature`, not declared: `name/0` (the
directory), `version/0` (the first CHANGELOG.md entry) and `summary/0`
(the task's `@shortdoc`) — what `mix workbench.catalog` prints.

Adding a feature = creating its cartridge here and adding it to the
`WorkbenchIgniter.Features` list, in shelf order. A collection that
should pick it also names it in its `members/1`.

## Writing a DESIGN.md

[`health_probe/DESIGN.md`](health_probe/DESIGN.md) is the reference for
the shape; this is what makes one worth reading. It is a set of
criteria, not a template — a template gets filled in, and a filled-in
rationale is worse than none.

1. **Fixed sections, fixed order**: Abstract, Problem, Background,
   Design, Evaluation, Limitations, References. An empty section may
   be skipped; none may be reordered.
2. **Start from the sources, not from the text.** Read the primary
   documentation — the platform's, the library's — in full *before*
   writing Design. Blog posts are evidence of practice, not of truth.
   Write down the date you read them.
3. **Quote, do not paraphrase**, every claim about what an external
   system does. What cannot be quoted is an assumption, and is written
   as one.
4. **Each decision against its alternatives**: what was chosen, what
   was rejected, and the (quoted) fact that decided it. A decision with
   no recorded alternative is not a decision, it is a habit.
5. **Where sources contradict each other, say so and take a side.** It
   is the most valuable part of the document and the first to be left
   out.
6. **Evaluation states what was *not* measured.** An honest "argued
   from the pipeline, not measured" is worth more than a number that
   was never taken.
6b. **A figure where it shows a mechanism the prose cannot** — who acts
   in whose turn, which edge goes away — and nowhere else; drawn in
   `assets/diagrams/`, with the sources of what it depicts cited like
   any other claim. A list of options redrawn as boxes is not a
   comparison.
7. **Length follows what had to be decided.** A dep-only cartridge's is
   a page — why this library and not that one. Do not imitate the
   reference's length.
8. **A `Revision: cartridge vX.Y.Z (date)` line at the top**, moved
   with the cartridge CHANGELOG when a decision changes — not when a
   comma does.
9. **English**, like the rest of the repository.
10. **Only links that were opened.** Anything not read in full goes in
    its own block, and says so.

What is deliberately not here: an example of each section (that is
what the reference is for) and a review checklist — the same choice the
cover guide makes: a list of objections freezes judgement instead of
recording it.
