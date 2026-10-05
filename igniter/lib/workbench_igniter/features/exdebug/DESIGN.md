# DESIGN — exdebug

*Revision: cartridge v0.1.0 (2026-09-20). Sources read that day: the
hex API for `ex_debug` (1.0.0, published 2024-04-18, 1 784 downloads in
all, 136 in the last month), the library's README and its whole source
— `lib/debug.ex`, 171 lines, at `github.com/JosePamplona/ExDebug@main`
— and a probe project built here, whose runs are quoted verbatim under
Evaluation.*

## Abstract

The box installs one dependency and writes nothing, so its whole
argument is about *which* inspector a project keeps and **where its
calls are allowed to stay**. Elixir gives two answers already —
`IO.inspect/2`, which prints a bare term, and `dbg/1`, which prints the
whole pipeline with its source lines — and both print in every
environment, which is why the habit around them is to write the call,
read it, and delete it. `ExDebug.console/2` is the third: a framed
print at one point of a pipeline, labelled and timestamped, that
returns its input and goes silent outside `:dev` and `:test`, so the
call can be left where it is. This paper says what that silence rests
on (a runtime read of `MIX_ENV`, not a compile-time `Mix.env()`), what
it costs (the dependency cannot be `only: [:dev, :test]`, and a release
started without `MIX_ENV` raises), and why the box writes no
configuration.

## Problem

Looking at a value in the middle of a pipeline is the most common
debugging act there is, and the three ways to do it are not
interchangeable:

| | What it prints | Left in the code |
| --- | --- | --- |
| `IO.inspect(v, label: "x")` | the term, one line, no frame | prints in `:prod` too — so it is deleted |
| `v \|> dbg()` | *every* step of the pipeline with its source lines | prints in `:prod` too — and is loud when one point was wanted |
| `v \|> ExDebug.console(label: "x")` | one point, framed: label + UTC stamp, the term pretty-printed in colour, the app and its version | silent outside `:dev` and `:test` |

`dbg/1` (Elixir 1.14+) is the real alternative, and it is better at
what it does: stepping through a pipeline the first time, with the
source of each step beside its value. What it is not is quiet. When the
question is *what is passing through here, every time this runs*, the
whole pipeline is noise, and the print still has to come out before the
code ships.

The need the shelf is answering (`NEED.md`) is the other half: a value
looked at without dressing it up first, and without a cleanup pass
afterwards.

## Design

**One dependency, no `only:`.** `{:ex_debug, "~> 1.0"}`, exactly as the
library's own README writes it, available in every environment. This is
not laxity, it is the shape of the library: the environment check is
*inside* `console/2`, not at the call site, so a call left in a
pipeline has to compile in `:prod` — with `only: [:dev, :test]` the
production build would fail on the very calls the design exists to let
you keep. The box installs the tool as its author wrote it and
documents the consequence.

**What the silence rests on.** `console/2` prints when
`System.get_env("MIX_ENV")` is `"dev"` or `"test"`, read at *run* time,
with `"dev"` as the fallback when the variable is unset — not
`Mix.env()`, which would be fixed at compile time. For a project of
this workbench that is settled by the image: the runner stage of the
Dockerfile `phx.gen.release` writes carries `ENV MIX_ENV="prod"`
(line 95 of the template, read 2026-09-20), which is the workbench's
deploy path, so the no-op holds where the release actually runs. A
release started by hand without that variable falls back to `"dev"`,
takes the print path, and calls `Mix.Project.config()` for the footer —
a module a release does not carry. It raises. Verified below; recorded
under Limitations rather than patched, because patching it means
wrapping somebody's function in a shim the project would then have to
learn instead of the library.

**No configuration written.** The library reads five keys from
`config :ex_debug` — `width`, `color`, `line_color`, `time_color`,
`syntax_colors` — and `console/2` takes the same five per call. Every
one of them has its default *in the library* (`config/0`, lines
147–169: 80 columns, label 255, lines 238, time 247, and a syntax
palette). A generated block of those defaults would be a file the
project has to maintain that says exactly what the library already
says, and the first time upstream changes a default the project would
silently keep the old one. The project writes the block when it wants
another palette; the box does not open the question for it.

**No options.** With nothing written there is nothing for an option to
decide. `--config`, the only candidate, was rejected on the paragraph
above: it would exist to write a file whose content is already the
default. The script's crossing says the same in one line — exdebug, *as
it is*, row 15 (`SCRIPT.md`).

**Whose library this is.** `ex_debug` is the workbench author's own
(hex owner `josepamplona`; one release, 2024-04-18; 136 downloads in
the last month). The box says so here rather than letting the shelf
imply a community standard, and the claim it makes is sized
accordingly: 171 lines, read in full for this paper, doing one thing —
not a dependency a project takes on trust, one it can read in ten
minutes. The alternative for whoever would rather not take it is in the
table above and needs no box: `dbg/1` ships with Elixir.

## Evaluation

A probe project, `mix new probe --sup` on Elixir 1.19.5/OTP 27 with
`{:ex_debug, "~> 1.0"}` added and `mix deps.get` resolving 1.0.0, and
one call run in four places:

```elixir
out = "Lorem-Ipsum" |> String.split("-") |> ExDebug.console(label: "Split return")
      |> Enum.join() |> String.downcase()
IO.puts("returned: #{inspect(out)}")
```

* `mix run` — the frame printed, the header `Split return ----
  2026-09-20 - 22:46:53.783336`, the list in colour, the footer
  `------- Probe v0.1.0`, then `returned: "loremipsum"`. The stamp is
  **UTC** (`NaiveDateTime.utc_now/0`), which is 6 hours off the host's
  clock here.
* `MIX_ENV=prod mix run` — no frame, `returned: "loremipsum"`. The
  passthrough is the same value, not a copy of it.
* `MIX_ENV=prod mix release`, then
  `MIX_ENV=prod bin/probe eval 'ExDebug.console(:hello, label: "…")'` —
  silent, returns `:hello`.
* The same release with `env -u MIX_ENV` —
  `** (UndefinedFunctionError) function Mix.Project.config/0 is
  undefined (module Mix.Project is not available)`, from
  `ExDebug.footer/2`, `lib/debug.ex:127`.

The cartridge itself is covered by
`test/workbench_igniter/features/exdebug_test.exs`: the dep lands in
`mix.exs`, and a second run is `assert_unchanged`.

## Limitations

- **A release without `MIX_ENV` raises** at the first `console/2` call,
  as quoted above. The workbench's own image sets it; a project that
  runs its release some other way inherits the risk of whatever calls
  it left in. The box does not check the image, and could not: the
  Dockerfile is the project's.
- **The stamp is UTC**, with no option for the host's zone.
- **The colours are raw ANSI 256**, written to stdout whatever is
  reading it: a log collector that stores bytes stores the escape
  codes.
- **One release since 2024-04-18.** A library that stops moving is a
  small liability *in proportion to the calls left in the code*, which
  this design encourages. The exit is cheap — the calls are one
  function — but it is not free.
- Nothing here has been measured for cost: `console/2` formats and
  writes synchronously on the calling process, which is what
  `IO.inspect/2` does too, and is a reason not to leave one inside a
  hot loop.

## References

1. `ex_debug` on hex — `hex.pm/api/packages/ex_debug`, read
   2026-09-20: 1.0.0, 2024-04-18, MIT, owner `josepamplona`.
2. `lib/debug.ex` at `github.com/JosePamplona/ExDebug@main`, read in
   full 2026-09-20 — `console/2` (the `MIX_ENV` guard, line 42),
   `footer/2` (`Mix.Project.config()`, line 127), `config/0` (the
   defaults, lines 147–169).
3. `Kernel.dbg/2`, Elixir 1.14 — the alternative that ships with the
   language.
4. `deps/phoenix/priv/templates/phx.gen.release/Dockerfile.eex`, line
   95 — `ENV MIX_ENV="prod"` in the runner stage.
5. `SCRIPT.md` (the repository root), the author's selection (2026-09-18):
   exdebug, *as it is*, row 15.
