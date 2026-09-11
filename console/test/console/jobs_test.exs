defmodule Console.JobsTest do
  # The queue is one process for the whole console: not async.
  use ExUnit.Case

  alias Console.Jobs

  # A workbench of one script, so a job can run without Docker: it
  # writes what it is told, coloured, and exits how it is told.
  setup do
    dir = Path.join(System.tmp_dir!(), "console-jobs-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    File.write!(Path.join(dir, "wb.sh"), """
    #!/bin/sh
    shift # --yes
    for l in "$@"; do printf '\\033[32m%s\\033[0m\\n' "$l"; done
    echo "WB_ANSI=$WB_ANSI"

    exit ${EXIT:-0}
    """)

    File.chmod!(Path.join(dir, "wb.sh"), 0o755)
    was = System.get_env("WORKBENCH_DIR")
    System.put_env("WORKBENCH_DIR", dir)

    on_exit(fn ->
      if was, do: System.put_env("WORKBENCH_DIR", was), else: System.delete_env("WORKBENCH_DIR")
      File.rm_rf!(dir)
    end)

    :ok
  end

  test "jobs are numbered from 1 in the order asked, whatever their ids" do
    a = Jobs.run({:delete, nil}, ["delete"], confirm: true)
    b = Jobs.run({:delete, nil}, ["delete"], confirm: true)
    on_exit(fn -> Jobs.cancel(a) && Jobs.cancel(b) end)
    [%{id: ^b, n: nb}, %{id: ^a, n: na} | _] = Jobs.list()
    assert is_integer(na) and nb == na + 1
  end

  test "the lines go out in batches as HTML, before the exit, and stay for whoever asks later" do
    Jobs.subscribe()
    id = Jobs.run({:mix, nil}, ["one", "two", "three"])
    assert_receive {:job, %{id: ^id, state: :running}}, 2000
    # The batch: every line, its ANSI turned into spans, from index 0.
    assert_receive {:job_lines, ^id, 0, lines}, 2000
    assert length(lines) == 4
    assert hd(lines) =~ "one"
    # The console asks the workbench for colour: it has no terminal to be asked by.
    assert List.last(lines) =~ "WB_ANSI=always"
    assert hd(lines) =~ "<span"
    refute hd(lines) =~ "\e"
    # The exit comes after the last lines, never before.
    assert_receive {:job, %{id: ^id, state: :done, exit: 0} = job}, 2000
    refute Map.has_key?(job, :lines)
    # A page that missed the batch reads it from the start.
    assert {0, ^lines} = Jobs.lines(id)
    assert {0, []} = Jobs.lines("nobody")
  end

  test "a job asked with confirm: true waits as pending and can be cancelled" do
    Jobs.subscribe()
    id = Jobs.run({:delete, nil}, ["delete"], confirm: true)
    assert_receive {:job, %{id: ^id, state: :pending, kind: {:delete, nil}}}
    assert Enum.find(Jobs.list(), &(&1.id == id)).state == :pending
    refute Jobs.busy?()

    assert :ok = Jobs.cancel(id)
    assert_receive {:job, %{id: ^id, state: :cancelled}}
    # Nothing ran: the workbench was never asked.
    refute Jobs.busy?()
    assert :error = Jobs.cancel(id)
    assert :error = Jobs.confirm(id)
  end
end
