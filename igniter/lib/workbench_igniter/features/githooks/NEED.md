# githooks

You want the checks to run before the commit exists, not after the push.

**Before:** CI catching what a pre-commit hook would have, one push later.

**After:** `git_hooks` running format, tests and credo on commit, configured in the project.

**Not for:** enforcing anything on others — hooks are local to each clone.
