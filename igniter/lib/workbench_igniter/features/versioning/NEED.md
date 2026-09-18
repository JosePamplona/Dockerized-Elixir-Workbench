# versioning

You are about to change something, and there is nowhere to say what changed.

**Before:** the version is `0.1.0` because the generator had to write something, and the history of the project is its git log — which records every commit and answers no question a reader has.

**After:** a version the project chose, and a `CHANGELOG.md` opened at it: an `Unreleased` section to write into as you go, and a template line to uncomment when you cut the release — or `mix version 0.2.0` to do the uncommenting, write the number and refresh the README's badge, if you asked for them.

**Not for:** deciding when `0.1.0` becomes `0.2.0` — the one part of this that cannot be automated; the task writes the number you chose.
