defmodule Console.NodesTest do
  use ExUnit.Case, async: true

  alias Console.Nodes

  # A slice of nodejs/Release's schedule.json, as it decodes.
  @schedule %{
    "v22" => %{
      "start" => "2024-04-24",
      "lts" => "2024-10-29",
      "maintenance" => "2025-10-21",
      "end" => "2027-04-30",
      "codename" => "Jod"
    },
    "v23" => %{"start" => "2024-10-16", "maintenance" => "2025-04-01", "end" => "2025-06-01"},
    "v24" => %{
      "start" => "2025-05-06",
      "lts" => "2025-10-28",
      "maintenance" => "2026-10-20",
      "end" => "2028-04-30",
      "codename" => "Krypton"
    },
    "v25" => %{"start" => "2025-10-15", "maintenance" => "2026-04-01", "end" => "2026-06-01"},
    "v26" => %{
      "start" => "2026-05-05",
      "lts" => "2026-10-28",
      "maintenance" => "2027-10-20",
      "end" => "2029-04-30",
      "codename" => ""
    },
    "v27" => %{"alpha" => "2026-10-28", "start" => "2027-04-22", "end" => "2030-04-30"}
  }

  test "the released majors, newest first, each where it stands that day" do
    majors = Nodes.majors(@schedule, ~D[2026-09-28])

    assert Enum.map(majors, &{&1["major"], &1["state"]}) == [
             {"26", "current"},
             {"25", "end of life"},
             {"24", "lts"},
             {"23", "end of life"},
             {"22", "maintenance"}
           ]

    # An LTS line is one from the start, named or not yet; an odd major never is.
    assert Enum.map(majors, & &1["lts"]) == [true, false, true, false, true]
    assert Enum.find(majors, &(&1["major"] == "24"))["codename"] == "Krypton"
    assert Enum.find(majors, &(&1["major"] == "26"))["codename"] == nil
    assert Enum.find(majors, &(&1["major"] == "24"))["until"] == "2028-04-30"
  end

  test "a day moves the lines: before its LTS date a line is current, after its end gone" do
    at = fn day -> Nodes.majors(@schedule, day) |> Map.new(&{&1["major"], &1["state"]}) end

    assert at.(~D[2025-06-01]) == %{
             "22" => "lts",
             "23" => "end of life",
             "24" => "current"
           }

    assert at.(~D[2026-10-28])["26"] == "lts"
    assert at.(~D[2026-10-20])["24"] == "maintenance"
  end
end
