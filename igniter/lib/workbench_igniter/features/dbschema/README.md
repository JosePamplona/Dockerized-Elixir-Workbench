# dbschema

The database's own page in the project's documentation, drawn from
[DbSchema](https://dbschema.com): the model table by table, and the
entity-relationship diagram in the reader's theme.

DbSchema is a desktop tool. You open it on the project's database,
export the model over `assets/db_schema/` — a `database.dbs`, and per
theme a `MainLayout.svg` and a `database.md` — and this box is what
turns that export into something a reader sees.

## What it installs

* **`mix db`** (`lib/mix/tasks/db.ex`) and its test
  (`test/mix/tasks/db_test.exs`). The task reads the export and writes
  the page: the Markdown formatted ExDoc's way — one tab set per table,
  the foreign keys read as the tables they point at, the HTML entities
  decoded, the generator's own footer dropped — and the two SVGs copied
  into `guides/images/` as `model-light.svg` and `model-dark.svg`, their
  font swapped for the site's. It is the author's task, installed as
  written.
* **`{:html_entities, "~> 0.5"}`**, which is what the task decodes
  DbSchema's Markdown with.
* **A sample export** under `assets/db_schema/` (`--combo`), so `mix db`
  has something to read and the task's test has its input files before
  anyone opens DbSchema.
* **The page and both diagrams**, written on the insert — what `mix db`
  would write — so a documentation site has a database page from its
  first build: `guides/database.md`, `guides/images/model-light.svg`,
  `guides/images/model-dark.svg`.
* **The page listed in the site**, under Support, when the project
  already has exdoc's `docs:` block. It is not listed twice, and a
  project with no site gets the page all the same — whoever adds the
  site later lists it.

## Options

| Option | What it decides |
| --- | --- |
| `--combo` | Which sample export is planted: `none` (the default, a stock Phoenix database), `auth0`, `auth0_openai`, `auth0_stripe`, `auth0_openai_stripe` |

## Two themes, one page

The page names two images, each with the URL fragment ExDoc reads:

```markdown
![img](./assets/model-light.svg#gh-light-mode-only)

![img](./assets/model-dark.svg#gh-dark-mode-only)
```

ExDoc hides the `#gh-dark-mode-only` image in the light theme and the
`#gh-light-mode-only` one in the dark, which is GitHub's own convention,
so the same Markdown reads right in the repository. `./assets/` is where
the site serves `guides/images/` from (exdoc's `assets:` map).

## Builds on

**ecto**: there is no database page without a database. Not exdoc — the
page and the images are written whether or not the project has a
documentation site.

## Running it again

The mark is `lib/mix/tasks/db.ex`: a second insert finds the task and
skips with a notice. Keeping the page current is the task's job, not the
installer's — export from DbSchema over `assets/db_schema/`, then
`./wb.sh mix db`.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/dbschema/` | The cartridge: its code and its papers |
| `├── 📄 dbschema.ex` | The manifest, `--combo`, what it plants |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it is run again |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Why one box, and why the URL fragments |
|  |  |
| `📁 priv/features/dbschema/` | Everything that is not code |
| `├── 📁 templates/` | The two files the project is given |
| `│   ├── 📄 db_task.eex` | `mix db`: the export, formatted for ExDoc |
| `│   └── 📄 db_task_test.eex` | Its test: the lines the task reports |
| `└── 📁 assets/db_schema/` | The sample exports, one directory each |
| `    ├── 📁 none/` | A stock Phoenix database: `schema_migrations` |
| `    ├── 📁 auth0/` | With auth0's `users` |
| `    ├── 📁 auth0_openai/` | And openai's `conversations` and `messages` |
| `    ├── 📁 auth0_stripe/` | auth0's tables: Stripe keeps its objects at Stripe |
| `    └── 📁 auth0_openai_stripe/` | auth0's and openai's, on the Stripe export |
| `        └── 📄 database.dbs`, `light/`, `dark/` | In each: the model, and per theme its `MainLayout.svg` and `database.md` |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 dbschema_test.exs` | The combos, the page, the two fragments |
