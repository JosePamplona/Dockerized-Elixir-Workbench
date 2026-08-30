# clustering

Your deployment runs several replicas, and they should act as one.

**Before:** replicas that never see each other: a PubSub per node, a broadcast that reaches one browser in four.

**After:** the release boots as a named node from its own address and `DNSCluster` finds the others through one DNS name; `./wb.sh up --deploy scaled` shows four of them join.

**Not for:** a single workspace — one container has nothing to cluster with; and rolling deploys across images, since the cookie is baked.
