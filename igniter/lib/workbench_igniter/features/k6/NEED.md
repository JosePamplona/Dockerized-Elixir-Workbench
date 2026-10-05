# k6

You want to know what the app does under load before someone else finds out.

**Before:** a browser, F5, and a guess.

**After:** `./wb.sh k6` puts virtual users on the deployment that is up — dev, the release, or the replicas behind the balancer — and reports latencies and failures; `k6/smoke.js` is yours to grow.

**Not for:** unit or integration tests — those are `mix test`'s; k6 measures the running system from outside.
