# ash — Design

*Revision: cartridge v0.5.0 (2026-09-24): §2.6 and §3.8 read the
installed sources on that date. The rest: cartridge v0.2.0
(2026-08-29), sources consulted on that date; quotations are verbatim
from the file or page as read then.*

## Abstract

The workbench wanted a cartridge that installs the Ash framework with
the choices ash-hq.org's *Get Your Installer* offers for an existing
application. Reading the site and its installer script showed that the
site is a generator of one command — `mix igniter.install <packages>
<flags>` — and that every Ash package carries its own Igniter
installer. The cartridge therefore reimplements nothing: it maps its
options to that package list and **queues the command** with
`Igniter.add_task/3`, to run once its own (empty) patch set is
applied. The alternatives — declaring the packages as `installs:` in
the task's `Info`, or composing the installers in-process — were
rejected on what Igniter 0.8.3's source does with each. The design
was verified on a stock `phx.new` project.

## 1. Problem

Ash is not a library one adds to `mix.exs`: it rewrites the repo
module, the config, the test case, the `setup` aliases, and generates
a domain with resources and their migrations. Done by hand that is a
day of reading; done by Ash's installers it is one command. The
question for the workbench was only *which* command, and how to make
the choices ash-hq.org offers — data layer, APIs, authentication
strategies, a catalogue of extensions — into cartridge options the
`add` command and the catalog can present.

## 2. Background

### 2.1 What the site generates

The home page's installer widget is a LiveView; its *Existing App*
command is rendered client-side and is not in the static HTML [1].
What the site serves for a *new* project is a shell script, and its
one meaningful line is [2]:

```sh
mix igniter.new "$app_name" --with-args="${with_args}" --yes-to-deps --yes --setup \
  --install "ash_postgres,ash_phoenix,ash_authentication,ash_json_api" $cli_args
```

— the packages chosen on the page, comma-joined, handed to Igniter.
The page itself says "Uses igniter to install Ash into your
application" and, of the advanced choices, "Some selected features
require manual setup" [1]. The Ash guide's own instruction for an
existing project is `mix igniter.install ash` [3, summary only].

So the *Existing App* command is taken to be
`mix igniter.install <the same list> --yes`: an assumption, stated as
one, consistent with the guide and with the `igniter.new --install`
form, which is documented as installing the listed packages after
generating the project.

### 2.2 What `mix igniter.install` does

Igniter's task documentation [4]:

> "`argv` values are also passed to the igniter installer tasks of
> installed packages."

and the function behind it, `Igniter.Util.Install.install/4`, is
documented as *not* composable [5]:

> "The functions in this module are not composable, and are primarily
> meant to be used internally and to support building custom tooling
> on top of Igniter, such as Fireside."

Its body adds the deps, calls `Igniter.apply_and_fetch_dependencies/2`
(which "Applies the current changes to the `mix.exs` in the Igniter
and fetches dependencies" [6]), then finds each `<package>.install`
with `Mix.Task.get/1` and runs it, ending in `Igniter.do_or_dry_run/2`
— it returns `:ok`, not an igniter [5].

### 2.3 What a task's `installs:` does — and does not

`Igniter.Mix.Task.Info` documents the field [7]:

> "`installs` - A list of dependencies that should be installed before
> continuing."

But the default `run/1` of a task built with `use Igniter.Mix.Task`
only *validates* the argv against the info and then calls
`Igniter.Mix.Task.configure_and_run/3`, which parses the argv and
calls `igniter/1` — nothing in that path reads `installs` [8]. The
field is read by `Igniter.Util.Info.compose_install_and_validate!/8`
[9], whose only callers are itself and `Igniter.Util.Install.install/4`
[5]: `installs` is honoured *along the `igniter.install` chain* (an
installer that needs another package), not when a task is run on its
own.

And `apply_and_fetch_dependencies/2` opens with [6]:

```elixir
if igniter.assigns[:test_mode?] do
  raise "Cannot use `Igniter.apply_and_fetch_dependencies/1-2` in test mode"
end
```

### 2.4 What a queued task is

`Igniter.add_task/3` appends `{task, argv}` to `igniter.tasks` [10].
After the patch set is written, `do_or_dry_run/2` runs `mix deps.get`
when there are tasks, then each one *as a shell command* [11]:

```elixir
case Mix.shell().cmd("mix #{task_name} #{Enum.join(args, " ")}") do
```

A queued `igniter.install` is therefore literally the command typed
at a prompt, in a fresh `mix` process with the written `mix.exs`.

### 2.5 What the Ash installers accept and touch

Read in full: `ash.install` [12], `ash_postgres.install` [13],
`ash_authentication.install` [14], `ash_authentication_phoenix.install`
[15], `ash_authentication.add_strategy` [16].

* `ash.install` takes `--example` ("Creates some example resources")
  and `--setup` ("Runs `mix ash.setup` after installation") [12].
* `ash_postgres.install` takes `--repo` and `--yes`; before writing
  `config/dev.exs` it checks
  `Igniter.Project.Config.configures_key?(igniter, "dev.exs", otp_app, [repo])`
  and, when true, returns the igniter unchanged — the same guard on
  `runtime.exs` and `test.exs` [13]. A `phx.new` project configures its
  repo in all three, so the installer's hardcoded `localhost` /
  `postgres` credentials never land there. It also rewrites the
  `test` and `setup` aliases (`ecto.setup` → `ash.setup`), adds
  `installed_extensions/0` and `min_pg_version/0` to the repo (default
  `16.0.0`), and queues `mix ash.codegen initialize` [13].
* `ash_authentication.install` takes `--auth-strategy` as `:csv`,
  plus `--accounts`, `--user`, `--token`, and composes
  `ash_authentication.add_strategy` for each strategy [14].
* `ash_authentication_phoenix.install` declares the same switches and
  composes `ash_authentication.install` — but only after finding no
  Accounts domain and *asking* [15]:

  > "Could not find #{type} module. Please set the equivalent CLI
  > flag. … 2. You have not yet run the `ash_authentication`
  > installer. To run this, answer Y to this prompt. Run the installer
  > now?"

  through `Mix.shell().yes?/1`, which `--yes` does not answer.
* The strategies `add_strategy` accepts are `password`, `magic_link`,
  `otp`, `api_key`, `totp`, `recovery_code`, `github`, `google`,
  `apple`, `auth0`, `microsoft`, `okta`, `slack`, `oidc`, `oauth2`,
  `dynamic_oidc`, `webauthn` [16].

### 2.6 The whole command, read in the installed sources

Read on 2026-09-24 in the `deps/` of a workspace that carries every
option (igniter 0.8.4, ash 3.33.10, ash_postgres 2.7.3, ash_phoenix
2.3.25, ash_authentication 4.15.0, ash_authentication_phoenix 2.17.4,
spark 2.13.1) [18]. What §2.2–§2.4 found in 0.8.3 holds; this is the
rest of the run.

**One igniter, one write.** `igniter.install` resolves each bare
package against Hex (the latest stable release, written `~> MAJOR.0`,
or `~> 0.MINOR` below 1.0), writes `mix.exs`, and runs `deps.get` and
`deps.compile` *before* any installer: a `<package>.install` task only
exists once its package is compiled [19]. It then threads one igniter
through every installer, in argv order, each handed the whole flags
argv, and ends in one `do_or_dry_run`: one write, then the queued
tasks [19].

**Three ways a package the command did not name gets in** [19]:

* `installs:` in an installer's `Info` — igniter.install adds the
  package, fetches it, compiles it and *runs its installer*, before the
  one that asked for it, to any depth (ash_oban and oban_web ask for
  `oban`; ash_double_entry for `ash_money`).
* `adds_deps:` — added and fetched, its installer never run
  (ash_json_api asks for `open_api_spex`).
* `Igniter.Project.Deps.add_dep/3` inside an installer's body — only
  the in-memory `mix.exs` changes; it is written in the final write,
  and fetched by the `deps.get` that runs before the queued tasks (and
  again by the one `./wb.sh add` runs after the insert).

**No installer.** A package without `<package>.install` — ash_archival,
ash_paper_trail, ash_cloak, cloak — stays in `mix.exs`; the run prints
it under "did not exist or could not be found" and goes on [19].

**Prompts `--yes` does not answer.** `Owl.IO.select` in
`AshPostgres.Igniter.select_repo/2` when more than one `AshPostgres.Repo`
exists, and ash_authentication_phoenix's `Mix.shell().yes?/1` (§2.5).
Neither is reached here: one repo, and ash_authentication's installer
runs first and writes the modules the other looks for.

**What each package the insert commit carries came from**, the
workspace's commit read against the sources:

| Package | Added by | Source |
| --- | --- | --- |
| the ones named in the command | igniter.install, at Hex's latest | [19] |
| `sourceror` | `spark.install`, which `ash.install` composes: `add_dep` when missing | [20] |
| `picosat_elixir` | `Ash.Policy.Authorizer`'s install hook, run when `ash.extend` gives a resource the authorizer (ash_authentication's User and Token): picosat, or `simple_sat` on Windows, when neither is a dep | [21] |
| `bcrypt_elixir` | `ash_authentication.add_strategy password`: `add_dep` | [16] |
| `ex_money_sql` | `ash_money.add_to_ash_postgres`, which `ash_money.install` composes when `ash_postgres` is in | [22] |
| `req_llm` | `ash_ai.install`: `add_dep`, unless `--no-req-llm` | [22] |
| `absinthe_phoenix` | ash_graphql's `setup_phoenix`: `add_dep` | [22] |
| `open_api_spex` | ash_json_api's `adds_deps` | [22] |
| `oban` | ash_oban's and oban_web's `installs` | [22] |

`cloak` is not among them: nothing adds it; the site's Encryption
option names it before `ash_cloak` (§3.7), and so does the command.

## 3. Design

### 3.1 Queue the site's command; do not run installers in-process

Three ways to get Ash installed from a workbench task were on the
table:

1. **Declare `installs:` in the task's `Info`** — the field's name
   promises exactly this. Rejected on §2.3: the default `run/1` never
   reads it, so `mix workbench.install.ash` would add nothing.
2. **Run the chain in-process**: call
   `compose_install_and_validate!` to add and fetch the packages, then
   `Igniter.compose_task` each `<package>.install`, keeping Ash's
   changes inside the cartridge's own diff. Feasible, but it
   re-implements `Igniter.Util.Install.install/4` — the dep-option
   handling, the `only:` groups, the "installer not found" report —
   against a function documented as internal [5], and it cannot run in
   test mode at all (§2.3), so the cartridge test would need a branch
   in production code.
3. **Queue `mix igniter.install <packages> <flags>`** with
   `add_task/3`. Chosen: the queued task is the site's command itself
   (§2.1, §2.4), Igniter owns everything after the queue, the
   cartridge's patch set is empty and its test asserts the one thing
   the cartridge produces — the argv. What is given up: Ash's changes
   show in the queued command's output, not in the cartridge's diff.
   The notice says so.

![Who writes what, and when: wb.sh runs the cartridge, which builds the argv of the packages mix.exs lacks and hands Igniter a patch set holding only the .env entry and the queued igniter.install task; Igniter writes .env, runs the task, each package installer writes its files, and the output returns with the notice](../../../../../assets/diagrams/ash/who-writes-what.svg)

*The cartridge's turn is one message wide. Everything Ash writes
happens in the queued task's turn, which is why the diff is empty and
the output is not.*

### 3.2 The site's sections as options, each closed

The options are the site's rows, not a raw package list: `--data-layer`
(several of a closed set, as the site's checkboxes — a resource picks
its own layer — with `none` standing alone; an error otherwise), `--api`
(closed set), `--auth`
(the strategies, validated by `add_strategy` [16], not here — and two
packages, `ash_authentication` *before* `ash_authentication_phoenix`,
because the Phoenix installer's fallback is a prompt (§2.5) that hung
the first real run of this cartridge, while listed first
`ash_authentication.install` runs with `--auth-strategy` and the
question never comes up), and one option per section of the *Advanced
Options* — `--ai`, `--finance`, `--automation`, `--security`,
`--dev-tools`, `--components` — each closed on the packages the site
offers there, in the site's order; a package a section does not offer
is an error naming the ones it does. One flag per advanced checkbox was
rejected as fifteen flags that would each be one string; one flag per
section is the site's own grouping, and six.

Until cartridge v0.5.0 the *Advanced Options* were one open `--with`,
because the site adds to its catalogue faster than a cartridge would.
`mix workbench.ash.site` answered that on 2026-09-24: of what the site
offers, the cartridge lacked only `appsignal` and `opentelemetry`, both
marked "Installer coming soon". The open field then only took packages
the site does not offer, which is `mix igniter.install <package>`'s
job, not this cartridge's; and a section the site adds is a report of
that same check, and an option here.

### 3.3 `ash` first, always; `ash_phoenix` always

The site's list omits `ash` [2]; the guide's command is `ash` alone
[3]. `ash_postgres.install` does not compose `ash.install` (no
reference to it in the file [13]), so a list without `ash` would
install the data layer over an unconfigured Ash. `ash` is put first.
`ash_phoenix` is always in because the workbench only makes Phoenix
projects; the site's *Phoenix* checkbox exists for new, non-Phoenix
apps.

### 3.4 Only the missing packages; the mark is the `ash` dependency

Packages already declared in `mix.exs` are left out of the queued
command (`Igniter.Project.Deps.has_dep?/2` per package, on the name
part of a `org/package@version` spec); when none is left nothing is
queued and a notice says so. This makes a re-run with the same options
a no-op and a run with more (`--dev-tools ash_admin`) queue only the
new ones. `installed?/1`
reads the `ash` dependency — always the first package, and the one
every other needs. The one deviation from the cartridge anatomy: that
mark is planted by the queued command, not by the patch set, so the
catalog test's "flips once installed" case excludes this cartridge and
says why.

### 3.5 Standalone, on the vanilla line

Not composed by `workbench.setup`: the opinionated line's `auth0`
cartridge owns a `users` table and its `enhancements` generate Ecto
schemas and a `db` task, which Ash's domain, resources and
`ash.setup` aliases replace rather than extend. The cartridge belongs
with `new2` — a stock `phx.new` project plus Ash — like `clustering`
and `health_probe`.

### 3.6 `TOKEN_SIGNING_SECRET` in `.env`, and what is deliberately absent

The one thing the cartridge writes itself. The real run (§4) showed
`ash_authentication.install` adding a literal `token_signing_secret`
to `config/dev.exs` and, to `config/runtime.exs`, inside the `:prod`
block:

```elixir
config :probe,
  token_signing_secret:
    System.get_env("TOKEN_SIGNING_SECRET") ||
      raise("Missing environment variable `TOKEN_SIGNING_SECRET`!")
```

The workbench's prod compose reads `.env`; without the variable
`./wb.sh up -e prod` boots into that raise. So with `--auth` the
cartridge appends the entry — a generated 64-character secret in
`.env`, a blank one in `.env.sample`, which is committed — through
`WorkbenchIgniter.EnvFile.entry/4`, which grew a fourth argument for
exactly this (its doc used to forbid secrets because both files got
the same text). Written in the cartridge's own patch set, before the
queued command, and keyed on the variable name so a re-run appends
nothing.

Absent on purpose: `.env` entries for OAuth client ids — which
variables each strategy reads was not established from the sources
(the strategy tasks were not read), and writing names from memory
would be worse than none. No `--repo`: `ash_postgres.install` derives
`MyApp.Repo` [13], which is what `phx.new` made. No re-pointing of the
repo's `config/dev.exs` block: §2.5 shows it is not touched, and §4
confirmed it.

### 3.7 The site's command, exactly

§2.1 inferred the *Existing App* command from the widget's markup;
the map that drives the widget [17] says what each option really adds,
and four things differed. The site's Oban option adds `oban_web` after
`ash_oban`; its Encryption option adds `cloak` before `ash_cloak`; its
Double Entry option requires Money, so `ash_money` precedes
`ash_double_entry`; its TypeScript option hands `ash_typescript`
`--framework react`; and its API-keys option adds `ash_authentication`
alone, the Phoenix half only coming with a strategy that has pages.
The cartridge does the same now (`@companions`, `flags/1`,
`auth_packages/1`), keeping the sections' values as package names: a companion is
what the command puts in *beside* the package named, in the site's
order. The alternative — offering the site's feature keys (`oban`,
`cloak`) instead of packages — was rejected: a key that stands for two
packages would be a second vocabulary for the same thing.

What keeps this true is `mix workbench.ash.site` (`site.ex`): it
fetches the map and compares it with the tables, option by option.
Presets (*LiveView*, *React*) and `phoenix` are skipped; the packages
the site offers and the cartridge does not (`appsignal`,
`opentelemetry`, marked "Installer coming soon" on the site) are
reported as such, not hidden.
### 3.8 Where each package came from, in the cartridge's words

The console reads a box that declares no package off its insert commit,
and marked what it read with one line: *it comes with phx.new*. True of
a base cartridge, false of ash. Only the cartridge knows what it ran, so
it says it (`origins/2`, given the options the insert went in with and
the packages the commit added), and the console numbers the notes under
the table.

Ash gives two. The packages the command named carry that the options
named them in the `mix igniter.install` it runs, and that the command
added them. The note names the command and not its argv: an early take
rebuilt it whole, and the note came out as long as the table, saying
again what the row says (the package) and what the insert's line says
(the options). The rest
carry that they were added *at the request of* the installer of a
package the command named. Not *by* it: §2.6 finds three ways — the
installer's own `add_dep`, its `installs`/`adds_deps` that
igniter.install honours, and a hook of Ash's that an installer's
`ash.extend` sets off. The note does not name the installer: the commit
does not say which one, and a guess from a table kept by hand would go
stale with the first release that moves a dependency.

## 4. Evaluation

**Unit tests** (`test/workbench_igniter/features/ash_test.exs`, 14
cases, in-memory Phoenix project): the default command; the mapping
of every option to its packages in order; repeated `:csv` switches;
`--data-layer none`; `--example` and `--yes` handed down; no file
touched; the notice; unknown `--data-layer` / `--api` as issues with
nothing queued; present packages left out, the no-op notice, and the
`org/package@version` match; `installed?/1`; the manifest. The catalog
suite (`catalog_test.exs`) lists the cartridge among the standalone
and excludes it from the "flips once installed" case (§3.4).

**Real project** (2026-08-28, local, no containers): a stock
`mix phx.new probe --no-install` on Phoenix 1.8 / Elixir 1.19.5 /
OTP 27 / Igniter 0.8.3, with this package as a path dep, then
`mix workbench.install.ash --api json_api --auth password --yes`.

*First run*: `ash.install`, `ash_postgres.install`,
`ash_phoenix.install`, `ash_json_api.install` reported ✔, then
`ash_authentication_phoenix.install` printed the prompt of §2.5 and
the run hung on it — `--yes` was on the command line. That is what
put `ash_authentication` before its Phoenix half in the list (§3.2).

*Second run*, with the fix: the six installers ✔ in 2 min 31 s
(`ash ~> 3.0`, `ash_postgres ~> 2.0`, `ash_phoenix ~> 2.0`,
`ash_json_api ~> 1.0`, `ash_authentication ~> 4.0`,
`ash_authentication_phoenix ~> 2.0`, plus `picosat_elixir ~> 0.2`);
`mix ash.codegen` generated two migrations and the resource snapshots;
`git status` showed the `Accounts` domain with `User` and `Token`, the
JSON:API router, the auth controller and overrides, `.igniter.exs`,
and `config/config.exs`, `dev.exs`, `runtime.exs`, `test.exs`,
`mix.exs` (`setup` and `test` aliases on `ash.setup`), the repo and
the endpoint and router modified. The repo's block in `dev.exs`,
`test.exs` and `runtime.exs` was untouched, as §2.5 predicts; what
the three gained is listed in §3.6. *Third run*, same options: nothing
queued, the "nothing to install" notice, no file changed. `mix test`
in the probe (`ash.setup` against a Postgres on `127.0.0.1:5432`)
passed 5/5.

The toolchain image installs `build-essential`
(`scripts/Dockerfile.local`), so `picosat_elixir`'s C compiles under
`./wb.sh add` too — argued from the Dockerfile, not run.

**Not measured**: the queued command against every data layer and
API — `sqlite`, `csv`, `graphql`, `typescript` and the *Advanced
Options* were mapped from their package names and not run; a
`./wb.sh add ash` inside the workspace container, where the network
and Postgres wiring differ from the local run; `--example`; any
strategy but `password`.

## 5. Limitations and open questions

* The *Existing App* command of the site was inferred (§2.1) until
  its feature map was read [17] and the four differences reconciled
  (§3.7). The map is what to re-read when the site changes:
  `mix workbench.ash.site` does it and reports the differences; it
  does not update anything.
* `ash_postgres.install` sets `min_pg_version/0` to `16.0.0` when it
  cannot detect the server [13]; the workspace's `postgres:latest`
  satisfies it, an older pinned image would not.
* OAuth strategies need client ids the installer cannot know. Which
  environment variables the generated config reads, and so what
  `.env.sample` should carry beside `TOKEN_SIGNING_SECRET`, is the
  first thing to establish for a v0.2.0.
* A project generated with `--no-ecto` and `--data-layer postgres`
  will get `ash_postgres.install`'s own repo and config; not tried.
* `ash_authentication_phoenix.install` asks through
  `Mix.shell().yes?/1` when it finds no Accounts domain (§2.5). The
  cartridge avoids the question by ordering; an `--accounts` that does
  not match what `ash_authentication.install` created would meet it
  again, and hang under `./wb.sh add`.
* Igniter forces `--yes` when there is no TTY, so under `./wb.sh add`
  every prompt of the queued command answers yes, including "Modify
  mix.exs and install?". That is the same behaviour every other
  cartridge has under `add`.

* `ash.install --example` generates `Support.Ticket` and
  `Support.Representative` without `--extend postgres` [20]: the
  example resources live in no table. They show the DSL; they do not
  persist.
* `ash_phoenix.install` deletes from an existing `AGENTS.md` the
  `phoenix:ecto` block and the *Form handling* section [20]: phx.new's
  advice for an Ecto project, replaced by nothing. The cartridge installs
  it as its author wrote it.
* The queued `ash.codegen` writes the migrations and their snapshots;
  nothing applies them. `mix ash.setup` does, through the `setup` alias
  ash_postgres rewrote (§2.5).

## References

Read in full on 2026-08-28 unless marked otherwise.

1. ash-hq.org home page, static HTML as served —
   <https://ash-hq.org/>. The installer widget's package names were
   read off the markup (`ash_postgres`, `ash_sqlite`, `ash_csv`,
   `ash_json_api`, `ash_graphql`, `ash_typescript`,
   `ash_authentication`, `tidewave`, `ash_ai`, `usage_rules`,
   `ash_money`, `ash_double_entry`, `ash_oban`, `ash_state_machine`,
   `ash_events`, `ash_archival`, `ash_paper_trail`, `ash_cloak`,
   `live_debugger`, `ash_admin`, `mishka_chelekom`, `cinder`).
2. The generated installer script —
   <https://ash-hq.org/install/demo?install=ash_postgres,ash_phoenix,ash_authentication,ash_json_api>.
3. Ash, *Get Started* — <https://ash.hexdocs.pm/get-started.html>.
   **Summary only**: fetched through a summarizer, not read in full;
   quoted for nothing but the `mix igniter.install ash` command.
4. Igniter 0.8.3, `Mix.Tasks.Igniter.Install` moduledoc —
   `deps/igniter/lib/mix/tasks/igniter.install.ex`.
5. Igniter 0.8.3, `Igniter.Util.Install` —
   `deps/igniter/lib/igniter/util/install.ex`.
6. Igniter 0.8.3, `Igniter.apply_and_fetch_dependencies/2` —
   `deps/igniter/lib/igniter.ex`.
7. Igniter 0.8.3, `Igniter.Mix.Task.Info` moduledoc —
   `deps/igniter/lib/mix/task/info.ex`.
8. Igniter 0.8.3, `Igniter.Mix.Task.__using__/1` (`run/1`) and
   `configure_and_run/3` — `deps/igniter/lib/mix/task.ex`.
9. Igniter 0.8.3, `Igniter.Util.Info.compose_install_and_validate!/8`
   — `deps/igniter/lib/igniter/util/info.ex`.
10. Igniter 0.8.3, `Igniter.add_task/3` — `deps/igniter/lib/igniter.ex`.
11. Igniter 0.8.3, `Igniter.do_or_dry_run/2` and
    `run_queued_tasks_with_tracking/1` — `deps/igniter/lib/igniter.ex`.
12. `Mix.Tasks.Ash.Install`, `main` —
    <https://raw.githubusercontent.com/ash-project/ash/main/lib/mix/tasks/install/ash.install.ex>.
13. `Mix.Tasks.AshPostgres.Install`, `main` —
    <https://raw.githubusercontent.com/ash-project/ash_postgres/main/lib/mix/tasks/ash_postgres.install.ex>.
14. `Mix.Tasks.AshAuthentication.Install`, `main` —
    <https://raw.githubusercontent.com/team-alembic/ash_authentication/main/lib/mix/tasks/ash_authentication.install.ex>.
15. `Mix.Tasks.AshAuthenticationPhoenix.Install`, `main` —
    <https://raw.githubusercontent.com/team-alembic/ash_authentication_phoenix/main/lib/mix/tasks/ash_authentication_phoenix.install.ex>.
16. `Mix.Tasks.AshAuthentication.AddStrategy`, `main` —
    <https://raw.githubusercontent.com/team-alembic/ash_authentication/main/lib/mix/tasks/ash_authentication.add_strategy.ex>.
17. ash-hq.org, the installer widget's feature map in the site's app
    bundle — `/assets/app-69827d3ab630e9afe6bb67e913d94655.js`, read
    2026-08-29. One entry per option with `adds` (the packages it puts
    in the command), `requires`, `args` and `tooltip` (the hover text,
    two paragraphs). The tooltips are the source of the catalog's
    per-value docs (`choices/0`). The map also records what the site's
    command adds beyond this cartridge's tables — `oban` adds `oban_web`
    with `ash_oban`, `cloak` adds `cloak` with `ash_cloak`, TypeScript
    passes `--framework react`, `double_entry` requires `money`, the
    API-key option adds `ash_authentication` alone — reconciled in
    §3.7 (cartridge v0.2.0).
18. The installed sources, copied from the `deps` volume of a workspace
    inserted with every option (`Insert ash --data-layer postgres --api
    json_api,graphql,typescript --auth password,magic_link,api_key
    --with tidewave,ash_ai,…,cinder --example`), read 2026-09-24.
19. Igniter 0.8.4, `Mix.Tasks.Igniter.Install`,
    `Igniter.Util.Install` (`run_installers`, `get_deps!`),
    `Igniter.Util.Info` (`compose_install_and_validate!`, `installs`,
    `adds_deps`), `Igniter.Project.Deps` (the Hex lookup and the
    requirement) and `Igniter.Util.Version` — `deps/igniter/lib/`.
20. ash 3.33.10 `ash.install`, spark 2.13.1 `spark.install`,
    ash_phoenix 2.3.25 `ash_phoenix.install` — `deps/*/lib/mix/tasks/`.
21. ash 3.33.10, `Ash.Policy.Authorizer.install/5` —
    `deps/ash/lib/ash/policy/authorizer/authorizer.ex`.
22. The installers of ash_money (`ash_money.add_to_ash_postgres`),
    ash_ai, ash_graphql (`lib/igniter.ex`), ash_json_api, ash_oban and
    oban_web — `deps/*/lib/`.
