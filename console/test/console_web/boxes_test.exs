defmodule ConsoleWeb.BoxesTest do
  @moduledoc """
  The console's boxes follow a rule of three families (2026-09-27, the
  interface inventory): a card frames what is acted on, a sheet is
  what is read and wears no frame, a terminal box frames what came out
  of a process or a file. The two frames are the house's, declared
  once in `assets/design/generated/components.css` — `.card` and
  `.term-box` — and the console names them, never redraws them. Before
  this, `console.css` declared the card four times and the terminal
  box eight, each a copy that drifted on its own; this is the ten-line
  grep that keeps the eleventh from being written.
  """
  use ExUnit.Case, async: true

  @design "../assets/design/generated"
  @served "priv/static/assets/css"
  @console "priv/static/assets/css/console.css"

  @card "border:1px solid var(--line);background:var(--surface);border-radius:3px"
  @term "background:var(--term);color:var(--term-ink);border:1px solid var(--term-line)"

  test "the card and the terminal box are declared once, in the house's components" do
    components = File.read!(Path.join(@served, "components.css"))
    assert length(Regex.scan(~r/^\.card\{/m, components)) == 1
    assert length(Regex.scan(~r/^\.term-box\{/m, components)) == 1
  end

  test "console.css draws neither frame again" do
    css = File.read!(@console)
    refute css =~ @card, "the card's frame is declared in console.css: name .card instead"
    refute css =~ @term, "the terminal box is declared in console.css: name .term-box instead"
    refute css =~ "newcard", "the New Project card's content class is .newproject"
  end

  test "no template writes class=\"card\" by hand: it names the component" do
    written =
      "lib"
      |> Path.join("**/*.ex")
      |> Path.wildcard()
      |> Enum.reject(&String.ends_with?(&1, "components/card.ex"))
      |> Enum.filter(&(File.read!(&1) =~ ~r/class="card[\s"]|"card",/))

    assert written == []
  end

  test "the console serves the design system's projections as build.py wrote them" do
    for file <- ~w(components.css tokens.css) do
      assert File.read!(Path.join(@design, file)) == File.read!(Path.join(@served, file)),
             "#{file} differs from assets/design/generated: run ./assets/design/build.py"
    end
  end
end
