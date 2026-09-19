# version_manager

You have more than one Elixir project on your machine, and they don't all want the same Elixir.

**Before:** your host has one Elixir, the last one you installed; the project from two years ago and the one from this morning share it, and switching between them is something you do by hand, or forget to — until `mix` compiles with the wrong one, or the editor's language server does.

**After:** the file a version manager reads — `.tool-versions` for asdf, which mise reads too, or `mise.toml` if you asked for mise's own — naming this project's Erlang and Elixir. You `cd` into the project and `mix`, `iex` and your editor get its versions; you `cd` into the next one and get that one's. The file travels with the repository, so whoever clones it gets the same.

**Not for:** the container, which takes its stack from the image and never reads this file; and not for installing the versions — `asdf install` or `mise install` on your machine does that, once.
