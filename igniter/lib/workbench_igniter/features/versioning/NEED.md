# versioning

Your project has a version number, and no versioning: nobody can say what changed between one build and the next.

**Before:** `mix.exs` says `0.1.0` and has said it since the generator wrote it — maybe for years, maybe in production. What a given build carries, and what changed since the one that worked, is in the git log, which records every commit and answers no question a reader has.

**After:** a `CHANGELOG.md` opened at the version the project is on today — new or well under way, `mix.exs` is left as it is — with an `Unreleased` section to write into as you go and a template line to uncomment when you cut a release. If you asked for them: `mix version 0.2.0` to do the cutting (the number, the changelog, the README's badge), and that badge.

**Not for:** deciding when `0.1.0` becomes `0.2.0` — the one part of this that cannot be automated — nor for generating the changelog out of commit messages; this one is written by hand, for whoever reads it.
