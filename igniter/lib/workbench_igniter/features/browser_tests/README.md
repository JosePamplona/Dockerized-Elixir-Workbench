# Cartridge: browser_tests

Tests that drive the application through a real browser — **pending**:
identified, not designed yet.

* **Task**: `mix workbench.install.browser_tests` (does not exist yet)

## Description

Phoenix tests a page where it is rendered: the HTML the server sends
and the events a LiveView handles, with no browser involved. That is
fast and covers most of an application, and it cannot see what happens
only in a browser — a JavaScript hook, a file upload, a navigation that
loads the page again. Testing those takes a browser, and a browser is
what nobody wants to install on every machine and in CI. This box is
that: the browser as a service of the workspace, and in the project
the tests that open the application through it.

The manifest is registered so the catalog shows the box as pending,
but nothing is designed and the installer is not written: nothing can
insert it yet.

## What it is expected to bring

Not decided — this is where the design starts from, and its
`DESIGN.md` settles each line:

* **The browser, in the compose**: [Playwright](https://playwright.dev)
  with its browsers, declared by the cartridge like every other
  service (`compose/1`, role `devtools`), under a profile `up` never
  starts — the way `k6` is there to be run and not to stay up.
* **The tests, in the project**: the library that drives the browser
  from ExUnit, its configuration in `test`, and a database every
  browser test can use at once without seeing another's rows.
* **An example that runs**: one test that opens a page and does
  something only a browser can, so the insert is seen passing and not
  only compiled.

It builds on `html`: a project that serves no pages has nothing for a
browser to open.

Open, for the design: which library drives the browser, of the ones
Elixir has; where the browser runs and how it reaches the application
under test, in the pod and outside it; how the suite is run (its own
verb, as `./wb.sh k6`, or `mix test` with a tag); and what keeps these
tests from being the slow, flaky end of the suite — how many there
should be is part of the answer.

When it is built, fill this directory in like any other cartridge (see
the checklist in the package README): `DESIGN.md`, `task.ex`, its
templates under `priv/features/browser_tests/`, its test and this
README.

## Contents

| File | Role |
| --- | --- |
| `browser_tests.ex` | Manifest only (`pending?/0` returns `true`) |
| `NEED.md` | The need it answers |

Cartridge test: none until built.
