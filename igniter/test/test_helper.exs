# A phx.new project held in memory, for the tests of what the cartridges
# do to one: phx.new's own output (`PhxDelta.generate/1`), with the
# sources loaded — Igniter's test-mode glob does not match the relative
# patterns its module search uses, so without this the project's modules
# (the router, the web module) would be invisible to it.
defmodule WorkbenchIgniter.TestProject do
  @flags ~w(--app test --module Test --database postgres --adapter bandit)

  @doc "`flags` are added to the defaults, or replace them when they carry --app."
  def new(flags \\ [], files \\ %{}) do
    flags = if "--app" in flags, do: flags, else: @flags ++ flags

    Igniter.new()
    |> Igniter.assign(:test_mode?, true)
    |> Igniter.assign(:test_files, Map.merge(WorkbenchIgniter.PhxDelta.generate(flags), files))
    |> Igniter.include_glob("**/*.{ex,exs}")
  end
end

ExUnit.start()
