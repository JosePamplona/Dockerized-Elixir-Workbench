# enhancements

You want the workbench's house conventions in the project from day one.

**Before:** every project deciding its schema base, its helper, its tasks and its first tests on its own.

**After:** `MyApp.Schema`, the helper, `mix db` and `mix version`, and a base test suite that already covers what the setup wired.

**Not for:** the vanilla line — this is the opinionated line's foundation, and `new2` leaves the project stock.
