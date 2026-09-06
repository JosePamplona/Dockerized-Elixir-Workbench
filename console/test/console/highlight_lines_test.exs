defmodule Console.HighlightLinesTest do
  use ExUnit.Case, async: true

  test "cuts a lexed file into one HTML string per line, spans closed on each" do
    {:lexer, lines} =
      Console.Highlight.lines("a.ex", "defmodule A do\n  @doc \"\"\"\n  two\n  \"\"\"\nend\n")

    assert length(lines) == 6
    assert hd(lines) =~ ~s(<span class="kd">defmodule</span>)

    for l <- lines,
        do: assert(length(Regex.scan(~r/<span/, l)) == length(Regex.scan(~r/<\/span>/, l)))
  end

  test "plain and images" do
    assert {:plain, ["&lt;a&gt;", ""]} = Console.Highlight.lines("x.svg", "<a>\n")
    assert :image = Console.Highlight.lines("x.png", "")
  end
end
