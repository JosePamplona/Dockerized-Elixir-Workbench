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
end
