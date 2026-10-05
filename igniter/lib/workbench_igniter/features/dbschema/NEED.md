# dbschema

You have a diagram of the database on your machine, and nobody else can see it.

**Before:** the model lives in DbSchema on your desktop. When somebody asks what the `users` table holds, you open the tool, take a screenshot, and paste it into a chat where it goes stale the same week.

**After:** the model is a page of the project's own documentation, with the diagram in the reader's theme and every table written out — columns, types, keys, the foreign keys read as the tables they point at. You export from DbSchema over `assets/db_schema/`, run `mix db`, and the page is current again.

**Not for:** a project whose schema is its source of truth and already draws itself — Ash, or `ecto.dump`. Nor for a database you do not model in DbSchema: the box formats that tool's export and nothing else.
