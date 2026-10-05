defmodule Console.HexTest do
  @moduledoc """
  What hex says of a package, and how long ago it said it. The fetch
  itself is not exercised here — it is `:httpc` against hex.pm, which a
  test has no business calling — so what is held is the reading of an
  answer and the words for a distance in time.
  """
  use ExUnit.Case, async: true

  alias Console.Hex

  describe "ago/2" do
    @now ~U[2026-09-23 12:00:00Z]

    test "the distance in the words the console uses" do
      assert Hex.ago("2026-09-23T06:00:00.000000Z", @now) == "today"
      assert Hex.ago("2026-09-22T06:00:00.000000Z", @now) == "yesterday"
      assert Hex.ago("2026-09-10T06:00:00.000000Z", @now) == "13 days ago"
      assert Hex.ago("2026-03-23T06:00:00.000000Z", @now) == "6 months ago"
      assert Hex.ago("2025-01-26T06:21:19.157107Z", @now) == "a year ago"
      assert Hex.ago("2022-01-11T06:00:00.000000Z", @now) == "4 years ago"
    end

    test "a date hex did not give is no date" do
      assert Hex.ago(nil, @now) == nil
      assert Hex.ago("the day before", @now) == nil
    end
  end

  describe "read/2" do
    # hex's own answer, cut to what is read out of it: the shape the
    # package endpoint returns, captured on 2026-09-23. The call is a
    # function `read/2` takes, so the suite holds the reading without
    # ever telling hex.pm that it ran.
    @answer ~s({
      "name": "excoveralls",
      "latest_stable_version": "0.18.5",
      "latest_version": "0.18.5",
      "downloads": {"all": 97802365, "day": 32723, "recent": 1659997, "week": 157195},
      "releases": [
        {"version": "0.18.5", "inserted_at": "2025-01-26T06:21:19.157107Z"},
        {"version": "0.18.4", "inserted_at": "2025-01-18T10:50:18.527063Z"}
      ]
    })

    defp answering(bodies) do
      fn url ->
        name = url |> String.split("/") |> List.last()

        case bodies[name] do
          nil -> {:error, "hex.pm has no such package"}
          body -> {:ok, body}
        end
      end
    end

    test "the latest stable release, the day it was published, and the downloads" do
      readings = Hex.read(["excoveralls"], answering(%{"excoveralls" => @answer}))

      assert readings == %{
               "excoveralls" => %{
                 latest: "0.18.5",
                 released_at: "2025-01-26T06:21:19.157107Z",
                 downloads: 97_802_365,
                 recent: 1_659_997
               }
             }
    end

    test "the date is the release's own, not the package's last change" do
      # A package whose newest release is a pre-release keeps the date
      # of the stable one the reader is told about.
      answer =
        String.replace(
          @answer,
          ~s("releases": [),
          ~s("releases": [{"version": "0.19.0-rc.1", "inserted_at": "2026-09-01T00:00:00Z"},)
        )

      assert %{"excoveralls" => %{latest: "0.18.5", released_at: "2025-01-26" <> _}} =
               Hex.read(["excoveralls"], answering(%{"excoveralls" => answer}))
    end

    test "a package hex does not answer for carries its reason, and the rest are still read" do
      readings =
        Hex.read(["excoveralls", "no_such_package"], answering(%{"excoveralls" => @answer}))

      assert %{latest: "0.18.5"} = readings["excoveralls"]
      assert readings["no_such_package"] == %{error: "hex.pm has no such package"}
    end

    test "an answer that is not a package, and one with no stable release" do
      bodies = %{"a" => "not json at all", "b" => ~s({"name": "b", "releases": []})}
      readings = Hex.read(["a", "b"], answering(bodies))

      assert readings["a"] == %{error: "hex.pm answered something that is not a package"}
      assert readings["b"] == %{error: "hex.pm publishes no stable release of it"}
    end

    test "nothing asked for is nothing read" do
      assert Hex.read([], fn _url -> flunk("nobody should be asked") end) == %{}
    end
  end
end
