defmodule Console.JobsTest do
  # The queue is one process for the whole console: not async.
  use ExUnit.Case

  alias Console.Jobs

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
