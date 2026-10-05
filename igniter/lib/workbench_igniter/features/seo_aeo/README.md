# Cartridge: seo_aeo

SEO & AEO: what the application emits so its pages are found and quoted
correctly — **pending**: identified, not designed yet.

* **Task**: `mix workbench.install.seo_aeo` (does not exist yet)

## Description

A page is read by more than people. A search engine's crawler reads it
to decide what it is about and whether to list it (search engine
optimisation, SEO), and an assistant reads it to answer someone's
question and say where the answer came from (answer engine
optimisation, AEO). Both work from what the application sends: the
title and description of each page, its one true address, which pages
exist, what may be crawled, and data a machine can read without
guessing. A stock Phoenix project sends almost none of it. This box is
that layer, and the review that says it was checked.

The manifest is registered so the catalog shows the box as pending,
but nothing is designed and the installer is not written: nothing can
insert it yet.

## What it is expected to bring

Not decided — this is where the design starts from, and its
`DESIGN.md` settles each line:

* **What each page says of itself**: title, description, canonical
  address and the tags a shared link is drawn from, set per page and
  written once in the root layout; structured data where a page has
  something a machine should read as data.
* **What the application says of the whole**: a sitemap built from the
  project's own routes, and crawling rules.
* **The answer-engine half, as options**: each one named for what it
  is and chosen by the reader, never a default. `llms.txt` is a
  proposal and not a standard; letting assistants' crawlers in or
  keeping them out is the project's decision, not the box's.
* **The review, and the checks that run**: a document in the
  repository with what was checked and what is open, and one task that
  audits the running pages and brings its findings to it.

It builds on `html`: a project that serves no pages has nothing here
to emit.

Open, for the design: what of AEO is established enough to install and
what is only said; what a LiveView page needs, given that its first
render is plain HTML; how the sitemap learns of pages that come from
data and not from the router; and which audit runs, and where.

When it is built, fill this directory in like any other cartridge (see
the checklist in the package README): `DESIGN.md`, `task.ex`, its
templates under `priv/features/seo_aeo/`, its test and this README.

## Contents

| File | Role |
| --- | --- |
| `seo_aeo.ex` | Manifest only (`pending?/0` returns `true`) |
| `NEED.md` | The need it answers |

Cartridge test: none until built.
