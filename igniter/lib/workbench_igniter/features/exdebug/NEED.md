# exdebug

You want to look at a value while developing without dressing it up first.

**Before:** `IO.inspect` with a label, again, and a pass to take them all out before the code ships.

**After:** `ExDebug.console/2` anywhere in the pipeline — the value framed with your label, the time and the app, and handed on untouched. It prints in `:dev` and `:test`, so the call can stay where it is.

**Not for:** what production should be told. That is the `Logger`, with a level and a place to go; this one says nothing outside `:dev` and `:test`.
