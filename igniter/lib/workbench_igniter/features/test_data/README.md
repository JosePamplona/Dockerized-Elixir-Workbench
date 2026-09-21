# Cartridge: test_data

Test records with valid defaults, the one value that matters written in
the test, and Faker for the rest.

* **Task**: `mix workbench.install.test_data`
* **Inserted by**: `wb.sh add test_data`

## Description

Most of a test record is not what the test is about. A user needs an
email to exist, but the test checks their name. Written by hand in every
test, the email buries the name. Hidden in a shared setup, the name goes
missing: the reader cannot see why the assertion holds. A **factory**
answers both. Valid defaults are written once, and the test overrides
only the value it is about:

```elixir
user = insert(:user, name: "Ana")
assert Greeting.for(user) == "Hola, Ana"
```

[ExMachina](https://github.com/beam-community/ex_machina) is that
factory for Ecto schemas, and [Faker](https://github.com/elixirs/faker)
fills the values nobody asserts on with realistic ones: names, cities,
sentences. On an [Ash](https://hexdocs.pm/ash/Ash.Generator.html)
project the same need has a different answer. `Ash.Generator` makes the
record *through the resource's action*, validations and policies
included, where ExMachina would write under them.

On the Ecto line each ExMachina call stops somewhere different, and a
test that does not need the database should not reach it:

| Call | Returns | Database |
| --- | --- | --- |
| `build(:user)`, `build_list(3, :user)` | structs | no |
| `params_for(:user)`, `string_params_for(:user)` | a map for a changeset or a controller, without `belongs_to` | no |
| `params_with_assocs(:user)` | the same map, its parents inserted | the parents |
| `insert(:user)`, `insert_list(3, :user)` | structs, through `Repo.insert!` | yes |

## What it installs

The box reads the project's line:

| The project has | It installs |
| --- | --- |
| Ecto, no Ash | `{:ex_machina, "~> 2.8", only: :test}`, `{:faker, "~> 0.19", only: :test}`; `test/support/factory.ex` (`<App>.Factory`); `test/<app>/factory_test.exs` |
| Ash | `{:faker, "~> 0.19", only: :test}`; `test/support/generator.ex` (`<App>.Generator`) |
| neither | nothing: refused, naming `./wb.sh add ecto` |

On both lines it adds the libraries' test-helper lines (Faker's alone on
Ash), as their READMEs
ask for them, in this cartridge's own block of `test/test_helper.exs`:

```elixir
# >>> test_data — its libraries, started as their READMEs ask
{:ok, _} = Application.ensure_all_started(:ex_machina)
Faker.start()
# <<< test_data
```

The factory module comes **without factories**. The box cannot know your
schemas, and a factory for a schema that is not there would not compile.
Instead it carries the four rules in its `@moduledoc`, where the next
person to add a factory will read them, and one commented factory that
shows each rule:

1. **Minimal and valid.** A default is only what a valid record needs.
   A value an assertion depends on is written in the test.
2. **Unique by sequence.** A unique column is `sequence/2`, never Faker.
   Faker repeats itself, and two concurrent tests inserting the same
   value wait on each other's lock.
3. **Associations by `build`.** `insert` saves the whole tree once, at
   the end.
4. **Faker for what nobody asserts.**

**The factory test.** ExMachina does not run your changeset.
`factory_test.exs` finds every `*_factory/0` and inserts it inside the
sandbox. A `NOT NULL`, a foreign key or a unique index that a factory
breaks then fails under that factory's name, not in whichever test
happened to use it first. It cannot call your changeset, because that
function's name is a convention and not a contract. The module doc shows
the per-schema line for that:
`assert User.changeset(%User{}, params_for(:user)).valid?`.

**On Ash** the generator module carries the same rules in Ash's terms.
`changeset_generator` runs the action; `seed_generator` is for a state
no action reaches. Unique values come from
`System.unique_integer([:positive])`, because `sequence/3` is unique
within one test only. Faker goes in lazily, as
`StreamData.repeatedly(fn -> Faker.Person.name() end)`. There is no
factory test on this line: a generator that runs the action is checked
by that action every time it is used.

**It leaves alone** the `*Fixtures` modules `phx.gen` writes. They create
through the context, which is the other honest answer. Use a fixture
where the context's rules and side effects belong in the test, and a
factory where they don't and speed matters.

**Idempotency**: `rerun: :adds`. Each piece is added when it is missing:
a dependency, a module (a factory module you already have is left as
it is, with a notice), the helper block. A project that took the old
`exmachina` box, which installed only the dependency, gets the rest on a
second run.

## Faker and the seed

A Faker value drawn inside a test repeats under `mix test --seed N`,
because ExUnit reseeds `:rand` for every test from the seed it prints.
So a failure Faker finds can be run again. Three things are exceptions:
`Faker.random_bytes/1` (it uses crypto), values drawn in another process,
and ExMachina's sequence numbers (they depend on the order the suite
ran in). No locale is set. `:es` covers Address, Color, Internet and
Person only and answers the rest in English. A project that wants it
adds `config :faker, :locale, :es` to `config/test.exs`.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/test_data/` | The cartridge: its code and its papers |
| `├── 📄 test_data.ex` | Manifest, the line it reads and the pieces it adds |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | The patterns, the sources, and why two shapes |
|  |  |
| `📁 priv/features/test_data/templates/` |  |
| `├── 📄 factory.eex` | `<App>.Factory`, its rules in its doc |
| `├── 📄 factory_test.eex` | The test that inserts every factory |
| `└── 📄 generator.eex` | `<App>.Generator`, `use Ash.Generator` |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 test_data_test.exs` | Both lines, the refusal, the second run |
