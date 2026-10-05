# mock

Your tests must not call the real service.

**Before:** tests that reach an API, or code that is untestable because it does.

**After:** `Mock` stubs a module for the duration of a test.

**Not for:** OTP 29 and later — `meck` does not compile there; the migration to Mox is pending.
