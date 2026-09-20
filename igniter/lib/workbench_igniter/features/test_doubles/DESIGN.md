# test_doubles — Design

*Revision: cartridge v0.1.0 (2026-09-20), the paper written the day
before it. It replaces
[mock](../mock/), a dep-only cartridge, and inherits the eight
generated test files that stand on it. Sources consulted on
2026-09-19; quotations are verbatim from the page or file as read
then, and the hex figures are the API's (`hex.pm/api/packages/<name>`)
on that date. Versions as read: mox 1.3.2 (2026-09-11), mimic 2.4.2
(2026-09-18), hammox 1.0.0 (2026-07-24), mock 0.3.9 (2024-12-16),
meck 1.2.0 (2026-05-27).*

## Abstract

A project's tests must not call the real thing — the API over the
network, the file the task writes, the database that is supposed to
fail. Elixir has three answers and they are not interchangeable. Mox
replaces nothing: it builds a *new* module against a behaviour the
project declares, and the code under test must already ask its
configuration whom to call. Mimic replaces the module itself, any
module, by copying it out of the way, and needs nothing of the code —
at the price of standing on somebody else's API. `mock`, the shelf's
answer until now, does the same through Erlang's meck, but globally to
the VM, which costs the suite its `async: true`. The shelf carried the
third as a four-line dep-only box named for one of the five things it
installs, while eight generated test files used it for the other four.
This paper makes one box with the double as its option, `--double
mox|mimic`, one or several, and states the rule the option exists to
teach: **Mox where the cartridge owns the boundary, Mimic where the
module belongs to somebody else**. A census of what the shelf actually
falsifies decides the default: of the eight files, five replace `File`,
`System`, `Repo`, `Finch` or `HTTPoison` — modules no `@callback` of
the project's can reach — so `mimic` is what a project inherits unless
it asks otherwise. Type checking is a switch, not a library: `--type-check`
is Hammox on the Mox side and `Mimic.copy/2`'s `type_check: true` on
the other. And the box writes, which is what `mock` never did: the
`Mimic.copy/1` lines and the `Mox.defmock/2` calls live in
`test_helper.exs`, a file five cartridges will write into, which needs
the same owner-block file tool that credo and coveralls need for the
git hook. The blocker that opened this migration turns out to be
narrower than the papers said: meck has compiled on OTP 29 since 1.0.0
(2024-12-13), but `mock` pins `~> 0.9.2` and has not released since
2024-12-16, so the fix exists upstream and cannot arrive.

## 1. Problem

### 1.1 The box is four lines and the wrong noun

`mock.ex` adds `{:mock, "~> 0.3", only: :test}` and returns. There is
no template, no `priv/`, no CHANGELOG, no paper. Three cartridges
compose it — healthcheck (`healthcheck.ex:42,166`), coveralls
(`coveralls.ex:93,277`), enhancements (`enhancements.ex:53,345`) — and
chiefs_setup picks it directly (`chiefs_setup.ex:47`). The knowledge
the box is supposed to hold is not in it; it is in the eight test files
those cartridges plant, and those files were never the box's to
explain.

The name is the second half of the problem. Of the five test doubles
Meszaros named (§2.1), a *mock* is the strictest — the one that fails
when the expected call does not happen. Almost nothing the shelf
generates is one. They are stubs and spies.

### 1.2 The census

What the eight generated files actually replace, and whose module it
is:

| File | Replaced | Whose |
| --- | --- | --- |
| `auth0/accounts_test.eex` | `HTTPoison.get/2` | third party |
| `auth0/user_controller_test.eex` | `Auth0Jwks.Token`, `<App>.Accounts.from_token/1` | third party + the project's |
| `openai/assistant_test.eex` (673 lines), `conversation_controller_test.eex` (732), `assistant_fixtures.eex` | `Finch.request/2` | third party |
| `coveralls/cover_test.exs` | `File.write!/2` | stdlib |
| `enhancements/db_task_test.eex` | `File.cp!/2`, `File.write!/2` | stdlib |
| `healthcheck/controller_test.eex` | `Repo.query/1` and `System.cmd/2`, made to raise | stdlib + the project's repo |

Every one is `with_mock`/`with_mocks` with `[:passthrough]`: a global
replacement of a module the project did not define. Two of them are not
doubles of a service at all — `Repo.query` raising `Postgrex.Error` and
`System.cmd` raising `RuntimeError` exist to reach an error branch, and
`File.write!` in `cover_test.exs` is a **spy**, forwarding to the test
process with `send(parent, {:write, path, content})`.

The helper that holds three of those groups, `mock_helper.eex`, is
planted by **enhancements** (`enhancements.ex:373`) and its clauses
belong to others: `<%= if @auth0 %>` for `HTTPoison` and
`Auth0Jwks.Token`, `<%= if @openai %>` for `Finch`. A cartridge holds
another cartridge's test helper — the same crossing of boundaries as
rest's `--health` tag, and it has to be undone here (§3.7).

### 1.3 Where the blocker really is

`mock.ex:8` and the README carry a PENDING that says meck's latest
release is 0.9.2 and does not compile on OTP ≥ 29. That was true of
meck 0.9.2 and is no longer true of meck: the prefix `catch` in
`meck_matcher.erl` is deprecated in OTP 29 and meck builds with
`warnings_as_errors`, so 0.9.2 (2021-03-06) fails [9][10][11] — but meck
released 1.0.0 on 2024-12-13 and is at 1.2.0 (2026-05-27) [8].

The wall is `mock`'s own: release 0.3.9 requires `meck ~> 0.9.2` [7],
which in hex's SemVer admits `>= 0.9.2` and `< 0.10.0`, so meck 1.x
cannot be resolved under it. mock 0.3.9 shipped on 2024-12-16, three
days *after* meck 1.0.0, still pinned to the old line, and has not
released since — twenty-one months as of this paper. The upstream fix
exists and cannot reach the shelf.

It does not bite today: the workbench pins `ERLANG_VERSION="28.5.0.6"`
(`config.conf:23`), so generated projects compile their tests. It bites
on the next pin, and the box already advertises it — `NEED.md` reads
"**Not for:** OTP 29 and later". A box on the shelf that announces
itself broken in the next Erlang is a claim the reader cannot use.

## 2. Background

### 2.1 The vocabulary, and why it exists

"Test Double is a generic term for any case where you replace a
production object for testing purposes" [1]; the term is Gerard
Meszaros', from the xUnit patterns work, and Fowler lists his five
kinds [1]:

* **Dummy** — "objects are passed around but never actually used.
  Usually they are just used to fill parameter lists."
* **Fake** — "objects actually have working implementations, but
  usually take some shortcut which makes them not suitable for
  production".
* **Stub** — "provide canned answers to calls made during the test,
  usually not responding at all to anything outside what's programmed
  in".
* **Spy** — "stubs that also record some information based on how they
  were called".
* **Mock** — "pre-programmed with expectations which form a
  specification of the calls they are expected to receive. They can
  throw an exception if they receive a call they don't expect".

The word was coined because "mock" had come to mean all five. That is
exactly the confusion the shelf inherited (§1.1), and the reason this
box is not named after one of them.

### 2.2 Mox: a noun, not a verb

Mox comes from Valim's *Mocks and explicit contracts* (2015-10-14) [2],
whose thesis is one sentence: "I always consider 'mock' to be a noun,
never a verb." The argument against the alternative is operational, not
aesthetic — replacing a module globally "means you can no longer run
that part of your test suite concurrently", and it couples the test to
the implementation, so swapping the HTTP client breaks tests whose
application behaviour did not change.

The library states four rules [3]:

1. "No ad-hoc mocks. You can only create mocks based on behaviours"
2. "No dynamic generation of modules during tests"
3. "Concurrency support. Tests using the same mock can still use `async: true`"
4. "Rely on pattern matching and function clauses for asserting on the input"

Mechanically: `Mox.defmock(MyMock, for: MyBehaviour)` creates a new
module; `expect/4` records a call that must happen; `stub/3` a function
that may be called "zero or many times"; `verify_on_exit!/1` is the
setup callback that checks the expectations. Ownership is per process —
private mode is the default, `allow/3` "Allows other processes to share
expectations and stubs defined by owner process", and `set_mox_global`
"Permits any process to consume mocks but disables `async: true`" [3].
It stands on `nimble_ownership ~> 1.0` [12].

Rule 1 is the whole consequence for this shelf: **Mox cannot touch
`File`, `System`, `Finch`, `HTTPoison` or `Auth0Jwks.Token`**. It never
replaces a module; it builds one beside it, and the production code has
to be the thing that chooses. Adopting Mox for the census of §1.2 is
not a change of dependency but a redesign of five cartridges'
boundaries: a `@callback`, an implementation, and a
`Application.get_env/3` at the call site.

### 2.3 Mimic: copy the module out of the way

Mimic "is a library that simplifies the usage of mocks in Elixir",
works "similarly to mox but without explicit behavior contracts", and
its mechanism is stated plainly: it works by "copying your module out
of the way and replacing it with one of its own which can delegate
calls back to the original or to a mock function as required" [4]. Its
README puts the lineage in one line: "a sane way of using mocks in
Elixir. It borrows a lot from both Meck & Mox!" [5].

The setup is a declaration per module, before `ExUnit.start()`:

```elixir
# test_helper.exs
Mimic.copy(Calculator)
ExUnit.start()
```

"Importantly calling `copy/1` will not change the behaviour of the
module" [4] — a copied module that nothing stubs runs as itself, so
declaring one is not a cost paid by unrelated tests.

The verbs are the taxonomy of §2.1 made API: `stub/3` "Define a stub
function for a copied module"; `expect/4` "Define a stub which must be
called within an example"; `reject/1` "Define a stub which must not be
called" [4]. Private mode is the default and supports async; global
mode is `set_mimic_global`, and "If using global mode you should remove
`async: true` from your tests" [4]. `:set_mimic_from_context` picks
private for `async: true` tests and global otherwise [5], which is the
setting a generated project should carry.

Two caveats matter for the census:

* **Local calls are not intercepted.** Intra-module calls bypass Mimic
  because of the BEAM's local-call optimisation; a function must be
  reached by its fully qualified name to be stubbed [5]. This does not
  touch the census (every replaced call is remote), but it does touch
  any future double of a cartridge's own module.
* `copy/2` "is idempotent" [4] — a module declared twice is not an
  error, which is what makes a shared `test_helper.exs` written by
  several cartridges safe (§3.4).

### 2.4 The two are not rivals; the census says so

| What is replaced | Mox | Mimic |
| --- | --- | --- |
| `Finch`, `HTTPoison` (openai, auth0) | only after a client behaviour exists | directly |
| `<App>.Accounts.from_token/1` | natural — the project's own code | yes |
| `File.write!/2`, `File.cp!/2` (coveralls, enhancements) | impossible | yes |
| `System.cmd/2`, `Repo.query/1` made to raise (healthcheck) | impossible | yes |

The rows Mox cannot serve are not oversights of the library: they are
Valim's point [2] turned around. A test that must falsify `File` is
telling you there is no boundary there — sometimes because the code
should have one, and sometimes, as with `System.cmd` raising, because
what is being simulated is the platform failing, which is not a
collaborator at all.

### 2.5 Type checking is a switch, not a library

**Hammox** "is a library for rigorous unit testing using mocks,
explicit behaviours and contract tests" [6]; "Most of the functions in
this module come from Mox for backwards compatibility" [6], and it
depends on `mox ~> 1.2` [12] — it *wraps* Mox rather than replacing it,
adding runtime validation of callback typespecs and raising
`Hammox.TypeMatchError` when arguments or return values do not match.

**Mimic has the same faculty on its own side**, and this is the finding
that shapes the option: `copy/2` takes `type_check`, "Must be a boolean
defaulting to `false`. If `true` the arguments and return value are
validated against the module typespecs or the callback typespecs in
case of a behaviour implementation" [4]. It is why Mimic depends on
`ham ~> 0.3` [12].

So the shelf does not choose between "Mox" and "Hammox" as two values.
It offers one switch that means *verify the contract at runtime*, and
each double implements it in its own way (§3.3).

### 2.6 What the ecosystem is doing with them

Hex, read 2026-09-19 [7][8][12]; the weekly figure is the API's `week`
bucket and the release date is the latest release's:

| Package | Latest | Date | Downloads, all time | Last week |
| --- | --- | --- | --- | --- |
| mox | 1.3.2 | 2026-09-11 | 31,232,322 | 134,375 |
| mock | 0.3.9 | 2024-12-16 | 21,162,437 | 59,251 |
| mimic | 2.4.2 | 2026-09-18 | 5,863,760 | 53,358 |
| hammox | 1.0.0 | 2026-07-24 | 4,709,291 | 18,332 |

The download columns say less than the date column. `mock` is still
widely used — it is a decade of test suites, and nobody rewrites
those — but it has not shipped in twenty-one months while its own
dependency moved two major versions past the pin (§1.3). Mox and Mimic
both released within the last eight days of this reading, Mimic the day
before. Licences: Mox, Mimic and Hammox Apache-2.0; mock MIT [7].

### 2.7 Req.Test, and why it is not the answer here

Req ships its own testing facility: stubs registered with
`Req.Test.stub(name, plug)` and attached with `plug: {Req.Test, name}`,
"because `Req.Test` itself is a plug whose job is to fetch the
mocks/stubs under `name`" [13]. It uses "the same ownership model of
nimble_ownership, also used by Mox", so it works in concurrent tests
[13]. Nothing is replaced: the request is answered before it reaches
the network, by a `Plug.Conn`.

It is the best answer of the three **for a client built on Req**, and
the shelf's clients are not: openai is on Finch and auth0 on HTTPoison
(§1.2). Adopting it means changing the HTTP client of two cartridges,
which is their decision and not this box's. Recorded here so it is not
re-argued: if openai or stripe move to Req, their doubles leave this
box and become `Req.Test` stubs.

## 3. Design

### 3.1 One box, the double as its option

`test_doubles`, with `--double`, one or several values, in the shape
db_admin established for `--admin`: `mox`, `mimic`. Unlike db_admin,
**no value carries a state requirement** — both libraries install on
any project, with or without ecto, on any database — so `choices/0`
here documents the two and validates them, and nothing more.

The name is Meszaros' and Fowler's (§2.1), not the ecosystem's, which
says "mock" for all of it. The shelf has no search box — only the logs
do — so a reader meets the box by reading NEED lines down the shelf,
and the NEED is where the ecosystem's word goes, so that whoever came
looking for mocks lands and leaves with the distinction:

> Your tests must not call the real thing.
> **Before:** tests that reach the network, or `with_mock` replacing
> `File` for the whole VM.
> **After:** Mox for the service you own a contract with, Mimic for the
> module that is not yours — mocks, stubs and spies, each where it
> belongs.
> **Not for:** factories and fixtures; that is exmachina and what
> `phx.gen` already writes.

### 3.2 The default is `mimic`

A cartridge inserted without `--double` gets Mimic. Three reasons, in
order of weight:

1. **It is the only value that serves the census** (§2.4). Five of the
   eight files replace a module no behaviour of the project can reach.
   A box that defaulted to Mox would install a library that cannot be
   used until three other cartridges are redesigned.
2. **It is the migration that exists.** Mimic is `with_mock` without
   the global replacement: same reach, per-process, `async: true`
   preserved. The eight files move by rewriting call sites, not by
   changing where the boundaries of the code are.
3. **It does not foreclose Mox.** `--double mox,mimic` installs both,
   and that is the shape the reference project wants (§3.6): Mox for
   stripe's client, which is the cartridge's own boundary, and Mimic
   for everything the project did not write.

What the default costs, said in the README rather than hidden: a test
suite standing on Mimic is coupled to modules it does not own, and a
change in `Finch`'s API will break tests whose application behaviour
did not change — Valim's warning [2], which is true and which the
census does not let us avoid.

### 3.3 `--type-check`: one switch, two implementations

One boolean, meaning *validate arguments and returns against the
typespecs*:

* with `mox` → the dependency becomes `hammox` (which brings `mox ~> 1.2`
  itself [12]) and the generated helper calls `Hammox.defmock/2`;
* with `mimic` → the dependency does not change; every `Mimic.copy/1`
  the box writes becomes `Mimic.copy(Mod, type_check: true)` [4].

Off by default, and the README says why: on the Mox side it is only
worth the switch in a project that writes `@spec`s, and on the Mimic
side it validates against the *copied module's* typespecs, which is a
third party's promise and may be looser than the test wants.

### 3.4 What the box writes, and the file it shares

This is what separates the box from the one it replaces. `mock` added a
dependency; the knowledge of both libraries is in the wiring, and the
wiring is a file:

* **Mimic** needs one `Mimic.copy/1` per falsifiable module in
  `test_helper.exs`, before `ExUnit.start()`, plus
  `:set_mimic_from_context` in the generated test case.
* **Mox** needs `Mox.defmock/2` in `test_helper.exs`, the `@callback`
  of the contract in `lib/`, and the line of `config/test.exs` that
  injects the double.

And `test_helper.exs` is **shared**: healthcheck would declare `Repo`
and `System`, coveralls `File`, auth0 `HTTPoison` and its `Accounts`,
openai `Finch` — each cartridge owning its block, exactly as `MixFile`,
`ComposeFile`, `EnvFile` and `IgnoreFile` own theirs, and idempotent
because `Mimic.copy/2` is [4].

That is the second request of the same shape in two consecutive steps
of the migration: credo and coveralls both write into one git hook and
each must own its block. **One owner-block file tool serves both**, and
building it before either installer is the cheaper order. It exists
since 2026-09-19 as `WorkbenchIgniter.BlockFile`
(`lib/workbench_igniter/block_file.ex`): one generic tool with the
comment marker and the anchor as options — `put/5`, `drop/4`,
`block/3`, `owners/2` — and the rule that no cartridge may answer
`installed?/1` or `state/1` off a sentinel. The alternative, Sourceror
on `test_helper.exs` since it is Elixir, was not taken: it serves that
file and not the hook, and the shape repeats (`.tool-versions`, a
`Makefile`, an `AGENTS.md`).

### 3.5 The mark

The dependency, as `mock`'s was: `dep_installed?/2` on `:mimic`,
`:mox` or `:hammox`. With several values the box is in when any of them
is, and the form reports which, the way db_admin reports the admins it
installed. The generated `test_helper.exs` is not the mark: a project
may legitimately have emptied it.

### 3.6 Who composes it, and with which value

The three cartridges that compose `mock` today do not want the same
thing, and this is where the composition has to become explicit:

| Cartridge | Needs | Why |
| --- | --- | --- |
| healthcheck | `mimic` | `Repo.query/1` and `System.cmd/2` raising |
| coveralls | `mimic` | `File.write!/2`, as a spy |
| enhancements | `mimic` | `File.cp!/2`, `File.write!/2` |
| auth0, openai | `mimic` today; `mox` if their client grows a behaviour | §2.4 |
| stripe (pending) | `mox` | the cartridge owns the client; the reference project's row 15 already says Mox |

This was feared to be blocked and is not. A **composing cartridge**
already passes argv — `Igniter.compose_task/3` takes it, as coveralls
composes exdoc with `--exdoc` — so healthcheck composes
`workbench.install.test_doubles` with `--double mimic` and says what it
needs. Two composers that disagree do not fight, because `rerun/0` is
`:adds`: healthcheck's mimic and stripe's mox both end up installed,
which is the honest answer for a project that has both cartridges.

What stays closed is the **collection**, and deliberately:
chiefs_setup's rule is that its argv names "the flags that tell a
member which *fellow picks* ride along, never a member option surfaced
as the collection's". So chiefs_setup picks `test_doubles` bare and the
project gets mimic; a chief who wants Mox asks for it by hand. That is
the same limit recorded against versioning's `--mix-task`, and it is a
rule rather than a gap.

### 3.7 What the box takes back from enhancements

`mock_helper.eex` stops being enhancements'. The clauses are
redistributed to the cartridges whose modules they falsify — the
`HTTPoison`/`Auth0Jwks` ones to auth0, the `Finch` ones to openai —
each writing its own block into the shared helper through the tool of
§3.4. enhancements keeps nothing of them. This is the same correction
as rest's `--health`, and the two should be judged together.

### 3.8 What is deliberately absent

* **Factories and fixtures.** A double removes a collaborator; a
  factory builds data. They are different needs, and more decisively
  they are on different *lines*: Mox and Mimic serve both the Phoenix
  and the Ash project, while ExMachina makes Ecto structs and Ash has
  `Ash.Generator`. A member that is dead on half the shelf would make
  the box's line unstatable just as the catalog is about to state it.
  exmachina stays a box of its own; fixtures `phx.gen` already writes,
  and the workbench does not plant over generated code.
* **coveralls.** Coverage says where the tests are not looking; that is
  not "do not call the real thing". It also carries HTML report themes,
  `mix cover`, `coveralls.json` and a console door, so it would swallow
  its host rather than be absorbed. It stays in pin, gaining the git
  hook, as the author's selection has it.
* **A collection.** If the three ever want to be inserted together,
  that is a collection of the Phoenix line — doubles, exmachina,
  coveralls — and costs no boundary.

## 4. Evaluation

### 4.1 Unit tests (2026-09-20)

Ten of the cartridge's own, and the catalog's two: the default install
is mimic and nothing else; `--double mox` is Mox and `--double mox
--type-check` is Hammox; `mimic,mox` installs both, and so does a
second run asking for the other; a re-run with the same double is
`assert_unchanged`; a value that is not one of the two refuses the run
with what it got. Of the way in: two cartridges' blocks stand above
`ExUnit.start()`, each its own; a module registered twice is written
once and a new one grows the block; `--type-check` reaches every copy
and turns `defmock` into Hammox's; `forget/2` leaves the other
cartridge's block untouched; a project with no test helper gets one.
The shared-file tool underneath has thirteen of its own, including the
seam a dropped block leaves and the half-deleted block that raises
naming file and owner.

The catalog run inserts it with `--double mox --type-check` — neither
value a default — and reads `%{double: ["mox"], type_check: true}` back
off the project.

### 4.2 Not measured

The installer exists; the migration does not. What this paper commits
to measuring when it happens, in the form db_admin's §4 takes:

* The eight files of §1.2 rewritten on Mimic, with `async: true`
  restored where `mock` forbade it, and the suite green on the pinned
  toolchain.
* The same suite on an OTP 29 image, which is the claim `mock` cannot
  make (§1.3).
* `Mimic.copy/1` declared for `File` and `System` and the suite run
  whole, to confirm that a copied stdlib module left unstubbed is the
  module — "calling `copy/1` will not change the behaviour of the
  module" [4] is the library's word, and a report that mounts it for
  every test is where it would show if it were not.
* One cartridge converted the other way, Mox with a real behaviour
  (openai's client is the candidate: one `@callback`, one config line),
  to measure what the redesign actually costs per cartridge.
* `--type-check` on both values against a deliberately wrong stub,
  to confirm each side raises.

## 5. Limitations and open questions

* **The default couples tests to third parties.** §3.2 accepts
  knowingly what §2.2 argues against. The honest position is that the
  default is the *migration*, not the destination: every cartridge that
  grows a real boundary should move to Mox, and the box should make
  that the easy step rather than the ideological one.
* **Which cartridges should grow a boundary** is not decided here.
  openai and auth0 are the candidates; healthcheck's `System.cmd` and
  `Repo.query` probably are not, since what they simulate is the
  platform failing.
* **Neither precondition is left.** `WorkbenchIgniter.BlockFile`
  landed on 2026-09-19, before this installer and before credo's and
  coveralls' git hook, which is the other step that owed it; and the
  composed switch turned out to be available already (§3.6). What is
  left is the migration itself, cartridge by cartridge.
* **Mimic's local-call caveat** [5] is invisible today and will not be
  once a cartridge doubles its own module; whether the generated code
  should be written in fully qualified calls as a matter of course is
  open.
* **`mock` is not deleted from the world.** Projects generated before
  this box have it. Whether the workbench offers a migration — rewriting
  `with_mock` call sites — or simply stops shipping it is open; the
  second is what the shelf has done with retired boxes until now.
* **Hammox's version.** 1.0.0 (2026-07-24) requires `mox ~> 1.2` [12]
  and Mox is at 1.3.2; the pin holds today and is a thing to watch,
  since a Mox major would strand the `--type-check` path.

## References

Read on 2026-09-19. Hex figures are from the JSON API
(`hex.pm/api/packages/<name>` and `.../releases/<version>`) on that
date.

1. Martin Fowler, *TestDouble* (bliki); the five kinds are Gerard
   Meszaros'. <https://martinfowler.com/bliki/TestDouble.html>
2. José Valim, *Mocks and explicit contracts*, 2015-10-14.
   <https://dashbit.co/blog/mocks-and-explicit-contracts>
3. *Mox* — module documentation: the four rules, `defmock/2`,
   `expect/4`, `stub/3`, `verify_on_exit!/1`, `allow/3`,
   `set_mox_global`, `set_mox_private`. <https://hexdocs.pm/mox/Mox.html>
4. *Mimic* — module documentation: the copying mechanism, `copy/1,2`
   and its `type_check` option, `stub/3`, `expect/4`, `reject/1`,
   private and global mode. <https://hexdocs.pm/mimic/Mimic.html>
5. edgurgel/mimic, *README.md*: the lineage, setup,
   `:set_mimic_from_context`, and the local-call caveat.
   <https://github.com/edgurgel/mimic>
6. *Hammox* — module documentation: contract testing, its relation to
   Mox, `protect/2,3`, `Hammox.TypeMatchError`.
   <https://hexdocs.pm/hammox/Hammox.html>
7. Hex, packages *mock*, *mox*, *mimic*, *hammox*, *ex_machina*:
   versions, dates, downloads, licences. <https://hex.pm/packages/mock>
8. Hex, package *meck*, release list: 0.9.2 (2021-03-06), 1.0.0
   (2024-12-13), 1.1.0 (2025-10-12), 1.1.1 (2026-03-30), 1.2.0
   (2026-05-27). <https://hex.pm/packages/meck>
9. Apache Thrift, THRIFT-6186, *lib/erl eunit tests cannot run on OTP
   29: the pinned meck 0.9.2 does not compile*.
10. saleyn/erlexec, issue #204, *exec_util.erl fails to compile on
    Erlang/OTP 29 — deprecated prefix catch + warnings_as_errors*.
    <https://github.com/saleyn/erlexec/issues/204>
11. silviucpp/erlkaf, issue #87, *Build fails on Erlang/OTP 29*.
    <https://github.com/silviucpp/erlkaf/issues/87>
12. Hex, release requirements: `mock 0.3.9` → `meck ~> 0.9.2`;
    `mox 1.3.2` → `nimble_ownership ~> 1.0`; `mimic 2.4.2` → `ham ~> 0.3`;
    `hammox 1.0.0` → `mox ~> 1.2`, `ordinal ~> 0.1`, `telemetry ~> 1.0`.
13. *Req.Test* — module documentation: `stub/2`, `plug: {Req.Test, name}`,
    the nimble_ownership model, `allow/3`.
    <https://hexdocs.pm/req/Req.Test.html>

Consulted in the workbench, not sources: `features/mock/` (`mock.ex`,
`README.md`, `NEED.md`), the eight generated files of §1.2,
`enhancements/templates/mock_helper.eex`, `config.conf`, `SCRIPT.md`
and `RELEASE_PLAN.md` Phase 2.
