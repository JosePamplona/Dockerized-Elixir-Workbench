defmodule ConsoleWeb.BackTest do
  @moduledoc """
  A box, or the workbench drawer, opens over the screen the reader is
  on, and the screen keeps its place under it: on Project, the paper
  and the commit open on it. Put back and Close come back to that place.
  """
  # The bench is one process for the whole console: these drive it.
  use ConsoleWeb.ConnCase

  import Phoenix.LiveViewTest

  defp status do
    %{
      "exists" => true,
      "compose_project" => "lorem_ipsum",
      "workspace" => "/w",
      "deployment" => nil,
      "baked" => %{},
      "ports" => %{},
      "git" => %{
        "repo" => true,
        "clean" => true,
        "head" => "abc1234",
        "identity" => "The Workbench <wb@example>",
        "inserts" => []
      },
      "containers" => [],
      "project" => %{"cartridges" => []}
    }
  end

  defp k6 do
    %{
      "name" => "k6",
      "summary" => "What k6 is",
      "pending" => false,
      "base" => false,
      "collection" => false,
      "covers" => %{"front" => nil},
      "options" => [],
      "requires" => [],
      "version" => nil
    }
  end

  defp arrives(reading) do
    Console.Bench.subscribe()
    send(Process.whereis(Console.Bench), {make_ref(), reading})
    assert_receive {:bench, _, _}
  end

  setup do
    arrives({:status, {:ok, status()}})
    arrives({:catalog, {:ok, [k6()]}})
    :ok
  end

  test "a cartridge pressed on History opens its box over History, and Put back returns there",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/project?paper=history&commit=abc1234")

    render_click(view, "open", %{"name" => "k6"})
    assert_patch(view, "/project?paper=history&commit=abc1234&box=k6")

    html = render(view)
    assert html =~ ~s(aria-label="The box in hand")
    assert html =~ ~s(href="/project?paper=history&amp;commit=abc1234")

    render_click(view, "close", %{})
    assert_patch(view, "/project?paper=history&commit=abc1234")
  end

  test "the box's manual names its paper in the same key, and History stays under it",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/project?paper=history&commit=abc1234")

    render_click(view, "open", %{"name" => "k6"})
    assert_patch(view, "/project?paper=history&commit=abc1234&box=k6")

    # The ribbon's Manual link names the box's paper; the project's is left out of the URL, not overwritten.
    view
    |> element(~s(a[href="/project?commit=abc1234&box=k6&screen=manual&paper=readme"]))
    |> render_click()

    assert_patch(view, "/project?commit=abc1234&box=k6&screen=manual&paper=readme")

    # Put back still goes to History with its commit: the paper under the box was never readme.
    html = render(view)
    assert html =~ ~s(href="/project?paper=history&amp;commit=abc1234")
    render_click(view, "close", %{})
    assert_patch(view, "/project?paper=history&commit=abc1234")
  end

  test "the workbench drawer opens over the paper and Close comes back to it", %{conn: conn} do
    {:ok, view, _} = live(conn, "/project?paper=history")

    view |> element(~s(a[href="/project?paper=history&wb=config"])) |> render_click()
    assert_patch(view, "/project?paper=history&wb=config")

    # The ribbon's Manual names `paper` for the workbench, once; History stays under it.
    [manual] =
      Regex.run(~r{href="(/project\?wb=manual&amp;paper=[^"]+)"}, render(view),
        capture: :all_but_first
      )

    manual = String.replace(manual, "&amp;", "&")
    view |> element(~s(a[href="#{manual}"])) |> render_click()
    assert_patch(view, manual)

    html = render(view)
    assert html =~ ~s(href="/project?paper=history")
    render_click(view, "close", %{})
    assert_patch(view, "/project?paper=history")
  end
end
