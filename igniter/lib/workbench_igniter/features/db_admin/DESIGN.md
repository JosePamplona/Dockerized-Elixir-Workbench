# db_admin — Design

*Revision: cartridge v0.1.0 (2026-09-18). It merges two boxes, pgadmin
(v0.1.1) and adminer (v0.1.0), and adds two admins. Adminer's sources
were consulted on 2026-09-09 and phpMyAdmin's and CloudBeaver's on
2026-09-18; quotations are verbatim from the file or page as read then.
The mechanism as installed is in the [README](README.md); the rule a
service cartridge follows — a file the project owns, the topology's
part in the compose — is settled in `scripts/PLAN.md` and argued in
[monitoring's paper](../monitoring/DESIGN.md) §3.4.*

## Abstract

A developer wants to look at the database: the tables, a few rows, a
query with its result in a grid, without the server's shell client.
The tools that do it in a browser fall in two kinds. A database's own
admin goes deep on one server — pgAdmin on Postgres, phpMyAdmin on
MySQL and MariaDB — and refuses the rest. A generalist reads several —
Adminer, one PHP page, on seven; CloudBeaver, DBeaver's server, on
dozens — and knows less of each. The shelf had one of each kind as two
boxes, the first closed to every database but Postgres and the second
written as its consolation. This paper makes them one box with the
admin as its option, `--admin`, one or several, each value declaring
which of ecto's databases it serves as a requirement on the value —
read off the project as it is, never off what an insert was asked —
and the box shaped by the database when no admin is named: its own
admin where it has one, Adminer where it has none. Two admins were
added against sources and then measured: phpMyAdmin, whose official
image already allows MySQL's empty root password and only needs its
Apache moved off port 80 inside a pod that is one network namespace;
and CloudBeaver, which opens with a setup wizard, keeps users of its
own and rewrites its connections file — and yet comes up configured,
the workspace's database a connection anyone opening the page can use,
from three environment variables, one read-only file mounted where the
image keeps the seed of a fresh workspace, and its own switch for
environment variables in a connection, which lets the compose say
where the database is. It serves Postgres, MySQL and SQL Server;
SQLite is a driver its server ships disabled, and the box says so
instead of patching the server's configuration. Every admin is a file
the project owns — the mark — and a container the compose carries
because the project asked for it, each on a port of its own; Adminer
alone behind a password, the one its own rule asks for.

## 1. Problem

Ecto puts a project on one of four databases — `postgres`, `mysql`,
`mssql`, `sqlite3` — and the workspace's compose runs the server
unpublished, reachable only from inside. Looking at it means a shell
into a container and the server's own client: `psql`, `mysql`,
`sqlcmd`, `sqlite3`, each with its own way of listing tables, and a
query retyped for every table. A web admin beside the database, on a
port of its own, already pointing at it, removes that; which admin is
the question, and it has no single answer: pgAdmin shows Postgres'
plans and server activity and no other server; phpMyAdmin is the same
for MySQL; SQL Server and SQLite have no web admin of that rank;
Adminer reads all four and is one page; CloudBeaver brings DBeaver's
editor and ER diagrams at the price of a Java server.

The shelf answered with two boxes. pgadmin came out of the retired
opinionated line, which was Postgres, and refused any other adapter;
adminer was written on 2026-09-09 as its "à-la-carte counterpart",
its NEED opening with "Your project isn't on Postgres, and pgAdmin
said no." Two boxes for one need, split by mechanism, the second
defined by the first's refusal — and any recipe that picked pgadmin
stopped there on a project off Postgres. Since 2026-09-18 a
requirement can name a state and an option's value can carry a
requirement (`choices/0`), so the split is no longer needed to say
"this admin, only on this database".

## 2. Background

### 2.1 What exists per database

| | Its own web admin | Read by |
| --- | --- | --- |
| Postgres | pgAdmin | Adminer, CloudBeaver |
| MySQL, MariaDB | phpMyAdmin | Adminer, CloudBeaver |
| SQL Server | none: its tools are desktop ones (SSMS, Azure Data Studio) | Adminer, CloudBeaver |
| SQLite | none of that rank (sqlite-web is a small project) | Adminer |

The desktop tools and sqlite-web were not opened; neither is a
candidate. `mcr.microsoft.com/mssql/server` is the engine ecto's
compose already runs, not an admin.

### 2.2 pgAdmin

Carried over from the pgadmin box as it stood (v0.1.1), and not re-read
for this paper: the `dpage/pgadmin4` image, told its port with
`PGADMIN_LISTEN_PORT`, run in desktop mode
(`PGADMIN_CONFIG_SERVER_MODE: 'False'`,
`PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED: 'False'`) so no pgAdmin
account stands between the browser and the server list; the servers it
opens with are a JSON file it imports at first start
(`/pgadmin4/servers.json`), and the password comes from a `pgpass` file
the container writes before `exec`-ing the image's entrypoint — `exec`
because without it the shell stayed PID 1 and every stop waited the ten
seconds of grace and ended in SIGKILL, seen on the events feed.

### 2.3 phpMyAdmin, and the image

The official image is phpMyAdmin's own [19]: "a free software tool
written in PHP, intended to handle the administration of MySQL over
the Web", which "supports a wide range of operations on MySQL and
MariaDB". The official-images library file [23] tags `5.2.3-apache,
5.2-apache, 5-apache, apache, 5.2.3, 5.2, 5, latest`, with `fpm` and
`fpm-alpine` variants that need a web server beside them. Its
`apache/Dockerfile` [22] is `FROM php:8.3-apache`, `ENV VERSION=5.2.3`,
`CMD ["apache2-foreground"]`.

The server is made by the image's `config.inc.php` [20] off the
environment: `PMA_HOST` — "define address/host name of the MySQL
server" — and `PMA_PORT`; with `PMA_USER` set, `auth_type` is `config`
and the password is `PMA_PASSWORD` or `''`, otherwise `cookie`, a login
form. Every server it makes gets
`$cfg['Servers'][$i]['AllowNoPassword'] = true;`, which is what MySQL's
`root` with no password needs, and the file ends by including the
user's — "`/* Include User Defined Settings Hook */`", `if
(file_exists('/etc/phpmyadmin/config.user.inc.php'))` — after "Revert
back to last configured server to make it easier in
config.user.inc.php": `$i` is the server just configured. The README
[19]: "You can add your own custom config.inc.php settings (such as
Configuration Storage setup) by creating a file named
`config.user.inc.php` with the various user defined settings in it, and
then linking it into the container using: `-v
/some/local/directory/config.user.inc.php:/etc/phpmyadmin/config.user.inc.php`".
And the port: "`APACHE_PORT` - if defined, this option will change the
default Apache port from `80` in case you want it to run on a different
port like an unprivileged port."

### 2.4 Adminer, and the image

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

### 2.5 Adminer's image and MS SQL: the sources contradict each other

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

### 2.6 Adminer's login rule

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

### 2.7 Adminer's servers plugin, and who answers first

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

### 2.8 Where the SQLite file is

phx.new's generator [17] writes the dev database as
`Path.expand("../#{app}_dev.db", __DIR__)` — the project's root, which
the dev pod mounts at `/app/src`; the release opens `DATABASE_PATH`,
`/app/data/<app>_prod.db` on the `data` volume (ecto.ex). The SQLite
driver's `select_db()` [12] attaches the name as a path — `"ATTACH " .
$this->quote(preg_match("~(^[/\\\\]|:)~", $filename) ? $filename :
dirname($_SERVER["SCRIPT_FILENAME"]) . "/$filename")` — guarded by
`is_readable($filename)`: an absolute path is taken as it is. The pod
shares a network namespace, not volumes.

### 2.9 CloudBeaver, and the image

CloudBeaver is DBeaver's web server, `dbeaver/cloudbeaver` on Docker
Hub; the image pulled on 2026-09-18 answered `26.2.0.202608310912` and
listens on 8978 (`CLOUDBEAVER_WEB_SERVER_PORT`). Its supported
databases page [24] lists MySQL, MariaDB, PostgreSQL, SQL Server and
SQLite among the pre-downloaded drivers, under a note: "Not all
databases in the list are available for connection by default." Five
things about it decide the design.

**The first start is a wizard.** The server configuration page [25]:
"When you start the CloudBeaver server for the first time, an
administrator interface guides you through the server setup. However,
in some cases-like when running in a Kubernetes environment-you might
need to configure the server automatically", by `CB_SERVER_NAME`,
`CB_SERVER_URL`, `CB_ADMIN_NAME` and `CB_ADMIN_PASSWORD`.

**Connections are a file, and the server rewrites it.**
`data-sources.json` "stores all database connection definitions" [27]
and "lives at `${WORKSPACE}/workspace/GlobalConfiguration/.dbeaver`";
a connection names a `provider` and a `driver`, a `configuration` with
`host`, `port`, `database`, an `auth-model` and, to pre-configure
credentials, `auth-properties` [26] — with the warning that they "are
stored in plain text until the first connection", after which
"CloudBeaver encrypts the credentials, removes them from
`data-sources.json`". A file the server rewrites cannot be the
project's file mounted in place. But the image's
`run-cloudbeaver-server.sh`, read off the image, seeds a fresh
workspace: `[ ! -d "workspace/.metadata" ] && mkdir -p
workspace/.metadata && mkdir -p workspace/GlobalConfiguration/.dbeaver
&& [ ! -f "workspace/GlobalConfiguration/.dbeaver/data-sources.json" ]
&& cp conf/initial-data-sources.conf
workspace/GlobalConfiguration/.dbeaver/data-sources.json`. The seed is
read once, copied, and never written.

**Who may see a connection.** The image's `conf/cloudbeaver.conf` has
`anonymousAccessEnabled: "${CLOUDBEAVER_APP_ANONYMOUS_ACCESS_ENABLED:true}"`
(the wiki's page documents `false`; the image is the side taken) and
`grantConnectionsAccessToAnonymousTeam:
"${CLOUDBEAVER_APP_GRANT_CONNECTIONS_ACCESS_TO_ANONYMOUS_TEAM:false}"` —
"Provides access to predefined shared connections for the anonymous
team" [25].

**Where the database is.** The same table [25]:
`systemVariablesResolvingEnabled`,
`CLOUDBEAVER_SYSTEM_VARIABLES_RESOLVING_ENABLED`, default `false` —
"Enables using environment variables in the connection configuration."

**And SQLite.** The running server's
`workspace/.data/.cloudbeaver.runtime.conf` lists `disabledDrivers`:
`duckdb:duckdb_jdbc`, the three `h2:h2_embedded*` and
`sqlite:sqlite_jdbc`; the wiki gives the property no environment
variable ("Not available") [25]. The drivers that open a file on the
server's own disk are off in a server meant to be shared.

## 3. Design

### 3.1 One box, the admin as its option

`db_admin`, named by its role as `version_manager` is, with `--admin`
taking `pgadmin`, `phpmyadmin`, `adminer`, `cloudbeaver`. The need is
one — look at the database — and the four differ in what they are for,
which is what an option's values say. The two old boxes leave the
shelf; their files in a project do not move (`pgadmin/servers.json`,
`adminer/login.php`), so a project that got pgAdmin from the old box
reads as carrying `db_admin` with `pgadmin`, with nothing migrated:
the mark was always the project's file, not a record of which box
wrote it.

`--admin` takes several (`:csv`), and a second run adds another
(`rerun: :adds`): each admin is a piece of its own — its file, its
container, its port — as each of ash's packages is. The case is real:
pgAdmin for a plan, Adminer for a quick look, in the same workspace;
or trying CloudBeaver without ejecting what is there. A file that is
there is never rewritten.

### 3.2 Which databases an admin serves, and the default

Each value carries its requirement in `choices/0`: `pgadmin` builds on
`{"ecto", database: "postgres"}`, `phpmyadmin` on `database: "mysql"`,
`cloudbeaver` on `database: ["postgres", "mysql", "mssql"]`, `adminer`
on `"ecto"` alone — any database, but one there has to be; until v0.2.0
it said nothing, and the form showed it with no requirement beside it. The list is new to the
resolver — a list of values is met by any one of them — and is said
as one: "ecto with database postgres, mysql or mssql". The state is
asked of ecto's own `state/1`, which reads the driver in the project's
deps, so it holds on a project born with the database or moved to it
since. The catalog carries each value's `requires` and `conditions`,
and the console's form shows a value the project's database does not
serve unlit, with the reason, rather than hiding it. One chosen admin
that does not serve the database refuses the whole run: a run that
did half of what was asked would have to be read to know which half.

`--admin` has no default (v0.2.0): without it the run is refused,
naming the four. Which admin to run beside the database is the
developer's choice, not a fact the project states. v0.1.0 shaped the box
by the database, as dashboard_extras is — `pgadmin` on postgres,
`phpmyadmin` on mysql, `adminer` on mssql and sqlite3 — and the form
showed that pick as if it were the value; dropped on 2026-09-21, since a
second container nobody chose is not a default worth having.

### 3.3 phpMyAdmin: the file says who, the compose says where

`phpmyadmin/config.user.inc.php` sets, on the server the image has
just made, `auth_type = 'config'`, the user and the password — ecto's
credentials for MySQL, `root` and none — and `verbose`, the app's
name. `PMA_USER` would do the first three, but who signs in is the
project's, off its adapter, and the project's part goes in the
project's file; where the server is (`PMA_HOST: 127.0.0.1`,
`PMA_PORT`) is the deployment's and goes in the compose. `127.0.0.1`
and never `localhost`, for the reason §3.6 measured on Adminer: the
MySQL client reads `localhost` as its unix socket. `APACHE_PORT: 8081`:
the pod is one network namespace, so every service needs a port of its
own inside it, and 80 is nobody's to take; 8081 sits beside Adminer's
8080. The tag is the major, `5`, as Adminer's: the file is written
against 5's `$cfg['Servers'][$i]`. `AllowNoPassword` is the image's
already (§2.3), so the file does not repeat it.

### 3.4 CloudBeaver: a seed, three variables, two switches

`cloudbeaver/data-sources.json` is one connection,
`workbench-<app>`, with the provider and driver for the adapter
(`postgresql`/`postgres-jdbc`, `mysql`/`mysql8`,
`sqlserver`/`microsoft`, as the server's own driver list names them),
ecto's credentials as `auth-properties`, and `${WORKBENCH_HOST}`,
`${WORKBENCH_PORT}`, `${WORKBENCH_DATABASE}` where the place goes. The
compose mounts it read-only as the image's
`/opt/cloudbeaver/conf/initial-data-sources.conf` — the seed (§2.9) —
so the server copies it into a workspace it then owns and may rewrite,
and the project's file is never written. The container keeps no
volume: recreated, it seeds again from the file, which is the
behaviour a file the project owns should have.

The compose sets `CB_SERVER_NAME`, `CB_ADMIN_NAME: cbadmin` and
`CB_ADMIN_PASSWORD: pass` — pgAdmin's and Adminer's password; measured,
the three are enough to skip the wizard, `CB_SERVER_URL` is not needed
and the password policy is not applied to it — then
`CLOUDBEAVER_APP_GRANT_CONNECTIONS_ACCESS_TO_ANONYMOUS_TEAM` so the
page opens on the connection without a sign-in, and
`CLOUDBEAVER_SYSTEM_VARIABLES_RESOLVING_ENABLED` with the three
`WORKBENCH_*` values: where the database is and which one to open —
`<app>_dev` on the dev pod, `<app>_prod` on a release — are the
deployment's.

Not on SQLite. Enabling the driver means replacing the image's
`conf/cloudbeaver.conf` whole — a copy of a versioned file of the
image kept in the project — and running the server as the file's owner
with the root group so it can still write its workspace (measured:
as `1000:1000` it dies on `mkdir workspace/.metadata: Permission
denied`; as `1000:0` it starts, and the connection answers "Driver
disabled"). Adminer is already there for SQLite; the requirement says
so and the door stays open (§5).

### 3.5 Adminer: one plugin file, the project's, fusing two of Adminer's

`adminer/login.php` returns one object, a subclass of
`AdminerLoginServers` holding an `Adminer\Password`. Why one and not
two files: both plugins answer `credentials()`, and with two files the
servers plugin answers first (§2.7). Measured: with `login-servers.php`
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
this image loads plugins (§2.4).

The password is `pass`, pgAdmin's; the file carries `password_hash()`
of it, made once — bcrypt keeps its salt in the hash, so one hash
verifies forever. It is not a secret: it is what Adminer's rule asks
for, and it protects the page, not the database, which the pod does
not publish.

On SQL Server the typed password is sa's instead, since that server
checks its own and `Password` withholds only from a server that
requires none (§2.6) — so what to type differs by adapter. The plugin
could level it, answering `credentials()` with ecto's password
whatever was typed, and `pass` would open all four; it does not,
because the rule is Adminer's own and a box installs a tool as its
author wrote it. What the box owes the reader instead is the
credentials themselves, and they are a table in the
[README](README.md): each database's user, password and port, for any
client — a shell, a desktop DBeaver — not only for these four
(2026-09-19).

**Tried and not kept (2026-09-19): no password, the port on loopback.**
Adminer is the one admin of four behind a password, and the author's
reason for the rule (§2.6) — "a forgotten Adminer uploaded on a place
accessible by an attacker" — would be met better by the port than by a
password: every admin's port is published on every interface of the
host, the machine's network included. So both were built: the plugin
filling the password in with ecto's and sending the form from the
first page, its `login()` answering `true` for its server so Adminer's
rule does not run; and each admin published on `127.0.0.1` alone. The
first worked on all four databases (§4.3). The second cut the console
off: inside its container it calls a door as `host.docker.internal`,
the host's bridge gateway, and a port published on loopback does not
answer there — measured, `000` from the console against `200` for the
same image published on every interface. With the ports back on every
interface, an Adminer without a password would have been open to the
network, so the password stayed. Closing the admins to the network
without losing the console's reading is open (§5).

### 3.6 Adminer: what the file carries and what the compose hands over

The driver and the user are the project's — read off the adapter,
off `PhxDelta.facts/1`, and never off an option. Where the server is (`127.0.0.1:port`) and which database
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

### 3.7 Adminer: the mount, the identity, the version

The directory is mounted read-only as the image's `plugins-enabled/`
(a bind, as k6's `./k6:/scripts:ro`; pgAdmin's `configs:` is one
file). On SQLite the container also gets the file's mount — the source
in dev, the `data` volume in prod — and runs as the file's owner (the
workspace's UID:GID, the release's `nobody`), because SQLite writes its
journal beside the file and the image's `adminer` user could not. The
image tag is the major, `6`, `ADMINER_IMAGE_VERSION` in `config.conf`:
the file is written against 6's plugin API (`Adminer\Plugin`,
`Adminer\Password`, the login rule of 6.0.0) and `latest` moves
majors. No health condition: Adminer connects when asked.

### 3.8 pgAdmin: as it was

`pgadmin/servers.json` and the block of §2.2, unchanged from the
pgadmin box: the same file, the same container, the same port. Its
servers file names no database to open (`MaintenanceDB: postgres`, and
pgAdmin lists them all), so there is nothing of the deployment's in it
but `localhost:5432`, which is every pod's.

### 3.9 The services, and the pod only

`services/1` answers the admins whose file is there, so which
containers the box brings hangs on its state, as ecto's engine does:
the catalog's `compose` is empty and the status of a project says
them. Each is `role: "devtools"`, on the dev and prod pods, one
published port, by default the one it listens on (5050, 8081, 8080,
8978; the bake takes the first free one from there). None on the
scaled deployment: there the database is on a bridge network, not on
127.0.0.1, and an admin has no business beside replicas.

## 4. Evaluation

### 4.1 Unit tests

`test/workbench_igniter/features/db_admin_test.exs`: the refusal
without `--admin`, and one admin serving each of the four databases; each admin's file per adapter; the three
refusals (a value off its database, said with what the project has;
CloudBeaver on SQLite; an unknown name); several at once, a second
run adding one and leaving the file that is there alone, one bad value
refusing the whole run; the mark; the manifest. The resolver's list in
`requirements_test.exs`, the console's reading of it in
`cartridges_test.exs`, three new golden composes
(`dev-mysql-phpmyadmin`, `dev-db-cloudbeaver`,
`prod-mssql-adminer-cloudbeaver`) beside Adminer's and pgAdmin's.

### 4.2 Adminer, measured on 2026-09-09

With `adminer:6.0.1` and the workspace's own images (`postgres:latest`,
`mysql:8`, `mcr.microsoft.com/mssql/server:2022-latest`), Adminer
sharing the database container's network namespace as it does in the
pod, driven by `curl` through the login form (its `token` included)
and the page after it, following redirects. The file was the template
rendered by hand for each adapter.

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

### 4.3 Adminer without its password, measured on 2026-09-19 and not kept

The option of §3.5's last paragraph, with `adminer:6` (6.0.1) in the network namespace of a `pause`
container published on `127.0.0.1:18080`, the file rendered by the
installer for each adapter, opened in Chromium through `playwright-cli`
with nothing typed:

| Adapter | Landed on |
| --- | --- |
| postgres | `?pgsql=lorem_ipsum&username=postgres&db=lorem_ipsum_dev&ns=public` — `Schema: public` |
| mysql | `?server=lorem_ipsum&username=root&db=lorem_ipsum_dev` — `Database: lorem_ipsum_dev` |
| mssql (2022, database `master`) | `?mssql=lorem_ipsum&username=sa&db=master&ns=dbo` — `Schema: dbo` |
| sqlite3 (as the file's owner) | `?sqlite=lorem_ipsum&username=&db=/app/src/lorem_ipsum_dev.db` — `Database: /app/src/lorem_ipsum_dev.db` |
| postgres, the server down | the login form with "SQLSTATE[08006] … Connection refused", and still there five seconds later: no loop |

And the binding, from inside the running console container
(`workbench_console`), `curl http://host.docker.internal:PORT/`:
`adminer:6` published as `-p 127.0.0.1:18090:8080` answered `000`, the
same image as `-p 18091:8080` answered `200`; both answered `200` from
the host's `localhost`.

### 4.4 phpMyAdmin and CloudBeaver, measured on 2026-09-18

With `phpmyadmin:5` (5.2.3), `dbeaver/cloudbeaver:latest` (26.2.0) and
`postgres:latest`, `mysql:latest`,
`mcr.microsoft.com/mssql/server:2022-latest`, every container in the
network namespace of one `pause` container, as in the pod; CloudBeaver
asked through its GraphQL endpoint (`/api/gql`) from a session that
never signed in.

| Admin | On | Result |
| --- | --- | --- |
| phpMyAdmin | MySQL, `APACHE_PORT=8081`, `PMA_HOST=127.0.0.1`, the rendered `config.user.inc.php` | Apache answers on 8081; the page lands signed in — `root@127.0.0.1`, title `… / lorem_ipsum \| phpMyAdmin 5.2.3`, the workspace's database listed |
| phpMyAdmin | the same, before MySQL listens | "mysqli::real_connect(): (HY000/2002): Connection refused"; a reload once it listens lands signed in — `depends_on` orders the start, it does not wait |
| CloudBeaver | no variables | `serverConfig.configurationMode: true` — the wizard |
| CloudBeaver | `CB_SERVER_NAME`, `CB_ADMIN_NAME`, `CB_ADMIN_PASSWORD=pass`, no `CB_SERVER_URL` | `configurationMode: false`; the log says "New user created: [userId=cbadmin]" |
| CloudBeaver | MySQL, the seed mounted read-only, the two switches, `WORKBENCH_DATABASE` alone from the environment | the session lists `workbench-lorem_ipsum` (`mysql:mysql8`); `initConnection` → `connected: true`; MySQL's process list shows `root`, `127.0.0.1`, db `lorem_ipsum_dev` |
| CloudBeaver | Postgres, host, port and database from the environment | `connected: true`; `pg_stat_activity`: `postgres`, `lorem_ipsum_dev`, "CloudBeaver Community 26.2.0 - Main" |
| CloudBeaver | SQL Server 2022, the same, database `master` | `connected: true`; `sys.dm_exec_sessions` shows both CloudBeaver sessions on `master` |
| CloudBeaver | SQLite, as `1000:1000` | the server dies: "mkdir: cannot create directory ‘workspace/.metadata’: Permission denied" |
| CloudBeaver | SQLite, as `1000:0` and as `65534:0` | the server starts; `initConnection` → "Driver disabled" |

After a connection the copy in the container's workspace still held
the credentials in plain text; the project's file, mounted read-only,
cannot change either way.

### 4.5 In a workspace

On a copy of a live Postgres workspace that had pgAdmin from the old
box, with the workbench itself: `wb.sh status --json` reported
`db_admin` installed, `state: {admin: [pgadmin]}`, service `pgadmin`
— nothing migrated. `wb.sh add db_admin --admin phpmyadmin` refused:
"--admin phpmyadmin builds on ecto with database mysql, and this
project's database is postgres." `wb.sh add db_admin --admin
adminer,cloudbeaver` committed `adminer/login.php`,
`cloudbeaver/data-sources.json` and the compose in one commit, ports
8080 and 8978 published beside 5050. With the pod, the database and
the three admins up from that file (the app left down): pgAdmin
answered 200; Adminer's form came filled with `postgres` and
`lorem_ipsum_dev`; CloudBeaver was out of configuration mode, listed
the connection to a session that never signed in, answered `FATAL:
database "lorem_ipsum_dev" does not exist` on the fresh volume — the
dev database is `./wb.sh setup`'s to create — and `connected: true`
once it existed.

Earlier, on 2026-09-09, the adminer box was measured the same way:
`WORKBENCH_SERVER: 127.0.0.1:5432` and `WORKBENCH_DATABASE:
lorem_ipsum_dev` baked, `pass` landing on `Schema: public`, the mounted
directory readable by the image's `adminer` user.

### 4.6 Not measured

phpMyAdmin and CloudBeaver in a baked workspace on their own databases
(the workspace probe was Postgres; phpMyAdmin was measured beside a
bare MySQL with the rendered file); any admin on a release's pod;
Adminer on SQLite inside a baked workspace, and Adminer 6.0.2 (the
image was one patch behind); pgAdmin's sources, not re-read.

## 5. Limitations and open questions

* Every admin's port is published on the host, on every interface —
  the machine's network reaches it — signed in or behind a password
  that is on the box (`pass`). It is dev tooling; the database itself
  stays unpublished. A release's pod carries them too, as pgAdmin's
  always did: a rehearsal on the developer's machine, not a deployment
  to guard. Publishing them on loopback alone cuts the console off
  (§3.5, §4.3); closing them to the network wants the console to read
  them another way — through Docker, or on the bridge's gateway as well
  as loopback — and is open.
* CloudBeaver gives whoever opens the page the connection with ecto's
  credentials, and keeps an administrator (`cbadmin` / `pass`) for its
  own settings. What is changed in its UI lives in the container and
  goes with it.
* CloudBeaver's page remembers its tree in the browser, and every
  workspace serves it from the same origin (`localhost:8978`) under the
  same connection id (`workbench-<app>`): a tab left open from the
  project that held the port before asks for nodes the new server does
  not have — seen 2026-09-19 on a workspace remade from Postgres onto
  MySQL, *Navigator node
  `…/database/lorem_ipsum_dev_16389/schema/public_2200/table/users_16729`
  not found*, a Postgres schema and its OIDs on a MySQL that has no
  schemas. The server was right (`mysql:mysql8`, connected, its tree
  Tables/Views/Indexes/Procedures/Triggers/Events); the page was the
  stale part. Reload it after switching what is behind the port; the
  container keeps no state of its own to clean.
* CloudBeaver on SQLite is open: it takes the server's configuration
  file replaced and the container run as the file's owner with the root
  group (§3.4). If a later image gives `disabledDrivers` a variable, it
  is one line in the fragment and one value in `serves`.
* CloudBeaver's image has no major tag to pin (`latest`, or a full
  version): `CLOUDBEAVER_IMAGE_VERSION` in `config.conf` is how to hold
  one. The seed's path and the launch script's copy are the image's
  internals, read off 26.2.0.
* The dev database does not exist until `./wb.sh setup`; CloudBeaver's
  connection names it and fails until then, as Adminer's form does.
* Adminer's `ADMINER_PLUGINS` and `ADMINER_DESIGN` are not set. The
  entrypoint writes into `plugins-enabled/` for the former, which the
  read-only mount would refuse.
* On MSSQL Adminer's password is sa's, not `pass`: the server checks
  passwords, and a matched `Password` is withheld only from a server
  that requires none.
* The console's door lands on Adminer's login form; the URL could
  carry `?pgsql=<app>&username=…&db=…` [15] but never the password, so
  the form is one field either way.
* Adminer's image's `DefaultServerPlugin` regex looks for an `<input
  name='auth[server]'>`; with the field replaced by a `<select>` it
  finds nothing, harmlessly.

## References

1–18 read on 2026-09-09. The vrana/adminer files are `master` as of
that date (`VERSION = "6.1.0-dev"`), one minor ahead of the image's
6.0.1; what is quoted of them was measured to hold on 6.0.1. 19–27
read in full on 2026-09-18, the CloudBeaver wiki as its Markdown
sources (`raw.githubusercontent.com/wiki/dbeaver/cloudbeaver/`), and
the image's own files read off `dbeaver/cloudbeaver:latest` (26.2.0).
28 read on 2026-09-19.

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
    datasources* (summary only, 2026-09-09; read in full as 24 and 26).
19. phpmyadmin/docker, *README.md*. <https://github.com/phpmyadmin/docker>
20. phpmyadmin/docker, `apache/config.inc.php`.
21. phpmyadmin/docker, `apache/docker-entrypoint.sh`.
22. phpmyadmin/docker, `apache/Dockerfile`.
23. docker-library/official-images, `library/phpmyadmin`.
    <https://github.com/docker-library/official-images/blob/master/library/phpmyadmin>
24. CloudBeaver wiki, *Supported databases*.
    <https://github.com/dbeaver/cloudbeaver/wiki/Supported-databases>
25. CloudBeaver wiki, *Server configuration*.
    <https://github.com/dbeaver/cloudbeaver/wiki/Server-configuration>
26. CloudBeaver wiki, *Configuring server datasources*.
    <https://github.com/dbeaver/cloudbeaver/wiki/Configuring-server-datasources>
27. CloudBeaver wiki, *Data sources JSON reference*, *Initial data
    configuration*, *Anonymous access configuration*.
    <https://github.com/dbeaver/cloudbeaver/wiki/Data-Sources-Json-Reference>
28. vrana/adminer, `adminer/include/auth.inc.php` at `v6.0.1`: the
    login POST under `verify_token()`, `auth_error()` and the
    connection made only with a password in the session. Read
    2026-09-19.
