# clustering

Boots the production release as a **named distributed node**, so the
replicas of a deployment find each other.

Standalone cartridge: no setup composes it. Install it on demand with

```sh
./wb.sh add clustering
mix workbench.install.clustering --dns-query my-app.internal
```

> **A workspace runs a single `app` container**, so there is nothing to
> cluster with locally — this prepares the project for a real
> multi-replica deployment. Every replica must run the same image: the
> release cookie is baked at `mix release` time and all nodes have to
> share it.

## Why it exists

`phx.new` ships nine tenths of cluster discovery already:

| Piece | Where it comes from |
| --- | --- |
| `{:dns_cluster, "~> 0.2"}` | `mix.exs`, from `phx.new` |
| `{DNSCluster, query: ... \|\| :ignore}` | the app's supervision tree |
| `DNS_CLUSTER_QUERY` read into `:dns_cluster_query` | `config/runtime.exs`, inside its `:prod` block |

What it leaves open is the release booting in distributed mode. Without
it `Node.connect/1` has nothing to work with and DNSCluster says so
itself at boot:

```
node not running in distributed mode. Ensure the following exports are
set in your rel/env.sh.eex file
```

That file is what this cartridge owns.

## What it installs

**`rel/env.sh.eex`** — the release's boot script, with the distributed
block appended to Mix's default template:

```sh
# Workbench clustering: boot as a named distributed node.
if [ -z "$RELEASE_NODE" ]; then
  RELEASE_NODE_IP="$(hostname -i 2>/dev/null)"
  RELEASE_NODE_IP="${RELEASE_NODE_IP%% *}"
  export RELEASE_NODE="$RELEASE_NAME@${RELEASE_NODE_IP:-127.0.0.1}"
fi
export RELEASE_DISTRIBUTION=name
```

The node name carries the container IP, which is unknown until the
container runs — that is why it belongs here and not in `runtime.exs`.
DNSCluster dials `<basename>@<ip>` for every IP the query resolves, so
the basename has to be the release name it reads back from `node()`.
POSIX `sh` only: the production runner image has no bash. A
`RELEASE_NODE` provided from outside always wins.

**`rel/vm.args.eex`, `rel/remote.vm.args.eex`, `rel/env.bat.eex`** — the
other three `mix release.init` templates, which have to exist alongside
`env.sh.eex`. They are generated from the *running* Elixir (Mix exposes
the text of each default as a function of the `release.init` task)
instead of being copied into this repo and left to drift, and they land
inside the patch set so they show up in the diff.

**`DNS_CLUSTER_QUERY` in `.env` and `.env.sample`** — the DNS name that
resolves to the replica IPs:

```
# Cluster discovery, queried by DNSCluster (:prod only).
DNS_CLUSTER_QUERY="my_app.default.svc.cluster.local"
```

Default is the Kubernetes form; on Fly.io it is usually
`<app>.internal`. The variable is inert in dev — `runtime.exs` only
reads it under `:prod` — and an unresolvable query is silent: DNSCluster
logs nothing and simply finds no peers.

## Options

| Option | Default |
| --- | --- |
| `--dns-query` | `<app>.default.svc.cluster.local` |

## Variable ownership

`DNS_CLUSTER_QUERY`, `RELEASE_DISTRIBUTION` and `RELEASE_NODE` used to
sit commented out in the `workbench.setup` `.env` template. They live in
this cartridge now, each where it belongs: the query in the environment
files, the release pair in the boot script that can resolve the node name.

## Idempotency

Re-running is a no-op. Existing `rel/*.eex` files are kept untouched, the
distributed block is only appended when its header comment is absent
(Mix's default template already carries a *commented* `export
RELEASE_DISTRIBUTION` sample, which does not count), and the environment
entry is only added when `DNS_CLUSTER_QUERY` is not declared yet.

## Why a workspace cannot cluster with itself

The workspace compose uses the **pod pattern**: `app`, `database` and
`pgadmin` all join the network namespace of a `pause` container
(`network_mode: "service:network"`), which is what lets them reach each
other on `localhost` and keeps Phoenix's default database configuration
untouched. Docker Compose does let you scale a service in that mode, but
the replicas share the namespace — measured with two `alpine` replicas
behind a `pause` container:

```
app-1  | IP=172.25.0.2 HOST=4b2cf11d8563
app-1  | nc: bind: Address in use
app-1  | BIND FAILED
app-2  | IP=172.25.0.2 HOST=4b2cf11d8563
```

Same IP and same hostname for both. So `docker compose up --scale app=N`
gives one replica that works and N-1 that die on the port bind, and every
`RELEASE_NODE` would resolve to the same `<name>@<ip>` — a duplicate node
name that epmd rejects. Nothing to cluster.

Clustering needs the app replicas on a normal bridge network, one IP
each. There Docker's embedded DNS answers with one A record per replica,
which is exactly what `DNS_CLUSTER_QUERY` consumes:

```
--- nslookup app ---
Name: app   Address: 172.25.0.4
Name: app   Address: 172.25.0.3
Name: app   Address: 172.25.0.5
```

(`getent hosts app` returns only one of them — the C library picks a
single address. DNSCluster does not go through NSS: `:inet_res.getbyname/2`
is a real DNS query and sees all three.)

The catch is that leaving the pod means the app no longer reaches
Postgres on `localhost`, which is the whole reason the pod exists. A
clustered deployment is therefore a different compose topology, not a
flag — and it belongs to the workbench script, which bakes the
workspace's `docker-compose.yml` from its seed on every `new`. Anything
this cartridge wrote there would be overwritten on the next creation.

## Seeing it work

That topology is what `./wb.sh up --deploy scaled` deploys: production
replicas behind an nginx balancer, one host port each plus the
balancer's, all sharing the `app` network alias so a single DNS name
answers with every address. `--replicas N` and `--no-balancer` shape what
gets baked.

The deployment does not require this cartridge — replicas behind a
balancer is a valid topology on its own, and the compose is identical
either way. What the cartridge adds lives entirely inside the release
image: without it the release boots with a short name, so the command
warns, leaves `DNS_CLUSTER_QUERY` unset (keeping DNSCluster out of the
supervision tree instead of letting it poll for peers it can never
reach) and the replicas run isolated.

```sh
./wb.sh add clustering
./wb.sh up --deploy scaled
docker compose --file _workspaces/<ws>/docker-compose.scaled.yml \
  exec app1 /app/bin/<app> remote
```

```elixir
iex> node()
:"my_app@172.25.0.4"
iex> Node.list()
[:"my_app@172.25.0.2", :"my_app@172.25.0.3", :"my_app@172.25.0.5"]
```

The balancer is the single entry point; the per-replica ports stay
published so a **specific** node can be addressed, which is what makes
the cross-node behaviour visible — two pages on two replicas, one
broadcast. And the balancing itself needs no project code to observe:
nginx adds `X-Served-By` with the address of the replica that answered,
the same address that appears in its node name.

```sh
curl -sI http://localhost:4000 | grep X-Served-By
```

It has to be a **production** deployment: `rel/env.sh.eex` only runs
from a release's boot script, and `mix phx.server` in dev never touches
it. That is also the easy side — in prod the database address is already
a variable (`DATABASE_URL`), while dev would mean editing the
`hostname: "localhost"` that `phx.new` hardcodes in `config/dev.exs`.

## What clustering is, and is not, for

A cluster is not how a stateless Phoenix app gains capacity. That comes
from N replicas behind a load balancer, and those replicas need not know
each other exists. Distribution buys **coordination** instead:

* `Phoenix.PubSub` across nodes — a user connected to node A receives
  what node B publishes. Without a cluster this needs
  `phoenix_pubsub_redis` and a Redis to go with it.
* `Phoenix.Presence`, a CRDT replicated between nodes.
* Cluster-wide singletons and distributed registries (`:global`, `pg`,
  [Horde](https://hexdocs.pm/horde)).
* Attaching to any node with `bin/<app> remote` and seeing the whole
  cluster from it.

The `--deploy scaled` deployment publishes one host port per replica
precisely because it demonstrates *clustering*, not scaling: there is no
load balancer in front, which a real deployment would have.

## Running more than one replica

Two consequences that have nothing to do with this cartridge's files but
everything to do with deploying what it enables.

**Migrations must be backward compatible.** A rolling deploy runs old
and new code against the same schema for as long as the rollout takes,
so every migration has to work with the *previous* release too. Anything
destructive is split across two deploys — add the column, backfill it,
switch the code, and only then drop the old one. This bites with a
single-node Postgres just the same: it is a consequence of replicating
the application, not of the database's own topology.

**Connections multiply by the replica count.** `phx.new` defaults
production to `POOL_SIZE=10`, so four replicas open forty connections
against a Postgres whose own default `max_connections` is a hundred. The
four of `--deploy scaled` fit comfortably; twenty replicas do not. The
usual answer is PgBouncer in transaction mode — and then Ecto needs
`prepare: :unnamed`, because named prepared statements do not survive
the pooler. The commented `# POOL_SIZE="10"` in `.env` stops being
decorative as soon as the replica count grows.

The one-shot migration step the cluster compose runs before the replicas
start (`rel/overlays/bin/migrate`, from `phx.gen.release`) is the same
pattern every platform uses under a different name: Heroku's release
phase, Fly.io's `release_command`, a Kubernetes `Job` or Helm
`pre-upgrade` hook, an ECS standalone task. It assumes a single logical
primary to migrate, which holds for a primary with read replicas or any
managed Postgres. Sharded or database-per-tenant setups need more: the
generated `Release.migrate/0` iterates over `:ecto_repos`, repos known
at compile time, not tenants resolved at runtime.

## Related

Only the release's boot environment is set up here. For strategies
beyond DNS — gossip, EPMD, Kubernetes API — see
[libcluster](https://hexdocs.pm/libcluster); it plugs into the same
supervision tree and does not conflict with this cartridge.
