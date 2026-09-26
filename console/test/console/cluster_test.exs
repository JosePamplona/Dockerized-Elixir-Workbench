defmodule Console.ClusterTest do
  @moduledoc """
  The two questions the cluster's box asks. *Who answers?* is the one
  that goes over the wire, so it is asked here against a server that
  answers as the balancer does — with `x-served-by`, and the second
  time without it.
  """
  use ExUnit.Case, async: true

  alias Console.Cluster

  # A balancer's answer, as `:httpc` hands the headers over: charlists,
  # both sides.
  test "the replica that answered is read off the header nginx adds" do
    assert Cluster.served_by([{~c"server", ~c"nginx"}, {~c"x-served-by", ~c"app2"}]) == "app2"

    # Its name is read whatever case the header comes in.
    assert Cluster.served_by([{~c"X-Served-By", ~c"app4"}]) == "app4"

    # No header, no name: the line above trims the label away.
    assert Cluster.served_by([{~c"server", ~c"nginx"}]) == ""

    # Binaries answer the same, so a change of client does not break it.
    assert Cluster.served_by([{"x-served-by", "app1"}]) == "app1"
  end

  # The whole probe, over the wire: four requests, and the replica each
  # one landed on. It read `to_string(v) |> Enum.join(", ")` until
  # 2026-09-26 — `Enum.join/2` given a binary — so every answer that
  # carried the header raised, and only those; a run against a
  # deployment that was not up never saw it.
  test "four requests, and the replica each one landed on" do
    port = free_port()
    {:ok, _} = serve(port, [{"x-served-by", "app3"}])

    lines = Cluster.answers(port)

    assert length(lines) == 4
    assert Enum.all?(lines, &(&1 == "HTTP 200 · X-Served-By: app3"))
  end

  test "an answer with no x-served-by is the code alone, without a dangling label" do
    port = free_port()
    {:ok, _} = serve(port, [])

    assert Cluster.answers(port) == List.duplicate("HTTP 200", 4)
  end

  test "nothing listening is an answer too, one line per request" do
    lines = Cluster.answers(free_port())

    assert length(lines) == 4
    assert Enum.all?(lines, &String.starts_with?(&1, "no answer: "))
  end

  # A port nobody holds: taken and let go, which is enough for a test
  # that binds it in the next breath.
  defp free_port do
    {:ok, s} = :gen_tcp.listen(0, [:binary, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(s)
    :ok = :gen_tcp.close(s)
    port
  end

  # The balancer, as far as this probe can tell: whatever headers it is
  # given, and 200.
  defp serve(port, headers) do
    plug = fn conn, _opts ->
      conn = Enum.reduce(headers, conn, fn {k, v}, c -> Plug.Conn.put_resp_header(c, k, v) end)
      Plug.Conn.send_resp(conn, 200, "")
    end

    start_supervised({Bandit, plug: plug, port: port, ip: :loopback, startup_log: false})
  end
end
