# healthcheck2 — Design

*Revision: cartridge v0.1.0 (2026-08-28). Sources consulted on that
date; quotations are verbatim from the page as read then.*

## Abstract

A Phoenix application deployed behind an orchestrator or a load
balancer is asked, every few seconds, whether it is alive and whether
it can take traffic. The two questions have different consequences —
one restarts the container, the other only diverts traffic — so this
cartridge answers them on two routes, `/health/live` and
`/health/ready`, from a plug mounted as the first element of the
endpoint pipeline. Liveness checks nothing beyond the VM answering;
readiness runs `SELECT 1` on the repo with a one-second timeout and
answers 503 on any failure. The design follows the platform contracts
of Kubernetes, Fly.io and AWS ECS as their documentation states them,
departs from two of the three Elixir guides surveyed on one point
(what liveness may check), and was verified by installing the
generated code into a stock `phx.new` project and running its tests
against a real database.

## 1. Problem

The workbench's existing `healthcheck` cartridge grew out of a
different need: a JSON endpoint a developer can open in a browser,
with versions, environment and database details in development, and
an entry in the Swagger page. It is a controller behind the router,
composed by the opinionated `workbench.setup`.

The vanilla edition of the workbench (`new2`, `setup2`) starts from a
stock `phx.new` project and adds features one at a time, each doing
one thing. What that project needs to be *deployed* is narrower than
what `healthcheck` offers: a route a platform can poll, cheaply, with
an answer the platform interprets correctly. Every mainstream platform
polls; none of them read a JSON body. And a probe that costs the whole
endpoint pipeline, or that answers "healthy" when the platform should
divert traffic, or "unhealthy" when the platform should *not* restart,
does harm at scale precisely because it is called so often.

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
other code indicates failure" [2] — a detail that matters in §3.5.

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
each platform wire the ones it has.

### 2.2 The Phoenix endpoint is a pipeline

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
conn is GET or HEAD, or 307 in other situations" — except for hosts in
its `:exclude` list, `["localhost", "127.0.0.1"]` by default [9].

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

## 3. Design

### 3.1 Two routes, split by consequence

`GET /health/live` and `GET /health/ready`, under one configurable
prefix. The split is not decorative: it is the only way one release can
give each platform the semantics that platform acts on. Kubernetes
wires both (and reuses `/ready` for its startup probe, which needs the
dependencies too); Fly wires `/ready`; ECS wires `/ready` on the
balancer and, optionally, `/live` on the container check.

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

### 3.3 Readiness is `SELECT 1` with a one-second timeout

`/ready` answers 200 when `repo.query("SELECT 1", [], timeout: 1_000)`
returns `{:ok, _}` and 503 otherwise. `Ecto.Adapters.SQL.query/4`
returns `{:ok, result} | {:error, Exception.t()}` with a default
`:timeout` of 15 000 ms [12].

The timeout is the point. Platforms give a probe two to five seconds
(Kubernetes `timeoutSeconds` defaults to 1 s; the ALB to 5 s [7]). A
readiness check that waits on the pool's queue — DBConnection's
`:queue_target` is 50 ms and `:queue_interval` 2 000 ms, and it
"doubles the queue_target" when checkouts run over it before dropping
requests [11] — would fail the probe by *timeout* while still holding
the connection it eventually gets. One second makes the plug answer
503 inside the platform's window, on its own terms, and release the
caller.

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

### 3.4 A plug mounted first, not a controller

The plug is declared before `Plug.Static`, the first plug of a
`phx.new` endpoint. Everything below it — static file lookup, request
id, telemetry event, body parsing, method override, session, router
dispatch — never runs for a probe. The gains are the ones Jola argues
[13]: no log line per probe (the telemetry-driven logger sits below),
no telemetry event polluting request metrics, no session cookie
minted, and no CPU on parsing. A controller behind the router pays all
of that, several times a minute per replica, forever.

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

### 3.5 Redirects: why "before `Plug.SSL`" matters

With `force_ssl` on, a probe arriving in plain HTTP on the internal
port would be answered by `Plug.SSL` with a 301 before reaching any
plug declared after it [9]. Mounted first, the health plug answers
before the redirect. What would otherwise happen differs by platform,
and none of the outcomes is acceptable:

* Fly fails on "anything other than a 200 OK" [4]: the instance is
  diverted for a configuration reason.
* The ALB's default matcher is `200` [7]: same.
* Kubernetes counts 200–399 as success [2]: the probe *passes* without
  the application having answered anything. A dead router, an
  unstarted repo, and the pod stays in rotation.

`Plug.SSL` excludes `localhost` and `127.0.0.1` by default [9], so an
ECS container check through the loopback interface [5] would be spared
either way; probes from a kubelet or a balancer arrive on the pod's
own address and would not.

### 3.6 The answer

Plain text, `ok` / `unavailable`, with `Cache-Control: no-store`. No
platform reads the body; a human with `curl` does, and an empty 200
tells them nothing. `no-store` is defensive: a proxy between the
platform and the pod must not reuse a verdict.

JSON with details was rejected for this cartridge because every field
is either a cost (a database version needs a query), a leak (versions
and environment on an unauthenticated route) or a lie (a static `"ok"`
in JSON is not more machine-readable than `ok`). The `healthcheck`
cartridge exists for the case where that body is wanted.

### 3.7 What is deliberately absent

* **No startup route.** Kubernetes' startup probe is a different
  *schedule* on the same question as readiness — "is the app up, with
  its dependencies" — and `/ready` serves it. A separate route would
  only make sense with a boot-phase flag the application sets, which
  is application knowledge.
* **No `?verbose`, no per-environment body.** See §3.6.
* **No authentication, no rate limiting.** Probes come from inside the
  network, unauthenticated, at a rate the platform decides.
* **No dependency and no configuration.** `Plug` ships with Phoenix,
  and the plug's options are literals in the generated module so the
  project owns them.
* **No compose change.** The workspace compose probes the app with a
  TCP connect on the internal port because the images carry no curl; a
  TCP connect is liveness by another name and needs nothing from this
  cartridge.

## 4. Evaluation

Two levels, both automated.

The **cartridge test** (`test/workbench_igniter/features/healthcheck2_test.exs`,
8 cases) runs the installer against Igniter's in-memory Phoenix
project and asserts on the patch set: the two files and their contents,
the endpoint line and its position before `Plug.Static` and the router,
the `--path` override, the no-repo variant (`Igniter.rm` of `lib/test/repo.ex`
before composing), and idempotency with the notice.

The **generated code** was verified on 2026-08-28 by installing the
cartridge into a stock `mix phx.new` project (Elixir 1.19.5 / OTP 27,
Phoenix 1.8) with `workbench_igniter` as a path dependency, compiling
with `--warnings-as-errors`, and running the project's full suite
against a local PostgreSQL: 12 tests, 0 failures, the 7 generated ones
among them — both routes through the endpoint (`/live` asserting the
conn was halted there), 503 with a repo returning `{:error, _}` and
with one raising, the pass-through of other paths, and `POST` on a
probe path not being a probe. The project's own formatter wrote the
endpoint line as `plug ProbeWeb.Plugs.Health`, without parentheses.

**Not measured.** The cost difference between a probe answered by this
plug and one answered by a controller behind the router. It is argued
from the pipeline, not from numbers; a benchmark would strengthen §3.4
and could weaken it for very low probe rates.

## 5. Limitations and open questions

* `SELECT 1` proves the database answers, not that the schema is the
  one the release expects. A pending-migrations check (`Ecto.Migrator`)
  would make readiness stricter at the price of a catalog query per
  probe; whether that belongs in a probe or in the deploy pipeline
  (`release_command`, a migration job) is left open — the workbench's
  `scaled` deployment runs migrations before the replicas start, which
  argues for the pipeline.
* The one-second timeout is a constant in the generated module. A
  project whose pool legitimately queues longer under load will see
  503s from readiness before requests actually fail; that is the
  intended signal (shed traffic before it times out), but it is a
  policy the project may want to tune, so the attribute is where it can
  be.
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

## 6. Relation to `healthcheck`

The two cartridges do not share a file or a route and can be
installed together. `healthcheck` is the developer's endpoint: JSON,
versions, `?verbose`, Swagger. `healthcheck2` is the platform's. A
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
9. Plug, *Plug.SSL* — redirect status, `:exclude`.
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
