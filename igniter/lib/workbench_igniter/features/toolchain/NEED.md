# toolchain

You open the project in your editor, on your own machine, and nothing there knows which Elixir this is.

**Before:** the container has the right stack and your host has whatever it has; the language server picks the wrong version, `mix` in your shell disagrees with `./wb.sh mix`, and `.elixir_ls/` keeps showing up in `git status`.

**After:** a `.tool-versions` naming the Elixir and Erlang the workspace actually runs — read straight off the toolchain that installs it, so it cannot drift — and the language server's cache ignored by git.

**Not for:** the container, which takes its stack from the image and never reads this file; and not for `mix.exs`, whose `elixir:` line is a requirement range, not a pin.
