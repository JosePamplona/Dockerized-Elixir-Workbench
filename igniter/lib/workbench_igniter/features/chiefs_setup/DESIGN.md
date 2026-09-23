# DESIGN — chiefs_setup

Revision: cartridge v0.2.0 (2026-08-30)

## Abstract

`workbench.setup` — the task that configured and composed the
opinionated project `wb.sh new` created — is retired and reborn as a
cartridge: a *collection*, whose installer inserts other cartridges.
With it, the registry's split between "composed" and "standalone"
cartridges disappears: there is one kind of cartridge, and composition
is just what one particular box does. The collection keeps one input
(`--interface`) and a fixed member list; `wb.sh add` expands it to one
insert commit per member.

## Problem

The workbench had two creation lines: `new` (setup composes 14 features
from `config.conf` flags) and `new2` (vanilla project, features added
one by one with `add`). Keeping both meant a behaviour where half the
callbacks (`flag/0`, `enabled?/1`, `implies/0`, `argv/1`,
`enabled_by/0`) existed only so setup could compose, a registry split
in two lists whose order carried hidden meaning, and a catalog with two
kinds of box. The decision to keep only the vanilla line left setup's
composition half without a home.

## Design

**A collection is a cartridge, not a second type.** Its manifest is
ordinary: `choices/0`, `option_docs/0`, `rerun/0` — the same machinery
every cartridge uses, which is what keeps the catalog and the console
uniform. The only new callback is `members/1`: the recipe, `{name,
argv}` in order, membership allowed to depend on the collection's own
options (the interface). Alternative rejected: a parameterized bundle
mirroring setup's 27 options — that relocates the composition machinery
instead of deleting it, couples the bundle to every member's switches,
and reintroduces the special box the change exists to remove.

**The one-input frontier.** A collection's option must be a decision
the collection owns, explainable on the box without naming a member's
switch (`--interface` qualifies; `--coverage-theme` does not — it is
coverage's `--html-theme`, set by inserting coverage). This is the rule
that keeps option creep from rebuilding setup under another name.

**Argv is recipe, not forwarding.** A member's argv tells it which
fellow picks ride along (`exdoc --coverage`), mirroring what setup's
`argv/1` derived from its flags. The cost accepted: the recipe breaks
at compile/test time if a member renames a switch — the catalog test
runs the collection's install, so a rename is caught there.

**One commit per member.** `wb.sh add` asks `mix workbench.expand` for
the missing members and inserts each as its own container run and
`Insert <name>` commit. Alternative rejected: one atomic
`Insert chiefs_setup` commit — it would make eject all-or-nothing and
hide which cartridges are in the history. Consequence embraced: the
collection has no commit and no eject of its own; its mark is
delegated (every fixed pick in, one interface in) and `state/1` reports
the interface found.

**What died with setup, and what came back.** The behaviour callbacks
above and the registry's `all/standalone/normalize/compose` — deleted,
not moved. `implies` (openai/stripe force auth0) became `requires`: the
à-la-carte world refuses and names the missing box instead of silently
installing it.

Setup's non-feature configuration went with it in the first pass and
was rescued in the second, as boxes rather than as lines in a task —
one decision each, joined to this recipe: `ansi`, `toolchain`
(`.tool-versions` + the ElixirLS ignore; two boxes since 2026-09-18,
`version_manager` and `toolchain`) and `changelog` (the initial
version + `CHANGELOG.md`). Two pieces deliberately became *no* box:
the generators and migration types, which are the config half of
enhancements' `--id-type`/`--timestamps` and belong in the cartridge
that already owns the decision — two boxes writing one policy can
contradict each other — and `dev_routes` in test, already written by
health_endpoint, which is what needs it. The `README.md` template found no
owner: a generated README has to know every cartridge, which is the
coupling this design removes, so it stays deleted.

## Evaluation

Argued from the code and the test suite, not measured: the catalog test
inserts the collection on a generated project and asserts every member's
mark flips (and only those). Wall-clock cost of per-member inserts (one
container run each, ~11 for a full add) accepted and not measured.

## Limitations

- Nothing prevents `add graphql` on a rest project: mutual exclusion
  was setup's `--interface` validation, and per-cartridge `conflicts`
  machinery was deliberately not built for one pair.
- The recipe's argv couples the collection to the member switches it
  names (`--exdoc`, `--coverage`, `--health`, `--interface`); the
  member's own defaults cover everything else.

## References

1. `SETUP2_INVENTORY.md` — the dissection of setup's parts (read
   2026-08-30).
2. `../README.md` — cartridge anatomy and the collections rule.
