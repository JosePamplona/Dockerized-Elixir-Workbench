# db_admin

You want to look at the database, not type SQL blind into its shell client.

**Before:** `./wb.sh bash`, then `psql`, `mysql`, `sqlcmd` or `sqlite3`, `\dt` or its cousin, and a query you retype for every table.

**After:** a database admin in the browser, on its own port beside the app's, already open on the project's database: pgAdmin on Postgres, phpMyAdmin on MySQL, Adminer on any of them, CloudBeaver if you want DBeaver's editor and diagrams.

**Not for:** a production database you administer for real — the admins sign in with the development credentials and sit on a published port. Nor for a project without Ecto: there is no database to open.
