defmodule ConsoleWeb.BoxSectionTest do
  @moduledoc """
  A section's name in a box's form, pressed in the console itself: the
  event reaches the box in hand, and the form comes back with the
  section ticked and the command saying so.
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

  defp pieces do
    value = &%{"value" => &1, "doc" => nil, "requires" => []}

    %{
      "name" => "pieces",
      "summary" => "A box of pieces",
      "pending" => false,
      "base" => false,
      "collection" => false,
      "covers" => %{"front" => nil},
      "requires" => [],
      "version" => nil,
      "options" => [
        %{
          "name" => "components",
          "type" => "csv",
          "multiple" => true,
          "choices" => [
            %{"group" => "general", "values" => Enum.map(~w(card badge), value)},
            %{"group" => "forms", "values" => Enum.map(~w(text_field url_field), value)}
          ]
        }
      ]
    }
  end

  defp arrives(reading) do
    Console.Bench.subscribe()
    send(Process.whereis(Console.Bench), {make_ref(), reading})
    assert_receive {:bench, _, _}
  end

  setup do
    arrives({:status, {:ok, status()}})
    arrives({:catalog, {:ok, [pieces()]}})
    :ok
  end

  test "pressed, a section is ticked whole; pressed again, cleared", %{conn: conn} do
    {:ok, view, _} = live(conn, "/deploy?box=pieces&screen=install")

    html = render_click(view, "section", %{"option" => "components", "group" => "forms"})
    assert html =~ ~r{forms\s*<span class="n">2 of 2</span>}
    assert html =~ ~r{general\s*<span class="n">0 of 2</span>}
    assert html =~ "--components text_field,url_field"

    html = render_click(view, "section", %{"option" => "components", "group" => "forms"})
    assert html =~ ~r{forms\s*<span class="n">0 of 2</span>}
    refute html =~ "--components text_field"
  end
end
