# test_doubles

Your tests must not call the real thing.

**Before:** tests that reach the network, or `with_mock` replacing `File` for the whole VM, which costs the suite its `async: true`.

**After:** Mox for the service you own a contract with, Mimic for the module that is not yours — mocks, stubs and spies, each where it belongs.

**Not for:** factories and fixtures, which build data rather than replace a collaborator: that is exmachina, and what `phx.gen` already writes.
