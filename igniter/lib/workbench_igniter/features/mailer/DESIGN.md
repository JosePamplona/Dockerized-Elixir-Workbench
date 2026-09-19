# mailer — Design

*Revision: cartridge v0.2.0 (2026-08-30). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md). This paper holds
two things: the mailer's own decisions, and the engine every base
cartridge runs on — `WorkbenchIgniter.PhxDelta` — which the mailer was
the first to use. The other seven papers refer to §2.3–§2.7 and
§3.1–§3.5 here instead of repeating them.*

## Abstract

`phx.new` decides at generation time whether a project has a mailer,
and nothing in Phoenix adds one afterwards: `--no-mailer` is documented
as "do not generate Swoosh mailer files", and there is no
`phx.gen.mailer`. What a mailer *is* to a Phoenix project is one module
and a few lines in seven other files, all of them conditioned on one
binding in `phx.new`'s templates. The cartridge does not know any of
this. It runs `phx.new`'s own generator twice on a scratch directory —
with the flags that describe the project as it is, read off the
project, and with the mailer on — takes the difference, and merges it
three ways onto the project's files with `git merge-file`. The
alternatives — an installer that writes the mailer's files itself, a
delta taken from Igniter's in-memory port of `phx.new`, a copy of the
templates — were rejected on what the sources do with each. The mark
is the `swoosh` dependency. The engine was verified by its unit tests
and by inserting all eight base cartridges into a stock API-only
`phx.new` project; the first run of that probe exposed the one
condition the delta depends on — the generator that takes it must be
the one that generated the project — and the second, with the versions
matched, was clean.

## 1. Problem

A Phoenix project born with `--no-mailer` and later needing to send
mail has Swoosh's installation guide to follow by hand: the
dependency, the API client setting, the mailer module, three
environments of adapter configuration, the dev mailbox route [4]. That
is what `phx.new` would have written, spread over `mix.exs`, four
config files, `runtime.exs`, the router and one new module (§2.1) —
and it is what `phx.new` will write *differently* at its next version.
Two questions for the workbench, then: how does a cartridge know what
to write, at the version of Phoenix the project runs on, without
carrying a copy that goes stale; and how does it write that onto a
project whose files have been edited since they were generated. The
first is the mailer's question and every other base cartridge's; the
answer is the engine.

## 2. Background

### 2.1 What `phx.new` does with `--no-mailer`

`mix help phx.new` [1]:

> `--no-mailer` - do not generate Swoosh mailer files

`Phx.New.Generator.put_binding/1` reads the option with its default
[2]:

```elixir
mailer = Keyword.get(opts, :mailer, true)
```

and `Phx.New.Single.generate/1` acts on it once [3]:

```elixir
if Project.mailer?(project), do: gen_mailer(project)
```

which copies one template, `phx_mailer/lib/app_name/mailer.ex.eex`, to
`lib/:app/mailer.ex`. Everything else the mailer touches is a
conditional inside a template that is generated either way [3]:

* `phx_single/mix.exs.eex`: `<%= if @mailer do %>{:swoosh, "~> 1.16"},
  {:req, "~> 0.5"},<% end %>`.
* `phx_single/config/config.exs.eex`: the `Swoosh.Adapters.Local`
  adapter, under the comment "You can see the emails in your browser,
  at "/dev/mailbox"".
* `phx_single/config/dev.exs.eex`: `config :swoosh, :api_client, false`
  — "Disable swoosh api client as it is only required for production
  adapters".
* `phx_single/config/test.exs.eex`: `adapter: Swoosh.Adapters.Test` —
  "In test we don't send emails" — and the api client off again.
* `phx_single/config/prod.exs.eex`: `config :swoosh, api_client:
  Swoosh.ApiClient.Req` and `config :swoosh, local: false`.
* `phx_single/config/runtime.exs.eex`: a commented Mailgun example
  inside the `:prod` block.
* `phx_web/router.ex.eex`: the dev-routes scope exists when
  `@dashboard || @mailer`, and inside it `forward "/mailbox",
  Plug.Swoosh.MailboxPreview` when `@mailer`.

So the mailer is one created file and seven changed ones, and the
changes are lines inside files the project already has. Measured with
`PhxDelta.delta/3` on a default project without the mailer:
`created` = `lib/probe/mailer.ex`; `changed` = `config/config.exs`,
`config/dev.exs`, `config/prod.exs`, `config/runtime.exs`,
`config/test.exs`, `lib/probe_web/router.ex`, `mix.exs` [15]. The same
seven on an API-only project.

### 2.2 What Swoosh asks for

Swoosh's own installation, as its documentation states it [4, summary
only]: the dependency; an API client — "To disable the API client
entirely: `config :swoosh, :api_client, false`", which "is necessary
when using `Swoosh.Adapters.Local`, `Swoosh.Adapters.Test`, or
SMTP-based adapters"; a mailer module, `use Swoosh.Mailer, otp_app:
:sample`; `Swoosh.Adapters.Local` in development with the
`Plug.Swoosh.MailboxPreview` route under `if Mix.env == :dev`; and in
production `config :swoosh, local: false`, "to prevent the local
storage process from running in production". What `phx.new` writes is
that recipe, with two choices of its own: `Swoosh.ApiClient.Req` and
the `req` dependency for production (Swoosh ships Hackney by default
and "also supports Finch and Req out-of-the-box" [4]), and
`Application.compile_env(:app, :dev_routes)` instead of `Mix.env ==
:dev` as the guard on the mailbox route, so the route is a
configuration of the project and not of the build.

### 2.3 The generator is a library

`Mix.Tasks.Phx.New.run/1` is a thin task: it parses the switches and
calls, in order, `Project.new/2`, `generator.prepare_project/1`,
`Generator.put_binding/1`, `validate_project/2`, `generator.generate/1`,
then git init and the install prompt [1]. The first four and
`generate/1` are public functions of `Phx.New.Project`, `Phx.New.Single`
and `Phx.New.Generator` (`@moduledoc false`, all of them) and take a
path: `copy_from/3` renders each template and writes it with
`Mix.Generator.create_file/2`, `config_inject/3` splits the target on
`"import Config"` and writes the result through `Code.format_string!`
[2]. Nothing in that chain reads the project it generates into;
everything is in the binding.

Two things vary between two runs of the same generator with the same
flags. `put_binding/1` draws `secret_key_base_dev`, `secret_key_base_test`,
`signing_salt` and `lv_signing_salt` from `random_string/1` —
`:crypto.strong_rand_bytes` — on every call [2]. And `AGENTS.md` is
assembled from the usage-rules files, unconditionally unless
`--no-agents-md` [2].

Where the generator comes from: the toolchain image installs it as an
archive, `mix archive.install hex phx_new --force` — unpinned, so the
version is whatever Hex serves when the image is built [11]. In this
package it is a test dependency, `{:phx_new, "~> 1.8", only: :test}`,
locked at 1.8.9 [12]. `mix phx.new`'s own help says of the options this
paper relies on that `--no-live` is "Automatically disabled if
`--no-html` is given" and `--no-assets` is "equivalent to
`--no-esbuild` and `--no-tailwind`" [1] — both visible in
`put_binding/1`: `live = html && Keyword.get(opts, :live, true)`,
`esbuild = Keyword.get(opts, :esbuild, assets)` [2].

### 2.4 Igniter's port of the generator

Igniter 0.8.3 ships `mix igniter.phx.install`, which is what
`Igniter.Test.phx_test_project/1` uses to build the in-memory project
every cartridge test runs against [7]. It refuses without the archive:

```elixir
if !Code.ensure_loaded?(Phx.New.Generator) do
  Mix.raise("""
  Phoenix installer is not available. Please install it before proceeding:

    mix archive.install hex phx_new
  """)
end
```

and then runs `Phx.New.Project.new`, `prepare_project` and
`put_binding` from the archive but its *own* generator,
`Igniter.Phoenix.Single.generate/2`, which renders the archive's
templates into the igniter instead of onto disk [7]. Its
`gen_ecto_config/2` is where the port and the original part [8]:

```elixir
def gen_ecto_config(igniter, %{binding: binding}) do
  adapter_config = binding[:adapter_config]

  config_inject(igniter, "config/dev.exs", """
  # Configure your database
  config :#{binding[:app_name]}, #{binding[:app_module]}.Repo#{kw_to_config(adapter_config[:dev])}
  """)
end
```

— one injection, into `config/dev.exs`. `phx.new`'s own
`gen_ecto_config/1` injects three: `config/dev.exs`, `config/test.exs`
and, inside `if config_env() == :prod do`, `config/runtime.exs` with the
`DATABASE_URL` block [2].

### 2.5 `git merge-file`

From its manual [9]:

> Given three files `<current>`, `<base>` and `<other>`, git merge-file
> incorporates all changes that lead from `<base>` to `<other>` into
> `<current>`. […] A conflict occurs if both `<current>` and `<other>`
> have changes in a common segment of lines. If a conflict is found,
> git merge-file normally outputs a warning and brackets the conflict
> with lines containing `<<<<<<<` and `>>>>>>>` markers.

> The exit value of this program is negative on error, and the number
> of conflicts otherwise […]. If the merge was clean, the exit value is
> 0.

### 2.6 What Igniter does to the files it holds

`Igniter.create_new_file/4` ends in `maybe_format(path, true, opts)`, and
`update_file/4` the same: an `.ex` source is formatted through the
project's `.formatter.exs` unless `format?: false` is given [6].
`format/3` also pulls `config/config.exs` and `config/#{Mix.env()}.exs`
into the igniter before formatting [6]. When the patch set is applied,
`Igniter.Project.Module.move_files/1` runs and moves any module whose
file is not at `Igniter.Project.Module.proper_location/3`, except files
matching the `dont_move_files` patterns of `.igniter.exs`;
`Igniter.Project.IgniterConfig.dont_move_file_pattern/2` adds a pattern
there, creating the file when the project has none [6, 10]. And an
igniter that holds an issue writes nothing: the whole patch set is
withheld, not the offending file alone (§4.2 shows it).

### 2.7 The other capabilities, for the record

The seven other base cartridges are the same engine with another flag
and another mark. Their deltas, measured the same way as §2.1 [15]:

| Capability | Creates | Changes (default project without it) |
| --- | --- | --- |
| gettext | 3 | 5 |
| ecto | 4 | 14 |
| esbuild | 3 | 6 |
| tailwind | 2 | 7 |
| html | 10 | 11 |
| live | 0 | 6 |
| dashboard | 0 | 3 |

The counts move with the project's shape — gettext changes two files on
an API-only project, five on a default one, because the components it
touches are html's — which is the point of §3.2.

## 3. Design

### 3.1 Ask the generator; do not reimplement it, and do not port it

Three ways for a cartridge to know what a mailer is:

1. **Write it into the cartridge.** An installer that calls
   `Igniter.Project.Deps.add_dep` for `swoosh` and `req`,
   `Igniter.Project.Config.configure` for each of the four
   environments, creates the module from a template, and patches the
   router's dev scope. Every one of those is a transcription of one
   `<%= if @mailer do %>` in §2.1 as it stands at Phoenix 1.8.9, and
   the cartridge would say "1.16" for Swoosh until someone noticed
   `phx.new` no longer did. Eight capabilities, eight transcriptions,
   each a maintenance obligation against a generator that is not in
   this repository. Rejected.
2. **Take the delta from Igniter's port** (§2.4): generate twice
   in-memory with `igniter.phx.install`, no scratch directory, no disk.
   Rejected on `gen_ecto_config/2`: the port's Ecto arrives with its
   `config/dev.exs` block and without `test.exs` and the `runtime.exs`
   `DATABASE_URL` block [8], so an ecto delta taken from it would leave
   a project that cannot run its tests or its release. The port is what
   Igniter needs for its own tests; it is not `phx.new`.
3. **Run `phx.new`'s generator on a scratch directory, twice.** Chosen.
   `PhxDelta.generate/1` calls `Phx.New.Project.new/2`,
   `Phx.New.Single.prepare_project/1`, `Phx.New.Generator.put_binding/1`
   and `Phx.New.Single.generate/1` — the chain of §2.3 minus git and the
   prompts — under `Mix.Shell.Quiet`, into
   `System.tmp_dir!()/phx_delta_<n>`, reads every file back into a map
   and removes the directory. The files are what `phx.new` writes, at
   whatever version answers to `Phx.New`: the archive in the toolchain,
   the test dependency in this package's suite. The cost is that the
   scratch writes happen outside Igniter's patch set, so `--dry-run`
   generates twice like a real run and only the merge is dry — and
   that the generator has to be *there*, and be the right one.
   `generator_check/1`, run by `apply/3` before anything is generated,
   refuses with an issue when `Phx.New.Generator` is not loadable (the
   message Igniter's port gives, §2.4) and when the archive's version —
   `Application.spec(:phx_new, :vsn)` — is not the `x.y.z` of
   `{:phoenix, "~> x.y.z"}` in the project's `mix.exs`, which is the
   generator's own version written by `phoenix_dep/1` (§2.3) and so the
   project's record of which `phx.new` made it. A requirement in any
   other form was edited by hand and says nothing; it is not checked.
   Why a version apart matters is §4.2's first run; why the archive can
   be a version apart is §5.

What is given up with 3 over 1: an installer whose diff a reader can
predict from the cartridge's source. What arrives is decided by the
generator, and the README tables say "with Phoenix 1.8.12" for that
reason.

### 3.2 The base is read off the project, not asked

`PhxDelta.facts/1` derives the flags that would generate the project
today: `--app` and `--module` from Igniter's project reading, each
capability from its dependency (`has_dep?` on `swoosh`, `gettext`,
`ecto_sql`, `esbuild`, `tailwind`, `phoenix_html`,
`phoenix_live_dashboard`), the database from which driver is a
dependency (`myxql`, `tds`, `ecto_sqlite3`, else `postgres`), the HTTP
adapter from `plug_cowboy`, `binary_id` and `live` from
`config/config.exs` (the live cartridge's paper says why those two
cannot be dependencies). The alternative — options on every base
cartridge saying what the project has, as the older composed
cartridges once took `--no-ecto` and `--no-html` — was what the
workbench moved away from when the base cartridges arrived (the
workbench CHANGELOG records it), because an option can be wrong and a
dependency cannot.

The consequence that matters: **the delta is taken against the project
as it is**, so the order of insertion does not matter and each delta
is specific to the shape. Inserting the mailer into a project with
html gives the router change; into one without, the same. Inserting
gettext into a project *with* html rewrites the core components to use
the backend; into one without, only `lib/app_web.ex` and `mix.exs`
(§2.7) — and when html is inserted afterwards its components come out
gettext-aware because `facts.gettext` is now true. The eight
capabilities compose in any order because none of them knows about the
others; `phx.new` does.

### 3.3 Two generations, one difference; the secrets equalized

`delta/3` classifies theirs against base: a path in theirs and not in
base is **created**; a path in both with different content is
**changed**, kept as `{base, theirs}` for the merge; a path identical
in both is not in the delta. A path in base and not in theirs is
**removed** — kept with base's content, because deleting a file the
project may have edited is the one operation a merge cannot undo:
`apply/3` removes it only while the project's copy is, byte for byte,
what `phx.new` put there. The case is one: `phx.new`'s static
placeholders under `priv/static/assets/` for a project without a
bundler, which esbuild and tailwind replace (§2.7 and their papers). A
placeholder the project rewrote into a bundle of its own — the case
`--no-esbuild`'s help describes — is the project's, and stays. The
first version of the engine had no removals at all and left the
placeholders tracked beside the pipelines; probe C (§4.3) showed them
overwritten by the first build.

Because `put_binding/1` draws fresh secrets on every run (§2.3), two
generations differ in `config/dev.exs`, `config/test.exs`,
`config/config.exs` and `lib/app_web/endpoint.ex` whatever their flags.
`equalize_secrets/2` splices base's salts and secret key bases into
theirs, file by file and in order, when the counts match; `apply/3`
splices the *project's* own secrets into both base and theirs the same
way before merging. Two results: `endpoint.ex` is not in the mailer's
delta at all (`phx_delta_test`: "phx.new's random secrets are not part
of the delta"), and a project's `signing_salt` line never reads as an
edit of ours, so it neither conflicts nor gets replaced.

### 3.4 Three-way merge with `git merge-file`, not AST patches

**First, the guarantee.** A file the project has not moved from what
`phx.new` wrote is written as `phx.new` writes it with the capability —
`theirs`, byte for byte, with the project's own secrets. That is the
case with the value in it — a project that grows a capability it left
out at birth, and should end where a birth with it would have — and it
is kept by construction, not by a merge coming out right. "Not moved"
is judged by content, not layout: the project's secrets are spliced
into base before comparing (§3.3), and an Elixir file is compared as
the formatter leaves both — a project that ran `mix format`, or that
Igniter formatted on an earlier insert, has not moved it. Everything
below is for a file the project *has* moved: there the engine offers
what it can — the project's edits kept, the capability's lines put in
— and says so when it cannot. `grown_vs_born_test` holds the guarantee
(§4.6): a project born bare and grown cartridge by cartridge is the
project born whole, byte for byte, secrets aside.

Changed files have three versions: the project's (ours), `phx.new`'s
without the capability (base), `phx.new`'s with it (theirs). Three
ways to put theirs' lines into ours:

1. **Overwrite with theirs.** Every edit the project made to
   `config/config.exs` since generation is lost. Rejected.
2. **Igniter's structural patches** — `Config.configure/4` for config
   lines, `Deps.add_dep/3` for `mix.exs`, Sourceror for the router.
   Needs a description of *what* changed per file per capability,
   which is option 1 of §3.1 again; and half the delta is not Elixir —
   `.heex`, `.css`, `.js`, `.pot`, `.formatter.exs`, `AGENTS.md`
   (§2.7) — where Igniter has no structural API.
3. **`git merge-file -p` with the three files.** Chosen. It is exactly
   the operation §2.5 describes — "incorporates all changes that lead
   from `<base>` to `<other>` into `<current>`" — line-based and
   language-agnostic, with one exit status for clean (0) and one for
   conflicts (their count). `merge3/3` writes the three to a scratch
   directory, labels them `project`, `phx.new` and `with the
   capability`, and reads stdout. The `git` binary is a requirement the
   workbench already has: the toolchain commits with it.

   The three are written with their end normalised to one newline. Not
   a nicety: Igniter writes every file that way (§2.6), and `phx.new`'s
   templates end however they end — `AGENTS.md` without a newline,
   `errors.pot` with two, `app.js` without (§4.3). A file an earlier
   insert wrote therefore differed from base on its last line, which
   `git merge-file` reads as a change of ours; and ecto's block on the
   `.pot`, html's and live's on `AGENTS.md`, live's on `app.js` are all
   appended *at that line* — "changes in a common segment" (§2.5), a
   conflict for every second base cartridge in a row. With the three
   ends equal the last line is not a change, and the appended block
   merges. The unit test is the byte itself: `merge3("a\nc\n", "a\nc",
   "a\nb\nc")` is `{:ok, …}`.

On conflict, `apply/3` leaves the file **untouched**, writes theirs
beside it as `<path>.phx-new` and adds an issue naming both. Writing
the conflict markers into the file, as `git merge-file` would, was
rejected because Igniter parses every `.ex` it writes (§2.6) and an
`.ex` with `<<<<<<<` in it is a parse error inside the patch set. Since
an issue withholds the *whole* patch set (§2.6), a conflict in one file
means nothing else is written: the project is as it was, plus the
issue telling the user which file to reconcile and against what. The
`.phx-new` file is therefore written to disk directly, outside the
patch set — the one side-effect write in the engine, made because the
file exists *for* the issue and a patch set the issue withholds would
withhold it too (the first version did, and the user had only the
message). In test mode it stays a patch, so the suite can assert it.

**Two Elixir files are applied as operations, not merged as text.**
Option 2 above was rejected for needing a description of what changed
per capability; for two files a *grammar* of the file is enough, and
the description is read off base and theirs each time, never written.
`mix.exs` is its keywords, dependencies and aliases
(`WorkbenchIgniter.MixFile`, 2026-09-16: anything beside where
`phx.new` writes — the workbench's own dependency on the `deps:` line
— conflicted on every project). The router is its pipelines, scopes
and routes (`WorkbenchIgniter.RouterFile`, 2026-09-19): each item known
by what it is — a pipeline by its name, a scope by its path and alias,
a route by its verb and path, the dev block by its `if` — with the
comments above it; theirs' additions go at the block's end when they
end it, else after the item they follow in theirs; a removal or a
change applies where the project still has the item as base had it,
and a block the project left as base had it becomes theirs whole, in
`phx.new`'s layout. What the project changed stays, with a notice — not
an issue, which would withhold the patch set for an edit that is no
fault. The text merge could not do this: html turns the `scope "/api"`
an API keeps its routes in into a comment, and dashboard and mailer
open the dev block at the router's end and add their route at the end
of `/dev` — each where a project writes too, so any project that had
used its router conflicted (§4.6). The grammar belongs to the router,
not to a version: before applying, `merge/3` applies the operations
to base, item by item, and they must give theirs back — a `phx.new`
whose change they cannot say fails that check and the router falls
back to the text merge above, conflict and all.

### 3.5 Files stay where `phx.new` puts them; the mark is read once

`phx.new` names `lib/` and `test/` after the app —
`lib/lorem_ipsum_9/mailer.ex` for `LoremIpsum9.Mailer` — while Igniter's
`proper_location/3` derives `lib/lorem_ipsum9/` from the module and
`move_files/1` would move the new module there at apply (§2.6).
`apply/3` therefore registers `^(lib|test)/<app>(_web)?/` with
`dont_move_file_pattern/2` before creating anything. The cost is a
`.igniter.exs` in the project from the first base cartridge on, with
that pattern in `dont_move_files` — visible in §4.2 — which a project
that already uses Igniter has anyway.

The project's own files are read into `ours` *before* any
`create_new_file`, because Igniter formats what it creates and pulls
the config files into the igniter as it does (§2.6): the merge must see
the file as it is on disk, not as the formatter would have it. The
merged text then goes through `update_file/4`, which formats it — the
one case where a base cartridge changes lines it did not mean to: a
project whose `.ex` files were not formatter-clean gets them cleaned.

### 3.6 The mark: `swoosh`

`installed?/1` is `dep_installed?(igniter, :swoosh)` — the same
`has_dep?` that `facts/1` reads for `mailer`, so the guard, the
catalog and the base generation agree by construction. Two other marks
were considered. `lib/<app>/mailer.ex` as a file: a project can define
a `Mailer` module for Bamboo or for nothing, and the delta does not
create the file when it exists (`on_exists: :skip`), so the module is
the one thing the mark must not be. `config :app, App.Mailer` in
`config.exs`: a configuration of the module, not of the capability;
the dependency is what `--no-mailer` leaves out first (§2.1) and what
Swoosh's installation begins with (§2.2). It is also why a default
`phx.new` project shows the cartridge inserted from birth: the mark is
read off the project, and a project born with a mailer carries it.

`insert/4` is the whole installer, shared by the eight: refuse with an
issue when a `requires/0` cartridge is not in (none for the mailer),
skip with a notice when the mark is in, otherwise `apply/3`.

### 3.7 What the mailer cartridge does not do

No production adapter and no environment variable: `phx.new`'s mailer
reads nothing from the environment — the `runtime.exs` example it
leaves is a comment (§2.1) — so, unlike ecto, there is no `.env` entry
to write, and writing one for an adapter the project has not chosen
would be a guess. No options: `phx.new` has none for it. What it does
add beyond the delta is the console door, `/dev/mailbox`, the path the
dev route forwards to — under `dev_routes`, so it exists in the
workspace's dev deployment and not in prod.

## 4. Evaluation

### 4.1 Unit tests

`igniter/test/workbench_igniter/`, run 2026-08-30 with the package's
test dependency (`phx_new` 1.8.9): 39 tests, 0 failures — 10 in
`phx_delta_test.exs` (facts of a default project and their flags;
absent capabilities as `--no-` flags; directories named after an app
with digits; the mailer's delta and the secrets equalized; `merge3/3`
clean, in conflict, and with the three ends differing — one newline,
none, two — merging alike; `generator_check/1` passing on the
installer's own project, refusing a `{:phoenix, "~> 9.9.9"}` naming
both versions, and silent on a hand-edited `"~> 1.8"`), 6 in
`features/mailer_test.exs` (the mark out
and in; the module, `swoosh` and the `config.exs` line arriving; a
project's own `mix.exs` edit surviving; a rewritten `deps` list
conflicting, the file untouched and `mix.exs.phx-new` created; the
`lorem_ipsum_9` module staying in `lib/lorem_ipsum_9/`; a second run
unchanged), 3 in `gettext_test.exs`, 6 in `ecto_test.exs`, 14 in
`base_cartridges_test.exs` — among them ecto after gettext and live
after html and esbuild on one in-memory project (no issue, the
appended blocks present), a dashboard insert refused on a `"~> 9.9.9"`
project with nothing changed, a `--no-agents-md` project receiving no
`AGENTS.md` from ecto, the placeholders taken away by esbuild and
tailwind and kept when rewritten, and the tailwind and live notices. The two sequence cases
pass with or without the end normalisation: Igniter's test mode does
not write the trailing byte the way a disk write does, so the byte is
guarded by the `merge3/3` case and the sequences by §4.4.

### 4.2 Real project

2026-08-30, local, no containers (Elixir 1.19.5 / OTP 27, `asdf`). A
stock `mix phx.new probe --no-install --no-html --no-assets --no-ecto
--no-mailer --no-gettext --no-dashboard` generated from this package's
test environment (`phx_new` 1.8.9), committed, then this package added
as a path dependency and `phx_new` as a dev dependency so that
`Phx.New` is loadable where the toolchain would have the archive; then
`mix workbench.install.<feature> --yes` for the eight in the order
mailer, gettext, ecto, esbuild, tailwind, html, live, dashboard, a
commit and `mix deps.get` after each; then `mix compile
--warnings-as-errors`, `mix assets.setup`, `mix assets.build`, and the
project's `mix test` against a Postgres started for the purpose on
`127.0.0.1:5432`.

*First run* — the dev dependency was `{:phx_new, "~> 1.8"}` and
resolved to **1.8.13**, while the project had been generated by 1.8.9.
`live` before html refused with the expected issue. Then the mailer:
"mix.exs: the mailer lines conflict with the project's own edits. The
file is untouched" — and `git status` clean, the whole patch set
withheld (§2.6). gettext inserted cleanly (`lib/probe_web.ex`,
`mix.exs`, `lib/probe_web/gettext.ex`, `priv/gettext/`, and
`.igniter.exs`, §3.5). ecto, esbuild, tailwind, html and dashboard each
conflicted on `mix.exs`; ecto also on `priv/gettext/errors.pot`; live
refused, html not being in. The project compiled and its two tests
passed, with only gettext in. The cause is §2.3 and §3.3 together: base
was generated by 1.8.13 and ours by 1.8.9, so `{:phoenix, "~> 1.8.9"}`
against `{:phoenix, "~> 1.8.13"}` is a change of ours in the deps
list; in an API-only project every capability's dependencies are
inserted *on the line after it* (`phx_single/mix.exs.eex`, §2.1), and
"changes in a common segment of lines" is a conflict (§2.5). gettext's
`{:gettext, "~> 1.0"}` goes after `telemetry_poller`, three lines
away, and merged. This run is kept as the measurement of what a
generator mismatch does; §5 draws the rule.

*Second run* — `phx_new` pinned to 1.8.9, everything else the same.
`live` refused before html. The mailer: 9 files — `config/config.exs`
(+9), `dev.exs` (+3), `prod.exs` (+6), `runtime.exs` (+18),
`test.exs` (+6), `lib/probe_web/router.ex` (+10: the dev scope with
the mailbox forward), `mix.exs` (+2), `lib/probe/mailer.ex` created
(3 lines), and `.igniter.exs` (§3.5) — 68 insertions, no deletion, no
issue; `mix deps.get` then added `swoosh` and `req` to the lock. A
second `mix workbench.install.mailer` printed "mailer is in already:
skipping." and changed nothing. gettext, esbuild, tailwind and
dashboard inserted clean (their papers have the figures). ecto
conflicted on `priv/gettext/errors.pot` and html on `AGENTS.md`, both
files written by an earlier insert; the diagnosis is in §4.3. `mix
compile --warnings-as-errors` passed; `mix assets.build` failed in
tailwind on `phoenix-colocated/probe/colocated.css`, html not being in
(tailwind paper §2.3); `mix test` 2/2.

### 4.3 The third run: two projects, ordered

The two conflicts of the second run were diffed against fresh base
generations for the same flags: `errors.pot` differed from base by one
trailing empty line, `AGENTS.md` by one trailing newline — Igniter
writes a file with exactly one `\n` at the end, `phx.new`'s
`errors.pot` template ends with two and `AGENTS.md` with none — and
both capabilities append their block at the end of those files, next
to the differing line. Two more probes were then run, ordered so that
no capability appends to a file an earlier insert had written.

*Probe B* — `phx.new --no-live --no-ecto --no-dashboard --no-mailer
--no-gettext` (html and both builders from birth), inserts in the
order live, ecto, gettext, mailer, dashboard: live 8 files (354
insertions, 62 deletions), ecto 18 (176/5, `.env` and `.env.sample`
among them), gettext 8 (276/18), mailer 8 (57/0), dashboard 3 (13/1);
no issue anywhere; live and ecto run again were no-ops with their
notices; `mix workbench.status` listed all eight base cartridges
installed. `mix compile --warnings-as-errors` passed; `mix
assets.setup` downloaded tailwindcss 4.3.0 and esbuild 0.25.4; `mix
assets.build` printed "≈ tailwindcss v4.3.0", "🌼 daisyUI 5.5.20" and
bundled `priv/static/assets/js/app.js` at 327.8 kB; `mix test`
against the Postgres: 5 tests, 0 failures. `AGENTS.md` carried the
elixir, phoenix, ecto, html and liveview blocks in `phx.new`'s order.

*Probe C* — the API-only project again, inserts in the order html,
esbuild, tailwind, dashboard, live, ecto: html 24 files (3 650
insertions — `default.css` is 80 kB — 5 deletions), esbuild 8
(297/2), tailwind 9 (279/4), dashboard 3 (24/3), then **live:
"AGENTS.md: the live lines conflict" and "assets/js/app.js: the live
lines conflict"**, nothing written — the same trailing byte, in two
files earlier inserts had written, both appended to at the end by
live; then ecto 18 files (176/5), clean, its `AGENTS.md` block being
in the middle. `priv/static/assets/` held `default.css` and the two
placeholders; after `mix assets.build` (2.7 KiB `app.js`, no LiveView)
`git status` showed both placeholders modified. Compile with
`--warnings-as-errors` passed; `mix test` 5 tests, 0 failures.

Times, for the record: an insert took 2–20 s wall clock including the
two generations, most of it dependency compilation after `deps.get`.

### 4.4 After the fix

The end normalisation (§3.4) and `generator_check/1` (§3.1) were
written from §4.2 and §4.3, and the two probes that had failed were
run again the same day.

*Probe C′* — the API-only project, inserts in the order html, esbuild,
tailwind, dashboard, **live**, ecto, gettext, mailer: not one issue.
live changed 6 files (339 insertions, 58 deletions: the LiveView
block in `AGENTS.md`, the `app.js` lines uncommented and the flash
handler gone, the config block, the components, the layouts), ecto 18
(176/5), gettext 8 (276/18), mailer 8 (49/1). After the run
`AGENTS.md`, `assets/js/app.js` and `priv/gettext/errors.pot` all
ended in one newline. `mix compile --warnings-as-errors` passed, `mix
assets.build` bundled the 327.8 KiB `app.js` with LiveView in it, `mix
test` 5 tests, 0 failures.

*Probe D* — the API-only project, gettext then ecto: clean, and
`priv/gettext/errors.pot` carried the eleven "From Ecto.Changeset"
entries. Then `phx_new` switched to `~> 1.8` — 1.8.13 — and
`mix workbench.install.mailer --yes`: one issue, "The project was
generated by phx.new 1.8.9 ({:phoenix, "~> 1.8.9"} in mix.exs) and the
installer's is 1.8.13: the delta would not be the project's. Install
that version (mix archive.install hex phx_new 1.8.9) and run this
again." — `git status` clean.

### 4.5 The workbench's own path

2026-08-30, after §4.4 and with `PHX_NEW_VERSION="1.8.12"` in
`config.conf` (§5): `./wb.sh new2 --no-mailer --no-dashboard` in a
fresh workspace (`_workspaces/test_32`, `lorem_ipsum_12`). The
toolchain image came out as `workbench:1.19.2-28.1-phx1.8.12` with
`phx_new-1.8.12` in its archives, the project with `{:phoenix, "~>
1.8.12"}` and a `Dockerfile.local` carrying the pin; `./wb.sh status`
listed gettext, ecto, esbuild, tailwind, html and live installed and
the other two not. `./wb.sh add mailer`: the compose's network and
database containers came up, the entrypoint ran `mix deps.get`, the
installer and `mix deps.get` again (fetching `swoosh`), and the
workspace got the commit *Insert mailer* signed as the host's git
identity — 2 min 15 s from the command to the commit, most of it the
container's dependency compilation. `./wb.sh add dashboard` the same
(*Insert dashboard*, `phoenix_live_dashboard` fetched). `./wb.sh add
mailer` again: "mailer is in already: skipping." and "Nothing to
commit." `./wb.sh status` then listed all eight. The workspace's log
reads *New project*, *Insert mailer*, *Insert dashboard*.

**Not measured.** A project whose own edits sit in the region a
capability changes, beyond the unit test's rewritten `deps` list; an
umbrella project (`Phx.New.Single` only); `--dev` and
`PHX_NEW_CACHE_DIR`; the cost of two generations on their own, which
§4.1's 4 s for 39 tests bounds from above; `./wb.sh eject mailer`
after §4.5; sending a mail.

### 4.6 The router, used

Six routers a project had used — a route in `/api` under html; a
scope appended at the end under dashboard and under mailer; a route of
the project's in `/dev` under mailer and under dashboard; a route in
`/` under dashboard — were grown in memory with the helpers of
`grown_vs_born_test` (2026-09-19). Merged as text, four of the six
conflicted, and none of the four had a route of the project's in the
capability's way: they met as lines, not as routes. Applied as
operations (§3.4), all six are clean, the project's routes where the
project put them and the capability's where `phx.new` puts them —
`router_file_test.exs` holds them. The same file walks every shape of
the router `phx.new` 1.8.9 makes — html with and without live,
dashboard, mailer: twelve — and each capability it lacks, and checks
that the operations turn base into theirs with no fallback. The first
run found one that fell back, html over a router with nothing else: two
items theirs adds side by side at the end, the `/` scope and the
comment that ends the block, were spliced in reverse; the splices now
keep their order.

The same day the guarantee of §3.4 went in: a file the project has not
moved is `theirs`, not merged. `grown_vs_born_test` used to compare
born and grown with allowances — how a file ends, a blank line after
`do`, the order of `mix.exs`'s lists and `.gitignore`'s patterns —
because merged files differed by those. With the guarantee none of them
is needed, and they are gone: every step of the 560 from a shape, and
every one of the 13 440 orders, gives the project born whole byte for
byte, its secrets aside.

## 5. Limitations and open questions

* **The archive is pinned by configuration, not by the project.**
  `generator_check/1` refuses a delta taken by another `phx.new` than
  the project's (§3.1), and the toolchain now installs the archive at
  `PHX_NEW_VERSION` from `config.conf` — baked into the workspace's
  `Dockerfile.local` and into the toolchain image's tag
  (`workbench:<elixir>-<otp>-phx<version>`), so a workspace keeps the
  image that made its project while a new version builds a new image
  beside it. What is not done: reading the version off the project.
  A workspace whose image was rebuilt from its own `Dockerfile.local`
  after `config.conf` moved on gets the old pin, which is right; a
  workspace whose `Dockerfile.local` was edited by hand does not, and
  the check is what catches it.
* **A hand-edited requirement is not checked** (§3.1): a project that
  loosened `{:phoenix, "~> 1.8.9"}` to `"~> 1.8"` is taken at its
  word, and a version apart then shows as `mix.exs` conflicts, as in
  §4.2.
* **Adjacent hunks conflict.** `git merge-file` needs unchanged lines
  between ours' and theirs' changes. `mix.exs` and the router no
  longer go through it (§3.4); every other file does, and a project
  edit beside a capability's hunk — a line of its own at the end of
  `config.exs`, a component after the last one in
  `core_components.ex` — conflicts there.
* **The router keeps what the project changed, whole.** A scope the
  project edited stays as the project has it even where the capability
  would change something small in it, and a notice says so; the
  capability's change to that scope is then the user's to make. html
  over an API is the case that matters: its `scope "/api"` stays, and
  `phx.new`'s commented example of one lands beside it.
* **A removal is decided on one comparison** (§3.3): a placeholder
  that differs from `phx.new`'s by a byte — a trailing newline added by
  an editor — is kept as the project's. Right by construction, and
  untidy in that one case.
* **`--no-agents-md` is read as the file's absence** (`facts/1`). A
  project that deleted `AGENTS.md` by hand after generating with it is
  read as having opted out, which is the right delta for it; a project
  that renamed the file is not, and gets a fresh one.
* **Formatting as a side effect** (§3.5): a merged `.ex` file is
  formatted on the way out. A project that does not run the formatter
  sees changes it did not ask for in the same commit as the insert.
* **`.igniter.exs` appears** with the first base cartridge (§3.5). It
  is Igniter's file, and harmless, but it is a file the project did not
  have.
* **The scratch directory** is `System.tmp_dir!()`; two generations per
  run, removed in an `after`. A crash between `mkdir_p!` and the
  `after` is not possible in the code as written; a generator that
  hangs would leave the directory.

## References

Read in full on 2026-08-30 unless marked otherwise.

1. `phx_new` 1.8.9, `Mix.Tasks.Phx.New` — the moduledoc (the options
   quoted) and `run/1`, `generate/4` —
   `igniter/deps/phx_new/lib/mix/tasks/phx.new.ex`; published at
   <https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html>.
2. `phx_new` 1.8.9, `Phx.New.Generator` — `put_binding/1`,
   `copy_from/3`, `config_inject/3`, `prod_only_config_inject/3`,
   `gen_ecto_config/1`, `random_string/1`, `generate_agents_md/1` —
   `igniter/deps/phx_new/lib/phx_new/generator.ex`; `Phx.New.Project` —
   `igniter/deps/phx_new/lib/phx_new/project.ex`.
3. `phx_new` 1.8.9, `Phx.New.Single` — the `template/2` declarations
   and `generate/1` — `igniter/deps/phx_new/lib/phx_new/single.ex`; the
   templates under `igniter/deps/phx_new/templates/`: `phx_single/mix.exs.eex`,
   `phx_single/config/{config,dev,test,prod,runtime}.exs.eex`,
   `phx_web/router.ex.eex`, `phx_mailer/lib/app_name/mailer.ex.eex`.
4. Swoosh 1.28.0, `Swoosh` moduledoc — <https://hexdocs.pm/swoosh/Swoosh.html>
   (served from <https://swoosh.hexdocs.pm/Swoosh.html>). **Summary
   only**: fetched through a summarizer; quoted for the installation
   steps, the api-client note, the mailbox preview route and
   `local: false`.
5. Phoenix 1.8, *Directory structure* —
   <https://hexdocs.pm/phoenix/directory_structure.html>. **Summary
   only**; consulted for where `mailer.ex` sits (`lib/hello`).
6. Igniter 0.8.3, `Igniter` — `create_new_file/4`, `update_file/4`,
   `maybe_format/4`, `format/3`, the apply path calling
   `Igniter.Project.Module.move_files/1` —
   `igniter/deps/igniter/lib/igniter.ex`.
7. Igniter 0.8.3, `Mix.Tasks.Igniter.Phx.Install` —
   `igniter/deps/igniter/lib/mix/tasks/igniter.phx.install.ex`;
   `Igniter.Test.phx_test_project/1` —
   `igniter/deps/igniter/lib/igniter/test.ex`.
8. Igniter 0.8.3, `Igniter.Phoenix.Generator.gen_ecto_config/2` —
   `igniter/deps/igniter/lib/igniter/phoenix/generator.ex`;
   `Igniter.Phoenix.Single.gen_ecto/2` —
   `igniter/deps/igniter/lib/igniter/phoenix/single.ex`.
9. `git-merge-file(1)`, the manual page of the git installed on the
   host, *Description*.
10. Igniter 0.8.3, `Igniter.Project.IgniterConfig.dont_move_file_pattern/2`
    — `igniter/deps/igniter/lib/igniter/project/igniter_config.ex`;
    `Igniter.Project.Module.proper_location/3` and `move_files/2` —
    `igniter/deps/igniter/lib/igniter/project/module.ex`.
11. `scripts/Dockerfile.local`, this repository — the archive install;
    `scripts/entrypoint.sh`, the `add` command.
12. `igniter/mix.exs` and `igniter/mix.lock`, this repository.
13. `igniter/lib/workbench_igniter/phx_delta.ex`,
    `features/mailer/mailer.ex`, `features/mailer/task.ex`,
    `WorkbenchIgniter.Feature.dep_installed?/2` and
    `missing_requirements/2` (`igniter/lib/workbench_igniter/feature.ex`);
    `igniter/test/workbench_igniter/phx_delta_test.exs`,
    `features/mailer_test.exs`, `features/base_cartridges_test.exs`;
    `igniter/test/support/test_project.ex`.
14. `CHANGELOG.md`, this repository — the base cartridges entry and the
    removal of the `--no-ecto`/`--no-html`/`--no-mailer`/`--no-dashboard`
    options from the composed cartridges.
15. `PhxDelta.delta/3` run on 2026-08-30 for each capability, on a
    default project's facts with that capability off and on an API-only
    project's (`--no-html --no-assets --no-ecto --no-mailer --no-gettext
    --no-dashboard`), listing `created` and `changed` paths — the
    figures in §2.1 and §2.7.
