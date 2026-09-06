defmodule ConsoleWeb.TabsTest do
  @moduledoc """
  The row of screens, and the pulses on it. A pulse means the same thing
  on both tabs that have one: something is happening on that screen right
  now — a job running, a container writing lines.
  """
  # The bench is one process for the whole console: these drive it.
  use ConsoleWeb.ConnCase

  import Phoenix.LiveViewTest

  defp status(containers) do
    %{
      "exists" => true,
      "compose_project" => "lorem_ipsum",
      "workspace" => "/w",
      "deployment" => nil,
      "baked" => %{},
      "ports" => %{},
      "git" => %{"repo" => false},
      "containers" => containers
    }
  end

  defp arrives(status) do
    Console.Bench.subscribe()
    send(Process.whereis(Console.Bench), {make_ref(), {:status, {:ok, status}}})
    assert_receive {:bench, :status, _}
  end

  defp logs_tab(html) do
    [tab] = Regex.run(~r{<a[^>]*>\s*Logs.*?</a>}s, html)
    tab
  end

  defp running(service), do: %{"Service" => service, "State" => "running", "Image" => "x:local"}
  defp exited(service), do: %{"Service" => service, "State" => "exited", "Image" => "x:local"}

  test "the Logs pulse follows the containers, not the reader's own follow flag", %{conn: conn} do
    arrives(status([running("app")]))
    {:ok, _view, html} = live(conn, "/deploy")
    assert logs_tab(html) =~ ~s(class="live")

    arrives(status([exited("app")]))
    {:ok, _view, html} = live(conn, "/deploy")
    refute logs_tab(html) =~ ~s(class="live")

    # A container that is not the app writes lines just the same.
    arrives(status([running("database")]))
    {:ok, _view, html} = live(conn, "/deploy")
    assert logs_tab(html) =~ ~s(class="live")
  end

  test "the Docker screen is lit before any project is, and opens on its containers", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/docker")
    [tab] = Regex.run(~r{<a[^>]*>\s*Docker.*?</a>}s, html)
    assert tab =~ ~s(aria-selected="true")
    [doc] = Regex.run(~r{<a[^>]*href="/docker\?doc=containers"[^>]*>}, html)
    assert doc =~ ~s(aria-selected="true")
    assert html =~ "The daemon"
  end

  test "the Git screen is unlit without a project, and says why", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/deploy")
    [tab] = Regex.run(~r{<button[^>]*>\s*Git\s*</button>}s, html)
    assert tab =~ ~s(aria-disabled="true")
    # Whichever status a test before this one left on the bench, the reason is there.
    assert tab =~ "no project" or tab =~ "no repository"
  end

  test "no containers at all is no pulse", %{conn: conn} do
    arrives(status([]))
    {:ok, _view, html} = live(conn, "/deploy")
    refute logs_tab(html) =~ ~s(class="live")
  end
end
