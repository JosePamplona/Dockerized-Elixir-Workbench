# Cartridge: exdebug

A look at what is passing through a pipeline, framed and labelled,
that the code can keep: it prints in `:dev` and `:test` and says
nothing anywhere else.

* **Task**: `mix workbench.install.exdebug`
* **Inserted by**: `wb.sh add exdebug`
* **Options**: none.

## Description

[ExDebug](https://hexdocs.pm/ex_debug) is a one-function library:
`ExDebug.console/2` goes anywhere in a pipeline, prints the value
passing at that point, and returns it untouched.

```elixir
"Lorem-Ipsum"
|> String.split("-")
|> ExDebug.console(label: "Split return")
|> Enum.join()
|> String.downcase()
# Split return -------------------------------------- 2026-09-20 - 22:46:53.783336
# ["Lorem", "Ipsum"]
# ------------------------------------------------------------------- MyApp v0.1.0
"loremipsum"   # the pipeline's own return, unchanged
```

The frame is the point. A header with your label and the time the call
ran, the term pretty-printed with syntax colours at a fixed width, and
a footer naming the application and its version — so a print that
scrolls past in a busy shell still says *which* value, from *which*
app, and *when*. The stamp is UTC.

The second thing is where the call may stay. `IO.inspect/2` and
`dbg/1` print in every environment, which is why they are written,
read and deleted; `console/2` prints in `:dev` and `:test` only, and
in `:prod` passes the value straight through. A probe left in the code
costs a function call in production and nothing else — and the next
person to wonder about that pipeline has the probe already there.

`dbg/1`, which ships with Elixir, is the better tool for stepping
through a pipeline the first time: it prints *every* step with its
source line. This one is for watching one point, repeatedly, in code
that stays. `DESIGN.md` sets the three side by side.

The library is small (171 lines) and is the workbench author's own —
`DESIGN.md` says so plainly, along with what that is worth.

## What it installs

* Dep `{:ex_debug, "~> 1.0"}` — in every environment, no `only:`. The
  guard is inside `console/2`, not at the call site, so a call left in
  a pipeline has to compile in `:prod` as well.

Nothing else: no configuration file, no generated module. The five
formatting keys (`width`, `color`, `line_color`, `time_color`,
`syntax_colors`) already default inside the library and are accepted
per call; a project that wants other defaults writes its own
`config :ex_debug` block.

**Idempotency**: `on_exists: :skip` — re-running it is a no-op.

## The mark

The dependency itself: `ex_debug` in the project's deps is what
`installed?/1` reads, the same mark the installer's guard reads. The
cartridge has no options, so it has no state.

## Running it in a release

The print is skipped when `MIX_ENV` is set to anything but `dev` or
`test` — read from the environment at run time, and falling back to
`dev` when it is unset. The runner stage of the Dockerfile
`phx.gen.release` writes sets `MIX_ENV="prod"`, so a release built the
workbench's way is silent. A release started some other way *without*
that variable takes the print path and raises, because the footer asks
`Mix.Project.config()` for the app's version and a release does not
carry Mix. `DESIGN.md` has the run.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/exdebug/` | The cartridge: its code and its papers |
| `├── 📄 exdebug.ex` | The dependency, and the mark |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | The three inspectors, and where a call may stay |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 exdebug_test.exs` | The dep lands; a second run changes nothing |
