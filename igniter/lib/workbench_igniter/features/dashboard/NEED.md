# dashboard

Something is slow in dev and you're guessing.

**Before:** logs, `:observer` if you remember how to start it, a hunch about which process it is.

**After:** `/dev/dashboard` — processes, memory, ETS, every request timed, the repo's queries when there is one — live in the browser, on the `/live` socket, only in dev.

**Not for:** production monitoring — it has no authentication and stays behind `dev_routes`.
