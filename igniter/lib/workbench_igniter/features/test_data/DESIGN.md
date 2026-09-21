# test_data — Design

*Revision: cartridge v0.1.0 (2026-09-20), written before the code, as
versioning's was. It replaces [exmachina](#7-what-it-replaces), a
dep-only cartridge. Sources consulted on 2026-09-20; quotations are
verbatim from the page or file as read then, and the hex figures are the
API's (`hex.pm/api/packages/<name>`) on that date. Versions as read:
ex_machina 2.8.2 (2026-08-02), faker 0.19.0 (2026-06-28), ash 3.33.8,
smokestack 0.9.2 (2025-01-30), stream_data 1.x.*

## Abstract

A test needs records — a user, the order that belongs to them — and
most of each record is not what the test is about. Written by hand in
every test they bury the one value that matters under the ones that do
not (Meszaros' *Irrelevant Information*); moved into a shared setup
they hide it instead (*Mystery Guest*). The answer every ecosystem
converged on is a builder with valid defaults and per-test overrides:
Pryce's Test Data Builder, which in Elixir is ExMachina's
`build(:user, name: "Ana")`. The shelf carried that as `exmachina`, a
four-line box that added the dependency and left the reader to find out
the rest: the factory module, where it goes, the line its README asks
for in the test helper, and the one trap everybody meets — ExMachina
writes with `Repo.insert!` and never runs the schema's changeset.

This paper makes the box the **need** and names it for it, `test_data`
— the sibling of `test_doubles`, which replaces a collaborator where
this one builds the data. It installs ExMachina with **Faker**, writes
the factory module with its rules in its own documentation, adds the
test that inserts every factory so a factory the database refuses fails
by name, and puts both libraries' test-helper lines where their READMEs
ask. And it reads the project's **line**: on an Ash project ExMachina is
wrong — it goes under the resource's actions, validations and policies
straight to the data layer — so there the same box writes an
`Ash.Generator` module, which runs the action, with Faker in it the way
Ash's own documentation uses it. One need, one box, shaped by what the
project is, as dashboard_extras is shaped by the database.

## 1. Problem

### 1.1 The box is four lines

`exmachina.ex` added `{:ex_machina, "~> 2.8", only: :test}` and
returned. Its NEED promised "`insert(:user)` with sensible defaults,
overridable", and nothing the box installed made that line work: there
was no `Factory` module to import, no line in `test_helper.exs`, and no
word about what a factory should and should not contain. What the box
knew about test data was its name.

### 1.2 What a reader meets on the first day

Four facts, all in the libraries' own papers, none in the old box:

1. **The changeset does not run.** ExMachina's maintainer, on the
   question: "ExMachina wraps the record in a changeset before
   inserting, but it's not the user defined changeset" [3]. A factory can
   produce a row the application would refuse, and only the database's
   constraints find out.
2. **`insert` saves the tree.** "ExMachina will automatically save any
   associations when you call any of the `insert` functions … we advise
   that factory definitions only use `build/2` when declaring
   associations" [1].
3. **Faker repeats itself.** Its data comes from finite lists; a unique
   index meets the birthday problem, and Faker has no unique helper —
   the request has been open since 2022 [6]. Ecto's sandbox documentation
   is explicit about what a repeated unique value costs a concurrent
   suite: the tests "will attempt to retrieve the same database lock,
   causing only one test to succeed and run while all other tests wait
   for the lock" [9].
4. **On Ash it is the wrong tool.** ExMachina.Ecto writes through the
   repo; an Ash resource's rules live in its actions. Ash's own
   direct-write tool warns about itself in the same words: "this bypasses
   resource actions, and goes straight to the data layer. No action
   changes or validations are run" [12].

### 1.3 The name

The box was named after the package. The two boxes before it in this
migration went the other way — `version_manager`, `db_admin` — because a
box is a need and the package is how this release answers it. Here the
answer is two packages on one line and a different one on the other, so
the package name is wrong three times.

## 2. Background

### 2.1 The patterns

* **Object Mother** (Fowler): "a kind of class used in testing to help
  create example objects". Its fault is the coupling: "many tests will
  depend on the exact data in the mothers" [15].
* **Test Data Builder** (Pryce, 2007), written as the answer to that: it
  "initialises its instance variables to commonly used or safe values"
  and has methods "for overriding the values", so "tests that don't care
  about the precise values … can create one in a single line" and "are
  isolated from those aspects of the objects' structure that have no
  bearing on the test" [16]. ExMachina's `build(:invoice, overrides)` is
  this pattern with the builder turned into data.
* **The smells a builder answers and the one it risks** (Meszaros): an
  *Obscure Test* is one where "it is difficult to understand the test at
  a glance"; *Irrelevant Information* — "a lot of irrelevant details
  about the fixture that distract the test reader" — is what a builder
  removes; *Mystery Guest* — "the test reader is not able to see the cause
  and effect between fixture and verification logic because part of it is
  done outside the Test Method" — is what a builder's hidden defaults can
  bring back [17]. The resolution both Pryce and factory_bot give is the
  same, and it is the box's first rule: **defaults minimal and valid;
  every value an assertion depends on is written in the test.**
  factory_bot says the first half verbatim: "one factory for each class
  that provides the simplest set of attributes necessary to create an
  instance of that class … only … attributes that are required through
  validations and that do not have defaults" [19].
* **Generated Value** (Meszaros): "one shouldn't use a Generated Value
  unless the value must be unique because of the non-determinism this may
  introduce" [18]. This is the honest argument against Faker, and §3.5 is
  the box's answer to it.
* **Four-Phase Test / Arrange–Act–Assert.** "Meszaros describes the
  pattern as Four-Phase Test. His four phases are Setup (Given), Exercise
  (When), Verify (Then) and Teardown" [20]. Factories live entirely in
  the first phase; a factory that asserts, or a test whose Arrange is a
  page long, has the phases mixed.

### 2.2 The standards, briefly

ISTQB defines test data as "Data needed for test execution" and its
preparation as "the activity to select data from existing databases or
create, generate, manipulate and edit data for testing" [21].
ISO/IEC/IEEE 29119-3 gives test data two documents of its own, *Test
Data Requirements* and a *Test Data Readiness Report* [22] — test data is
a specified artefact, not an afterthought. In a project this box serves,
**the factory module is that specification**: what a valid record is,
written once, and checked by the suite (§3.4). The test pyramid asks for
"lots of small and fast unit tests" [23], which is the case for `build`
(memory, no database) over `insert` wherever the database is not the
behaviour under test. And flakiness has a cost that is measured, not
argued: at Google "almost 16% of our tests have some level of flakiness"
and "about 84% of the transitions we observe from pass to fail involve a
flaky test", with "relying on non-deterministic or undefined behaviors"
among the causes [24] — random data and shared unique values are both
that.

### 2.3 ExMachina 2.8

A factory is a function `<name>_factory/0` in a module that
`use ExMachina.Ecto, repo: MyApp.Repo`; the README's advice is to "start
by creating one factory module (such as `MyApp.Factory`) in
`test/support/factory.ex`" and to split it with `__using__` when it
grows [1]. The API is a family by where the result stops [2]:

| Call | Returns | Database |
| --- | --- | --- |
| `build/2`, `build_pair/2`, `build_list/3` | structs | no |
| `params_for/2`, `string_params_for/2` | a map, without metadata, primary key or `belongs_to` | no |
| `params_with_assocs/2` | a map, its `belongs_to` inserted | the parents |
| `insert/2,3`, `insert_pair/2`, `insert_list/3` | structs, through `Repo.insert!/2` | yes |

`sequence/2` gives a value unique within the run, from one VM-global
agent. Lazy attributes — `fn -> build(:user) end`, or `fn account -> …
end` to see the parent — keep `build_pair` from sharing one child
between two parents [1]. The README asks for one line in the test
helper, "before ExUnit.start": `{:ok, _} =
Application.ensure_all_started(:ex_machina)` [1]. The README never
mentions Faker.

### 2.4 Faker 0.19

A pure-Elixir port of the Ruby gem's idea: `Faker.Person.name()`,
`Faker.Internet.email()`, `Faker.Address.city()`. Its README asks for
`Faker.start()` in the test helper [5]. Every draw goes through `:rand`
except `random_bytes/1` [5], and ExUnit reseeds `:rand` in each test
process from `--seed`, the module and the test's name: "This provides
randomness between tests, but predictable and reproducible results" [8].
So a Faker value drawn inside a test **repeats under `mix test --seed
N`** — not one drawn in another process, not `random_bytes`, and not an
ExMachina sequence number, which depends on the order the suite ran in.
The maintainer declined to tie Faker to ExUnit any further: "Faker is
already deterministic with stdlib … If you want predictability I would
suggest putting those values in the test itself" [7]. The `:es` locale
covers four modules — Address, Color, Internet, Person — and every other
one silently answers in English [5].

### 2.5 Ash.Generator

"Tools for generating input to Ash resource actions and for generating
seed data" [10]: a module that `use Ash.Generator` and defines functions
returning `changeset_generator(resource, action, opts)` — which *runs the
action* when `generate/1` takes a value from it — or `seed_generator/2`,
which "bypasses the action and saves directly to the data layer" [10].
`once/2` makes a parent a single time per test. The generators are
StreamData underneath and feed `ExUnitProperties` as they are; stream_data
is a runtime dependency of ash, so it is already there [10][11]. Ash's
usage rules say it without hedging: "Test your domain actions through the
code interface" and "Write generators using `Ash.Generator`" [13]. Its
own examples use Faker lazily, `StreamData.repeatedly(fn ->
Faker.Lorem.paragraph() end)` [10]. `Ash.Generator.sequence/3` is unique
"within the same test" only, and its warning names the alternative for a
database constraint: `System.unique_integer([:positive])` [10].

Smokestack, the Ash factory library, has been disowned by its author:
"I no longer think it's the correct approach for test factories … you
should probably use a combination of `Ash.Generator` and `Ash.Seed`" [14].

### 2.6 Factories and Phoenix's fixtures

`phx.gen.context` writes `test/support/fixtures/<context>_fixtures.ex`,
functions that create through the context — valid by construction,
slower, with the context's side effects. Ecto's own guide builds a
factory in thirty lines and notes that "we can implement such
functionality without relying on third-party projects" [4]. Valim, asked
where fixtures end and factories begin: "In practice we could call all of
them fixtures, but in one way or the other, I don't see a large
difference" [25]. Both are endorsed; neither replaces the other.

## 3. Design

### 3.1 One box, shaped by the line

![The four ways a test record reaches the database, and what each one runs on the way](../../../../../assets/diagrams/test_data/four-roads.svg)

The installer reads the project and takes one of two shapes, the way
dashboard_extras reads the database:

| The project has | It writes | Factory module |
| --- | --- | --- |
| `ash` in its deps | faker; `test/support/generator.ex`, `use Ash.Generator` | `<App>.Generator` |
| `ecto_sql` in its deps, no `ash` | ex_machina and faker; `test/support/factory.ex`, `use ExMachina.Ecto, repo: <App>.Repo`; `test/<app>/factory_test.exs` | `<App>.Factory` |
| neither | nothing: it refuses, naming ecto | — |

Ash first, because an Ash project on Postgres also carries a repo — the
repo is not what decides, the rules' home is. The refusal names ecto and
not ash because ecto is the one a Phoenix project inserts
(`./wb.sh add ecto`); an Ash project never reaches it. There is no
`requires/0`: the catalog's requirement is a conjunction, and this box
builds on one *or* the other.

The rejected alternative is the one the old shelf implied: an exmachina
box for the Phoenix line and nothing for Ash. The reference project is
on Ash, and its script's row 15 — "every policy example in `REGLAS.md` is
a test" — needs records made *through* the policies, which is exactly
what the Ash shape gives and ExMachina cannot.

### 3.2 The dependencies

`{:ex_machina, "~> 2.8", only: :test}` and `{:faker, "~> 0.19", only:
:test}`, the declarations of both READMEs [1][5]. Faker on both lines:
realistic values are the same need on both, and on Ash they go inside a
generator rather than a factory. No locale: `:es` would translate four
modules and leave the rest in English without a word [5], and a project
that wants it writes `config :faker, :locale, :es` in `config/test.exs`
— one line the README gives.

### 3.3 The test helper, as the READMEs ask

One block of `test/test_helper.exs` (`WorkbenchIgniter.BlockFile`),
before `ExUnit.start()`:

```elixir
# >>> test_data — its libraries, started as their READMEs ask
{:ok, _} = Application.ensure_all_started(:ex_machina)
Faker.start()
# <<< test_data
```

Under a plain `mix test` both lines are redundant: Mix starts every
dependency application before it requires the helper [8]. They are
written anyway, because a box installs a tool as its author wrote it,
and because they are not redundant under `mix test --no-start`, where
`sequence/2` would fail for want of its agent. Faker's README shows its
line *after* `ExUnit.start()`; it only starts an application, so it
stands in the same block, where the eject finds it. On Ash the block is
`Faker.start()` alone: Ash asks for no helper line [11].

### 3.4 The factory module, and the test that keeps it honest

`test/support/factory.ex` is the module, empty of factories — the box
cannot know the project's schemas, and a factory for a schema that is
not there would not compile. What it carries is the rules, in its own
`@moduledoc`, where the next person to add a factory reads them, and one
commented factory that shows each rule once:

```elixir
# def user_factory do
#   %MyApp.Accounts.User{
#     email: sequence(:email, &"user#{&1}@example.com"),
#     name: Faker.Person.name()
#   }
# end
```

The rules are four, each from §1.2 or §2.1:

1. **Minimal and valid.** Defaults are what a valid record needs; a value
   an assertion depends on is an override in the test [16][19].
2. **Unique by sequence.** A unique column is `sequence/2`, never Faker —
   the sandbox's lock and the 2–3× the dynamic values bought a suite [9].
3. **Associations by `build`.** `insert` saves the tree once, at the end
   [1].
4. **Faker for what nobody asserts.** It is decoration, and it repeats
   under `--seed` (§3.5).

`test/<app>/factory_test.exs` closes the changeset gap as far as a
generic test can. It finds every `*_factory/0` of the module — the
maintainer's own suggestion, "iterate over the functions and get all the
functions with 0 arity that end with `_factory`" [3] — and inserts each
one inside the sandbox, so a `NOT NULL`, a foreign key or a unique index
the factory breaks fails *by the factory's name*, not in whichever test
used it first. A factory for something that is not a table (a map, an
embedded schema) is built, not inserted. It does not run the schema's
changeset: the name of that function is a convention, not a contract, so
a generic test cannot call it. The per-schema form — `assert
User.changeset(%User{}, params_for(:user)).valid?` [3] — is in the
module's documentation, for the project to write where it counts. With
no factories the module has no tests and passes; it grows with the
factory.

The file uses `<App>.DataCase`, which `phx.new` writes with ecto; a
project without one gets `ExUnit.Case` and builds only.

### 3.5 Faker, and the argument against it

Meszaros' rule stands — a generated value is non-determinism, and "one
shouldn't use a Generated Value unless the value must be unique" [18] —
and the box keeps it by what it *allows* Faker to do rather than by
leaving it out. Faker fills the values nobody asserts on; the value the
test is about is a literal in the test; a unique one is a sequence. What
is left for Faker is the kind of surprise its maintainer says it is for —
a user named O'Hare whose apostrophe the template escaped [7] — and a
failure it finds repeats with the seed ExUnit prints. The principled form
of random data is a property with shrinking, StreamData's `check all`
[26]; Faker is not that and does not pretend to be. On Ash, where the
generators *are* StreamData, the two meet: `StreamData.repeatedly(fn ->
Faker.Person.name() end)` [10].

### 3.6 The Ash shape

`test/support/generator.ex`, `<App>.Generator`, `use Ash.Generator` —
Tunez, the reference application of the Ash book, puts it there under
that name [11] — with its rules in the `@moduledoc` and one commented
generator:

```elixir
# def user(opts \\ []) do
#   changeset_generator(MyApp.Accounts.User, :register,
#     defaults: [
#       email: "user#{System.unique_integer([:positive])}@example.com",
#       name: StreamData.repeatedly(fn -> Faker.Person.name() end)
#     ],
#     overrides: opts
#   )
# end
```

`changeset_generator` by default, because it runs the action; the
moduledoc names `seed_generator` for the state no action reaches. A
unique value is `System.unique_integer/1`, as Ash's warning says, not
`sequence/3`, which is unique within one test only [10]. There is no
factory test: a generator that runs the action is checked by the action
every time it is used, which is the check ExMachina lacks.
`config :ash, :disable_async?, true` in `config/test.exs` is what Ash's
Testing guide asks for with AshPostgres; ash_postgres' own installer
writes it, so this box does not.

### 3.7 What it does not touch

The project's `*Fixtures` modules. They create through the context, which
is the other honest answer (§2.6), and a project will want both: the
fixture where the context's rules and side effects are part of the test,
the factory where they are not and the speed is. The box adds beside
them and never rewrites them.

`elixirc_paths`. `phx.new` writes `defp elixirc_paths(:test), do: ["lib",
"test/support"]`; every project the workbench makes has it. A project
that does not gets a notice saying the line, not an edit to its
`mix.exs`.

## 4. The marks

`installed?/1` is true when `faker` or `ex_machina` is in the deps — the
second so a project that took the old exmachina box reads as having this
one. `rerun: :adds`: each piece is guarded on its own (the dependency by
`on_exists: :skip`, a file by its existence, the block by `BlockFile`),
so a second run on such a project adds Faker, the module, the test and
the helper lines, and touches nothing it finds. No options, so no
`state/1`.

## 5. Options not taken

* **A factory per existing schema.** Igniter could find the schemas and
  write a factory for each from its fields. It would write defaults the
  project did not choose for fields that may not be required, against
  rule 1, and it would be a guess on a project with no schemas at all,
  which is every new one.
* **`--faker`.** An option needs a use case that holds, and "ExMachina
  without realistic values" is not one: a project that wants literals
  writes literals; Faker installed and unused costs nothing at runtime.
* **`--locale`.** Four modules of `:es` (§2.4).
* **Smokestack** on the Ash line: disowned by its author [14].
* **ExMachina on the Ash line with `Ash.Seed` inside the factory.** It
  works, and it is `seed_generator` spelled with a second library.
* **A custom Faker `random_module` seeded from ExUnit.** Declined
  upstream [7], and unnecessary: `:rand` is already reseeded per test
  (§2.4).
* **Resetting sequences in `setup`.** ExMachina documents
  `ExMachina.Sequence.reset/0` for that, and under `async: true` it makes
  two concurrent tests draw the same value, which is the lock of §1.2.

## 6. Evaluation

The cartridge's suite covers both shapes: the dependencies, the module,
the factory test, the helper block, the refusal on a project with
neither, and the second run on a project that carries only
`ex_machina`. The generated code is verified in a `phx.new` probe with
the cartridge inserted from a path dependency: a factory added to the
generated module, the factory test inserting it, and `mix test --seed`
repeating its Faker values.

## 7. What it replaces

`exmachina` v0.0.0, the dep-only box, is renamed rather than archived:
the need is the same, and a project that carries its dependency is
recognised by this one (§4). Its papers were three short files; this one
and the CHANGELOG say what changed.

## References

1. beam-community/ex_machina, *README.md* (main): installation, the
   test-helper line, `test/support/factory.ex`, sequences, lazy
   attributes, "Ecto Associations", splitting factories.
   <https://github.com/beam-community/ex_machina>
2. *ExMachina.Ecto* — `params_for/2` and the insert strategy.
   <https://hexdocs.pm/ex_machina/ExMachina.Ecto.html>
3. ex_machina issues #103 (the changeset), #97 (a factory lint as a
   test), #198 (changeset validity per factory).
   <https://github.com/beam-community/ex_machina/issues/103>,
   <https://github.com/beam-community/ex_machina/issues/97>,
   <https://github.com/beam-community/ex_machina/issues/198>
4. Ecto, *Test factories* (guide).
   <https://hexdocs.pm/ecto/test-factories.html>
5. elixirs/faker, *README.md*, `lib/faker.ex`, `lib/faker/random.ex`,
   and the per-locale files under `lib/faker/`.
   <https://github.com/elixirs/faker>
6. elixirs/faker, issue #479, unique values.
   <https://github.com/elixirs/faker/issues/479>
7. elixirs/faker, PR #634, *adds integration with ex_unit seed*, closed
   2026-06-28. <https://github.com/elixirs/faker/pull/634>
8. *ExUnit* — `configure/1`, `:seed`; Mix, `mix test` and
   `compile.app` (dependency applications started before the helper).
   <https://hexdocs.pm/ex_unit/ExUnit.html#configure/1>
9. *Ecto.Adapters.SQL.Sandbox* — "Database locks and deadlocks".
   <https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html>
10. *Ash.Generator*. <https://hexdocs.pm/ash/Ash.Generator.html>
11. Ash, *Testing* (topic); sevenseacat/tunez,
    `test/support/generator.ex`. <https://hexdocs.pm/ash/testing.html>,
    <https://github.com/sevenseacat/tunez>
12. *Ash.Seed*. <https://hexdocs.pm/ash/Ash.Seed.html>
13. ash-project/ash, `usage-rules/testing.md`.
    <https://github.com/ash-project/ash/blob/main/usage-rules/testing.md>
14. jimsynz/smokestack, *README.md*.
    <https://github.com/jimsynz/smokestack>
15. Martin Fowler, *ObjectMother* (bliki), 2006.
    <https://martinfowler.com/bliki/ObjectMother.html>
16. Nat Pryce, *Test Data Builders: an alternative to the Object Mother
    pattern*, 2007. <http://www.natpryce.com/articles/000714.html>
17. Gerard Meszaros, *xUnit Test Patterns*, "Obscure Test".
    <http://xunitpatterns.com/Obscure%20Test.html>
18. Gerard Meszaros, *xUnit Test Patterns*, "Generated Value".
    <http://xunitpatterns.com/Generated%20Value.html>
19. factory_bot, *Best practices*.
    <https://thoughtbot.github.io/factory_bot/defining/best-practices.html>
20. Martin Fowler, *GivenWhenThen* (bliki), 2013.
    <https://martinfowler.com/bliki/GivenWhenThen.html>
21. ISTQB Glossary v3.7, *test data*, *test data preparation*.
    <https://glossary.istqb.org/en_US/term/test-data-1-3>
22. ISO/IEC/IEEE 29119-3:2021, *Test documentation*.
    <https://www.iso.org/standard/79429.html>
23. Ham Vocke, *The Practical Test Pyramid*, 2018.
    <https://martinfowler.com/articles/practical-test-pyramid.html>
24. John Micco, *Flaky Tests at Google and How We Mitigate Them*, Google
    Testing Blog, 2016.
    <https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html>
25. elixir-ecto/ecto, PR #4441, José Valim on fixtures and factories.
    <https://github.com/elixir-ecto/ecto/pull/4441>
26. whatyouhide/stream_data, *README.md*.
    <https://github.com/whatyouhide/stream_data>
