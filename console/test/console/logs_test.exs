defmodule Console.LogsTest do
  use ExUnit.Case, async: true

  alias Console.Logs

  test "parses a compose line into service, timestamp and text" do
    assert %{service: "database", ts: "2026-09-02T20:26:53.674776933Z", text: "LOG:  checkpoint starting"} =
             Logs.parse("database-1  | 2026-09-02T20:26:53.674776933Z LOG:  checkpoint starting")

    assert %{service: "app2", text: "[info] Sent 200 in 1ms"} = Logs.parse("app2-1 | 2026-09-02T20:26:53Z [info] Sent 200 in 1ms")
    assert %{text: ""} = Logs.parse("network-1   | 2026-09-02T09:03:05Z ")
    assert Logs.parse("Attaching to database-1, network-1") == nil
  end

  # With the ansi cartridge in, the app's lines carry escapes: the text
  # is what they say, the html is how they say it.
  test "a coloured line is plain in text and spans in html, and a lone reset is no line" do
    line = Logs.parse("app-1 | 2026-09-04T05:50:09Z \e[33m[warning]\e[0m slow query")
    assert line.text == "[warning] slow query"
    assert line.html == ~s(<span class="ansi-fg-3">[warning]</span> slow query)
    assert Logs.parse("app-1 | 2026-09-04T05:50:09Z \e[0m") == nil
    # A plain line's html is its text, escaped.
    assert %{text: "a <b> & c", html: "a &lt;b&gt; &amp; c"} = Logs.parse("app-1 | 2026-09-04T05:50:09Z a <b> & c")
  end
end
