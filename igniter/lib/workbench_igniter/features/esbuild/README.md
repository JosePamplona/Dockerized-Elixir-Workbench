# esbuild

Phoenix's esbuild for a project generated with `--no-esbuild`.

"From Phoenix v1.7, new applications use esbuild to prepare assets via
the Elixir esbuild wrapper" ([asset management](https://hexdocs.pm/phoenix/asset_management.html)):
the [esbuild](https://hexdocs.pm/esbuild/) package downloads the
binary and runs it from a profile in `config.exs`, a watcher rebuilds
`assets/js/app.js` in development, and `mix assets.setup`,
`assets.build` and `assets.deploy` drive it. `mix help phx.new` on the
flag: "We do not recommend setting this option, unless for API only
applications, as doing so requires you to manually add and track
JavaScript dependencies".

Base cartridge. Install it on demand with

```sh
./wb.sh add esbuild
mix workbench.install.esbuild
```

## What it installs

Whatever `phx.new` generates for it at the installer's version in the
toolchain — asked of `phx.new` itself (`WorkbenchIgniter.PhxDelta`, see
[mailer](../mailer/) for the mechanism). With Phoenix 1.8.12: `{:esbuild, "~> 0.10"}`, `config :esbuild` (the
version and the `test` profile: entry `js/app.js`, bundled to
`priv/static/assets/js`), the esbuild watcher in `dev.exs`, `esbuild
test` in the `assets.setup`/`assets.build`/`assets.deploy` aliases,
`assets/js/app.js`, `assets/tsconfig.json` and `assets/vendor/topbar.js`
(without esbuild, phx.new serves a plain script instead), and the
`phx-click` JS hooks the core components and layouts carry only with a
bundler. And, when the project had no `assets/` directory before, the
assets steps of the production `Dockerfile` (`mix assets.setup`, `COPY
assets`, `mix assets.deploy`) that `phx.gen.release --docker` writes at
birth only for a project that has one.

Files the project already changed are merged three ways; a conflict is
reported with `phx.new`'s version of the file beside it.

What goes: `--no-esbuild` put a placeholder `priv/static/assets/js/app.js`
in the project (a comment naming the scripts to bundle by hand). The
insert takes it away when it is still that comment; a file the project
rewrote there is the project's and stays — until the first
`mix assets.build` writes the bundle over it. `.gitignore` ignores the
path from the insert on.

## Options

None. `phx.new` has none for it.

## Idempotency

Re-running is a no-op: when the `esbuild` dependency is there — a default project carries
it — nothing is touched and a notice says so.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/esbuild/` | The cartridge: its code and its papers |
| `├── 📄 esbuild.ex` | The mark and the `--no-esbuild` delta |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why it is shaped so; the engine: mailer's |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 base_cartridges_test.exs` | Shared with the other base cartridges |
