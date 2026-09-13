defmodule ConsoleWeb.ShelfTest do
  @moduledoc """
  The shelf reads one state at a time — inserted, on the shelf, not
  done — and *Inserted* is the one with more to say: the row the Record
  paper used to draw, with where the cartridge came from, the
  parameters it was installed with and the addresses it opens.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  defp entry(name, opts \\ []) do
    %{
      "name" => name,
      "summary" => "What #{name} is",
      "pending" => Keyword.get(opts, :pending, false),
      "base" => Keyword.get(opts, :base, false),
      "collection" => Keyword.get(opts, :collection, false),
      "covers" => %{"front" => opts[:cover]},
      "options" => [],
      "version" => nil
    }
  end

  defp status(installed) do
    %{
      "exists" => true,
      "compose_project" => "lorem_ipsum",
      "ports" => %{"app" => 4000},
      "containers" => [],
      "project" => %{
        "cartridges" =>
          for(n <- installed, do: %{"name" => n, "installed" => true, "params" => %{}})
      }
    }
  end

  defp shelf(catalog, status, opts) do
    render_component(&ConsoleWeb.Shelf.shelf/1,
      catalog: catalog,
      status: status,
      filter: Keyword.fetch!(opts, :filter),
      view: Keyword.get(opts, :view, "covers"),
      tab: "shelf",
      reads: %{}
    )
  end

  defp catalog, do: [entry("ecto", base: true), entry("adminer"), entry("k6", pending: true)]

  test "the ribbon is the state, and counts it" do
    html = shelf(catalog(), status(["ecto"]), filter: "shelf")
    assert html =~ ~r{Inserted.*?1}s
    assert html =~ ~r{On the shelf.*?1}s
    assert html =~ ~r{Not done.*?1}s
  end

  test "one state at a time: the shelf shows what the ribbon picked" do
    html = shelf(catalog(), status(["ecto"]), filter: "shelf")
    assert html =~ "adminer"
    refute html =~ ">ecto<"
    refute html =~ "k6"

    html = shelf(catalog(), status(["ecto"]), filter: "pending")
    assert html =~ "k6"
    refute html =~ "adminer"
  end

  test "what a cartridge is stays a fact on the box, where the ribbon no longer asks it" do
    html = shelf(catalog(), status([]), filter: "shelf")
    assert html =~ "base"
  end

  test "Inserted, in list, is the Record's row: parameters and addresses" do
    html = shelf(catalog(), status(["ecto"]), filter: "in", view: "list")
    assert html =~ "installation parameters"
    assert html =~ "addresses"
    assert html =~ "Knock on every door"
    assert html =~ ~s(<table class="wide carts">)
  end

  test "a row of the Inserted table is not a link: the doors and the verb in it are" do
    html = shelf(catalog(), status(["ecto"]), filter: "in", view: "list")
    assert html =~ ~s(<tr class="in">)
    refute html =~ ~r{<a[^>]*class="lrow}
  end

  test "On the shelf and Not done, in list, read in Inserted's table, with an Insert each" do
    for filter <- ["shelf", "pending"] do
      html = shelf(catalog(), status(["ecto"]), filter: filter, view: "list")
      assert html =~ ~s(<table class="wide carts">)
      assert html =~ "<th>facts</th>"
      assert html =~ "installation parameters"
      assert html =~ "addresses"
      refute html =~ "Knock on every door"
      # A row carries a verb now, so it is not a link: the mention opens the box.
      refute html =~ ~r{<a[^>]*class="lrow}
      assert html =~ ~r{<a[^>]*class="btn primary"[^>]*>\s*Insert\s*</a>}
      # Insert runs nothing here: it leads to the box's Installation screen.
      refute html =~ ~s(phx-value-args="add )
    end

    html = shelf(catalog(), status(["ecto"]), filter: "shelf", view: "list")
    assert html =~ ~s(href="/shelf?box=adminer&amp;screen=install")

    # A box without an installer leads there too: the screen says so.
    html = shelf(catalog(), status(["ecto"]), filter: "pending", view: "list")
    assert html =~ ~s(href="/shelf?box=k6&amp;screen=install")
  end

  test "an Inserted row ejects by its commit, and is unlit without one" do
    born = status(["ecto"])
    html = shelf(catalog(), born, filter: "in", view: "list")
    assert html =~ ">Eject</button>"
    assert html =~ "no commit to revert"
    refute html =~ ~s(phx-value-args="eject ecto")

    inserted =
      put_in(born, ["git"], %{
        "clean" => true,
        "inserts" => [%{"feature" => "ecto", "sha" => "abc1234def", "subject" => "Insert ecto"}]
      })

    html = shelf(catalog(), inserted, filter: "in", view: "list")
    assert html =~ ~s(phx-value-args="eject ecto")
    assert html =~ "git revert abc1234"
  end

  test "a cartridge on the shelf says what it takes, typed, and what it would open, shut" do
    health =
      Map.merge(entry("healthcheck"), %{
        "options" => [
          %{"name" => "endpoint", "type" => "string", "default" => "/health", "choices" => []}
        ],
        "console" => %{"doors" => [%{"label" => "health", "path" => "{endpoint}"}]}
      })

    html = shelf([health], status([]), filter: "shelf", view: "list")
    assert html =~ "--endpoint"
    assert html =~ ~s(<i class="val">string</i>)
    assert html =~ "default /health"
    assert html =~ "/health"
    assert html =~ "not inserted"
  end

  test "a parameter with choices shows them in place of its type, four and the count" do
    values = for v <- ~w(postgres mysql mssql sqlite3 other), do: %{"value" => v, "doc" => nil}

    ecto =
      Map.put(entry("ecto"), "options", [
        %{"name" => "database", "type" => "string", "default" => "postgres", "choices" => values},
        %{"name" => "with", "type" => "csv", "choices" => Enum.take(values, 2), "open" => true}
      ])

    html = shelf([ecto], status([]), filter: "shelf", view: "list")
    assert html =~ "postgres | mysql | mssql | sqlite3 +1"
    assert html =~ "postgres | mysql …"
    assert html =~ "one of, or another postgres, mysql"
    refute html =~ ~s(<i class="val">string</i>)
  end

  test "Inserted, in covers, is the boxes: they are the boxes wherever they stand" do
    html = shelf(catalog(), status(["ecto"]), filter: "in", view: "covers")
    refute html =~ "installation parameters"
    assert html =~ "box"
  end

  test "without a project it opens on the shelf, and with one on what it carries" do
    assert ConsoleWeb.Shelf.first_doc(nil, catalog()) == "shelf"
    assert ConsoleWeb.Shelf.first_doc(status([]), catalog()) == "shelf"
    assert ConsoleWeb.Shelf.first_doc(status(["ecto"]), catalog()) == "in"
  end
end
