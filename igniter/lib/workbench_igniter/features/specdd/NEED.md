# specdd

You are handing the project to a coding agent, and the prompt is the only place it learns what it may touch.

**Before:** `AGENTS.md` says how Phoenix is written; what the agent may change, what must hold and where it must stop is retyped in every prompt and lost with it.

**After:** `.specdd/` with the SpecDD rules, a pointer at the top of `AGENTS.md`, and three starting `.sdd` specs — the project, `lib/`, `test/` — that the agent resolves before it edits.

**Not for:** replacing phx.new's usage rules — those say how Elixir is written; specs say what may change and what must hold.
