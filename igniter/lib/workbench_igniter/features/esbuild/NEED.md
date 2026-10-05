# esbuild

Your page needs JavaScript, and there is no bundler to write it in.

**Before:** a placeholder `app.js` that is a comment telling you which scripts to copy by hand; no `import`, no LiveView client, no watcher.

**After:** `assets/js/app.js` bundled on every save, `phoenix_html` and `phoenix_live_view` a plain `import` away, one file to ship with `mix assets.deploy`.

**Not for:** a Node toolchain — esbuild's binary comes alone; npm packages are a choice you make afterwards.
