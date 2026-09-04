defmodule ConsoleWeb.JobsScreenTest do
  @moduledoc """
  What a job offers at the foot of its own output, and to whom. A
  failure and a stop offer to run again; a job that ended well offers
  nothing; one waiting for a word or waiting its turn can still be
  dropped; and the one that is running offers to be stopped — but only
  where a run can be signalled at all, and only after the question is
  answered.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  defp screen(jobs, opts \\ []) do
    render_component(&ConsoleWeb.JobsScreen.jobs_screen/1,
      jobs: jobs,
      open: MapSet.new(Enum.map(jobs, & &1.id)),
      now: DateTime.utc_now(),
      words: "[]",
      asking: opts[:asking],
      stoppable: Keyword.get(opts, :stoppable, true)
    )
  end

  defp job(id, state, opts \\ []) do
    %Console.Jobs{
      id: id,
      kind: {:add, "phoenix"},
      args: ["add", "phoenix"],
      cmdline: "./wb.sh --yes add phoenix",
      state: state,
      exit: opts[:exit],
      started_at: DateTime.utc_now(),
      finished_at: DateTime.utc_now()
    }
  end

  test "a failed job offers to run again" do
    html = screen([job("a", :failed, exit: 2)])
    assert html =~ "run it again"
    assert html =~ ~s(phx-click="retry")
    assert html =~ ~s(phx-value-id="a")
  end

  test "the lines are the hook's, not the render's" do
    html = screen([job("d", :running)])
    assert html =~ ~s(id="jl-d")
    assert html =~ ~s(phx-hook="JobLines")
    assert html =~ ~s(phx-update="ignore")
    assert html =~ ~s(data-job="d")
  end

  test "a job that ended well offers nothing" do
    refute screen([job("b", :done, exit: 0)]) =~ "run it again"
  end

  test "a job waiting for a word keeps its own words" do
    html = screen([job("c", :pending)])
    refute html =~ "run it again"
    assert html =~ "run it</button>"
  end

  test "a queued job can be dropped, and says nothing has happened" do
    html = screen([job("e", :queued)])
    assert html =~ "waiting its turn"
    assert html =~ ~s(phx-click="cancel")
    assert html =~ "nothing of it has happened yet"
    refute html =~ "stop it"
  end

  test "the running job offers to stop, and asks before it does" do
    html = screen([job("f", :running)])
    assert html =~ ~s(phx-click="stop_ask")
    refute html =~ ~s(phx-click="stop")

    asked = screen([job("f", :running)], asking: "f")
    assert asked =~ "stop it where it is?"
    assert asked =~ ~s(phx-click="stop")
    assert asked =~ ~s(phx-click="stop_keep")
    refute asked =~ ~s(phx-click="stop_ask")
  end

  test "where nothing can be signalled, nothing is offered" do
    refute screen([job("g", :running)], stoppable: false) =~ "stop it"
  end

  test "a stopped job is not a failed one, and offers to run again" do
    html = screen([job("h", :stopped, exit: 143)])
    assert html =~ "stopped on your word"
    assert html =~ "run it again"
    assert html =~ ">stopped</"
    refute html =~ "exit 143"
  end
end
