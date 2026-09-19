# toolchain

You open the project in your editor, on your own machine, and its language server leaves a directory in your `git status`.

**Before:** ElixirLS builds the project into `.elixir_ls/`, beside the source, the first time the editor opens it; the directory shows up as untracked in every `git status` until someone ignores it by hand, in each clone.

**After:** `/.elixir_ls/` in the project's `.gitignore`, under its comment, once.

**Not for:** telling the host which Elixir this is — that is `version_manager`'s, a different tool; and not for other language servers' directories, which this box does not know yet.
