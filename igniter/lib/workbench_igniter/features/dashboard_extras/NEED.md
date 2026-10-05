# dashboard_extras

Your dashboard has two pages that show nothing until you install something: the machine's, and the database's.

**Before:** OS Data greyed out with an *Enable* link, Ecto Stats telling you to install a library; `top` in another terminal, and for the database the catalog queries you look up every time — which index is never used, who holds the lock, what is bloated.

**After:** both pages lit in LiveDashboard: CPU load, memory and disks; index usage, locks, cache hits, table sizes, long-running queries — for the database your project is on, Postgres, MySQL or SQLite.

**Not for:** SQL Server — LiveDashboard has no stats for it, and you get the machine's page alone. Nor for history: both pages show the moment you look; what the app does over time is metrics' job.
