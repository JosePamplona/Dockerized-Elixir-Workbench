# gettext — Design

*Revision: cartridge v0.1.0 (2026-08-30). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md); the engine —
generate twice, take the difference, merge three ways — is argued in
the [mailer paper](../mailer/DESIGN.md) §2.3–§2.7 and §3.1–§3.5, and
this paper holds only what gettext decides for itself.*

## Abstract

`phx.new --no-gettext` leaves out the `gettext` dependency, the
backend module, `priv/gettext` and every `use Gettext` line — and, less
visibly, changes how the components and layouts it *does* generate
render their strings. The cartridge brings back whatever `phx.new`
generates for gettext at the installer's version, as the difference
between the project generated with and without the flag against the
project's own shape, so the components come out gettext-aware when the
project has them and untouched when it does not. The mark is the
`gettext` dependency. The one thing this cartridge taught the engine is
what happens when Ecto comes in later: `errors.pot` is a file the ecto
delta changes at its end, and the byte Igniter and `phx.new` disagree
on there was a conflict until the merge normalised it.

## 1. Problem

Gettext's own guide is short — a backend, `use Gettext, backend:` in
the modules that translate, `mix gettext.extract` and
`gettext.merge` [4] — but in a Phoenix project the strings that need
translating are already written, in `core_components.ex`, the layouts
and the error helpers, and `phx.new` writes them one way with gettext
and another without (§2.1). Adding gettext by hand therefore means
rewriting generated files line by line; the question for the cartridge
was whether the engine's delta captures that rewrite, and against which
shape of project.

## 2. Background

### 2.1 What `phx.new` does with `--no-gettext`

`mix help phx.new`: "`--no-gettext` - do not generate gettext files"
[1]. `put_binding/1`: `gettext = Keyword.get(opts, :gettext, true)`;
`Single.generate/1`: `if Project.gettext?(project), do:
gen_gettext(project)`, which copies three templates —
`phx_gettext/gettext.ex.eex` to `lib/:lib_web_name/gettext.ex`,
`errors.po.eex` to `priv/gettext/en/LC_MESSAGES/errors.po`,
`errors.pot.eex` to `priv/gettext/errors.pot` [2, 3]. The backend
template is `use Gettext.Backend, otp_app: :<app>` [3].

The conditionals elsewhere [3]:

* `phx_single/mix.exs.eex`: `{:gettext, "~> 1.0"}`.
* `phx_single/lib/app_name_web.ex.eex`: `use Gettext, backend:
  <Web>.Gettext` in `controller/0` and in `html_helpers/0`.
* `phx_web/components/core_components.ex.eex`: `use Gettext, backend:
  <Web>.Gettext`, and the `translate_error/1` clause that calls
  `Gettext.dngettext` / `dgettext` with the `"errors"` domain (the
  version without gettext interpolates the message itself).
* `phx_web/components/layouts.ex.eex` and `core_components.ex.eex`:
  every user-facing string goes through
  `maybe_heex_attr_gettext/2` and `maybe_eex_gettext/2`, which render
  `{gettext("close")}` with the flag and `"close"` without [2].
* `phx_single/config/runtime.exs.eex`: the live-reload pattern
  `~r"priv/gettext/.*\.po$"` under the `:dev` block.
* `phx_gettext/errors.pot.eex` and `errors.po.eex`: the Ecto messages
  ("From Ecto.Changeset.cast/4" onwards) only `<%= if @ecto do %>`.

Measured deltas [7]: on a default project without gettext, created
`lib/probe_web/gettext.ex`, `priv/gettext/en/LC_MESSAGES/errors.po`,
`priv/gettext/errors.pot`; changed `config/runtime.exs`,
`lib/probe_web.ex`, `lib/probe_web/components/core_components.ex`,
`lib/probe_web/components/layouts.ex`, `mix.exs`. On an API-only
project (no html): the same three created, and only `lib/probe_web.ex`
and `mix.exs` changed.

### 2.2 What Gettext asks for

Gettext 1.0.2's moduledoc [4, summary only]: a backend —
`use Gettext.Backend, otp_app: :my_app` — and `use Gettext, backend:
MyApp.Gettext` in the modules that call `gettext/1`, `ngettext/3`,
`dgettext/2`; messages under `priv/gettext/<locale>/LC_MESSAGES/<domain>.po`,
"configurable"; `mix gettext.extract` "pulls `gettext()` calls into
`.pot`" files and `mix gettext.merge priv/gettext` "updates
locale-specific `.po` files". The note on the backend: "Before v0.26.0
of this library… `use Gettext` used to define macros in the calling
module. This created heavy compile-time dependencies" — the reason the
1.x form separates the backend from its users, and the form `phx.new`
writes.

### 2.3 The engine's files at the end

Two of gettext's three created files are the ones a later ecto insert
changes: the Ecto block of `errors.pot` and `errors.po` is appended at
their end (§2.1), and the mailer paper's §3.5 records that Igniter
writes a file with exactly one trailing newline while `phx.new`'s
`errors.pot` ends with two. The consequence is in §4.

## 3. Design

### 3.1 The delta, against the project's shape

Nothing is decided here that the engine does not decide: the cartridge
is `PhxDelta.insert(igniter, __MODULE__, :gettext)`. What the choice of
engine buys gettext specifically is §2.1's second half — the rewritten
strings. A hand-written installer would have to know that
`core_components.ex` has thirty-odd strings to wrap, and which ones;
the delta knows because `phx.new` renders them both ways and
`git merge-file` carries the difference onto the project's copy, edits
and all (mailer §3.4). And because the base is read off the project
(mailer §3.2), a project without html gets a delta without component
changes, and a project that inserts html *after* gettext gets
gettext-aware components from the html delta, since `facts.gettext` is
then true.

### 3.2 The mark: `gettext`

`installed?/1` is `dep_installed?(igniter, :gettext)`, the same read
`facts/1` makes. The alternatives: `lib/<app>_web/gettext.ex` — a file,
skipped when it exists, and a project may keep a backend under another
name; `priv/gettext` — a directory, which the delta does not create
when empty and which a project can carry for other reasons. The
dependency is what `--no-gettext` leaves out first and what Gettext's
installation begins with (§2.2).

### 3.3 No options, nothing beyond the delta

`phx.new` has no option for gettext, and the cartridge adds none: the
default locale is `en`, the domain `errors`, both `phx.new`'s. No
`.env` entry: nothing gettext reads comes from the environment. No
console door: `priv/gettext` is not a route.

## 4. Evaluation

**Unit tests** (`features/gettext_test.exs`, 3 cases; run 2026-08-30
in the suite of the mailer paper §4.1, 0 failures): the mark
out on `--no-gettext` and in by default; the backend, `errors.pot` and
the `mix.exs` line arriving and `core_components.ex` mentioning
`Gettext`; a second run unchanged.

**Real project** (mailer §4.2, second run, `phx_new` 1.8.9 on both
sides): on the API-only probe, `mix workbench.install.gettext --yes`
changed `lib/probe_web.ex` (2 lines) and `mix.exs` (1), created
`lib/probe_web/gettext.ex`, `priv/gettext/en/LC_MESSAGES/errors.po`
and `priv/gettext/errors.pot` — 48 lines in all, no issue. The
project compiled with `--warnings-as-errors` and its tests passed.
Then `mix workbench.install.ecto --yes` on that project reported
"priv/gettext/errors.pot: the ecto lines conflict with the project's
own edits" and wrote nothing. Diffing the probe's `errors.pot` against
a fresh base generation for the same flags: identical but for one
trailing empty line, present in `phx.new`'s file and not in the one
Igniter wrote (§2.3); the ecto delta appends its block at the end of
the file, adjacent to that line, and `git merge-file` counts adjacent
changes as a conflict. `errors.po` was byte-identical. That byte is what the engine's
`merge3/3` now normalises (mailer paper §3.4, mailer v0.2.0): the same
sequence run again — probe D of the mailer paper §4.4 — inserted ecto
over gettext's `.pot` with no issue, the file ending with the eleven
Ecto entries. Inserted the other way round (probe B), the `.pot` is
created with them.

**Not measured**: `mix gettext.extract` on the inserted project;
`./wb.sh add gettext` inside the container; a project with a backend
of its own.

## 5. Limitations and open questions

* **The delta does not extract.** A project that already has strings
  of its own in controllers and templates gets `gettext` wrapped only
  around `phx.new`'s strings; its own stay as they are, and
  `mix gettext.extract` finds nothing until they are wrapped. That is
  what gettext is, not a gap in the cartridge, but the README should
  not suggest otherwise.
* **The locale is `en` and the domain `errors`**, as `phx.new` writes
  them. A second locale is `mix gettext.merge priv/gettext --locale`,
  the project's business.

## References

Read in full on 2026-08-30 unless marked otherwise.

1. `phx_new` 1.8.9, `Mix.Tasks.Phx.New` moduledoc —
   `igniter/deps/phx_new/lib/mix/tasks/phx.new.ex`.
2. `phx_new` 1.8.9, `Phx.New.Generator` — `put_binding/1`,
   `maybe_heex_attr_gettext/2`, `maybe_eex_gettext/2` —
   `igniter/deps/phx_new/lib/phx_new/generator.ex`.
3. `phx_new` 1.8.9, `Phx.New.Single` (`template(:gettext, …)`,
   `gen_gettext/1`) and the templates `phx_gettext/gettext.ex.eex`,
   `phx_gettext/errors.pot.eex`, `phx_gettext/en/LC_MESSAGES/errors.po.eex`,
   `phx_single/mix.exs.eex`, `phx_single/lib/app_name_web.ex.eex`,
   `phx_web/components/core_components.ex.eex`,
   `phx_web/components/layouts.ex.eex`,
   `phx_single/config/runtime.exs.eex` — `igniter/deps/phx_new/`.
4. Gettext 1.0.2, `Gettext` moduledoc — <https://hexdocs.pm/gettext/Gettext.html>
   (served from <https://gettext.hexdocs.pm/Gettext.html>). **Summary
   only**: fetched through a summarizer; quoted for the backend form,
   the directory layout, the extract/merge tasks and the v0.26 note.
5. Phoenix 1.8, *Directory structure* —
   <https://hexdocs.pm/phoenix/directory_structure.html>. **Summary
   only**; `gettext.ex` listed among `lib/hello_web`'s files.
6. `igniter/lib/workbench_igniter/features/gettext/gettext.ex`,
   `task.ex`; `igniter/test/workbench_igniter/features/gettext_test.exs`;
   the [mailer paper](../mailer/DESIGN.md) for the engine.
7. `PhxDelta.delta/3` run on 2026-08-30 (mailer paper, reference 15).
