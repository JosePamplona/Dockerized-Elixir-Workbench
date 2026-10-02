defmodule ConsoleWeb.DockerScreenTest do
  @moduledoc """
  The containers table's since column: Docker's status line with only
  its time left, whatever the state, since the state and the exit code
  are the state column's and the health is its dot's.
  """
  use ExUnit.Case, async: true

  alias ConsoleWeb.DockerScreen

  test "a running container: the Up and the health go" do
    assert DockerScreen.since(%{state: "running", status: "Up 4 hours (healthy)"}) == "4 hours"
    assert DockerScreen.since(%{state: "running", status: "Up 39 minutes"}) == "39 minutes"
  end

  test "an exited container: the state and the code go, the ago stays" do
    assert DockerScreen.since(%{state: "exited", status: "Exited (0) 7 minutes ago"}) ==
             "7 minutes ago"

    assert DockerScreen.since(%{state: "exited", status: "Exited (137) 36 hours ago"}) ==
             "36 hours ago"
  end

  test "restarting and paused read the same way" do
    assert DockerScreen.since(%{state: "restarting", status: "Restarting (1) 5 seconds ago"}) ==
             "5 seconds ago"

    assert DockerScreen.since(%{state: "paused", status: "Up 2 days (Paused)"}) == "2 days"
  end

  test "a container that never ran has no time" do
    assert DockerScreen.since(%{state: "created", status: "Created"}) == ""
    assert DockerScreen.since(%{state: "created", status: nil}) == ""
  end

  # The events' column of who did it: as wide as the longest name in
  # view, so a container of no service is not broken over its lines.
  describe "the events" do
    import Phoenix.LiveViewTest, only: [render_component: 2]

    defp events(events) do
      dk = %{DockerScreen.initial(events) | doc: "events", scope: "daemon"}
      render_component(&DockerScreen.docker_screen/1, dk: dk, status: nil, jobs: [])
    end

    defp event(fields) do
      Map.merge(
        %{
          type: "container",
          action: "start",
          detail: nil,
          ts: ~U[2026-10-02 18:00:00Z],
          id: "",
          name: nil,
          service: nil,
          project: nil,
          image: nil,
          exit: nil,
          signal: nil
        },
        Map.new(fields)
      )
    end

    test "the column is the longest name's" do
      name = "lorem_ipsum_workbench_term_4163"
      html = events([event(name: name), event(name: "lorem_ipsum_web_1", service: "web")])

      assert html =~ ~s(id="dk-events" style="--svc-w:#{String.length(name)}ch")
    end

    test "with nothing yet it is the stylesheet's" do
      html = events([])

      assert html =~ ~s(id="dk-events")
      refute html =~ "--svc-w"
    end
  end
end
