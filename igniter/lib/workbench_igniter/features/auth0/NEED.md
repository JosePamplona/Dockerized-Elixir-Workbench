# auth0

Your app needs users who sign in, and you never want to hold a password.

**Before:** rolling your own authentication, or storing password hashes and everything that follows from it.

**After:** Auth0 does identity and issues JWTs; the project gets an Accounts context, a User and a token plug, and never sees a password.

**Not for:** new projects on the vanilla line — the dependencies it rests on are abandoned upstream (config.conf says so); `ash` with `--auth` is the living alternative.
