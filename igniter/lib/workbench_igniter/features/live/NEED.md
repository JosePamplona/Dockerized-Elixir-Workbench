# live

Your page should react without reloading.

**Before:** html with its `LiveSocket` lines written but commented out; every click a full request; no `phx-click`, no JS commands.

**After:** the `/live` socket connected on load, `phx-click` on the flash and the theme toggle, `show`/`hide` commands, a LiveView mountable from the router.

**Not for:** a project without esbuild — the client lives in `app.js`, and without a bundler there is nothing in the browser to connect; the insert says so.
