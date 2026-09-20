# Cartridge: db_admin

A database admin in the browser, open on the project's database.

* **Task**: `mix workbench.install.db_admin`
* **Inserted by**: `wb.sh add db_admin [--admin pgadmin,adminer,…]`
* **Requires**: `ecto`; each admin, the databases it serves.

## Description

Looking at a database — its tables, a few rows, a query with its
result in a grid — is a job for a tool with a window, and the ones that
run in a browser come in two kinds. A database's own admin goes deep on
one server and refuses the rest; a generalist reads several and knows
less of each:

| `--admin` | What it is | Good for | Image | Serves |
| --- | --- | --- | --- | --- |
| `pgadmin` | [pgAdmin](https://www.pgadmin.org), Postgres' own | query plans drawn, server activity, roles, its dashboards | 529 MB | postgres |
| `phpmyadmin` | [phpMyAdmin](https://www.phpmyadmin.net), MySQL's and MariaDB's own | users and privileges, server variables, import and export | 608 MB | mysql |
| `adminer` | [Adminer](https://www.adminer.org), one PHP page | a quick look and an edit on any database; the lightest by far | 122 MB | postgres, mysql, mssql, sqlite3 |
| `cloudbeaver` | [CloudBeaver](https://github.com/dbeaver/cloudbeaver), DBeaver in the browser | a full SQL editor with completion, ER diagrams, data export; a Java server | 717 MB | postgres, mysql, mssql |

The sizes are the images as pulled on 2026-09-19, at the tags
`config.conf` names: `dpage/pgadmin4:latest`, `phpmyadmin:5`,
`adminer:6`, `dbeaver/cloudbeaver:latest`.

Which image, told what, opening with which file so that the page comes
up already on the project's database — and which of them can serve the
database the project is on: that is what this cartridge knows.

**Without `--admin`** it is the one for the project's database: its own
admin where it has one — `pgadmin` on postgres, `phpmyadmin` on mysql —
and `adminer` on mssql and sqlite3, which have none. **With it**, one or
several, comma-separated; one that does not serve the project's
database refuses the run and says what the project has:

    --admin pgadmin builds on ecto with database postgres, and this
    project's database is mysql.

The database is read off the project as it is — the driver in its deps,
through ecto's own `state/1` — never off what an insert was asked.

## What it installs

For each admin, a file the project owns — the one the admin opens
with, and the mark — and a container in the workspace's compose:

| Admin | The project's file | The container |
| --- | --- | --- |
| `pgadmin` | `pgadmin/servers.json` — one server, `localhost:5432`, user `postgres`, named after the app, in pgAdmin's own group, `Servers` | `dpage/pgadmin4`, port 5050, desktop mode (no pgAdmin account), the password from a `pgpass` it writes at start |
| `phpmyadmin` | `phpmyadmin/config.user.inc.php` — signed in as `root`, no password, the server named after the app | `phpmyadmin:5`, its Apache moved to 8081 (`APACHE_PORT`), told where MySQL is (`PMA_HOST`, `PMA_PORT`) |
| `adminer` | `adminer/login.php` — one Adminer plugin: the database as the one server in the login form, the user and the database filled in, and the password Adminer checks itself, `pass` (on MSSQL, sa's) | `adminer:6`, port 8080, the project's `adminer/` mounted as its `plugins-enabled/`; on SQLite it mounts the file and runs as its owner |
| `cloudbeaver` | `cloudbeaver/data-sources.json` — one connection, `workbench-<app>`, the driver and the credentials off the adapter, the place left as `${WORKBENCH_HOST}`, `${WORKBENCH_PORT}`, `${WORKBENCH_DATABASE}` | `dbeaver/cloudbeaver`, port 8978, the file mounted as the seed of its workspace; configured by variables so no wizard comes up, the connection open to whoever opens the page (its own administrator: `cbadmin` / `pass`) |

Who signs in and on which driver are the project's — ecto's
credentials for the adapter, `phx.new`'s own — so they go in the
project's file. Where the database is and which one to open
(`<app>_dev` on the dev pod, `<app>_prod` on a release) are the
deployment's, so the compose says them.

### Signing in

Development credentials, the same in every workspace — dev tooling on
the developer's machine, not secrets:

| Admin | What you type |
| --- | --- |
| `pgadmin` | nothing: desktop mode, no pgAdmin account; the server's password comes from the `pgpass` the container writes |
| `phpmyadmin` | nothing: signed in as `root` |
| `adminer` | a password, the only field left: **`pass`** on Postgres, MySQL and SQLite — Adminer's own, checked by Adminer and never sent to the database — and **`some!Password`** on SQL Server, sa's, which that server checks itself. The user and the database come filled in |
| `cloudbeaver` | nothing: the connection is open on arrival. CloudBeaver's own settings take its administrator, **`cbadmin`** / **`pass`** |

Adminer asks for one because it refuses a login with an empty
password, a database without passwords, or a server that accepts any —
which is all four of these inside the pod. That rule is Adminer's, and
the box leaves it as its author wrote it rather than teaching the
plugin to answer for the server; what the box does instead is fill the
rest of the form in, and say here what to type.

### The credentials

The database's own, as `phx.new` and ecto set them — for any client,
not only these four: a shell in the workspace, a desktop DBeaver, a
migration you run by hand. The server answers on `127.0.0.1` inside
the pod, and the databases are `<app>_dev` and, in a release,
`<app>_prod`:

| Database | Port | User | Password | In Adminer, type |
| --- | --- | --- | --- | --- |
| Postgres | 5432 | `postgres` | `postgres` | `pass` |
| MySQL | 3306 | `root` | none | `pass` |
| SQL Server | 1433 | `sa` | `some!Password` | `some!Password` |
| SQLite | — | none | none | `pass` |

SQLite is a file, not a server: `/app/src/<app>_dev.db` in the
workspace, `/app/data/<app>_prod.db` on the release's volume.

The image tags are `PGADMIN_IMAGE_VERSION`, `PHPMYADMIN_IMAGE_VERSION`,
`ADMINER_IMAGE_VERSION` and `CLOUDBEAVER_IMAGE_VERSION` in
`config.conf`; each port is the first free one from its default.

**A second run adds** (`rerun: :adds`): `wb.sh add db_admin --admin
cloudbeaver` on a project that has pgAdmin puts CloudBeaver beside it.
A file that is there is never rewritten. An insert is one commit —
the files and the compose — so `./wb.sh eject db_admin` reverts it
whole.

Why Adminer needs a password of its own, why CloudBeaver's file is a
seed and not its live configuration, why not CloudBeaver on SQLite, and
everything that was measured: [DESIGN.md](DESIGN.md).

## In the workbench

The containers are declared for `mix workbench.compose` (`services/1`
answers the admins whose file is there; `compose/1` says what each is,
off `priv/features/db_admin/compose/`), so `wb.sh add` bakes them into
the dev and prod composes in the insert's own commit, and the next
`up` brings them up. They sit on the pod's network, where the database
answers on `127.0.0.1` without being published; the scaled deployment
has none. The console shows each as a door on its port.

A project that got pgAdmin or Adminer from the boxes this one replaced
(`pgadmin`, `adminer`) carries the same files, and reads as carrying
`db_admin` with them.

## Contents

| File | Role |
| --- | --- |
| `📁 lib/workbench_igniter/features/db_admin/` | The cartridge: its code and its papers |
| `├── 📄 db_admin.ex` | The admins, their files and containers |
| `├── 📄 task.ex` | The Mix task `wb.sh add` runs |
| `├── 📄 README.md` | What it installs, and how it runs |
| `├── 📄 NEED.md` | The need, the line the shelf shows |
| `├── 📄 CHANGELOG.md` | Its versions, apart from the workbench's |
| `└── 📄 DESIGN.md` | Each admin against its sources |
|  |  |
| `📁 priv/features/db_admin/` | What it writes: project and compose |
| `├── 📁 templates/` | Each admin's file, for the project |
| `│   ├── 📁 pgadmin/` |  |
| `│   │   └── 📄 servers.json.eex` | Postgres as the one server, the app's name |
| `│   ├── 📁 phpmyadmin/` |  |
| `│   │   └── 📄 config.user.inc.php.eex` | `root` signed in, no password |
| `│   ├── 📁 adminer/` |  |
| `│   │   └── 📄 login.php.eex` | The login with driver, user, database |
| `│   └── 📁 cloudbeaver/` |  |
| `│       └── 📄 data-sources.json.eex` | The first connection, the place left out |
| `└── 📁 compose/pod/` | Each admin's container, told the database |
| `    ├── 📄 pgadmin.yml.eex` | Port 5050, desktop mode, its `pgpass` |
| `    ├── 📄 pgadmin.configs.yml.eex` | Hands pgAdmin the `servers.json` |
| `    ├── 📄 phpmyadmin.yml.eex` | Its Apache moved to port 8081 |
| `    ├── 📄 adminer.yml.eex` | Port 8080, the login as its plugin |
| `    └── 📄 cloudbeaver.yml.eex` | Port 8978, the connection as its seed |
|  |  |
| `📁 test/workbench_igniter/features/` |  |
| `└── 📄 db_admin_test.exs` | Each admin on each database, the refusals |
