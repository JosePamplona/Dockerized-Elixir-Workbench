# coveralls

You want to know where the tests aren't looking.

**Before:** a green suite and no idea which lines it never touched.

**After:** `mix cover`: a percentage, an HTML report — at `/dev/docs/cover` with exdoc — and a minimum the build can refuse to go under.

**Not for:** proving the code is right — coverage says where the tests are, not whether they ask the right questions.
