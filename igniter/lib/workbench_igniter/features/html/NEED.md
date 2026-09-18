# html

Your API needs a page.

**Before:** JSON only: no layouts, no components, no browser pipeline, and `phx.gen.html` generating files that cannot compile.

**After:** `/` with a home page, a root layout and `Layouts.app`, the core components, HTML error pages, the browser pipeline with session and CSRF, live reload — the page a `phx.new` project is born with; and LiveView on it, the `/live` socket connected on load, `phx-click`, the `show`/`hide` commands, unless you say `--no-live`.

**Not for:** styling, which is `tailwind`; and the LiveView client on a project without esbuild — the socket lives in `app.js`, and without a bundler nothing in the browser connects.
