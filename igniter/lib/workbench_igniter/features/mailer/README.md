# mailer

Phoenix's Swoosh mailer for a project generated with `--no-mailer`.

A mailer is how a Phoenix project sends mail: [Swoosh](https://hexdocs.pm/swoosh/Swoosh.html)
— "Compose, deliver and test your emails easily in Elixir" — behind a
`MyApp.Mailer` module, with the `Local` adapter and a mailbox page at
`/dev/mailbox` in development, the `Test` adapter in tests, and a real
adapter the project configures for production. `phx.new` writes all of
that unless told `--no-mailer`, and has no way to add it later.

The first **base** cartridge: a capability `phx.new` decides at
generation time, added after the fact. Install it on demand with

```sh
./wb.sh add mailer
mix workbench.install.mailer
```

## What it installs

Whatever `phx.new` generates for a mailer at the installer's version in
the toolchain — the cartridge does not know, on purpose. It asks
`phx.new` (`WorkbenchIgniter.PhxDelta`): the project is generated twice
by `phx.new`'s own generator on a scratch directory, with the project's
own flags and with the mailer on, and the difference is merged in. With Phoenix 1.8.12 that is:

| File | What comes in |
| --- | --- |
| `mix.exs` | `{:swoosh, "~> 1.16"}` and `{:req, "~> 0.5"}` |
| `lib/my_app/mailer.ex` | `MyApp.Mailer` (`use Swoosh.Mailer`) |
| `config/config.exs` | the `Swoosh.Adapters.Local` adapter and the api client off |
| `config/dev.exs` | the mailbox preview in the dev routes |
| `config/test.exs` | `Swoosh.Adapters.Test`, api client off |
| `config/prod.exs`, `config/runtime.exs` | the production adapter notes, `api_client: Swoosh.ApiClient.Req` |
| `lib/my_app_web/router.ex` | the dev-only scope with `forward "/mailbox", Plug.Swoosh.MailboxPreview` — the console's *mailbox* door |

Nothing in the endpoint: the mailer is one module, seven files of
configuration and one route.

Files the project already changed are merged three ways — the
project's edits stay, the mailer's lines come in; a conflict is
reported as an issue with git's markers in the file, never resolved
silently.

## Options

None. `phx.new` has none for it.

## Idempotency

Re-running is a no-op: when `swoosh` is a dependency — a project
generated *with* a mailer carries it — the installer touches nothing and
says so. That is also why the catalog shows the cartridge as inserted in
every default `phx.new` project: the mark is read off the project.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/mailer/` | The cartridge: its code and its papers |
| `├── 📄 mailer.ex` | The mark and the `--no-mailer` delta |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why the delta, and the engine behind it |
|  |  |
| `📁 test/workbench_igniter/` |  |
| `├── 📁 features/` |  |
| `│   └── 📄 mailer_test.exs` | The mark, the delta on a project |
| `└── 📄 phx_delta_test.exs` | The engine every base cartridge runs on |

No `priv/features/mailer/`: nothing of its own to write.

## Design

Why the delta and not a hand-written installer, why `git merge-file`
and not Igniter's patches, what the engine cannot do (delete a file,
take a delta with a `phx.new` of another version than the project's,
merge a hunk that sits right after one of the project's own edits),
and what was measured on a real project — in the
[design paper](DESIGN.md). The other seven base cartridges refer to
it for the engine and keep their own papers short.
