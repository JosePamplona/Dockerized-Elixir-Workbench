# gettext

Phoenix's gettext for a project generated with `--no-gettext`.

[Gettext](https://hexdocs.pm/gettext/Gettext.html) is Elixir's
"gettext-based API for working with internationalized applications":
a backend module (`MyAppWeb.Gettext`), `use Gettext, backend:` in the
modules that translate, messages in `priv/gettext/<locale>/LC_MESSAGES/<domain>.po`,
and `mix gettext.extract` / `gettext.merge` to keep them in step with
the code. `phx.new` writes the backend, the `en` locale with the
`errors` domain, and wraps every string of its components and layouts
in `gettext/1` — unless told `--no-gettext`, in which case it writes
the same strings bare.

Base cartridge. Install it on demand with

```sh
./wb.sh add gettext
mix workbench.install.gettext
```

## What it installs

Whatever `phx.new` generates for gettext at the installer's version in
the toolchain — asked of `phx.new` itself (`WorkbenchIgniter.PhxDelta`,
see [mailer](../mailer/) for the mechanism). With Phoenix 1.8.12: the
`gettext` dependency, `MyAppWeb.Gettext` (the backend),
`priv/gettext/` with `errors.pot` and the `en` locale, and the lines
that use it in `core_components.ex`, the error views and the
`.formatter.exs` import. Files the project already changed are merged
three ways; a conflict is reported with `phx.new`'s version of the file
beside it.

## Options

None. `phx.new` has none for it.

The components come out gettext-aware when the project has them (html
in) and untouched when it does not; html inserted afterwards brings
gettext-aware components of its own, since the delta reads the project
as it is.

Order does not matter: inserted before [ecto](../ecto/), the `.pot`
gains the changeset messages when ecto comes in; after it, the `.pot`
is created with them.

## Idempotency

Re-running is a no-op: when `gettext` is a dependency — a default
project carries it — nothing is touched and a notice says so.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/gettext/` | The cartridge: its code and its papers |
| `├── 📄 gettext.ex` | The mark and the `--no-gettext` delta |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why it is shaped so; the engine: mailer's |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 gettext_test.exs` | The mark, the delta on a project |
