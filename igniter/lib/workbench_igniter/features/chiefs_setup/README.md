# chiefs_setup

The collection cartridge: it installs no file of its own — its
installer inserts other cartridges, the workbench's picks for a project
that wants the opinionated line without choosing box by box.

## The recipe

In insertion order (the order the old `workbench.setup` composed them
in, which the marks build on):

| # | Pick | Argv it gets |
| :-: | :-- | :-- |
| 1–4 | ansi, version_manager, toolchain, versioning | — |
| 5–9 | dashboard_extras, pgadmin, credo, mock, exdebug | — |
| 10 | rest `--health` **or** graphql | `--interface` decides |
| 11 | coveralls | `--exdoc` |
| 12 | exdoc | `--coveralls` |
| 13 | enhancements | `--interface`, `--exdoc`, `--health` |
| 14 | healthcheck | — |

The first four are the house's settings on a stock project — coloured
logs, the host's version pin, the language server's ignore, a version
and a changelog — and the rest is what it then carries.

The argv a pick gets is the recipe telling it which *fellow picks* ride
along (exdoc links the coverage report because coveralls is in the
box), never a member option surfaced as the collection's. auth0, openai
and stripe are not picks: they need external accounts, so they stay à
la carte (`wb.sh add auth0`, …) — and neither is guidelines, whose URL
is the team's to give. Nor is `--build` on exdoc and coveralls: the
recipe leaves it off, so an insert never waits on a suite or a
database.

## Options

* `--interface` - The API the picks build: `rest` | `graphql`.
  Default: `rest`. The one choice the collection owns; anything a
  single member decides (coverage theme, probe path, minimum coverage)
  is set by inserting that member directly.

## Two ways in

* `./wb.sh add chiefs_setup [--interface graphql]` — the workbench
  expands the recipe (`mix workbench.expand chiefs_setup`) and inserts
  each **missing** pick as its own `Insert <name>` commit, so `eject`
  keeps reverting one cartridge alone. Re-running adds only what is not
  in yet.
* `mix workbench.install.chiefs_setup` — composes every pick into one
  patch set, for running installers by hand outside the workbench
  script. One atomic apply, no per-pick commits.

## The mark

Delegated: the collection is installed when every fixed pick is in and
one of the two interfaces is. `state/1` reports which interface the
project carries. There is no `Insert chiefs_setup` commit and nothing
to eject as a whole — eject the members.

## Design rule for collections

A collection's option must be a decision the collection itself owns —
explainable on the box in one line without naming another cartridge's
switch. Re-exposing a member's option is how the one-type-of-cartridge
simplification would rot back into a second type; whoever needs the
member's option uses the member. The rationale is in
[DESIGN.md](DESIGN.md).
