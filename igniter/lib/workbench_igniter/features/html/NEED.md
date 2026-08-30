# html

Your API needs a page.

**Before:** JSON only: no layouts, no components, no browser pipeline, and `phx.gen.html` generating files that cannot compile.

**After:** `/` with a home page, a root layout and `Layouts.app`, the core components, HTML error pages, the browser pipeline with session and CSRF, live reload — the page a `phx.new` project is born with.

**Not for:** LiveView — that is `live`, on top of this; and styling, which is `tailwind`.
