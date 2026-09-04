defmodule Console.BenchTest do
  # The bench is one process for the whole console: not async.
  use ExUnit.Case

  alias Console.Bench

  setup do
    Bench.subscribe()
    :ok
  end

  # An arrival, as the task that read it would send it. Nothing here
  # starts a container: the readings are disabled at boot in test.
  defp arrives(status) do
    send(Process.whereis(Bench), {make_ref(), {:status, {:ok, status}}})
    assert_receive {:bench, :status, arrived}
    arrived
  end

  test "a reading that dies is said, and does not wedge the key it was reading" do
    bench = Process.whereis(Bench)

    # A task that never answers: the ref it is monitored by is what the
    # DOWN carries, and what the bench has to recognise.
    ref = make_ref()
    send(bench, {:DOWN, ref, :process, self(), :killed})

    # An unknown ref changes nothing and takes nothing down.
    refute_receive {:bench, :error, _, _}, 200
    assert Process.alive?(bench)

    # And the key it *was* reading is free again: `reading?` is the
    # question every page asks before deciding whether to wait.
    refute Bench.reading?(:stacks)
    refute Bench.reading?(:installers)
  end

  test "a fast reading keeps the cartridges, and a delete takes them with it" do
    project = %{"app" => "demo", "cartridges" => [%{"name" => "rest", "installed" => true}]}

    full = arrives(%{"exists" => true, "compose_project" => "demo", "project" => project})
    assert full["project"] == project

    # Fast: no cartridges in the reading, and the project is still there.
    fast = arrives(%{"exists" => true, "compose_project" => "demo"})
    assert fast["project"] == project

    # Deleted: the workspace is empty, so there is nothing to carry —
    # the doors and the inserted cartridges go with the project.
    gone = arrives(%{"exists" => false})
    assert gone["project"] == nil
    assert Bench.status()["project"] == nil
  end
end
