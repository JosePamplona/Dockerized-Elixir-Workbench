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

  test "drops what is not a style" do
    assert ANSI.to_html("\e[2K\e[1Gline") == "line"
  end
end
