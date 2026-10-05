defmodule ConsoleWeb.RebindTest do
  @moduledoc """
  The console started for another workspace, or for a project by another
  name. It is the one condition true of the whole console at once —
  every mix and git of a job runs in a container of its own — so it is
  said across the frame, against the band, and not in a note inside the
  rail where it was missed (2026-09-27).

  And nothing is disabled with it: in this state the console works
  whole, only slower.
  """
  use ConsoleWeb.ConnCase

  import Phoenix.LiveViewTest

  # The band alone: the page carries the words `build volumes` in a
  # Terminal title too, and every panel is in the DOM whichever tab is
  # open, so a refute over the whole page proves nothing.
  defp band(html) do
    case Regex.run(~r{<div[^>]*class="rebind".*?</div>\s*</div>}s, html) do
      [found] -> found
      _ -> ""
    end
  end

  defp mounted_for(project, workspace) do
    System.put_env("WORKSPACE_MOUNT", "/app/src")
    System.put_env("WORKSPACE_MOUNT_PROJECT", project)
    System.put_env("WORKSPACE_MOUNT_PATH", workspace)

    on_exit(fn ->
      for k <- ~w(WORKSPACE_MOUNT WORKSPACE_MOUNT_PROJECT WORKSPACE_MOUNT_PATH),
          do: System.delete_env(k)
    end)
  end

  test "with no mount there is no warning: the console runs by hand", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/deploy")
    refute html =~ ~s(class="rebind")
  end

  test "started for another workspace, it says that one is mounted", %{conn: conn} do
    mounted_for("some_other_app", "/somewhere/else")
    {:ok, _view, html} = live(conn, "/deploy")

    said = band(html)
    assert said =~ "/somewhere/else"

    # The consequence first, the mechanism after: it is why a job that
    # took seconds now takes minutes.
    assert said =~ "Jobs run in a container of their own"
    assert said =~ "has that one mounted, not this one"
    assert said =~ "Start again"
    assert said =~ "console up"

    # Not the volumes: this one is not about them. The console has
    # another directory bind-mounted, and no name would fix that.
    refute said =~ "build volumes"
  end

  # The other half, and the one a reader meets after creating a project
  # from the card: same workspace, another name. Here it *is* about the
  # volumes, and the band names the two it holds.
  test "started for another name in this workspace, it names the volumes", %{conn: conn} do
    here = Console.Workbench.workspace()
    mounted_for("some_other_app", here)
    {:ok, _view, html} = live(conn, "/deploy")

    said = band(html)
    assert said =~ "build volumes"
    assert said =~ "some_other_app_build"
    assert said =~ "some_other_app_deps"
    refute said =~ "has that one mounted"
  end

  test "it says it once: the rail's Workspace section no longer repeats it", %{conn: conn} do
    mounted_for("some_other_app", "/somewhere/else")
    {:ok, _view, html} = live(conn, "/deploy")

    [rail] = Regex.run(~r{<aside[^>]*id="rail".*?</aside>}s, html)
    refute rail =~ "Start again"
    refute rail =~ "some_other_app"
  end

  # What the state changes is where a job's mix runs, and nothing else.
  # The screens, their tabs and their verbs stay as they are.
  test "nothing is disabled: the console in this state works whole", %{conn: conn} do
    mounted_for("some_other_app", "/somewhere/else")
    {:ok, _view, warned} = live(conn, "/deploy")

    for k <- ~w(WORKSPACE_MOUNT WORKSPACE_MOUNT_PROJECT WORKSPACE_MOUNT_PATH),
        do: System.delete_env(k)

    {:ok, _view, plain} = live(conn, "/deploy")

    strip = fn html ->
      html
      |> String.replace(~r{<div :?if.*?class="rebind".*?</div>}s, "")
      |> String.replace(~r{<div class="rebind".*?</div>\s*</div>}s, "")
    end

    # The same count of things that can be pressed, warned or not.
    pressable = fn html ->
      length(Regex.scan(~r/aria-disabled="true"/, strip.(html)))
    end

    assert pressable.(warned) == pressable.(plain)
  end
end
