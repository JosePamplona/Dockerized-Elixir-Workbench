# ecto

Your app has data to keep, and it started without a database.

**Before:** an API that computes and forgets, or a repo wired by hand across four config files and a supervision tree, with the tests sharing one database.

**After:** a `Repo` on the adapter you name, migrations under `priv/repo`, the sandbox that isolates every test, `DATABASE_URL` in `.env`, and the workspace's Postgres after `./wb.sh bake`.

**Not for:** changing your mind later — a project with data changes database by migration, not by flag; inserted once.
