# ansi

You read the application's logs through Docker, and everything comes out the same shade of grey.

**Before:** Elixir sees no terminal on the other side of the container and turns colour off, so the `[info]` and the `[error]` look alike in a wall of output.

**After:** one line in `config.exs`, and the levels, the SQL and the stack traces come out coloured wherever you read them — `./wb.sh logs`, `iex`, the console.

**Not for:** colouring what the runtime does not colour already; it lifts Elixir's own decision, it does not add formatting.
