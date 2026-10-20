# health_probe — Design

*Revision: cartridge v0.3.0 (2026-10-20). Sources [1]–[18] consulted on
2026-08-28, [19]–[36] on 2026-10-20; quotations are verbatim from the
page or file as read then.*

## Abstract

A Phoenix application deployed behind an orchestrator or a load
balancer is asked, every few seconds, whether it is alive and whether
it can take traffic. The two questions have different consequences —
one restarts the container, the other only diverts traffic — so this
cartridge answers them on two routes, `/health/live` and
`/health/ready`, from a plug mounted as the first element of the
endpoint pipeline. Liveness checks nothing beyond the VM answering;
readiness runs `SELECT 1` on the repo with a 500 ms timeout and
answers 503 on any failure, the whole check bounded by a task since
the query's own timeout does not cover the pool's queue. Because Phoenix plugs `Plug.SSL` ahead of
every plug of the project's, both routes are also listed in
`force_ssl`'s `exclude: [paths: …]` in `config/prod.exs`, which phx.new
fills in since Phoenix 1.8.2. The design follows the platform contracts
of Kubernetes, Fly.io and AWS ECS as their documentation states them,
departs from two of the three Elixir guides surveyed on one point
(what liveness may check), and was verified twice: by installing the
generated code into a stock `phx.new` project and running its tests
against a real database (v0.1.0), and by probing a live production
deployment the way a kubelet does (v0.3.0), which is how the
`force_ssl` defect of the first two versions was found (§3.5, §4).

## 1. Problem

The workbench's `health_endpoint` cartridge answers a different need: a
JSON endpoint a developer can open in a browser, with versions,
environment and database details in development, and an entry in the
Swagger page. It is a controller behind the router.

What a project needs to be *deployed* is narrower: a route a platform
can poll, cheaply, with an answer the platform interprets correctly.
Every mainstream platform polls; none of them read a JSON body. And a
probe that costs the whole endpoint pipeline, or that answers "healthy"
when the platform should divert traffic, or "unhealthy" when the
platform should *not* restart, does harm at scale precisely because it
is called so often.

## 2. Background

### 2.1 Probes are a contract with the platform

The word *probe* is Kubernetes' — its documentation defines three, and
each one binds a different action to a failure [1]:

> "If a container fails its liveness probe more times than the
> configured tolerance, the kubelet restarts that container."

> "If the readiness probe returns a failed state, the EndpointSlice
> controller removes the Pod's IP address from the EndpointSlices of
> all Services that match the Pod." — "the Pod stops receiving traffic
> from matching Services."

> "Startup probes verify whether the application within a container is
> started. If a startup probe is configured, Kubernetes does not
> execute liveness or readiness probes until the startup probe
> succeeds."

The same page carries the warning this design is built around [1]:

> "Incorrect implementation of liveness probes can lead to cascading
> failures. This results in restarting of container under high load;
> failed client requests as your application became less scalable; and
> increased workload on remaining pods due to some failed pods."

and the task guide adds that liveness probes "must be configured
carefully to ensure that they truly indicate unrecoverable application
failure, for example a deadlock" [2]. For an `httpGet` probe, "any code
greater than or equal to 200 and less than 400 indicates success. Any
other code indicates failure" [2] — a detail that matters in §3.5. The
probe's own timeout, `timeoutSeconds`, "defaults to 1s" [19] — a
detail that matters in §3.3.

The task guide is explicit about the startup probe: it is set up "with
the same command, HTTP or TCP check" as liveness, with a
`failureThreshold * periodSeconds` "long enough to cover the worst case
startup time", and "if the startup probe never succeeds, the container
is killed" [19]. Readiness is where the guide places dependencies: an
application might "depend on external services after startup. In such
cases, you don't want to kill the application, but you don't want to
send it requests either" [19].

Fly.io has one check type per service, and its consequence is routing
only [3]:

> "A failing health check can prevent request routing to your Machine.
> However your Machines won't automatically restart or stop due to
> failing their health checks."

Its HTTP check expects "a 2xx HTTP response" [3] and, per the
configuration reference, "will not automatically follow any HTTP 301
or 302 redirect, so it will fail if it receives anything other than a
200 OK response" [4].

AWS ECS has two layers. A *container health check* is a command the
agent runs inside the container — "you must include the commands in
the container image" [5] — whose exit code sets the container, and
through it the task, to `HEALTHY` or `UNHEALTHY`. A *load balancer*
health check is an HTTP request from the ALB to a path, with defaults
of 30 s interval, 5 s timeout, 2 consecutive failures to go unhealthy,
5 consecutive successes to come back, and `200` as the only success
code [7]. When a service uses a load balancer and its task defines a
container health check, "the service scheduler waits for both the task
to reach a healthy status and the load balancer target group health
check to return a healthy status" [6]. `healthCheckGracePeriodSeconds`
is the window during which "the Amazon ECS service scheduler ignores
unhealthy Elastic Load Balancing, VPC Lattice, and container health
checks after a task has first started" [6].

Three platforms, three shapes: Kubernetes separates *restart* from
*divert*; Fly only diverts; ECS restarts on the container check and
diverts on the balancer check. An application that wants to run on all
three unchanged has to expose the two semantics as two routes and let
each platform wire the ones it has. The naming is not this cartridge's
invention: MicroProfile Health specifies the same two endpoints,
`/health/live` and `/health/ready` [20], and Spring Boot exposes the
same split as `/actuator/health/liveness` and `/readiness` [21].

### 2.2 The Phoenix endpoint is a pipeline, and `Plug.SSL` is ahead of it

`Phoenix.Endpoint` "provides an initial plug pipeline for requests to
pass through" [10]; plugs run in the order they are declared, the
router last. A `phx.new` endpoint declares, in order: `Plug.Static`,
the code reloader (dev only), `Plug.RequestId`, `Plug.Telemetry`,
`Plug.Parsers`, `Plug.MethodOverride`, `Plug.Head`, `Plug.Session` and
the router. `Plug.Conn.halt/1` "halts the Plug pipeline by preventing
further plugs downstream from being invoked" [8]: a plug that answers
and halts stops the request wherever it stands.

The `:force_ssl` endpoint option forwards to `Plug.SSL` [10], which
answers a plain-HTTP request with a redirect — "301 if the method of
conn is GET or HEAD, or 307 in other situations" [9]. Where it sits is
not in the endpoint file: `use Phoenix.Endpoint` expands to
`use Plug.Builder` followed, when `force_ssl` is set, by
`plug Plug.SSL, force_ssl` [22] — before the first line of the
project's own pipeline. No plug the project declares can run before it.

Since Phoenix 1.8.2, "[phx.new] set `force_ssl` in `prod.exs` by
default" [23]. The template the workbench's toolchain generates
(phx_new 1.8.15) writes:

```elixir
# Force using SSL in production. This also sets the "strict-security-transport" header,
# known as HSTS. If you have a health check endpoint, you may want to exclude it below.
# Note `:force_ssl` is required to be set at compile-time.
config :my_app, MyAppWeb.Endpoint,
  force_ssl: [
    rewrite_on: [:x_forwarded_proto],
    exclude: [
      # paths: ["/health"],
      hosts: ["localhost", "127.0.0.1"]
    ]
  ]
```

The `paths:` it hints at is Plug's: since Plug 1.19.0, "[Plug.SSL]
Allow excluding redirects based on hosts, paths, or the connection"
[24, 25]. Its documentation names the case — redirects to avoid "such
as requests coming from `localhost` or `127.0.0.1`, or from health
check endpoints" — and warns that the default
`[hosts: ["localhost", "127.0.0.1"]]` is replaced, not extended, by any
`exclude` given [9]. A path is matched whole: the option is split into
segments at `init/1` and tested as `conn.path_info in paths` [26], so
`"/health"` excludes `/health` and not `/health/live`.

Before 1.19 there was no such option. The request for one dates from
2019, for a GKE health check answered with a 301; Plug's maintainer
declined it as "a slippery slope" and suggested wrapping `Plug.SSL` in
a function plug of the endpoint that skips the health path, or serving
health checks on another port [27]. The issue was marked possible in
1.19 the day it shipped [27].

### 2.3 Prior art in Elixir

Three guides were read in full. Jola [13] mounts a `HealthCheck` plug
at the top of the endpoint that answers `/health_check` with an empty
200 and halts, arguing from cost: the check runs often (the post cites
ECS polling "around 6 times a second" on its setup), so it should
"short circuit" everything downstream and, executing before
`Plug.Logger`, produce no log line. Naseer [14] and Cogini [15] follow
the Kubernetes vocabulary — startup, liveness, readiness — and expose
them through a plug rather than a controller; both run `SELECT 1` on
the repo. Cogini's guide accompanies a library that packages the
three probes behind a callback module [18]; `healthchex` [16] offers
liveness and readiness as plugs; `plug_checkup` [17] offers named
checks with timeouts and a JSON report.

The guides disagree on one point. Naseer's `is_alive?/0` and Cogini's
`liveness/0` both query the database, and Cogini states that liveness
"should include checks for dependencies, e.g., whether the app can
connect to a database" [15]. The Kubernetes documentation says the
opposite: liveness should indicate "unrecoverable application failure,
for example a deadlock" [2], and dependency-driven liveness is the
textbook case of the cascading failure it warns about [1]. This design
follows the platform documentation (§3.2).

None of the three addresses `force_ssl`. Advice on it in forums
predates Plug 1.19: mount the health plug before `Plug.SSL` — which
holds only where `Plug.SSL` is plugged by hand, not through
`force_ssl` (§2.2) — wrap `Plug.SSL` as [27] suggests, or widen the
balancer's success codes to 200–399 [28].

### 2.4 How long a query waits for a connection

What a query's `:timeout` bounds is not in Ecto's documentation, which
gives it as "Execute request timeout" [12]; it is in DBConnection's
code [29]. The caller computes an absolute deadline from `:timeout`
when it asks the pool for a connection, but the timer that enforces it
is started only once a connection is handed over (`start_deadline/5`);
until then the caller waits in a `receive` with no `after`. A query
that finds a free connection is bounded by its `:timeout`, queue time
included. A query that finds none waits in the pool's queue, and only
the pool can drop it.

The pool drops by CoDel, "Controlled Delay" [29, 35]: an algorithm
from network queues, built to tell "the necessary, useful 'good'
queue" — a burst that drains — from the "bad" one that stands and only
adds delay [35]. One slow request does not tell them apart, so CoDel
watches the queue over an interval. DBConnection's pool checks every
`:queue_interval` (2 000 ms by default) whether its queue moved; when
the shortest wait over a whole interval stayed above `:queue_target`
(50 ms) it marks itself slow and drops every request queued for longer
than twice the target, with the error "connection not available and
request was dropped from queue after …ms", whose first suggested cause
is "Ensuring your database is available" [29]. The interval is the
price of not dropping bursts; the RFC sets its target at 5–10 % of the
interval [35], DBConnection at 2.5 %, tuned for web requests that have
fifteen seconds to wait.

A database that is down is, to the pool, the extreme of overload: no
connection ever comes back, the queue never moves, and a request waits
for the check that measures the delay and the next one that drops it —
two intervals, about four seconds. Measured in §4.3. Both values are
the repo's (`queue_target`, `queue_interval` in its configuration), so
they apply to every query of the application; per call there is only
`queue: false`, which fails at once when no connection is free [11].

## 3. Design

### 3.1 Two routes, split by consequence

`GET /health/live` and `GET /health/ready`, under one configurable
prefix. The split is not decorative: it is the only way one release can
give each platform the semantics that platform acts on. Kubernetes
wires both, and points its startup probe at `/live` as its guide does
(§2.1): a startup probe that fails kills the container, so pointed at
`/ready` it would restart pods whose database is down during a deploy —
the restart on a dependency that §3.2 keeps out of liveness. Readiness
is not lost by that: Kubernetes does not run it until the startup
probe has passed, and then it holds traffic back until `/ready` says
yes. Fly wires `/ready`; ECS wires `/ready` on the balancer and,
optionally, `/live` on the container check.

A single route would force a choice between two wrong answers: a
liveness-only check that keeps routing traffic to an instance whose
database is gone, or a readiness-only check that restarts every
replica when the database is gone.

### 3.2 Liveness checks nothing

`/live` answers 200 with no other condition than the request reaching
the plug. The BEAM answering a request on the endpoint *is* the
liveness signal: the scheduler runs, the acceptor pool runs, the
endpoint is compiled and started.

The alternative — checking the database — was rejected on the
Kubernetes warning quoted in §2.1. A database outage would make every
orchestrator restart every replica, repeatedly, and no restart brings
the database back; meanwhile the application's other work (static
assets, cached reads, queues draining) is killed along with it.
Readiness carries the dependency instead: failing it diverts traffic
without killing anything, and the instance comes back by itself when
the dependency does.

What liveness does not detect: a deadlocked GenServer the endpoint
does not depend on, a full mailbox, a stuck scheduler. Those are real
failures, and they are the ones a *specific* liveness check would
target. The cartridge does not guess which process matters to a given
project; `ready?/1` is the place to add that knowledge, and the
`@moduledoc` says so.

### 3.3 Readiness is `SELECT 1` with a 500 ms timeout

`/ready` answers 200 when `repo.query("SELECT 1", [], timeout: 500)`
returns `{:ok, _}` within 500 ms, and 503 otherwise. The query runs in
a `Task`; the plug waits for it with `Task.yield/2` for the same
500 ms and kills it with `Task.shutdown/2` if it has not answered.
`Ecto.Adapters.SQL.query/4` returns `{:ok, result} | {:error,
Exception.t()}` with a default `:timeout` of 15 000 ms [12].

The task is what makes the timeout a bound. The query's own
`:timeout` holds only once the pool hands over a connection (§2.4):
with the database down there is none to hand, and without the task the
probe answered its 503 after about four seconds — the pool's two CoDel
intervals — long after a kubelet with its one-second default had given
up on it (§4.3). Three ways to bound it were weighed:

1. **A task around the query.** Chosen. It bounds the whole check, the
   queue included, whatever the pool does; the query keeps its own
   `:timeout` for the time after the checkout. Its cost is one process
   per probe, and a request left in the pool's queue when the task is
   killed — the pool finds its caller gone when it gets to it and
   serves the next one.
2. **`queue: false`.** A 503 at once when no connection is free. But a
   pool that is merely *busy* — every connection in use, one free ten
   milliseconds later — gives the same answer, so readiness would flap
   under load, exactly when the platform reads it most.
3. **A shorter `queue_interval` in the repo's configuration.** It
   would make the whole application fail faster with the database
   down, and drop more of the bursts it now absorbs. It is the
   project's policy for every query, and a probe has no business
   setting it; the probe is the one caller that must answer within a
   second.

The value has to fit inside the platform's own timeout. Kubernetes'
`timeoutSeconds` defaults to 1 s [19]; Fly's and the ALB's are set per
check (the ALB's default is 5 s [7]). Up to v0.2 the query waited one
second — the whole of Kubernetes' default, so a slow database ended in
the kubelet's timeout rather than the plug's 503. 500 ms leaves half
of that second for HTTP, the kubelet and a container whose CPU is
throttled. A healthy `SELECT 1` takes a few milliseconds on a
database in the same region and tens to a hundred or so across
regions; past half a second, 503 is the answer the platform should
get. The lower bound has a cost too: a query that times out has its
connection closed by the pool [29], so a timeout set too tight would
make every latency spike cost the database a reconnection. 750 ms was
considered and left: it would work, with a quarter of the margin.

`ready?/1` also rescues any exception and catches any exit, returning
`false`: a repo process that is not started, a pool that raises
instead of returning `{:error, _}`, an adapter surprise. A probe must
never produce a 500 from the check itself — that is a crash report the
platform reads as "unhealthy" too, but with a stack trace nobody asked
for and a wrong reason.

Why `SELECT 1` and not a query on a table: it exercises the connection,
the pool and the server's ability to answer, which is what "can take
traffic" means for a database-backed app, without depending on schema.
A migration check is deliberately absent (§5).

Whether readiness should check the database at all is not settled in
practice. Kubernetes' guide gives an external service as the case for
it (§2.1). Against it, operators report that a database shared by
every replica makes every replica unready at once: the Service is left
with no endpoints, and a short database outage becomes a total one,
with clients refused at the door instead of answered by the
application [30, 31, 32]. For it, a per-pod check takes out the one
replica that lost its own path to the database while the others keep
serving [33]. The cartridge checks, because a database-backed Phoenix
application that cannot reach its repo answers most requests with an
error, and the platform's thresholds (`failureThreshold`, the ALB's
two consecutive failures) are where a project tunes how long a blip
may last before traffic moves. §5 records the open side.

### 3.4 A plug mounted first, not a controller

The plug is declared before `Plug.Static`, the first plug of a
`phx.new` endpoint. Everything below it — static file lookup, request
id, telemetry event, body parsing, method override, session, router
dispatch — never runs for a probe. The gains are the ones Jola argues
[13]: no log line per probe (the telemetry-driven logger sits below),
no telemetry event polluting request metrics, no session cookie
minted, and no CPU on parsing. A controller behind the router pays all
of that, several times a minute per replica, forever.

What mounting first does *not* buy is a place ahead of `Plug.SSL`
(§2.2, §3.5). Up to v0.2 this paper, the README and both moduledocs
said it did.

The cost is that the probe is invisible to the router: `mix
phx.routes` does not list it, and router pipelines (`:api`,
authentication) cannot apply. That is intended — a probe must be
reachable without credentials and without a session — but it is a
surprise for someone who greps the router for the route, which is why
the endpoint carries a comment above the `plug` line.

`socket` declarations are not part of the plug pipeline, so the plug
is placed after them; the installer looks for the first `plug` call in
the endpoint's scope rather than the first line, which keeps it correct
for endpoints whose declarations are reordered.

### 3.5 Redirects: the probes are excluded from `force_ssl`

With `force_ssl` on, a probe arriving in plain HTTP on the internal
port is answered by `Plug.SSL` with a 301 before any plug of the
project's runs (§2.2). Probes arrive that way: a kubelet or a balancer
calls the pod's own address, without `X-Forwarded-Proto`, and
`Plug.SSL` spares only `localhost` and `127.0.0.1` by default [9].
What follows differs by platform, and none of the outcomes is
acceptable:

* Fly fails on "anything other than a 200 OK" [4]: the instance never
  receives traffic.
* The ALB's default matcher is `200` [7]: same.
* Kubernetes counts 200–399 as success [2]: the probe *passes* without
  the application having answered anything. A dead router, an
  unreachable database, and the pod stays in rotation.

Measured on a live deployment in §4.2: both routes answered 301 to a
request carrying the pod's address, and `/ready` kept answering 301
with the database stopped.

Four ways out were weighed:

1. **`exclude: [paths: …]` in `force_ssl`, both routes listed.**
   Chosen. It is Plug's own option for the case (§2.2) and the one
   Phoenix's template points at; whoever opens `prod.exs` reads which
   routes skip HTTPS without opening another file. Its cost is that
   the prefix lives in two places, the plug and `prod.exs`: changing
   one by hand and not the other brings the 301 back, silently, since
   from `localhost` everything still answers. The plug's moduledoc and
   the README say so.
2. **`exclude: [conn: {MyAppWeb.Plugs.Health, :probe?, []}]`.** The
   plug would decide what a probe is, and the exclusion would match
   what it answers. Rejected: the plug takes its prefix as an option
   (`plug Health, path: …`), which a function called by `Plug.SSL`
   never sees, so the single source would need the option removed;
   and `prod.exs` would show a tuple where a reader expects paths.
3. **Wrapping `Plug.SSL`** as [27] suggests. Superseded by (1) since
   Plug 1.19, and it replaces `force_ssl` in the endpoint rather than
   configuring it.
4. **A notice and a README line, no edit.** Rejected: the defect would
   stay on by default in every phx.new project, and the cartridge
   exists so that a probe works on a platform.

The installer edits `prod.exs` inside the `config` call that holds
`force_ssl`, and only where one does: an existing `exclude` gets the
two routes appended to its `paths` (created if absent), keeping its
other entries; a missing `exclude` is written with the routes *and*
Plug's default hosts, since a new `exclude` replaces them (§2.2). The
call is found by its arguments — the app, the endpoint, a keyword with
`force_ssl` — because a project with assets has two `config` calls for
the endpoint, `cache_static_manifest` first; Igniter's configuration
API, tried first, wrote the nested key into that one (§4.3). Phoenix's
commented `# paths: ["/health"]` is left where it is: the
configuration API works on the syntax tree, where a comment is not a
node, and replacing it would mean matching a line of text that the
next phx.new may word differently. Paths are matched whole (§2.2), so
the hint's `/health` would not have covered the probes anyway. The
option needs Plug 1.19, which any project generated since Phoenix
1.8.2 — the first to set `force_ssl` by default — already carries.

### 3.6 The answer

Plain text, `ok` / `unavailable`, with `Cache-Control: no-store`. No
platform reads the body; a human with `curl` does, and an empty 200
tells them nothing. `no-store` is defensive: a proxy between the
platform and the pod must not reuse a verdict.

JSON with details was rejected for this cartridge because every field
is either a cost (a database version needs a query), a leak (versions
and environment on an unauthenticated route) or a lie (a static `"ok"`
in JSON is not more machine-readable than `ok`). The `health_endpoint`
cartridge exists for the case where that body is wanted.

### 3.7 What is deliberately absent

* **No startup route.** Kubernetes' startup probe uses liveness's
  check with a longer patience (§2.1), and `/live` serves it. A
  separate route would only make sense with a boot-phase flag the
  application sets, which is application knowledge.
* **No `?verbose`, no per-environment body.** See §3.6.
* **No authentication, no rate limiting.** Probes come from inside the
  network, unauthenticated, at a rate the platform decides.
* **No dependency, one line of configuration.** `Plug` ships with
  Phoenix, and the plug's options are literals in the generated module
  so the project owns them. The one configuration it writes is the
  `force_ssl` exclusion of §3.5, and only where `force_ssl` is set.
* **No compose change.** The workspace compose probes the app with a
  TCP connect on the internal port because the images carry no curl; a
  TCP connect is liveness by another name and needs nothing from this
  cartridge.

## 4. Evaluation

### 4.1 Automated

The **cartridge test** (`test/workbench_igniter/features/health_probe_test.exs`,
25 cases) runs the installer against Igniter's in-memory Phoenix
project and against projects generated by `phx.new` itself, and
asserts on the patch set and on the code it writes: the two files and
their contents, the endpoint line and its position before
`Plug.Static` and the router, the `--path` override in every spelling,
the no-repo variant, idempotency with the notice, and the plug
compiled and called against repos that answer, fail, raise and are
gone. Since v0.3.0 it also builds `Plug.SSL` from the `prod.exs` the
installer leaves and sends it a probe as a kubelet does — plain HTTP to
`10.0.0.7` — asserting that phx.new's own `prod.exs` redirects it and
the cartridge's does not, for `/health`, `/status` and the root prefix,
on a project without assets (one `config` for the endpoint in
`prod.exs`) and one with them (two); that the routes land in the
`exclude` of the block that holds `force_ssl`, read as text, and the
`cache_static_manifest` block is left as it was;
that the rest of the site, and `/health/live/x`, still redirect; that
`localhost` is still spared; that an existing `exclude` keeps its
entries; that a missing one is written with Plug's default hosts; that
a `prod.exs` without `force_ssl` is left byte for byte; and that
Phoenix's commented hint stays.

The **generated code** was verified on 2026-08-28 (v0.1.0) by
installing the cartridge into a stock `mix phx.new` project
(Elixir 1.19.5 / OTP 27, Phoenix 1.8) with `workbench_igniter` as a
path dependency, compiling with `--warnings-as-errors`, and running the
project's full suite against a local PostgreSQL: 12 tests, 0 failures,
the 7 generated ones among them. The project's own formatter wrote the
endpoint line as `plug ProbeWeb.Plugs.Health`, without parentheses.
That project was generated before Phoenix 1.8.2 and had no `force_ssl`,
which is why the run could not see §3.5.

### 4.2 The live run that found the redirect

2026-10-20, workspace `_001` (`lorem_ipsum`: Phoenix 1.8.15,
Plug 1.20.3, health_probe v0.2.1 inserted), `./wb.sh up --deploy prod`:
the release image, `force_ssl` from phx.new's `prod.exs`, the app
published on `localhost:4000`. Requests in plain HTTP with `curl`; the
`Host` header set to an address that is not `localhost` is what a
kubelet or a balancer sends when it calls the pod:

| Request | `/health/live` | `/health/ready` |
| --- | --- | --- |
| `Host: localhost` | 200 | 200 |
| `Host: 10.0.0.7:4000` | 301 → `https://localhost/health/live` | 301 → `https://localhost/health/ready` |
| `Host: 10.0.0.7:4000`, `X-Forwarded-Proto: https` | 200 | 200 |

With the database container stopped, `/health/ready` answered
`503 unavailable` from `localhost` and `301` with the pod's address —
the false pass of §3.5. Started again, `ok 200`. Every hand check made
from the developer's machine goes through `localhost`, which is why
the defect survived two versions.

### 4.3 The fixed cartridge, live

2026-10-20, a copy of `_001` as `claude_probe_hp` (its own compose
project, image and ports), health_probe ejected and inserted again
from this tree, the release built and up. With the pod's address as
`Host`: `/health/live` and `/health/ready` 200; `/` and
`/health/live/x` still 301; with the database container stopped,
`/ready` 503 and `/live` 200; started again, `/ready` 200.

Readiness with the database stopped, six probes a second or two
apart, with the query alone bounded by its `:timeout`: 503 after
4.08, 3.99, 3.99, 3.99, 3.99 and 3.99 s — the pool's two intervals
(§2.4). With the task around it: 503 after 0.501–0.502 s, six times;
with the database up, 200 in about 1 ms.

The test the cartridge writes into the project was run there, against
its PostgreSQL through the Ecto sandbox: 8 tests, 0 failures, among
them the database answering through the task (the sandbox follows the
task by `$callers`) and a repo that never answers, 503 within a
second.

The same run found that a project with assets has two
`config :app, MyAppWeb.Endpoint` blocks in `prod.exs` — the
`cache_static_manifest` one and the `force_ssl` one — and that the
installer wrote the exclusion into the first. The effective
configuration was right, since `Config` merges the two blocks deeply,
but it sat away from `force_ssl`; the automated test had only a
project without assets, which has one block. The installer now edits
the block that holds `force_ssl` (§3.5) and the test covers both
shapes; inserted again in the copy, the diff of `prod.exs` is the one
line inside that `exclude`, and the probes answered as above — 200,
301 for the rest of the site, 503 in 0.50 s with the database
stopped.

**Not measured.** The cost
difference between a probe answered by this plug and one answered by a
controller behind the router: argued from the pipeline, not from
numbers. The 500 ms timeout against a database under real load.

## 5. Limitations and open questions

* **Readiness on a shared database** can take every replica out of
  rotation at once (§3.3). The cartridge checks; a project whose
  replicas share one database and would rather serve errors than
  refuse connections can make `ready?/1` answer `true`, or raise the
  platform's failure threshold. Which default serves more projects is
  open.
* **The prefix lives in two places**, the plug and `prod.exs` (§3.5).
  The installer writes both; a hand edit of one is not caught.
  `force_ssl` turned on after the cartridge was inserted is not caught
  either: the exclusion has to be added by hand, as the plug's
  moduledoc says.
* `SELECT 1` proves the database answers, not that the schema is the
  one the release expects. A pending-migrations check (`Ecto.Migrator`)
  would make readiness stricter at the price of a catalog query per
  probe; whether that belongs in a probe or in the deploy pipeline
  (`release_command`, a migration job) is left open — the workbench's
  `scaled` deployment runs migrations before the replicas start, which
  argues for the pipeline.
* The 500 ms timeout is a constant in the generated module. A project
  whose database is legitimately slower will see 503s from readiness
  before requests actually fail; the attribute is where it can be
  tuned.
* Multiple repos (`:ecto_repos` with more than one entry) are not
  handled: the plug checks `MyApp.Repo`. A project with several would
  extend `ready?/1`.
* The plug matches `request_path` exactly; `/health/live/` with a
  trailing slash passes through to the router and 404s. Platforms send
  the path as configured, so this is a footgun only for hand-typed
  URLs.
* Liveness cannot see a stuck process the endpoint does not depend
  on (§3.2). That is a property of every generic liveness check, not
  of this one, but it should not be mistaken for coverage.
* **Shutdown is not covered.** Some guides have readiness fail once
  SIGTERM arrives so that traffic drains first; others hold that
  Kubernetes already removes a terminating pod from its endpoints and
  that a `preStop` delay is what matters [34]. The plug does neither.

## 6. Relation to `health_endpoint`

The two cartridges do not share a file or a route and can be
installed together. `health_endpoint` is the developer's endpoint: JSON,
versions, `?verbose`, Swagger. `health_probe` is the platform's. A
project that only deploys needs the second; a project whose team opens
`/health` in a browser may want both. Neither knows about the other.

## References

Read in full on 2026-08-28.

1. Kubernetes, *Liveness, Readiness, and Startup Probes*.
   <https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/>
2. Kubernetes, *Configure Liveness, Readiness and Startup Probes*.
   <https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/>
3. Fly.io, *Health Checks*.
   <https://fly.io/docs/reference/health-checks/>
4. Fly.io, *App configuration (fly.toml)*, section `http_service.checks`.
   <https://fly.io/docs/reference/configuration/>
5. AWS, *Determine Amazon ECS task health using container health checks*.
   <https://docs.aws.amazon.com/AmazonECS/latest/developerguide/healthcheck.html>
6. AWS, *Amazon ECS service definition parameters*, `minimumHealthyPercent`
   and `healthCheckGracePeriodSeconds`.
   <https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service_definition_parameters.html>
7. AWS, *Health checks for Application Load Balancer target groups*.
   <https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html>
8. Plug, *Plug.Conn* — `halt/1`, `request_path`.
   <https://hexdocs.pm/plug/Plug.Conn.html>
9. Plug, *Plug.SSL* — redirect status, `:exclude` (re-read on
   2026-10-20 in the Plug 1.20.3 source for the hosts/paths/conn forms).
   <https://hexdocs.pm/plug/Plug.SSL.html>
10. Phoenix, *Phoenix.Endpoint* — the plug pipeline, `:force_ssl`.
    <https://hexdocs.pm/phoenix/Phoenix.Endpoint.html>
11. DBConnection, *DBConnection* — `:queue_target`, `:queue_interval`, `:timeout`.
    <https://hexdocs.pm/db_connection/DBConnection.html>
12. Ecto SQL, *Ecto.Adapters.SQL* — `query/4`.
    <https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.html>
13. Jola, *Health checks for Plug and Phoenix*.
    <https://jola.dev/posts/health-checks-for-plug-and-phoenix>
14. Sheharyar Naseer, *Kubernetes Health Checks in Elixir & Phoenix*.
    <https://shyr.io/blog/kubernetes-health-probes-elixir/>
15. Cogini, *Kubernetes Health Checks for Elixir Apps*.
    <https://www.cogini.com/blog/kubernetes-health-checks-for-elixir-apps/>

Surveyed by their repository pages, not read in full:

16. `healthchex` — liveness and readiness probes as plugs.
    <https://github.com/KamilLelonek/healthchex>
17. `plug_checkup` — named checks with timeouts and a JSON report.
    <https://github.com/ggpasqualino/plug_checkup>
18. `kubernetes_health_check` — the library behind [15].
    <https://github.com/cogini/kubernetes_health_check>

Read on 2026-10-20:

19. Kubernetes, *Configure Liveness, Readiness and Startup Probes* —
    the sections *Protect slow starting containers with startup probes*
    and *Define readiness probes*, and `timeoutSeconds`, read in the
    page's source.
    <https://github.com/kubernetes/website/blob/main/content/en/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes.md>
20. Eclipse MicroProfile Health 2.1, specification. **Summary only**;
    quoted for the two endpoint names.
    <https://download.eclipse.org/microprofile/microprofile-health-2.1/microprofile-health-spec.html>
21. Spring, *Liveness and Readiness Probes with Spring Boot*.
    **Summary only**; quoted for the two endpoint names.
    <https://spring.io/blog/2020/03/25/liveness-and-readiness-probes-with-spring-boot/>
22. Phoenix 1.8.13, `lib/phoenix/endpoint.ex` — `plug/0`, the quoted
    block `use Plug.Builder` … `plug Plug.SSL, force_ssl` (line 485),
    and `__force_ssl__/2`. Read in the console's `deps/phoenix`.
23. Phoenix, *CHANGELOG* for v1.8, entry of v1.8.2 (2025-11-26).
    **Summary only**; the one entry quoted.
    <https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md>
24. Plug, *CHANGELOG*, entry of v1.19.0 (2025-12-08). **Summary only**;
    the one entry quoted.
    <https://github.com/elixir-plug/plug/blob/main/CHANGELOG.md>
25. Plug, commit `a6d285c`, *the `:exclude` option with hosts, paths
    and conn*. **Summary only**.
    <https://github.com/elixir-plug/plug/commit/a6d285c>
26. Plug 1.20.3, `lib/plug/ssl.ex` — `validate_exclude!/1` and
    `excluded?/2`. Read in the console's `deps/plug`.
27. elixir-plug/plug issue #815, *Plug.SSL: exclude paths* (2019–2025).
    **Summary only**; the maintainer's answer quoted.
    <https://github.com/elixir-plug/plug/issues/815>
28. Elixir Forum, *AWS SSL Healthcheck*. **Summary only**.
    <https://elixirforum.com/t/aws-ssl-healthcheck/14771>
29. DBConnection 2.10.2, `lib/db_connection/holder.ex` (`checkout/3`,
    `abs_timeout/2`, `checkout_call/5`, `start_deadline/5`) and
    `lib/db_connection/connection_pool.ex` (the moduledoc's CoDel,
    `@queue_target`, `@queue_interval`, the poll in `handle_info/2`,
    `timeout/5`, `drop_slow/3`, `drop/2` and its message; and
    `handle_info({:timeout, deadline, …})`: "client … timed out because
    it queued and checked out the connection for longer than …ms",
    then `Holder.handle_disconnect/2`). Read in `igniter/deps`.

Practitioners' posts on readiness and shutdown, read through a search
summary on 2026-10-20 — reports and opinions, not documentation:

30. *The pod that lied: a Kubernetes readiness probe war story*.
    <https://dev.to/devopsaitoolkit/the-pod-that-lied-a-kubernetes-readiness-probe-war-story-4kfg>
31. *Kubernetes Readiness Probes — Examples & Common Pitfalls*.
    <https://itnext.io/kubernetes-readiness-probes-examples-common-pitfalls-136e3a9a058d>
32. Encore, *Kubernetes horror stories*. <https://encore.dev/blog/horror-stories-k8s>
33. *Readiness Probe in Kubernetes: Encoding Dependencies or Not?*
    <https://fr.linkedin.com/in/jlcfontaine>
34. *Kubernetes graceful shutdown: handling SIGTERM and pod termination*.
    <https://jorijn.com/en/knowledge-base/kubernetes/troubleshooting/kubernetes-graceful-shutdown-sigterm-pod-termination/>

Read on 2026-10-20 for the pool's queue:

35. IETF, RFC 8289, *Controlled Delay Active Queue Management*.
    **Summary only**; quoted for good and bad queue, the interval and
    the target as a share of it. <https://www.rfc-editor.org/rfc/rfc8289.html>
36. Elixir Forum, *What does queue_target and queue_interval exactly
    mean in DBConnection?* **Summary only**: users' readings, no
    maintainer's. <https://forum.elixirforum.com/t/what-does-queue-target-and-queue-interval-exactly-mean-in-dbconnection/33682>
