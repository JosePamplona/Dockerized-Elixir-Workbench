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
end
