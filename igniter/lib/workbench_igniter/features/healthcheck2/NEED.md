# healthcheck2

Your platform polls the app, and the answer decides whether it restarts it or diverts traffic.

**Before:** one route answering both questions the same way — restarting on a database outage, or passing a probe through a redirect.

**After:** `/health/live` and `/health/ready` as the first plug of the endpoint: alive if the VM answers, ready if the repo does, within a second.

**Not for:** humans reading a body — it says `ok` or `unavailable`; the JSON is `healthcheck`'s.
