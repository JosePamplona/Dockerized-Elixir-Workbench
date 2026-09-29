# ash

You want a whole framework for your domain, set up the way its own site does it.

**Before:** reading Ash's guides and running a chain of installers by hand, in an order one of them hangs on when it is wrong.

**After:** `--data-layer`, `--api`, `--auth` and the site's six *Advanced Options* sections (`--ai`, `--finance`, `--automation`, `--security`, `--dev-tools`, `--components`): the command ash-hq.org's installer generates for an existing app, queued and run; `mix test --only network:ash_hq` tells you when the site's map moved.

**Not for:** the opinionated line (`new`) — its `users` table and generators fight with Ash's domain; this is a `new2` cartridge.
