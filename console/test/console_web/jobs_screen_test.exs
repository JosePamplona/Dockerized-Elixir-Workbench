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
      n: 7,
      kind: {:add, "phoenix"},
      args: ["add", "phoenix"],
      cmdline: "./wb.sh --yes add phoenix",
      state: state,
      exit: opts[:exit],
      started_at: DateTime.utc_now(),
      finished_at: DateTime.utc_now()
    }
  end

  defp tray(jobs, opts \\ []) do
    render_component(&ConsoleWeb.JobsScreen.tray/1,
      jobs: jobs,
      tab: "deploy",
      open: Keyword.get(opts, :open, false),
      asking: opts[:asking],
      stoppable: Keyword.get(opts, :stoppable, true)
    )
  end

  test "the tray's bar is the fold, and the square beside it puts it away" do
    html = tray([job("a", :done, exit: 0)])
    assert html =~ ~s(phx-click="tray_fold")
    # The chip is the last job's own, as its row wears it.
    assert html =~ ~s(class="chip good">exit 0</span>)

    assert tray([job("a", :failed, exit: 2), job("b", :done, exit: 0)]) =~
             ~s(class="chip bad">exit 2)

    assert html =~ ~s(aria-expanded="false")
    assert html =~ ~s(phx-click="tray_hide")
    refute html =~ ~s(href="/jobs")
    # Folded, the output is not rendered at all: the tray is a bar.
    refute html =~ ~s(id="tray-out")
  end

  test "the tray is on every screen but Jobs, once anything has run, until put away" do
    alias ConsoleWeb.JobsScreen
    jobs = [job("a", :done, exit: 0)]

    for tab <- ~w(deploy shelf project docker cluster),
        do: assert(JobsScreen.tray_shown?(tab, jobs))

    refute JobsScreen.tray_shown?("jobs", jobs)
    refute JobsScreen.tray_shown?("deploy", [])
    refute JobsScreen.tray_shown?("deploy", jobs, true)
  end

  test "open, the tray reads the last job under the bar, with the grip above it" do
    html = tray([job("a", :failed, exit: 2), job("b", :done, exit: 0)], open: true)
    assert html =~ ~s(id="tray-out")
    assert html =~ ~s(aria-expanded="true")
    # The last job is the first of the list, and its lines pane is the
    # tray's own: the Jobs screen shows the same job under `jl-`.
    assert html =~ ~s(id="tr-a")
    refute html =~ ~s(id="tr-b")
    # Its words about itself come with it.
    assert html =~ "run it again"
    # The bar is pinned to the foot, so the edge that moves is the top.
    assert html =~ ~s(data-grip="up")
  end

  test "with nothing run yet the bar folds nothing" do
    html = tray([])
    refute html =~ ~s(phx-click="tray_fold")
    refute html =~ ~s(id="tray-out")
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

  test "a job wears its number, on its row and on the tray's bar" do
    assert screen([job("a", :done, exit: 0)]) =~ ~s(>#7</span>)
    assert tray([job("a", :done, exit: 0)]) =~ ~s(>#7</span>)
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
