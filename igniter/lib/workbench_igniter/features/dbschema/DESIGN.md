# DESIGN — dbschema

Revision: cartridge v0.1.0 (2026-09-22)

## Abstract

The database's documentation was one feature living in two boxes: the
[exdoc](../exdoc/) cartridge planted `guides/database.md` and listed it
among the site's extras, and the [enhancements](../enhancements/)
cartridge planted the `mix db` task, its test and the DbSchema export
that feeds it. Neither owned the thing, and each carried a piece of the
other's knowledge — exdoc knew a page would be overwritten by a task it
did not install, enhancements wrote into a directory whose reader was
another box. This cartridge takes all of it. It is archived on the day
it is written: the mechanism is worth keeping and reading, the box is
not worth offering.

## Problem

Three facts had to hold at once, and no single box held them.

1. The page is generated. `mix db` overwrites `guides/database.md`
   every time the model is re-exported, so the file exdoc planted was a
   placeholder waiting to be replaced — exdoc's own README said so.
2. The page is listed in the site, which only exdoc knows how to write
   (`Igniter.Project.MixProject` over the `docs:` block).
3. The page exists whether or not the site does. `mix db` writes to
   `guides/` regardless; enhancements planted it with the Ecto group,
   with no reference to exdoc at all.

Split across two cartridges, (1) and (3) were enhancements' and (2) was
exdoc's, and the `opts[:ecto]` branch in exdoc's `docs_source/1` was
exdoc reasoning about a cartridge it does not name.

## Background

**DbSchema** is a desktop database designer (Wise Coders Solutions). Its
"HTML5 / Markdown documentation" export writes, per theme, a
`MainLayout.svg` of the diagram and a `database.md` of the tables, beside
the `.dbs` project file. The task was written against v9.5.3–v9.6.5 (its
own `@moduledoc` says so) and what it formats is that output: the
`&quot;public&quot;&#46;` schema prefix in the SVG, the `### Table
public.NAME` headings, the `(id) ref [public.users](#anchor) (id)`
foreign-key cells.

**ExDoc's two-theme images.** ExDoc's documentation for `extras` states
that an image whose URL ends in `#gh-dark-mode-only` is hidden in the
light theme, and one ending in `#gh-light-mode-only` in the dark — the
same fragments GitHub reads in a README, which is where the convention
comes from. Read 2026-09-22 in the ExDoc guides shipped with v0.38; it
is the mechanism exdoc's own v0.4.0 changelog entry cites when it
retires `themedImage.js`.

**ExDoc's `assets:` map.** exdoc's `docs:` block writes
`"guides/images" => "/assets"`, so a file the task puts in
`guides/images/` is served at `/assets/` and an extra page refers to it
as `./assets/<file>`.

## Design

**One box, not an option of exdoc.** The alternative was an exdoc
`--database` switch. It was rejected on the rule the shelf already
follows for [guidelines](../guidelines/): a box that reaches outside the
workbench — there a URL, here a desktop tool's export — should not be a
condition of inserting the documentation site. And the page is written
without a site at all, which an exdoc option could not do.

**`requires: ["ecto"]`, not `["ecto", "exdoc"]`.** Requiring exdoc would
refuse the insert on a project that has a database and no site, and the
page would then have no owner at all — which is the state this
extraction exists to end. Instead the cartridge does what
[changelog](../changelog/) does with `CHANGELOG.md`: write the file
always, and list it in the site only if `Exdoc.lists_pages?/1` says
there is one. Both orders work — site first, then this box, which lists
the page; or this box first, then exdoc, which lists what it finds.

**The fragments, not a script.** The page used to name one image and
lean on `guides/js/themedImage.js`, planted by exdoc, which swapped the
`src` when the theme changed. That script named `model-light.svg` and
`model-dark.svg` by hand — it served this one page and no other — and
exdoc retired it in v0.4.0. Writing both images with their fragments
moves the knowledge into the page that needs it, costs no JavaScript,
and reads correctly in a plain Markdown viewer and on GitHub, where a
script does not run. The cost: the page carries two image lines instead
of one, and a reader of the raw Markdown sees the diagram twice.

**`--combo`, and what it can be read back.** The sample exports are kept
as they were: five directories, one per shape of the sample database.
`state/1` reads the combo back off the tables in
`assets/db_schema/database.dbs` — `users` is auth0's, `conversations`
openai's — which is what enhancements did before it. It cannot see
Stripe: the `auth0_stripe` export names the same tables as `auth0`,
because Stripe keeps its objects at Stripe and the project stores none
of them. So `auth0_stripe` reads back as `auth0`, and
`auth0_openai_stripe` as `auth0_openai`. That is honest — the project
carries no mark of the difference — and it is written into `state/1`'s
doc rather than papered over with a marker file the project would keep
for the workbench's sake.

**The task is installed as its author wrote it.** Its formatting, its
comments, its two spellings of "source" are the project's from the
moment it lands. The only edit made on extraction is the image lines,
because the mechanism they used was taken away.

## Evaluation

The cartridge test covers: the task and its test planted; the export
landing per `--combo`, positively (`auth0_openai` has `conversations`)
and negatively (`none` has no `users`); the page and both images written
with both fragments, and the fragments present in the task's own source,
so a re-run writes the same page; the page listed under Support when
exdoc is in and not listed when it is out; `state/1` saying the combo
back; a second run changing nothing; and the refusal on a project
without Ecto.

Not measured: `mix db` has not been run against a fresh DbSchema export
from a version newer than v9.6.5, and the page has not been rendered by
`mix docs` in this revision to see the two images resolve — the
`assets:` mapping is argued from exdoc's generated `docs:` block, not
observed. The task's test mocks `File.cp!/2` and `File.write!/2` and
asserts the lines it reports, so it does not check the page's content
either; that was true before the extraction too.

## Limitations

- The export is the developer's to keep current. Nothing in the project
  notices that the model has moved on and the page has not.
- The task hard-codes DbSchema's `public` schema in several places, so a
  model on another schema comes out with the prefix showing.
- `state/1` cannot see Stripe (above).

## References

1. DbSchema, Wise Coders Solutions — <https://dbschema.com>. The tool
   the export comes from; version range from the task's own
   `@moduledoc` (v9.5.3–v9.6.5), not re-verified here.
2. ExDoc guides, `extras` and the `#gh-light-mode-only` /
   `#gh-dark-mode-only` fragments (v0.38, read 2026-09-22).
3. [exdoc/CHANGELOG.md](../exdoc/CHANGELOG.md), v0.4.0 — the theme
   script retired, and why.
4. [exdoc/DESIGN.md](../exdoc/DESIGN.md) — the site, the `guides/`
   layout and the `assets:` map.
5. [changelog/changelog.ex](../changelog/changelog.ex) — the
   `lists_pages?/1` → `list_page/4` pattern this follows.
