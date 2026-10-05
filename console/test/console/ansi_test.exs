defmodule Console.ANSITest do
  use ExUnit.Case, async: true

  alias Console.ANSI

  test "escapes the text and turns the workbench's styles into spans" do
    assert ANSI.to_html("plain <b>") == "plain &lt;b&gt;"

    assert ANSI.to_html("\e[1mCommitted\e[0m done") ==
             ~s(<span class="ansi-b">Committed</span> done)

    assert ANSI.to_html("\e[38;5;1mError\e[0m") == ~s(<span class="ansi-fg-1">Error</span>)
    assert ANSI.to_html("\e[4;34mlink\e[0m") == ~s(<span class="ansi-u ansi-fg-4">link</span>)
  end

  test "a background is the text's sixteen, as a class of its own" do
    assert ANSI.to_html("\e[41mX\e[0m") == ~s(<span class="ansi-bg-1">X</span>)
    assert ANSI.to_html("\e[31;44mX\e[0m") == ~s(<span class="ansi-fg-1 ansi-bg-4">X</span>)
    assert ANSI.to_html("\e[104mX\e[0m") == ~s(<span class="ansi-bg-12">X</span>)
    assert ANSI.to_html("\e[48;5;4mX\e[0m") == ~s(<span class="ansi-bg-4">X</span>)
    # The default ground puts it back, and leaves the text's colour.
    assert ANSI.to_html("\e[31;44mX\e[49mY") ==
             ~s(<span class="ansi-fg-1 ansi-bg-4">X</span><span class="ansi-fg-1">Y</span>)
  end

  test "a colour outside the sixteen is not painted, and its parameters are not codes" do
    # 48;5;208 read code by code was 5 (nothing) and 208 (nothing); 48;5;4
    # was an underline, 48;5;1 bold, and an RGB's numbers whatever they fell on.
    assert ANSI.to_html("\e[48;5;208mX\e[0m") == "X"
    assert ANSI.to_html("\e[48;2;31;200;4mX\e[0m") == "X"
    assert ANSI.to_html("\e[38;2;1;4;31mX\e[0m") == "X"
    assert ANSI.to_html("\e[58;5;1mX\e[0m") == "X"
    # What follows the colour is still read.
    assert ANSI.to_html("\e[48;2;31;200;4;1mX\e[0m") == ~s(<span class="ansi-b">X</span>)
    # A ground not painted takes the place of the one before it.
    assert ANSI.to_html("\e[44mX\e[48;5;208mY") == ~s(<span class="ansi-bg-4">X</span>Y)
  end

  test "reverse video changes the two over, the terminal's own for one not set" do
    assert ANSI.to_html("\e[7mX\e[0m") == ~s(<span class="ansi-fg-ground ansi-bg-ink">X</span>)
    assert ANSI.to_html("\e[7;31mX\e[0m") == ~s(<span class="ansi-fg-ground ansi-bg-1">X</span>)
    assert ANSI.to_html("\e[7;44mX\e[0m") == ~s(<span class="ansi-fg-4 ansi-bg-ink">X</span>)
    assert ANSI.to_html("\e[7;31;44mX\e[0m") == ~s(<span class="ansi-fg-4 ansi-bg-1">X</span>)
    assert ANSI.to_html("\e[7mX\e[27mY") == ~s(<span class="ansi-fg-ground ansi-bg-ink">X</span>Y)
  end

  test "the classes come in one order, whatever order the codes came in" do
    assert ANSI.to_html("\e[44;4;31;2;1mX\e[0m") ==
             ~s(<span class="ansi-b ansi-d ansi-u ansi-fg-1 ansi-bg-4">X</span>)
  end

  test "drops what is not a style" do
    assert ANSI.to_html("\e[2K\e[1Gline") == "line"
  end
end
