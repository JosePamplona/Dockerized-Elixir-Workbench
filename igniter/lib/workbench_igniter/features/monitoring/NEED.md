# monitoring

You want to see what the app is doing over time, not what it did the moment you looked.

**Before:** `./wb.sh logs`, LiveDashboard's live gauges that forget the second you close the tab, and a hunch about last night.

**After:** Grafana on its own port beside the app's, open already, with a dashboard per part of the app — requests, the VM, the database, LiveView — over the last hour, day or week; Prometheus keeps the numbers, and `./wb.sh k6`'s runs land beside them.

**Not for:** logs and traces — this is metrics; nor for a single number now, which LiveDashboard already shows.
