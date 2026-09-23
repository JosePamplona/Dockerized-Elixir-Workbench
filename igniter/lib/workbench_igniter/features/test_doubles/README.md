# Cartridge: test_doubles

What a test puts in the place of the real thing — so the suite never
reaches the network, the disk or a service you do not control.

* **Task**: `mix workbench.install.test_doubles`
* **Inserted by**: `wb.sh add test_doubles`

## Description

A *test double* is anything that stands in for a production object
while a test runs. The term is Gerard Meszaros', and it exists because
"mock" had come to mean five different things: a **dummy** that only
fills a parameter list, a **fake** with a working but simplified
implementation, a **stub** that gives canned answers, a **spy** that
also records how it was called, and a **mock** proper, which is
pre-programmed with the calls it expects and fails when they do not
come.

Elixir has two maintained libraries for this, and the choice between
them is not a preference. It is a question about **whose module is
being replaced**:

| `--double` | What it does | Reach |
| --- | --- | --- |
| `mimic` | [Mimic](https://github.com/edgurgel/mimic) copies the module out of the way and answers in its place | any module — `File`, `System`, an HTTP client, a repo made to raise |
| `mox` | [Mox](https://hexdocs.pm/mox) builds a *new* module against a behaviour you declare | only what you own a contract with |

Mox's first rule is "No ad-hoc mocks. You can only create mocks based
on behaviours": it never touches an existing module, so the code under
test has to ask its configuration whom to call. That is the point —
the boundary becomes explicit, and the suite stays concurrent. What it
cannot do is reach `File` or `Finch`, because there is no behaviour of
yours there to stand on.

Mimic reaches anything and asks nothing of the code. The price is that
a test then stands on somebody else's API: change the HTTP client and
tests break whose application behaviour did not.

So: **Mox for the service you own a contract with, Mimic for the
module you did not write.** Both together is a normal answer, and a
second run adds the other.

Without `--double` you get **mimic**, because that is what the shelf's
own generated tests need without redesigning the code they test
(`DESIGN.md` §3.2).

### Checking the doubles against the typespecs

`--type-check` validates arguments and return values at run time. One
switch, two implementations: [Hammox](https://hexdocs.pm/hammox) in
place of Mox — it wraps Mox and raises `Hammox.TypeMatchError` — and
`type_check: true` on every `Mimic.copy/2`. Off by default: on the Mox
side it only pays in a project that writes `@spec`s, and on the Mimic
side it validates against a third party's typespecs, which may be
looser than the test wants.

Mimic has no setting of its own for it, so on that side the copies are
where the project keeps the switch: `--type-check` types every copy
the test helper already carries, and the copies written after follow
them. With no copy yet and no Hammox, there is nowhere to keep it, and
the run says so; run it again once the copies are there.

## What it installs

* `{:mimic, "~> 2.0", only: :test}` with `--double mimic` (the default).
* `{:mox, "~> 1.2", only: :test}` with `--double mox`, or
  `{:hammox, "~> 1.0", only: :test}` when `--type-check` is on — Hammox
  depends on Mox, so Mox is in either way.

Nothing else, by itself. The wiring is written by the cartridges whose
tests use it, through the two functions below.

**Idempotency**: `on_exists: :skip`. A second run with another
`--double` adds it and leaves what is there (`rerun: :adds`).

## The way in, for other cartridges

This is what the box has that `mock` did not. A cartridge whose
generated tests need a double registers it, and owns its own block of
`test/test_helper.exs` — written through
`WorkbenchIgniter.BlockFile`, above `ExUnit.start()`:

```elixir
alias WorkbenchIgniter.Features.TestDoubles

igniter
|> TestDoubles.copy("health_endpoint", ["MyApp.Repo", "System"],
     note: "what its controller test makes raise")
|> TestDoubles.defmock("openai", [{"MyApp.OpenAI.Mock", "MyApp.OpenAI.Client"}])
```

gives

```elixir
# >>> health_endpoint — what its controller test makes raise
Mimic.copy(MyApp.Repo)
Mimic.copy(System)
# <<< health_endpoint

# >>> openai
Mox.defmock(MyApp.OpenAI.Mock, for: MyApp.OpenAI.Client)
# <<< openai

ExUnit.start()
```

* A line already registered is not written twice; a new one grows the
  block.
* `TestDoubles.forget(igniter, "openai")` takes one cartridge's block
  away and leaves every other's — what an eject owes.
* With `--type-check` in, each copy asks for it and `defmock` is
  Hammox's.

`Mimic.copy/1` on its own changes nothing: a copied module that no test
stubs runs as itself. The behaviour a `defmock` names, and the
`config/test.exs` line that injects it, are the calling cartridge's own
— Mox replaces nothing, so the code has to ask.

## Options

| Option | What it does |
| --- | --- |
| `--double mimic,mox` | The libraries to install, one or several. Default: `mimic`. |
| `--type-check` | Hammox in place of Mox; `type_check: true` on every Mimic copy. Default: off. |

## The mark

The dependency: `mimic`, `mox` or `hammox` in the project's deps. The
state says which doubles the project carries and whether they are
type-checked — Hammox, or a copy asking for it in the test helper. The
blocks of `test_helper.exs` are never read for this: a sentinel is an
editing boundary, not a record the project keeps for the workbench.

## Relation to `mock`

`mock` is the box this one takes over from: a dependency and nothing
else, on a library whose last release is 2024-12-16 and whose pin
(`meck ~> 0.9.2`) locks out the meck that compiles on OTP 29. The eight
generated test files that `import Mock` move one cartridge at a time
(health_endpoint, coverage, enhancements, auth0, openai), and `mock` stays
on the shelf until the last of them has.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/test_doubles/` | The cartridge: its code and its papers |
| `├── 📄 test_doubles.ex` | The two doubles, the mark, and the way in |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | The two libraries against their sources |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 test_doubles_test.exs` | The doubles, and each cartridge's block |

The shared-file tool it writes through is the workbench's, not the
cartridge's: `WorkbenchIgniter.BlockFile`
(`lib/workbench_igniter/block_file.ex`, tested in
`test/workbench_igniter/block_file_test.exs`).
