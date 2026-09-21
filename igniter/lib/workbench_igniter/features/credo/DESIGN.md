# credo: the reviewer, and the file it does not own

Revision: cartridge v0.1.0 (2026-09-20)

## Abstract

A dep-only cartridge for Credo, plus one option: `--githook`, which
runs it before every commit. The paper is short because only two things
had to be decided — which reviewer, and where its pre-commit line
lives. The second is the interesting one: the line goes in a block of
a file another cartridge owns.

## Problem

Elixir ships a formatter and a compiler that warns; neither has an
opinion about naming, nesting, duplicated code or a function nobody
calls. A team either argues those in every review or delegates them.

## Background

Credo 1.7.19 (rrrene, read 2026-09-20 from `deps/credo`): "a static
code analysis tool for the Elixir language with a focus on teaching and
code consistency … refactoring opportunities …, complex code fragments,
… common mistakes, … inconsistencies in your naming scheme and — if
needed — help you enforce a desired coding style" [1]. It runs as `mix
credo` with no configuration file at all, and `mix credo.gen.config`
writes one when the defaults are not the project's taste. Its checks
are grouped by intent (readability, refactor, warning, consistency,
design); `--strict` turns on the low-priority ones as well.

The alternatives, and why they are not this box: **Dialyzer** answers a
different question — types and unreachable code, not style — and costs
a PLT build, which is a cartridge-shaped decision of its own and not
this one's; **`mix format --check-formatted`** is layout, has no
opinions beyond it, and is one of the checks the precommit cartridge
installs because it comes with Elixir; **Sobelow** is security analysis
for Phoenix, a third question again. None of them replaces Credo and
Credo replaces none of them.

## Design

**The dependency, unmodified.** `{:credo, "~> 1.7", only: [:dev,
:test], runtime: false}` — the declaration Credo's own README gives [1]
— and no `.credo.exs`. A box installs a tool as its author wrote it;
the project generates its own configuration when it wants one, and a
configuration written by the workbench would be the workbench's taste
arriving unasked.

**`--githook` writes in a file this cartridge does not own.** The
pre-commit hook, `.githooks/pre-commit`, belongs to the **precommit**
cartridge: it carries the crossing into the container, the checks that
come with Elixir, and the skeleton. This cartridge composes that
installer and calls `Precommit.check/4`, which gives it a delimited
block of its own (`WorkbenchIgniter.BlockFile`). Three properties come
from that, and they are why the option lives here rather than in a box
that would know about every tool: the block is this cartridge's to
write and to take away, `state/1` reads it back without parsing
anybody else's lines, and coveralls' block can stand in the same file
untouched.

The rejected alternative is the one the release plan carried: absorb
the hook box into credo and coveralls, an option each and no box. It
leaves the formatter, the compiler's warnings and the suite with no
owner — they come with Elixir, and no cartridge installs them.

**`mix credo`, not `mix credo --strict`.** On a stock `phx.new`
project, strict mode reports low-priority readability issues from the
first commit. A hook that refuses a developer's first commit is a hook
they disable, and then the box has installed nothing. The workbench's
own CI runs strict; a project's hook starts where it can pass, and the
line is in a file the project owns.

**Above the divider.** `Precommit.check/4` takes a `:stage`, and this
block is born `:fast`: Credo reads the source and never compiles the
project, so it belongs with the checks that refuse a commit in a
second, ahead of `mix compile`, the suite and coveralls' block. Born,
not fixed — the stage only decides where a new block appears, and a
project that moves it has the block replaced where it stands. The
alternative is the default, `:slow`, which is where every block lands
if nobody says otherwise, and it would have put the cheapest check in
the hook behind the most expensive ones: a commit refused by Credo
would pay for a compile first, which is the one thing the divider
exists to prevent.

## Evaluation

Verified in the cartridge's suite: the dependency; the hook block with
its line; the block standing above the divider and nothing of it
below; `state/1` saying the block back; a second run adding the
block to a project that took the dependency without it; and the
default, which writes no hook and inserts no second cartridge.

Not measured: how long `mix credo` adds to a commit. It reads source
and does not compile the project, so it is on the cheap side of the
hook's divider — argued from what it does, not timed.

## References

1. Credo 1.7.19 — README and `lib/credo/check/`, read 2026-09-20 from
   the copy in `igniter/deps/credo`.
2. `WorkbenchIgniter.Features.Precommit` — the hook, its stages and
   `check/4`; its DESIGN.md carries the crossing into the container.
