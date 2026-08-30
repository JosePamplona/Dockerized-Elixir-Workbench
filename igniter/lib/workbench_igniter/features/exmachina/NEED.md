# exmachina

Your tests need realistic records, in one line each.

**Before:** hand-built maps and inserts repeated in every test.

**After:** ExMachina factories: `insert(:user)` with sensible defaults, overridable.

**Not for:** production data — factories are for tests.
