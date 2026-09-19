# adminer — Design

*Revision: cartridge v0.1.0 (2026-09-09). Sources consulted on that
date; quotations are verbatim from the file or page as read then. The
mechanism as installed is in the [README](README.md); the rule a
service cartridge follows — a file the project owns, the topology's
part in the compose — is settled in `scripts/PLAN.md` and argued in
[monitoring's paper](../monitoring/DESIGN.md) §3.4.*

## Abstract

pgAdmin, the collection's pick, administers Postgres and refuses the
other three adapters ecto can put a project on. This cartridge is its
à-la-carte counterpart: Adminer, one PHP page in a small image, on the
workspace's database whatever the adapter, on its own port beside the
app's. Three things had to be decided against sources. Which manager:
Adminer over one manager per adapter (phpMyAdmin is "MySQL and MariaDB"
alone, and SQLite and MSSQL have no web manager of that rank) and over
CloudBeaver (every adapter, but a Java server with users of its own).
Whether the image reaches MSSQL: the Docker Hub page says `pdo_dblib`
must be installed on top, the Dockerfile installs it, the running
image lists it — the page is stale — and a login into MSSQL 2022 was
measured. And how the workspace's databases pass Adminer's login rule,
which since 6.0.0 refuses an empty password, a database without
passwords and a server that accepts any: Postgres trusts 127.0.0.1
inside the pod, MySQL's root has no password, SQLite has none — so the
project's file carries `Adminer\Password`, a password Adminer verifies
itself and never sends on, fused with the `login-servers` plugin in
one class, because both answer `credentials()` and Adminer takes the
first answer. The file is the mark; the compose mounts its directory
as the image's `plugins-enabled/` and hands over where the database is
and which one to open, which are the deployment's.

## 1. Problem

[pgadmin](../pgadmin/) came out of the retired opinionated line, which
was Postgres. Its installer reads the adapter off the project and
refuses any other — "pgAdmin administers Postgres alone", its NEED.md
says. Since ecto took `--database` — `postgres`, `mysql`, `mssql`,
`sqlite3` — a project on three of the four has no way to look at its
database from the workspace but the server's own shell client. The
need is the one pgadmin's box states, "look at the database, not type
SQL blind into `psql`"; only the adapter differs. Two shapes were
open: a manager per adapter, or one that reads them all. Whichever it
was, it had to be a service cartridge as the house defines one: a
container the compose carries because the project asked for it,
opening with a file the project owns, the topology's part written by
the compose.

## 2. Background

### 2.1 What exists per adapter

phpMyAdmin's image page [5, summary only]: "phpMyAdmin supports a wide
range of operations on MySQL and MariaDB", configured by `PMA_HOST`,
`PMA_PORT`, `PMA_USER`, `PMA_PASSWORD` or a mounted
`config.user.inc.php`. For SQLite the web managers are small projects
(sqlite-web) and for MSSQL the tools are desktop ones (Azure Data
Studio); neither was opened, neither is a candidate. A manager per
adapter is three images, three configuration formats and three blocks
in the pod, with a gap on two of four.

### 2.2 Adminer, and the image

Adminer's README [2]: "a full-featured database management tool
written in PHP. It consists of a single file ready to deploy to the
target server"; "Supports: MySQL, MariaDB, PostgreSQL, CockroachDB,
SQLite, MS SQL, Oracle". Releases (the GitHub API): v6.0.2 2026-09-07,
v6.0.1 2026-08-14, v6.0.0 2026-08-07, v5.5.1 2026-07-21.

The official Docker image is the Docker Community's, "not to be
confused with any official `adminer` image provided by `adminer`
upstream" [3]. Its `6/Dockerfile` [4]: `FROM php:8.4-alpine`,
`docker-php-ext-install mysqli pdo_pgsql pdo_sqlite pdo_odbc pdo_dblib`,
`ENV ADMINER_VERSION=6.0.1`, `mkdir /var/www/html/plugins-enabled`,
`USER adminer`, `CMD [ "php", "-S", "[::]:8080", "-t", "/var/www/html" ]`,
`STOPSIGNAL SIGINT`. The official-images library file [6] tags it
`6.0.1, 6, latest, 6.0.1-standalone, 6-standalone, standalone` (and
`5.5.1, 5`): the image lags upstream by one patch.

The image's `index.php` [4] loads the plugins — `foreach
(glob('plugins-enabled/*.php') as $plugin) { $plugins[] =
require($plugin); }`, then `new \Adminer\Plugins($plugins)` — and
appends a `DefaultServerPlugin` of its own that prefills the Server
field from `ADMINER_DEFAULT_SERVER` (`?: 'db'`) by a regex on the
field's markup. The Docker Hub page [1]: "To load a custom plugin you
can add PHP scripts that return the instance of the plugin object to
`/var/www/html/plugins-enabled/`"; "If a plugin *requires* parameters
to work correctly instead of adding the plugin to `ADMINER_PLUGINS`,
you need to add a custom file to the container", with `login-servers`
as the example. `Plugins::__construct()` [16] takes "object instances
or null to autoload plugins from adminer-plugins/, non-objects are
reported and skipped".

### 2.3 The image and MS SQL: the sources contradict each other

The same Docker Hub page [1]: "While Adminer supports a wide range of
database drivers this image only supports the following out of the
box: MySQL, PostgreSQL, SQLite, SimpleDB, Elasticsearch. To add support
for the other drivers you will need to install the following PHP
extensions on top of this image: `pdo_dblib` (MS SQL), `oci8`
(Oracle), `interbase` (Firebird), `mongodb` (MongoDB)". The Dockerfile
[4] installs `pdo_dblib`. Measured on 2026-09-09: `docker run --rm
adminer:6.0.1 php -m` lists `mysqli mysqlnd pdo_dblib PDO_ODBC
pdo_pgsql pdo_sqlite sqlite3`. Adminer's MSSQL driver [7] takes
`sqlsrv`, then `pdo_sqlsrv`, then `pdo_dblib`:
`"dblib:charset=utf8;host=$server[host]" . (";port=$port")`. The side
taken is the Dockerfile's and the running image's; the page is stale.
Whether FreeTDS reaches the workspace's MSSQL 2022 was a question for
the Evaluation, not for the sources.

### 2.4 The login rule

`Adminer::login()` [8]:

```php
if ($password == "") {
    return lang('Adminer does not support accessing a database without a password.') . require_password_link(null);
}
if (!Driver::$passwords) {
    return lang('The database does not support passwords.') . require_password_link($password);
}
if (!password_required()) {
    return lang('The server accepts any password, so filling it in protects nothing.') . require_password_link($password);
}
return true;
```

`password_required()` [9] — "Check if the server requires a password,
i.e. it doesn't connect without it" — tries `Driver::connect($server,
$user, "")` once a session and remembers a `true`. adminer.org's page
on it [10, summary only]: since 4.6.3 no password-less access, because
"a forgotten Adminer uploaded on a place accessible by an attacker
could have been used to access a database"; since 6.0.0 also servers
accepting any password; the way out offered is "Fill in a password of
your choice and Adminer will offer a configuration requiring it without
passing it to the database". That configuration is `Adminer\Password`
[11]: "Require a password verified by Adminer. Instantiate it in
adminer-plugins.php, it must not extend Plugin - Plugins would ask to
configure it"; `__construct(string $password_hash)`, "result of
password_hash()"; its `credentials()` sends the server "" when the
typed password matches and the server requires none — "the server
doesn't know our password so don't send it - unless the server
requires a password, it can be even the same one" — and its `login()`
returns `true` on a match. The SQLite driver [12] declares `static
$passwords = false` and connects `":memory:"` with "the password is
refused by Adminer::login()" beside it. `plugins/login-password-less.php`
[13] is `@deprecated Use Adminer\Password`.

The workspace's credentials are ecto's table, phx.new's own:
`postgres` / `postgres`, `root` / `""` for MySQL
(`MYSQL_ALLOW_EMPTY_PASSWORD: "yes"` in the pod), `sa` /
`some!Password`, none for SQLite. And the postgres image's
`pg_hba.conf`, read off a running container on 2026-09-09: `host all
all 127.0.0.1/32 trust` and `host all all ::1/128 trust`, initdb's
defaults, then the image's own `host all all all scram-sha-256`.
Inside the pod every service reaches the database on 127.0.0.1, so
Postgres accepts any password there.

### 2.5 The servers plugin, and who answers first

`plugins/login-servers.php` [14]: "Display a fixed list of servers in
the login form"; `@param array{server:string, driver:string}[]
$servers [$description => ["server" => , "driver" =>
"server|pgsql|sqlite|..."]], note that the driver for MySQL is called
'server'`. On a POST it sets the driver from the chosen key;
`credentials()` returns the mapped server, `$_GET["username"]` and the
password; `login()` returns `false` for a key not in the list;
`loginFormField()` drops the driver field and turns the server field
into a `<select>` of the keys. So `Adminer\SERVER` — the URL's
`pgsql=…` value [15], "read from pgsql=localhost" — is the description,
not the address.

Two plugins can answer `credentials()`. `Plugins::__call()` [16]:
"non-null value from non-appending method short-circuits the other
plugins" — the first plugin in glob order that answers is the answer.

### 2.6 Where the SQLite file is

phx.new's generator [17] writes the dev database as
`Path.expand("../#{app}_dev.db", __DIR__)` — the project's root, which
the dev pod mounts at `/app/src`; the release opens `DATABASE_PATH`,
`/app/data/<app>_prod.db` on the `data` volume (ecto.ex). The SQLite
driver's `select_db()` [12] attaches the name as a path — `"ATTACH " .
$this->quote(preg_match("~(^[/\\\\]|:)~", $filename) ? $filename :
dirname($_SERVER["SCRIPT_FILENAME"]) . "/$filename")` — guarded by
`is_readable($filename)`: an absolute path is taken as it is. The pod
shares a network namespace, not volumes.

## 3. Design

### 3.1 Adminer, not a manager per adapter, not CloudBeaver

One image, one file, one block in the pod, every adapter. The
per-adapter shape (§2.1) gives three of each and still two gaps.
CloudBeaver [18, summary only] lists PostgreSQL, MySQL, SQLite and SQL
Server among its pre-downloaded drivers and preconfigures connections
from a `data-sources.json`, but it is a Java server with its own user
administration — a second application to run beside a page of tables.
Neither its configuration path nor its first-run setup was read in
full; it was not needed to decide.

### 3.2 An à-la-carte box beside pgadmin, not a replacement

pgadmin stays the collection's pick and Adminer a box of its own, as
healthcheck2 is beside healthcheck: two boxes for one need, a
different mechanism, one in the collection and one out. Adminer does
not refuse on Postgres — a reader on Postgres may want the lighter
one, or both, and what the reader could have is never hidden; the
boundary is the NEED's *Not for*: going deep into Postgres is
pgAdmin's. The collection therefore stays Postgres in practice
(`wb.sh add chiefs_setup` on MySQL stops at pgadmin); that is the
collection's decision, not this box's.

### 3.3 One plugin file, the project's, fusing two of Adminer's

`adminer/login.php` returns one object, a subclass of
`AdminerLoginServers` holding an `Adminer\Password`. Why one and not
two files: both plugins answer `credentials()`, and with two files the
servers plugin answers first (§2.5). Measured: with `login-servers.php`
and `password.php` side by side, MySQL denied `root` "(using password:
YES)" — the typed `pass` had been sent to the server. The subclass
takes Password's answer and puts login-servers' server on it; its
`login()` refuses a server not in the list and otherwise defers to
Password, which returns `true` on a match and leaves Adminer's own
rule to run otherwise — which is how MSSQL, whose server checks
passwords, logs in with sa's. It also fills the user and the database
into the form, a `preg_replace` of `value=""` on Adminer's own field
markup — the move the image's `DefaultServerPlugin` makes on the
server field — so the password is all there is to type. The
alternative, an `adminer-plugins.php` returning an array, is not how
this image loads plugins (§2.2).

The password is `pass`, pgAdmin's; the file carries `password_hash()`
of it, made once — bcrypt keeps its salt in the hash, so one hash
verifies forever. It is not a secret: it is what Adminer's rule asks
for, and it protects the page, not the database, which the pod does
not publish.

### 3.4 What the file carries and what the compose hands over

The driver and the user are the project's — read off the adapter, as
pgadmin reads it, off `PhxDelta.facts/1` and never off
an option. Where the server is (`127.0.0.1:port`) and which database
to open (`<app>_dev` or `<app>_prod`; on SQLite the file's path, which
differs between the source mount and the release volume) are the
deployment's, so the compose sets `WORKBENCH_SERVER` and
`WORKBENCH_DATABASE` and the file reads them with `getenv()`, its own
values standing for an Adminer run by hand beside the dev pod. This
is the rule monitoring settled — the topology's in the compose —
applied to a file that is PHP and can read its environment, where
Prometheus's could not.

`127.0.0.1`, never `localhost`. Measured: MySQL answered "No such file
or directory" to `localhost:3306` — the client reads `localhost` as
its unix socket whatever the port. Postgres and MSSQL took either; one
form for all.

### 3.5 The mount, the identity, the version

The directory is mounted read-only as the image's `plugins-enabled/`
(a bind, as k6's `./k6:/scripts:ro`; pgadmin's `configs:` is one
file). On SQLite the container also gets the file's mount — the source
in dev, the `data` volume in prod — and runs as the file's owner (the
workspace's UID:GID, the release's `nobody`), because SQLite writes its
journal beside the file and the image's `adminer` user could not. The
image tag is the major, `6`, `ADMINER_IMAGE_VERSION` in `config.conf`:
the file is written against 6's plugin API (`Adminer\Plugin`,
`Adminer\Password`, the login rule of 6.0.0) and `latest` moves
majors. No health condition: Adminer connects when asked.

## 4. Evaluation

Measured on 2026-09-09 with `adminer:6.0.1` and the workspace's own
images (`postgres:latest`, `mysql:8`,
`mcr.microsoft.com/mssql/server:2022-latest`), Adminer sharing the
database container's network namespace as it does in the pod, driven
by `curl` through the login form (its `token` included) and the page
after it, following redirects. The file was the template rendered by
hand for each adapter.

| Adapter | Typed | Result |
| --- | --- | --- |
| postgres | `pass` | `Schema: public` |
| postgres | `postgres`, or wrong | "The server accepts any password, so filling it in protects nothing." |
| mysql | `pass` | `Database: lorem_ipsum_prod` |
| mysql | empty | "Adminer does not support accessing a database without a password." |
| mysql | wrong | "Access denied for user 'root'@'127.0.0.1' (using password: YES)" |
| sqlite3 | `pass` | `Database: /app/src/lorem_ipsum_dev.db`; a `CREATE TABLE` through it, "Query executed OK", the file 8192 bytes after |
| sqlite3 | wrong | "The database does not support passwords." |
| mssql | `some!Password` | `Schema: dbo`, master's tables listed |
| mssql | `pass` | "SQLSTATE[01002] TDS server connection failed (127.0.0.1) (severity 9)" |

The rendered form: `<select name='auth[server]'><option>lorem_ipsum`,
the username `value="postgres"`, the database `value="lorem_ipsum_prod"`
off `WORKBENCH_DATABASE`.

Then in a workspace — a copy of a live Postgres one, on the workbench
itself: `wb.sh add adminer` inserted the file as its own commit and
said the compose was behind; `wb.sh bake` wrote the `adminer` service
with `WORKBENCH_SERVER: 127.0.0.1:5432` and `WORKBENCH_DATABASE:
lorem_ipsum_dev` and published 8080; `status` listed the port, the
service and the shelf row; the pod's `network`, `database` and
`adminer` brought up from that file (the app left down), the form came
up with the server fixed and the user and the database filled, and
`pass` landed on `Schema: public`. The mounted directory arrived with
the workspace's ownership, readable by the image's `adminer` user.

Not measured: SQLite and the release's volume inside a baked
workspace, and Adminer 6.0.2 (the image was one patch behind).

## 5. Limitations and open questions

* The pod publishes Adminer's port on the host with a password that
  is on the box. It is dev tooling, as pgAdmin's `pass` is; the
  database itself stays unpublished.
* On MSSQL the password is sa's, not `pass`: the server checks
  passwords, and a matched `Password` is withheld only from a server
  that requires none.
* The console's door lands on the login form; the URL could carry
  `?pgsql=<app>&username=…&db=…` [15] but never the password, so the
  form is one field either way.
* `ADMINER_PLUGINS` and `ADMINER_DESIGN` are not set. The entrypoint
  writes into `plugins-enabled/` for the former, which the read-only
  mount would refuse.
* The image's `DefaultServerPlugin` regex looks for an `<input
  name='auth[server]'>`; with the field replaced by a `<select>` it
  finds nothing, harmlessly.

## References

Read in full on 2026-09-09. The vrana/adminer files are `master` as of
that date (`VERSION = "6.1.0-dev"`), one minor ahead of the image's
6.0.1; what is quoted of them was measured to hold on 6.0.1.

1. Docker Hub, *adminer* (docker-library/docs, `adminer/content.md`).
   <https://hub.docker.com/_/adminer>
2. vrana/adminer, *README.md*. <https://github.com/vrana/adminer>
3. TimWolla/docker-adminer, *README.md*.
   <https://github.com/TimWolla/docker-adminer>
4. TimWolla/docker-adminer, `6/Dockerfile`, `6/index.php`,
   `6/entrypoint.sh`, `6/plugin-loader.php`.
5. Docker Hub, *phpmyadmin* (summary only). <https://hub.docker.com/_/phpmyadmin>
6. docker-library/official-images, `library/adminer`.
   <https://github.com/docker-library/official-images/blob/master/library/adminer>
7. vrana/adminer, `adminer/drivers/mssql.inc.php`.
8. vrana/adminer, `adminer/include/adminer.inc.php`, `login()`.
9. vrana/adminer, `adminer/include/auth.inc.php`, `password_required()`
   and the login POST.
10. Adminer, *Password* (summary only). <https://www.adminer.org/en/password/>
11. vrana/adminer, `adminer/include/password.inc.php`.
12. vrana/adminer, `adminer/drivers/sqlite.inc.php`.
13. vrana/adminer, `plugins/login-password-less.php`.
14. vrana/adminer, `plugins/login-servers.php`.
15. vrana/adminer, `adminer/include/bootstrap.inc.php`, `SERVER`, `DB`, `ME`.
16. vrana/adminer, `adminer/include/plugins.inc.php`, `__construct()`, `__call()`.
17. phoenixframework/phoenix, `installer/lib/phx_new/generator.ex`
    (the toolchain's `deps/phx_new`).
18. CloudBeaver, *Supported databases* and *Configuring server
    datasources* (summary only).
    <https://github.com/dbeaver/cloudbeaver/wiki/Supported-databases>
