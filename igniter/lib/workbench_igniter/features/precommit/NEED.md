# precommit

You want the checks to run before the commit exists, not after the push.

**Before:** the build going red twenty minutes later over a file nobody formatted, and no way to run the checks locally without an Elixir on your machine.

**After:** a hook that runs the project's own checks in the project's own container, refuses the commit on the first failure, and is a shell script you can read and reorder.

**Not for:** making anyone else run them — a hook lives in one clone and `--no-verify` skips it. What must hold for everybody belongs in CI.
